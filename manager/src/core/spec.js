'use strict';
// Peon Manager - Chancen (Konzept Peon_Manager_Chancen.md, Abschnitt 4 und 6, ab Manager 0.35.0).
// Eine Liste fuer alle Arten:
//   s  Spekulation schnell (4.2): unter dem belegten Verkaufspreis kaufen, zum belegten Preis wieder einstellen
//   l  Spekulation langfristig (4.3): kaufen, weil eine Prognose einen Anstieg erwartet
//   b  Aufkauf-Kandidat (4.4): wie Broker Buyout.lua, Regeln aus Brokers Einstellungen
//   v  Haendler (4.5): unter dem Haendlerpreis kaufen
// Jede Chance traegt ihre Pruefliste (checks): Bedingung, echter Wert, Grenze, erfuellt, knapp. Daraus entstehen der
// Satz fuer die Liste und fuer jeden anderen Gegenstand die Antwort auf „Warum nicht?“ (6.2).
// Wiederverkauf (F50) ist mit Manager 0.35.0 abgeloest (KarloDerBaer 13.11.2026).

const { buyout, low, high } = require('./chances');

const CUT = 0.05;
const EG_24 = 12;   // Einstellgebuehr fuer 24 Std. = 12 x die Gebuehr fuer 2 Std. (Broker D.Deposit)
const KINDS = { s: 'Spekulation schnell', l: 'Spekulation langfristig', b: 'Aufkauf', v: 'Händler' };
const NEAR = 0.1;   // innerhalb 10 % der Grenze: knapp (gelb)

// Startwerte (Abschnitt 4, KarloDerBaer 13.11.2026: wie im Konzept). Je Art hoechstens 5 Regler.
const DEFAULTS = {
  s: { gap: 0.30, nProof: 5, maxDays: 3, minGain: 10000 },
  l: { rise: 0.25, maxDays: 14 },
  v: { minGain: 100 },
  f: { signals: { scarce: true, glut: true, level: true, fest: true, week: true }, minSure: 'low' },
};
const SLIDERS = {
  s: [
    { key: 'gap', label: 'So viel günstiger als verkauft', unit: '%', min: 0.05, max: 0.8, step: 0.05 },
    { key: 'nProof', label: 'Mindestens so viele Verkäufe gesehen', unit: 'Stück', min: 1, max: 30, step: 1 },
    { key: 'maxDays', label: 'Höchstens so lange bis zum Verkauf', unit: 'Tage', min: 0.5, max: 14, step: 0.5 },
    { key: 'minGain', label: 'Mindestgewinn', unit: 'gold', min: 0, max: 1000000, step: 1000 },
  ],
  l: [
    { key: 'rise', label: 'Erwarteter Anstieg nach Gebühr mindestens', unit: '%', min: 0.05, max: 1, step: 0.05 },
    { key: 'maxDays', label: 'Zeitraum der Prognose höchstens', unit: 'Tage', min: 1, max: 30, step: 1 },
  ],
  v: [{ key: 'minGain', label: 'Mindestgewinn', unit: 'gold', min: 0, max: 100000, step: 100 }],
};

function rulesOf(saved) {
  const out = JSON.parse(JSON.stringify(DEFAULTS));
  for (const k of ['s', 'l', 'v']) {
    for (const sl of SLIDERS[k]) {
      const v = saved && saved[k] && saved[k][sl.key];
      if (typeof v === 'number' && Number.isFinite(v)) out[k][sl.key] = Math.max(sl.min, Math.min(sl.max, v));
    }
  }
  if (saved && saved.f) {
    for (const id of Object.keys(out.f.signals)) {
      const v = saved.f.signals && saved.f.signals[id];
      if (v === false || v === true || v === 'force') out.f.signals[id] = v;
    }
    if (['low', 'mid', 'high'].includes(saved.f.minSure)) out.f.minSure = saved.f.minSure;
  }
  return out;
}

