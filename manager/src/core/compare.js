'use strict';
// Peon Manager - Marktvergleich mit dem neutralen Auktionshaus (ab Manager 0.50.0, Konzept
// docs/konzepte/broker/Peon_Broker_Marktvergleich.md, Abschnitt 3). Je Paar Heimat und Neutral desselben Regelsatzes:
// in einem Haus kaufen, im anderen verkaufen. Grundlage sind die Stundenwerte (item_hour) und der Absatz je Tag (sales_day).
//
// Je Gegenstand und Richtung:
//   Kaufpreis      Median der Tageswerte des guenstigsten Preises in der Quelle
//   Verkaufspreis  Median der Verkaufspreise je Tag im Ziel, hoechstens der uebliche guenstigste Preis im Ziel
//   Netto          Verkaufspreis x (1 - Anteil Ziel) - Kaufpreis
//   Absatz         verkaufte Stueck je Tag im Ziel (Mittel ueber die Tage mit Absatzdaten im Markt)
//   Vorrat         Angebot im Ziel geteilt durch Absatz, also Tage bis alles weg ist
//   Bestaendigkeit Anteil der Tage, an denen Netto ueber null lag
//   Menge          eigener Anteil am Absatz x Haltedauer, hoechstens das uebliche Angebot in der Quelle
// Gewinn je Tag = Netto x Absatz x eigener Anteil, Bewertung = Gewinn je Tag x Bestaendigkeit x Abschlag fuer vollen Zielmarkt.

const DEFAULTS = {
  days: 7,          // Zeitraum (3, 7 oder 14)
  share: 0.1,       // eigener Anteil am Absatz (KarloDerBaer 20.11.2026: deutlich kleiner als ein Drittel)
  hold: 1,          // Haltedauer in Tagen (KarloDerBaer 20.11.2026: kuerzer als 3 Tage)
  minPct: 0.2,      // Spanne mindestens 20 %
  minNet: 1000,     // Netto mindestens 10 Silber je Stueck
  minSales: 1,      // Absatz im Ziel mindestens 1 Stueck am Tag
  minCons: 0.5,     // Bestaendigkeit mindestens 50 %
  cutN: 0.15,       // Anteil des neutralen Hauses, solange Broker ihn nicht gemessen hat (KarloDerBaer 20.11.2026)
  top: 10,          // ab 0.51.0: so viele Chancen gehen an Broker (KarloDerBaer 20.11.2026, einstellbar)
};
const CHOICES = { days: [3, 7, 14] };
const LIMITS = { share: [0.01, 1], hold: [0.25, 14], minPct: [0, 5], minNet: [0, 1e9], minSales: [0, 1e6], minCons: [0, 1], cutN: [0, 0.5], top: [1, 100] };
const CUT_HOME = 0.05;
const SUPPLY_OK = 3;       // bis 3 Tage Vorrat im Ziel kein Abschlag
const SUPPLY_MAX = 10;     // ab 10 Tagen Vorrat keine Chance
const GREEN_CONS = 0.7;    // gruen ab 70 % Bestaendigkeit und hoechstens SUPPLY_OK Tage Vorrat
const BROKER_MAX = 150;    // bis 0.50.x: so viele Chancen je Richtung gingen an Broker (ab 0.51.0 rules.top fuer beide zusammen)
// ab 0.51.0 (KarloDerBaer 20.11.2026): Langzeitwerte ueber 14 Tage fliessen in die Bewertung ein
const LONG = 14;           // Tage fuer die Langzeitwerte
const TREND_MIN = 0.6, TREND_MAX = 1.2;   // Faktor fuer einen schrumpfenden oder wachsenden Unterschied

// Regeln aus den Einstellungen, auf erlaubte Werte gebracht
function rules(r) {
  const out = { ...DEFAULTS };
  for (const k of Object.keys(DEFAULTS)) {
    const v = r ? Number(r[k]) : NaN;
    if (!Number.isFinite(v)) continue;
    if (CHOICES[k]) { if (CHOICES[k].includes(v)) out[k] = v; continue; }
    const [lo, hi] = LIMITS[k];
    out[k] = Math.min(hi, Math.max(lo, v));
  }
  return out;
}

