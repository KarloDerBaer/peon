'use strict';
// Peon Manager - Pakete im Markttausch (ab Manager 0.53.0, Konzept docs/konzepte/broker/Peon_Broker_Pakete.md Abschnitt 3).
// Je Richtung ein Paket aus mehreren kleinen Angeboten, das Risiko streut. Es muss Gewinn machen, wenn nur der Anteil
// safe der Angebote verkauft wird: vorsichtig gerechnet verkaufen sich genau die schlechtesten, die uebrigen bleiben liegen
// und zaehlen mit 0. Abgezogen werden der ganze Einsatz, der Anteil des Zielhauses (steckt im Netto der Chance) und die
// Einstellgebuehren aller Angebote, auch der nicht verkauften.

const DEP_PCT = 0.05, DEP_FACTOR = 4;   // wie compare.js (Broker D.Deposit, 8 Std.)
const PER_CAT = 3;                      // hoechstens so viele Angebote je Kategorie
const MAX_SHARE = 0.25;                 // ein Angebot hoechstens so viel vom Einsatz (Streuung)
const DEFAULT_GOLD = 250000;            // ohne Ledger: hoechstens 25 Gold Einsatz
const SEEDS = 30;                       // so viele Startangebote probieren
const MIN_OFFERS = 4;                   // darunter ist es kaum gestreut

function deposit(vendor, qty) {
  return vendor > 0 ? Math.floor(vendor * DEP_PCT) * DEP_FACTOR * qty : 0;
}

// Angebot aus einer Chance. info = { commodity, stack, cls, vendor }. Rueckgabe null, wenn nicht geeignet
function offerOf(c, info, ru, cut = 0.05) {
  const commodity = !!(info && info.commodity);
  let qty = 1;
  if (commodity) {
    // Massenware: so viel, wie im Ziel in hoechstens einem Tag weg ist (eigener Anteil am Absatz), hoechstens ein Stapel
    qty = Math.max(1, Math.min(Math.ceil((c.perDay || 0) * ru.share * Math.min(1, ru.hold)), (info && info.stack) || 20));
  } else if (c.perDay < 0.2) {
    return null;   // Einzelstueck, das sich im Ziel kaum verkauft
  }
  const unitNet = c.sell * (1 - cut);   // Erloes je Stueck nach dem Anteil des Zielhauses
  const cost = c.buy * qty;
  const revenue = Math.round(unitNet * qty);
  const dep = deposit(info && info.vendor, qty);
  // Verkaufswahrscheinlichkeit: Absatzquote, bei vollem Ziel weniger
  const rate = c.rate == null ? 0.5 : Math.max(0.05, Math.min(1, c.rate));
  const supply = c.supply == null ? 0 : c.supply;
  const p = rate * (supply <= 1 ? 1 : Math.max(0.2, 1 / Math.sqrt(supply)));
  const exp = Math.round(p * revenue - cost - (1 - p) * dep);
  return { key: c.key, dir: c.dir, qty, buy: c.buy, sell: c.sell, cost, revenue, dep, p, exp, commodity, cls: info && info.cls != null ? info.cls : -1,
    gap: !!c.gap, name: c.name || null };
}

// Gewinn, wenn nur der Anteil safe der Angebote verkauft wird (die schlechtesten zuerst)
function safeGain(offers, safe) {
  if (!offers.length) return 0;
  const k = Math.max(1, Math.ceil(offers.length * safe));
  const byRev = offers.slice().sort((a, b) => a.revenue - b.revenue);
  const sold = byRev.slice(0, k), unsold = byRev.slice(k);
  const cost = offers.reduce((a, o) => a + o.cost, 0);
  return sold.reduce((a, o) => a + o.revenue, 0) - cost - unsold.reduce((a, o) => a + o.dep, 0);
}

// Paket einer Richtung aus den Chancen. infoOf(key) -> { commodity, stack, cls, vendor }. budget in Kupfer.
// exclude = Set "dir|key". Rueckgabe { dir, offers, stake, gain (erwartet), gainSafe, safe, budget }
function build(chances, dir, infoOf, ru, budget, exclude = new Set(), cut = 0.05) {
  const cands = [];
  for (const c of chances) {
    if (c.dir !== dir || !c.ok || exclude.has(`${dir}|${c.key}`)) continue;
    const o = offerOf(c, infoOf(c.key), ru, cut);
    if (o && o.exp > 0 && o.cost > 0) cands.push(o);
  }
  // erwarteter Gewinn zuerst, bei gleichem der bessere je eingesetztem Gold
  cands.sort((a, b) => b.exp - a.exp || b.exp / b.cost - a.exp / a.cost);
  // Gierig auffuellen, solange Grenzen und Gewinnpruefung halten. Ein teures Angebot am Anfang verhindert oft alle weiteren
  // (die schlechtesten Verkaeufe decken seinen Einsatz nicht). Darum mit jedem der besten SEEDS als Start probieren und das
  // Paket mit dem hoechsten erwarteten Gewinn nehmen, Pakete mit mindestens MIN_OFFERS Angeboten gehen vor.
  const fill = (first) => {
    const offers = [];
    const perCat = new Map();
    const keys = new Set();
    let stake = 0;
    const tryAdd = (o) => {
      if (offers.length >= ru.pkgSize || keys.has(o.key)) return;
      if (o.cls >= 0 && (perCat.get(o.cls) || 0) >= PER_CAT) return;
      if (stake + o.cost > budget) return;
      if (o.cost > budget * MAX_SHARE) return;
      if (safeGain(offers.concat([o]), ru.pkgSafe) <= 0) return;
      offers.push(o);
      keys.add(o.key);
      perCat.set(o.cls, (perCat.get(o.cls) || 0) + 1);
      stake += o.cost;
    };
    tryAdd(first);
    for (const o of cands) tryAdd(o);
    return { offers, stake };
  };
  let best = { offers: [], stake: 0 }, bestScore = -Infinity;
  for (const seed of cands.slice(0, SEEDS)) {
    const pk = fill(seed);
    const g = pk.offers.reduce((a, o) => a + o.exp, 0);
    const score = (pk.offers.length >= Math.min(MIN_OFFERS, ru.pkgSize) ? 1e15 : 0) + g;   // gestreute Pakete gehen vor
    if (score > bestScore) { best = pk; bestScore = score; }
  }
  const { offers, stake } = best;
  const gain = offers.reduce((a, o) => a + o.exp, 0);
  return { dir, offers, stake, gain, gainSafe: Math.round(safeGain(offers, ru.pkgSafe)), safe: ru.pkgSafe, budget, cut };
}

// Fuer Data.lua: list = { "Schluessel:Menge:KaufenBis:VerkaufenAb:Erwartet" }, VerkaufenAb = Mindestpreis je Stueck, unter dem
// das Angebot nach Anteil und Einstellgebuehr keinen Gewinn mehr bringt
function forBroker(pkg, cut) {
  if (!pkg || !pkg.offers.length) return null;
  const list = pkg.offers.map((o) => {
    const minSell = Math.ceil((o.buy + o.dep / o.qty) / (1 - cut));
    return [o.key, o.qty, o.buy, minSell, o.sell].join(':');
  });
  return { stake: pkg.stake, gain: pkg.gain, gainSafe: pkg.gainSafe, list };
}

module.exports = { build, offerOf, safeGain, forBroker, deposit, PER_CAT, MAX_SHARE, DEFAULT_GOLD };