// Gold als Text wie im Spiel: 12g 50s, 30s 5c, 8c
function gold(c) {
  if (c == null || !Number.isFinite(c)) return '–';
  const neg = c < 0;
  const v = Math.round(Math.abs(c));
  const g = Math.floor(v / 10000), s = Math.floor((v % 10000) / 100), k = v % 100;
  const parts = [];
  if (g) parts.push(`${g.toLocaleString('de-DE')}g`);
  if (s) parts.push(`${s}s`);
  if (k && !g) parts.push(`${k}c`);
  return (neg ? '-' : '') + (parts.join(' ') || '0c');
}
const pctText = (x) => `${Math.round(x * 100)} %`;
const dec = (x) => (Math.round(x * 10) / 10).toLocaleString('de-DE');
function daysText(d) {
  if (d == null) return 'unbekannt';
  if (d < 1) return `etwa ${Math.max(1, Math.round(d * 24))} Std.`;
  return `etwa ${dec(d)} ${d < 1.05 ? 'Tag' : 'Tage'}`;
}
function hoursText(h) {
  if (h == null) return 'unbekannt';
  if (h < 1) return 'unter 1 Std.';
  return `etwa ${Math.round(h)} Std.`;
}

// Einstellgebuehr fuer 24 Std. (F18 wie Broker: 5 % des Haendlerwerts, abgerundet, mal 12)
const deposit = (hp, qty) => (hp > 0 ? Math.floor(hp * qty * 5 / 100) * EG_24 : 0);

// Pruefzeile. dirUp: Wert muss mindestens limit sein (sonst hoechstens)
function check(id, label, value, limit, ok, text, opts = {}) {
  let near = false;
  if (ok && typeof value === 'number' && typeof limit === 'number' && limit !== 0) near = Math.abs(value - limit) <= Math.abs(limit) * NEAR;
  return { id, label, value, limit, ok: !!ok, near, text, fixed: !!opts.fixed, user: !!opts.user, say: opts.say || null, weight: opts.weight || 0 };
}

// F59 Erwarteter Gewinn: Zielpreis x 0,95 x Menge - Einsatz - Einstellgebuehren fuer jedes weitere Einstellen nach 24 Std.
function profit(target, qty, cost, days, hp) {
  if (!(target > 0) || !(qty > 0)) return null;
  const relists = days != null ? Math.max(0, Math.ceil(days) - 1) : 0;
  const fees = deposit(hp, qty) * relists;
  return { gain: Math.floor(target * (1 - CUT) * qty - cost - fees), fees, relists };
}