function median(list) {
  const a = list.filter((x) => Number.isFinite(x)).sort((x, y) => x - y);
  if (!a.length) return null;
  const m = a.length >> 1;
  return a.length % 2 ? a[m] : (a[m - 1] + a[m]) / 2;
}

// Tageswerte eines Markts ohne Zwischenspeicher (Tests, Notfall): Map key -> Map day -> { min, qty }
function dayPrices(db, mid, fromDay) {
  const out = new Map();
  const add = (k, d, min, qty) => {
    let m = out.get(k);
    if (!m) { m = new Map(); out.set(k, m); }
    const x = m.get(d) || { s: 0, n: 0, qty: 0, t: 0 };
    x.s += min; x.n++; x.qty = qty; m.set(d, x);
  };
  for (const r of db.prepare("SELECT item_key AS k, t, min, qty FROM item_snap WHERE market_id = ? AND t >= ? AND source = 'scan' AND min > 0 ORDER BY t").iterate(mid, fromDay * 86400)) {
    add(r.k, Math.floor(r.t / 86400), r.min, r.qty || 0);
  }
  for (const [, m] of out) for (const [d, x] of m) m.set(d, { min: x.s / x.n, qty: x.qty });
  return out;
}

// Angebot im letzten Stand ohne Zwischenspeicher: Map key -> { t, min, qty }
function lastStand(db, mid) {
  const out = new Map();
  const s = db.prepare("SELECT sid, t FROM snapshots WHERE market_id = ? AND source = 'scan' ORDER BY t DESC LIMIT 1").get(mid);
  if (!s) return out;
  for (const r of db.prepare('SELECT item_key AS k, min, qty FROM item_snap WHERE sid = ?').iterate(s.sid)) {
    if (r.min > 0 && r.qty > 0) out.set(r.k, { t: s.t, min: r.min, qty: r.qty });
  }
  return out;
}

// Nur Angebote aus den letzten 3 Std. vor dem neuesten Stand zaehlen als aktuell
function freshOnly(last) {
  let top = 0;
  for (const x of last.values()) if (x.t > top) top = x.t;
  const out = new Map();
  for (const [k, x] of last) if (x.t >= top - 3 * 3600 && x.min > 0) out.set(k, x);
  return { t: top || null, items: out };
}

// Absatz eines Markts: { days (Tage mit Daten), items: Map key -> Map day -> { sold, expired, px } }
function daySales(db, mid, fromDay) {
  const items = new Map();
  const days = new Set();
  for (const r of db.prepare('SELECT item_key AS k, day AS d, sold, expired, value FROM sales_day WHERE market_id = ? AND day >= ?').iterate(mid, fromDay)) {
    days.add(r.d);
    let m = items.get(r.k);
    if (!m) { m = new Map(); items.set(r.k, m); }
    m.set(r.d, { sold: r.sold || 0, expired: r.expired || 0, px: r.sold > 0 && r.value > 0 ? r.value / r.sold : null });
  }
  return { days: days.size, daySet: days, items };
}