// Spekulation schnell (4.2) fuer einen Gegenstand. Liefert immer eine Bewertung mit Pruefliste, ok = Vorschlag.
function evalFast(c, key) {
  const R = c.rules.s;
  const ov = c.over(key);
  const offers = c.offers.get(key) || [];
  const pr = c.proof.get(key);
  const st = c.stats.get(key);
  const b = c.bands.get(key);
  const sh = c.shifts && c.shifts.get(key);
  const hp = c.vendor(key);
  const n = pr ? pr.n : 0;
  const proven = pr && n >= R.nProof ? pr.median : null;
  const ref = ov.target != null ? ov.target : proven;
  const limit = ov.limit != null ? ov.limit : ref != null ? Math.floor(ref * (1 - R.gap)) : null;
  const buy = limit != null ? offers.filter((o) => o.p <= limit) : [];
  const qty = buy.reduce((a, o) => a + o.q, 0);
  const cost = buy.reduce((a, o) => a + o.q * o.p, 0);
  const next = limit != null ? offers.find((o) => o.p > limit) : null;
  const target = ref != null ? Math.max(1, Math.min(ref, next ? next.p - 1 : ref)) : null;
  const ahead = target != null ? offers.filter((o) => o.p > (limit ?? 0) && o.p <= target).reduce((a, o) => a + o.q, 0) : 0;
  const pd = st && st.perDay > 0 ? st.perDay : null;
  const days = pd && qty > 0 ? (ahead + qty) / pd : pd && target != null ? (ahead + 1) / pd : null;
  const pf = profit(target, qty, cost, days, hp);
  const gain = pf ? pf.gain : null;
  const cheapest = offers.length ? offers[0].p : null;
  // Gewinn, wenn man nur das guenstigste Angebot kauft (fuer die Probe mit lockereren Reglern, 7.3)
  const t2 = ref != null ? Math.min(ref, offers[1] ? offers[1].p - 1 : ref) : null;
  const gainCheapest = cheapest != null && t2 != null ? Math.floor((t2 * (1 - CUT) - cheapest) * offers[0].q) : null;
  const disc = ref != null && cheapest != null ? 1 - cheapest / ref : null;
  const total = offers.reduce((a, o) => a + o.q, 0);
  const mass = c.isCommodity(key) && total >= c.broker.minQty;
  const hold = c.hold(key, ref);
  const checks = [
    check('mass', 'Kein Fall für Aufkauf', total, c.broker.minQty, !mass,
      mass ? `Massenware mit ${total.toLocaleString('de-DE')} Stück im Angebot, das prüft der Aufkauf` : 'Einzelstück oder wenig angeboten', { fixed: true }),
    check('gap', 'So viel günstiger als verkauft', disc, R.gap, disc != null && disc >= R.gap && qty > 0,
      ref == null ? 'Noch kein belegter Verkaufspreis' : cheapest == null ? 'Gerade nicht im Angebot'
        : `Günstigstes Angebot ${gold(cheapest)}, ${disc >= 0 ? pctText(disc) + ' unter' : pctText(-disc) + ' über'} ${ov.target != null ? 'deinem Zielpreis' : 'dem belegten Verkaufspreis'} ${gold(ref)} (nötig ${pctText(R.gap)})`,
      { user: ov.target != null || ov.limit != null, weight: 3, say: disc != null && disc > 0 ? `Liegt ${pctText(disc)} unter dem, wofür er zuletzt verkauft wurde.` : null }),
    check('proof', 'Mindestens so viele Verkäufe gesehen', n, R.nProof, n >= R.nProof,
      `Belegte Verkäufe in 14 Tagen: ${dec(n)} (nötig ${R.nProof})`, { weight: 2, say: `${dec(n)} Verkäufe in 14 Tagen belegt.` }),
    check('days', 'Höchstens so lange bis zum Verkauf', days, R.maxDays, days != null && days <= R.maxDays,
      days == null ? 'Absatz unbekannt' : `Verkaufsdauer ${daysText(days)}: ${ahead.toLocaleString('de-DE')} Stück vor dir, Absatz ${dec(pd)} am Tag (höchstens ${dec(R.maxDays)} Tage)`,
      { weight: 1, say: pd ? `Verkauft sich etwa ${dec(pd)} Mal am Tag.` : null }),
    check('gain', 'Mindestgewinn', gain, R.minGain, gain != null && gain >= R.minGain,
      gain == null ? 'Kein Gewinn zu rechnen' : `Erwarteter Gewinn ${gold(gain)} (mindestens ${gold(R.minGain)})`, { weight: 1, say: gain > 0 ? `Bringt etwa ${gold(gain)}.` : null }),
    check('shift', 'Kein neues Preisniveau nach unten', null, null, !(sh && sh.dir === 'down'),
      sh && sh.dir === 'down' ? 'Der Preis fällt seit über 12 Std. unter den üblichen Bereich' : 'Preis stabil oder steigend', { fixed: true }),
  ];
  // Risiko als Ampel (4.2)
  const why = [];
  let pts = 0;
  if (days != null && days > R.maxDays * 0.75) { pts++; why.push('Der Verkauf dauert fast so lange wie die Grenze.'); }
  if (n < 2 * R.nProof) { pts++; why.push('Noch wenige belegte Verkäufe.'); }
  if (b && b.schw > 0.4) { pts++; why.push('Der Preis schwankt stark.'); }
  if (hold && hold.hours < 1) { pts++; why.push('Solche Angebote sind meist nach weniger als 1 Std. weg.'); }
  if (c.age > 7200) { pts++; why.push('Der Stand ist älter als 2 Std.'); }
  return finish(c, key, 's', checks, { buy: limit, limit, target, qty, cost, gain, days, hold, ref, proven, fees: pf ? pf.fees : 0, relists: pf ? pf.relists : 0,
    perDay: pd, ahead, offers: buy.length, cheapest, gainCheapest, risk: pts >= 3 ? 'high' : pts >= 1 ? 'mid' : 'low', why, until: c.now + 6 * 3600 });
}

// Haendler (4.5, F51): Angebote unter dem Haendlerpreis
function evalVendor(c, key) {
  const R = c.rules.v;
  const hp = c.vendor(key);
  const offers = c.offers.get(key) || [];
  const buy = hp ? offers.filter((o) => o.p < hp) : [];
  const qty = buy.reduce((a, o) => a + o.q, 0);
  const cost = buy.reduce((a, o) => a + o.q * o.p, 0);
  const gain = hp ? Math.floor(qty * hp - cost) : null;
  const pr = c.proof.get(key);
  const hold = c.hold(key, pr && pr.n >= c.rules.s.nProof ? pr.median : null);
  const checks = [
    check('vendor', 'Unter dem Händlerpreis', offers.length && hp ? offers[0].p : null, hp, qty > 0,
      !hp ? 'Händlerpreis unbekannt' : offers.length ? `Günstigstes Angebot ${gold(offers[0].p)}, Händler zahlt ${gold(hp)}` : 'Gerade nicht im Angebot',
      { weight: 3, say: qty > 0 ? `${qty.toLocaleString('de-DE')} Stück unter dem Händlerpreis von ${gold(hp)}.` : null }),
    check('gain', 'Mindestgewinn', gain, R.minGain, gain != null && gain >= R.minGain, gain == null ? 'Kein Gewinn zu rechnen' : `Gewinn beim Händler ${gold(gain)} (mindestens ${gold(R.minGain)})`, { weight: 1, say: gain > 0 ? `Bringt beim Händler ${gold(gain)}.` : null }),
  ];
  const liveOnly = !!(hold && hold.hours < 1);
  return finish(c, key, 'v', checks, { buy: hp ? hp - 1 : null, limit: hp ? hp - 1 : null, target: hp, qty, cost, gain, days: 0, hold, liveOnly,
    risk: c.age > 1800 ? 'mid' : 'low', why: c.age > 1800 ? ['Der Stand ist älter als 30 Min.'] : [], until: c.now + 3 * 3600 });
}

// Aufkauf-Kandidaten (4.4) fuer den ganzen Markt. Regeln aus Brokers Einstellungen (c.broker).
function buyoutList(c) {
  const B = c.broker;
  const list = buyout(c.rows || [], { commodity: (k) => c.isCommodity(k), sales: c.stats, shifts: c.shifts, bands: c.bands, age: c.age, minGain: B.minGain, maxHours: B.hours,
    targetPct: B.targetPct, minQty: B.minQty, minLevels: B.minLevels, minSales: B.minSales });
  const out = [];
  for (const x of list) {
    const b = c.bands.get(x.key);
    const st = c.stats.get(x.key);
    const offers = c.offers.get(x.key) || [];
    const total = offers.reduce((a, o) => a + o.q, 0);
    const checks = [
      check('mass', 'Massenware mit genug Angebot', total, B.minQty, total >= B.minQty && offers.length >= Math.min(B.minLevels, 12),
        `${total.toLocaleString('de-DE')} Stück in ${offers.length} Preisstufen (nötig ${B.minQty} in ${B.minLevels})`, { fixed: true }),
      check('band', 'Nur im üblichen Bereich', x.limit, b ? high(b) : null, !!b && x.limit <= high(b) && x.target <= high(b) * (1 + B.targetPct),
        b ? `Kaufen bis ${gold(x.limit)}, Ziel ${gold(x.target)}, üblich bis ${gold(high(b))} (Ziel höchstens ${pctText(B.targetPct)} darüber)` : 'Noch kein üblicher Bereich', { fixed: true }),
      check('sales', 'Genug Absatz', st ? st.perDay : 0, B.minSales, !!st && st.perDay >= B.minSales, `Absatz ${dec(st ? st.perDay : 0)} am Tag (nötig ${B.minSales})`, { fixed: true, say: st ? `Verkauft sich etwa ${dec(st.perDay)} Mal am Tag.` : null }),
      check('hours', 'Schnell wieder verkauft', x.hours, B.hours, x.hours <= B.hours, `Verkauft in etwa ${dec(x.hours)} Std. (höchstens ${B.hours})`, { fixed: true, weight: 1 }),
      check('gain', 'Mindestgewinn', x.gain, B.minGain, x.gain >= B.minGain, `Gewinn ${gold(x.gain)} (mindestens ${gold(B.minGain)})`, { fixed: true, weight: 3, say: `Bis ${gold(x.limit)} aufkaufen bringt ${gold(x.gain)}.` }),
    ];
    if (!checks.every((k) => k.ok)) continue;
    out.push(finish(c, x.key, 'b', checks, { buy: x.limit, limit: x.limit, target: x.target, qty: x.qty, cost: x.cost, gain: x.gain, days: x.hours / 24, hold: null,
      risk: x.risk, why: x.why, until: c.now + 2 * 3600 }));
  }
  return out;
}