// Eine Richtung: kaufen in src, verkaufen in dst. Rueckgabe Werte oder null ohne genug Daten.
// Kurzfristig (Zeitraum der Regeln): Preise, Absatz, Bestaendigkeit. Langfristig (LONG Tage, ab 0.51.0): Bestaendigkeit ueber
// alle Tage (cons14), wie gleichmaessig im Ziel verkauft wird (even = Anteil der Tage mit Verkaeufen) und ob der Unterschied
// waechst oder schrumpft (trend = Gewinn der juengeren Haelfte geteilt durch die aeltere, begrenzt).
function direction(key, src, dst, cutDst, ru, minDays, today) {
  const spAll = src.prices.get(key), dpAll = dst.prices.get(key);
  if (!spAll || !dpAll) return null;
  const from = today - ru.days;
  const recent = (m) => new Map([...m].filter(([d]) => d > from));
  const sp = recent(spAll), dp = recent(dpAll);
  if (!sp.size || !dp.size) return null;
  const buy = median([...sp.values()].map((x) => x.min));
  const dstMin = median([...dp.values()].map((x) => x.min));
  if (!(buy > 0) || !(dstMin > 0)) return null;
  const dsAll = dst.sales.items.get(key);
  let sold = 0, expired = 0;
  const pxs = [];
  if (dsAll) for (const [d, x] of dsAll) if (d > from) { sold += x.sold; expired += x.expired; if (x.px) pxs.push(x.px); }
  const soldPx = median(pxs);
  const sell = soldPx ? Math.min(soldPx, dstMin) : dstMin;
  const net = sell * (1 - cutDst) - buy;
  const salesDays = [...dst.sales.daySet].filter((d) => d > from).length;
  const perDay = salesDays ? sold / salesDays : 0;
  const rate = sold + expired > 0 ? sold / (sold + expired) : null;
  // Gewinn je Tag nach Preisen beider Maerkte, Ziel = Verkaufspreis des Tages oder sein guenstigster Preis
  const dayNet = new Map();
  for (const [d, s] of spAll) {
    const t = dpAll.get(d);
    if (!t) continue;
    const dx = dsAll && dsAll.get(d);
    const px = dx && dx.px ? Math.min(dx.px, t.min) : t.min;
    dayNet.set(d, (px * (1 - cutDst) - s.min) / s.min);
  }
  let both = 0, plus = 0;
  for (const [d, v] of dayNet) if (d > from) { both++; if (v > 0) plus++; }
  if (both < minDays) return null;
  const cons = both ? plus / both : 0;
  // Langzeit
  let both14 = 0, plus14 = 0;
  for (const v of dayNet.values()) { both14++; if (v > 0) plus14++; }
  const cons14 = both14 ? plus14 / both14 : cons;
  const mDays = dst.sales.daySet.size;
  let soldDays = 0;
  if (dsAll) for (const x of dsAll.values()) if (x.sold >= 0.5) soldDays++;
  const even = mDays ? Math.min(1, soldDays / mDays) : 0;
  const ds = [...dayNet.keys()].sort((a, b) => a - b);
  let trend = 1;
  if (ds.length >= 4) {
    const half = Math.floor(ds.length / 2);
    const avg = (list) => list.reduce((a, d) => a + dayNet.get(d), 0) / list.length;
    const older = avg(ds.slice(0, half)), newer = avg(ds.slice(half));
    if (older > 0) trend = Math.min(TREND_MAX, Math.max(TREND_MIN, newer / older));
    else if (newer > 0) trend = TREND_MAX;
  }
  const longF = (0.5 + 0.5 * cons14) * (0.5 + 0.5 * even) * trend;
  const last = dst.last.items.get(key);
  const stock = last ? last.qty : 0;
  const supply = perDay > 0 ? stock / perDay : (stock > 0 ? Infinity : 0);
  const srcQty = median([...sp.values()].map((x) => x.qty)) || 0;
  const qty = Math.max(1, Math.min(Math.ceil(perDay * ru.share * ru.hold), Math.floor(srcQty) || 1));
  const gainDay = net > 0 ? net * perDay * ru.share : 0;
  const damp = supply <= SUPPLY_OK ? 1 : supply >= SUPPLY_MAX ? 0 : 1 - (supply - SUPPLY_OK) / (SUPPLY_MAX - SUPPLY_OK);
  const score = gainDay * cons * damp * longF;
  const pct = net / buy;
  const why = [];
  if (pct < ru.minPct) why.push('spanne');
  if (net < ru.minNet) why.push('netto');
  if (perDay < ru.minSales) why.push('absatz');
  if (cons < ru.minCons) why.push('bestaendig');
  if (supply >= SUPPLY_MAX) why.push('vorrat');
  const ok = !why.length;
  const light = !ok ? 'red' : cons >= GREEN_CONS && supply <= SUPPLY_OK ? 'green' : 'yellow';
  return { buy: Math.round(buy), sell: Math.round(sell), soldPx: soldPx ? Math.round(soldPx) : null, net: Math.round(net), pct,
    perDay, rate, stock, supply: Number.isFinite(supply) ? supply : null, cons, days: both, plus, qty, gainDay: Math.round(gainDay),
    cons14, days14: both14, plus14, even, trend, longF,
    score: Math.round(score), ok, light, why, dstMin: Math.round(dstMin), srcNow: (src.last.items.get(key) || {}).min ?? null, dstNow: last ? last.min : null };
}