// Spekulation langfristig (4.3) aus einer Prognose
function evalLong(c, key, fc) {
  const R = c.rules.l;
  const st = c.stats.get(key);
  const offers = c.offers.get(key) || [];
  const price = offers.length ? offers[0].p : fc ? fc.price : null;
  const rise = fc ? fc.expect * (1 - CUT) - CUT : null;
  const sureOk = fc && fc.dir > 0 && ['mid', 'high'].includes(fc.sure);
  const checks = [
    check('fc', 'Prognose „steigt“ mindestens mittel', null, null, !!sureOk,
      !fc ? 'Keine Prognose' : fc.dir < 0 ? 'Prognose: fällt' : `Prognose steigt, Sicherheit ${({ low: 'niedrig', mid: 'mittel', high: 'hoch' })[fc.sure]}`, { fixed: true, weight: 3,
        say: fc && fc.dir > 0 ? `Soll in ${fc.days} Tagen steigen (${fc.signals.map((s) => s.label).join(', ')}).` : null }),
    check('rise', 'Erwarteter Anstieg nach Gebühr mindestens', rise, R.rise, rise != null && rise >= R.rise, rise == null ? 'Kein Anstieg erwartet' : `Erwartet ${pctText(rise)} nach Gebühr (nötig ${pctText(R.rise)})`, { weight: 2 }),
    check('days', 'Zeitraum der Prognose höchstens', fc ? fc.days : null, R.maxDays, !!fc && fc.days <= R.maxDays, fc ? `${fc.days} Tage (höchstens ${R.maxDays})` : '–', {}),
    check('sales', 'Absatz vorhanden', st ? st.level : 0, 2, !!st && (st.level ?? 1) >= 2, st ? `Absatz ${dec(st.perDay)} am Tag` : 'Kein Absatz bekannt', { fixed: true, say: st ? `Verkauft sich etwa ${dec(st.perDay)} Mal am Tag.` : null }),
    check('offer', 'Im Angebot', price, null, price != null, price != null ? `Günstigstes Angebot ${gold(price)}` : 'Gerade nicht im Angebot', { fixed: true }),
  ];
  const target = price != null && fc ? Math.round(price * (1 + fc.expect)) : null;
  const qty = offers.length ? offers[0].q : 0;
  const gain = target != null && qty ? Math.floor(target * (1 - CUT) * qty - price * qty) : null;
  return finish(c, key, 'l', checks, { buy: price, limit: price, target, qty, cost: price * qty, gain, days: fc ? fc.days : null, hold: null,
    risk: fc && fc.sure === 'high' ? 'low' : 'mid', why: fc && fc.sure !== 'high' ? ['Prognose nur mit mittlerer Sicherheit.'] : [], until: c.now + (fc ? fc.days : 1) * 86400, outlook: fc || null });
}

// Satz aus der wichtigsten erfuellten Bedingung und der knappsten (6.1 Stufe 1), sonst „Warum nicht?“ (6.2)
function sentence(checks, ok) {
  if (!ok) {
    const first = checks.find((k) => !k.ok);
    return first ? `Kein Vorschlag, weil: ${first.text}.` : '';
  }
  const said = checks.filter((k) => k.ok && k.say);
  const main = [...said].sort((a, b) => b.weight - a.weight)[0];
  const tight = said.filter((k) => k !== main).sort((a, b) => (b.near - a.near) || (a.weight - b.weight))[0];
  return [main && main.say, tight && tight.say].filter(Boolean).join(' ');
}