// Satz zu einer Chance: "Fraktion kauft fuer 1g 20s, Neutral verkauft im Mittel fuer 2g 10s, 14 am Tag. Unterschied an 6 von 7 Tagen."
function money(c) {
  c = Math.round(c || 0);
  const g = Math.floor(c / 10000), s = Math.floor((c % 10000) / 100), k = c % 100;
  const p = [];
  if (g) p.push(`${g}g`);
  if (s) p.push(`${s}s`);
  if (k || !p.length) p.push(`${k}c`);
  return p.join(' ');
}
function num(v) { return v >= 10 ? String(Math.round(v)) : String(Math.round(v * 10) / 10).replace('.', ','); }
function say(dir, x) {
  const from = dir === 'n' ? 'Fraktion' : 'Neutral', to = dir === 'n' ? 'Neutral' : 'Fraktion';
  const sold = x.soldPx ? `verkauft im Mittel für ${money(x.sell)}` : `bietet ab ${money(x.sell)}`;
  let t = `${from} kauft für ${money(x.buy)}, ${to} ${sold}, ${num(x.perDay)} am Tag. Unterschied an ${x.plus} von ${x.days} Tagen`;
  if (x.days14 > x.days) t += `, über ${x.days14} Tage an ${x.plus14}`;
  if (x.trend != null && x.trend >= 1.1) t += ', wachsend';
  else if (x.trend != null && x.trend <= 0.8) t += ', schrumpfend';
  return t + '.';
}

// Ganze Rechnung fuer ein Paar. now in Sekunden. cutN: gemessener Anteil Neutral oder null (dann Annahme aus den Regeln)
function computePair(db, homeId, neutralId, opts = {}) {
  const ru = rules(opts.rules);
  const now = opts.now || Math.floor(Date.now() / 1000);
  const cutSure = Number.isFinite(opts.cutN) && opts.cutN > 0 && opts.cutN < 0.5;
  const cutN = cutSure ? opts.cutN : ru.cutN;
  const today = Math.floor(now / 86400);
  const span = Math.max(ru.days, LONG);
  const fromDay = today - span;
  const minDays = Math.min(3, Math.max(2, ru.days - 1));
  // opts.snaps (SnapIndex des Managers) liefert Tageswerte und letzten Stand aus dem Speicher, sonst aus der Datenbank
  const side = (mid) => {
    const prices = opts.snaps ? opts.snaps.dayMins(mid, now, span) : dayPrices(db, mid, fromDay + 1);
    const last = freshOnly(opts.snaps ? opts.snaps.lastSeen(mid, now) : lastStand(db, mid));
    return { prices, sales: daySales(db, mid, fromDay + 1), last };
  };
  const H = side(homeId), N = side(neutralId);
  const items = [], chances = [];
  let both = 0;
  for (const key of H.prices.keys()) {
    if (!N.prices.has(key)) continue;
    both++;
    const n = direction(key, H, N, cutN, ru, minDays, today);   // Fraktion kaufen, Neutral verkaufen
    const h = direction(key, N, H, CUT_HOME, ru, minDays, today); // Neutral kaufen, Fraktion verkaufen
    if (!n && !h) continue;
    let best = 'h';
    if (!h) best = 'n';
    else if (n && (n.ok !== h.ok ? n.ok : n.pct >= h.pct)) best = 'n';
    const b = best === 'n' ? n : h;
    const r1 = (v) => (v == null ? null : Math.round(v * 10) / 10);
    // Liste Alle (knapp): Preise und Absatz beider Seiten, bessere Richtung
    items.push({ key, hm: n ? n.buy : h.dstMin, nm: h ? h.buy : n.dstMin, sh: h ? r1(h.perDay) : null, sn: n ? r1(n.perDay) : null,
      dir: best, pct: Math.round(b.pct * 100), net: b.net, light: b.light });
    for (const [dir, x] of [['n', n], ['h', h]]) if (x && x.ok) chances.push({ key, dir, ...x, say: say(dir, x) });
  }
  chances.sort((a, b) => b.score - a.score);
  const sum = { both, items: items.length, n: 0, h: 0, green: 0, gainGreen: 0 };
  for (const c of chances) {
    sum[c.dir]++;
    if (c.light === 'green') { sum.green++; sum.gainGreen += c.gainDay; }
  }
  // ab 0.51.0: die besten rules.top (beide Richtungen zusammen, je Gegenstand die bessere) sind die Auswahl fuer Broker
  sum.picked = pickTop(chances, ru.top);
  return { t: now, rules: ru, cutN, cutSure, cutH: CUT_HOME, days: { home: H.sales.days, neutral: N.sales.days },
    stand: { home: H.last.t, neutral: N.last.t }, sum, chances, items };
}

// Auswahl: die ersten top Chancen (Liste nach Bewertung sortiert), je Gegenstand nur eine Richtung. Setzt c.pick, Rueckgabe Anzahl
function pickTop(chances, top) {
  const keys = new Set();
  for (const c of chances) {
    c.pick = keys.size < top && !keys.has(c.key);
    if (c.pick) keys.add(c.key);
  }
  return keys.size;
}

// Kandidaten fuer Broker (Data.lua, Konzept Abschnitt 5 und 10.2): ab 0.51.0 die Auswahl (pick, die besten rules.top) und
// alle angehefteten, je Gegenstand eine Richtung. Dazu die Grenzen, nach denen Broker eine Chance mit neuen Preisen entfernt.
// list[Schluessel] = "Richtung:KaufenBis:Verkaufspreis:Netto:Absatz x10:Menge:Vorrat x10:Bestaendigkeit %:Bewertung:Ampel"
function forBroker(res, pinned = new Set()) {
  if (!res || !res.chances) return null;
  const list = {}, say = {};
  const hasPick = res.chances.some((c) => c.pick !== undefined);
  let n = 0;
  const top = (res.rules && res.rules.top) || DEFAULTS.top;
  for (const c of res.chances) {
    if (list[c.key]) continue;   // je Gegenstand nur die bessere Richtung
    const want = hasPick ? c.pick : n < top;
    if (!want && !pinned.has(c.key)) continue;
    n++;
    const sup = c.supply == null ? 9999 : Math.min(9999, Math.round(c.supply * 10));
    list[c.key] = [c.dir, c.buy, c.sell, c.net, Math.round(c.perDay * 10), c.qty, sup, Math.round(c.cons * 100), c.score,
      c.light === 'green' ? 'g' : 'y'].join(':');
    say[c.key] = c.say;
  }
  const ru = res.rules || DEFAULTS;
  return { t: res.t, cutN: Math.round(res.cutN * 10000), cutSure: !!res.cutSure, minPct: Math.round(ru.minPct * 100), minNet: Math.round(ru.minNet), list, say };
}

module.exports = { DEFAULTS, CHOICES, rules, median, computePair, forBroker, pickTop, say, money, BROKER_MAX, SUPPLY_OK, SUPPLY_MAX, LONG };