function finish(c, key, kind, checks, x) {
  const ov = c.over(key);
  let ok = checks.every((k) => k.ok);
  if (ok && ov.never) { checks.push(check('never', 'Nie vorschlagen', null, null, false, 'Von dir auf „nie vorschlagen“ gesetzt', { user: true })); ok = false; }
  if (ok && ov.off && ov.off[kind]) { checks.push(check('off', 'Art für diesen Gegenstand aus', null, null, false, `Von dir ausgeschaltet: ${KINDS[kind]}`, { user: true })); ok = false; }
  const i = c.info(key);
  const fc = c.forecasts ? c.forecasts.get(key) : null;
  return { key, kind, kindLabel: KINDS[kind], name: i.name, quality: i.quality, item: i.item_id, ok, checks, say: sentence(checks, ok),
    outlook: x.outlook || (fc ? { dir: fc.dir, days: fc.days, sure: fc.sure, expect: fc.expect } : null), t: c.t, user: !!(ov.target != null || ov.limit != null), ...x };
}

// Alle Chancen eines Markts: { list (ok), near (fast erfuellt, fuer die Probe), live (nur live erreichbar) }
function marketChances(c) {
  const list = [], near = [], live = [];
  for (const key of c.offers.keys()) {
    const s = evalFast(c, key);
    if (s.ok) list.push(s);
    else if (s.cheapest != null && s.proven != null && s.checks.find((k) => k.id === 'gap').value >= c.rules.s.gap / 2 && !c.over(key).never) near.push(s);
    const v = evalVendor(c, key);
    if (v.ok) (v.liveOnly ? live : list).push(v);
  }
  for (const b of buyoutList(c)) if (b.ok) list.push(b);
  if (c.forecasts) {
    for (const [key, fc] of c.forecasts) {
      if (fc.dir < 0) continue;
      const l = evalLong(c, key, fc);
      if (l.ok) list.push(l);
    }
  }
  list.sort((a, b) => (b.gain ?? 0) - (a.gain ?? 0));
  return { list, near, live };
}

// Pruefliste fuer einen Gegenstand mit allen Arten (Warum nicht?, 6.2)
function itemChecks(c, key) {
  const out = [evalFast(c, key), evalVendor(c, key)];
  const b = buyoutList(c).find((x) => x.key === key);
  if (b) out.push(b);
  if (c.forecasts && c.forecasts.get(key)) out.push(evalLong(c, key, c.forecasts.get(key)));
  return out;
}

// Werte einer gespeicherten Chance (D5) gegen andere Regeln pruefen (Probe, 7.3)
function passes(kind, d, R) {
  if (kind === 's') {
    const gain = d.gain != null && d.gain > 0 ? d.gain : d.gainCheapest;
    return d.disc != null && d.disc >= R.s.gap && d.n >= R.s.nProof && d.days != null && d.days <= R.s.maxDays && gain != null && gain >= R.s.minGain && !d.shift && !d.mass;
  }
  if (kind === 'v') return d.gain != null && d.gain >= R.v.minGain;
  if (kind === 'l') return d.rise != null && d.rise >= R.l.rise && d.fcDays != null && d.fcDays <= R.l.maxDays && d.sure;
  return true;
}

// Werte des Moments fuer D5 (alle Bedingungen)
function moment(x) {
  const v = (id) => { const k = x.checks.find((y) => y.id === id); return k ? k.value : null; };
  const ok = (id) => { const k = x.checks.find((y) => y.id === id); return k ? k.ok : null; };
  return { disc: v('gap'), n: v('proof'), days: x.days ?? null, gain: x.gain ?? null, gainCheapest: x.gainCheapest ?? null, shift: ok('shift') === false, mass: ok('mass') === false && x.kind === 's',
    rise: v('rise'), fcDays: x.outlook ? x.outlook.days : null, sure: ok('fc'), qty: x.qty, cost: x.cost, ref: x.ref ?? null, hold: x.hold ? x.hold.hours : null, risk: x.risk, say: x.say };
}

module.exports = { KINDS, DEFAULTS, SLIDERS, rulesOf, gold, daysText, hoursText, deposit, profit, evalFast, evalVendor, evalLong, buyoutList, sentence,
  marketChances, itemChecks, passes, moment, CUT, low };
