'use strict';
// Peon Manager - Marktwerte fuer Chancen und Marktuebersicht (Rechenmodell Kapitel 9.3): Fallend und Steigend (F52),
// Lohnend (F53), Aufkauf. Ab Manager 0.35.0 rechnet spec.js die Chancen. Der Wiederverkauf (F50 bis F50c) und seine
// Trefferquote (F55) sind entfernt (KarloDerBaer 13.11.2026), die Tabellen opp_snap und opp_scan werden nicht mehr gefuellt.

const zlib = require('node:zlib');
const { parseRows, itemKey, unitPrice } = require('./stats');

const CUT = 0.05;          // Auktionshaus-Gebuehr beim Verkauf (F11)
const MOVE = 0.15;         // Fallend/Steigend: mindestens 15 % vom Langzeitwert
const DUMP = 0.30;         // Dumping: Min unter 70 % vom Langzeitwert (wie Broker dumpPct)
const PROOF = 0.8;         // in 14 Tagen mindestens einmal zu 80 % des Zielpreises verkauft, sonst zweifelhaft (Scherzpreise)
// Ab Manager 0.22.0 (KarloDerBaer 08.11.2026), gilt weiter fuer die Anzeige des ueblichen Bereichs (F50c):
const UNSURE = 0.4;        // F50c: Schwankung ueber 40 %: Bereich zu breit

function low(b) { return Math.max(0, b.lang * (1 - b.schw)); }
function high(b) { return b.lang * (1 + b.schw); }

function rowsOf(db, id) {
  const r = db.prepare('SELECT rows FROM snapshots WHERE id = ?').get(id);
  if (!r || !r.rows) return null;
  return parseRows(zlib.inflateSync(Buffer.from(r.rows)).toString('utf8'));
}

// Aufkauf (Manager 0.26.0, Neuaufbau Abschnitt 6.1, gleiche Regel wie Broker Buyout.lua ab 0.65): Massenware bis zu
// einer Preisstufe aufkaufen und zum Preis der naechsten Stufe wieder einstellen. Eine Stelle zaehlt, wenn der Gewinn
// (Menge x Ziel x 0,95 - Einsatz) mindestens BUYOUT_MIN ist, sich die Menge beim Absatz in hoechstens BUYOUT_HOURS Std.
// wieder verkauft und kein neues Preisniveau nach unten (F54) gilt. Je Gegenstand die Stelle mit dem hoechsten Gewinn.
// Das Gold des Charakters kennt der Manager nicht: keine Grenze fuer den Einsatz, kein Risikopunkt dafuer.
// Risiko wie im Spiel: je ein Punkt fuer Verkaufsdauer ueber 75 % der Grenze, viel Ware bis 5 % ueber dem Ziel,
// duenne naechste Stufe, Stand aelter als 30 Min. (ueber 2 Std. zwei Punkte), wenig Absatzdaten oder kein Bereich.
const BUYOUT_MIN = 5000;     // 50 Silber wie Broker dealMinMarket
const BUYOUT_HOURS = 2;      // wie Broker buyoutHours
const BUYOUT_RISK = { hoursPart: 0.75, nearPct: 0.05, thinMin: 5, thinPart: 0.1, old: 1800, veryOld: 7200 };

function buyout(rows, opts = {}) {
  const commodity = opts.commodity || (() => false);
  const sales = opts.sales || new Map();
  const shifts = opts.shifts || null;
  const bands = opts.bands || null;
  const age = opts.age || 0;
  const minGain = opts.minGain ?? BUYOUT_MIN;
  const maxHours = opts.maxHours ?? BUYOUT_HOURS;
  const levels = new Map();
  for (const r of rows) {
    const key = itemKey(r);
    if (!commodity(key)) continue;
    const p = unitPrice(r);
    if (p == null || !(r.qty > 0)) continue;
    const price = Math.round(p);
    let m = levels.get(key);
    if (!m) { m = new Map(); levels.set(key, m); }
    m.set(price, (m.get(price) || 0) + r.qty * (r.n || 1));
  }
  const out = [];
  for (const [key, m] of levels) {
    if (m.size < 2) continue;
    const s = sales.get(key);
    const perHour = s && s.perDay > 0 ? s.perDay / 24 : 0;
    if (!perHour) continue;
    const sh = shifts && shifts.get(key);
    if (sh && sh.dir === 'down') continue;
    const lv = [...m.entries()].sort((a, b) => a[0] - b[0]).map(([price, qty]) => ({ price, qty }));
    // ab Manager 0.35.0 wie Broker 0.71 bis 0.79 (nur mit opts.targetPct): nur Massenware, nur im ueblichen Bereich
    const bb = opts.targetPct != null && bands ? bands.get(key) : null;
    if (opts.targetPct != null) {
      const total = lv.reduce((a, x) => a + x.qty, 0);
      if (!bb || total < (opts.minQty || 0) || lv.length < Math.min(opts.minLevels || 0, 12) || s.perDay < (opts.minSales || 0)) continue;
    }
    let qty = 0, cost = 0, best = null;
    for (let i = 0; i < lv.length - 1; i++) {
      if (bb && (lv[i].price > high(bb) || lv[i + 1].price > high(bb) * (1 + opts.targetPct))) break;
      qty += lv[i].qty; cost += lv[i].qty * lv[i].price;
      const target = lv[i + 1].price;
      const gain = Math.floor(qty * target * (1 - CUT) - cost);
      const hours = qty / perHour;
      if (gain >= minGain && hours <= maxHours && (!best || gain > best.gain)) best = { i, qty, cost, target, gain, hours };
    }
    if (!best) continue;
    let near = 0;
    for (let j = best.i + 1; j < lv.length; j++) if (lv[j].price <= best.target * (1 + BUYOUT_RISK.nearPct)) near += lv[j].qty;
    const nextQty = lv[best.i + 1].qty;
    const why = [];
    let pts = 0;
    if (best.hours > maxHours * BUYOUT_RISK.hoursPart) { pts++; why.push('Der Verkauf dauert fast so lange wie die Grenze.'); }
    if (near > perHour * maxHours) { pts++; why.push('Viel Ware knapp über dem Zielpreis.'); }
    if (nextQty < BUYOUT_RISK.thinMin || nextQty < best.qty * BUYOUT_RISK.thinPart) { pts++; why.push('Die nächste Preisstufe ist dünn.'); }
    if (age > BUYOUT_RISK.veryOld) { pts += 2; why.push('Der Stand ist älter als 2 Std.'); }
    else if (age > BUYOUT_RISK.old) { pts++; why.push('Der Stand ist älter als 30 Min.'); }
    if (!s || (s.level ?? 1) < 2 || !(bands && bands.get(key))) { pts++; why.push('Wenig Absatzdaten oder noch kein üblicher Bereich.'); }
    out.push({ key, qty: best.qty, cost: best.cost, limit: lv[best.i].price, target: best.target, gain: best.gain, hours: best.hours,
      nextQty, near, risk: pts >= 3 ? 'high' : pts >= 1 ? 'mid' : 'low', why,
      sales: { perDay: s.perDay, level: s.level, rate: s.rate, avgPrice: s.avgPrice, maxSold: s.maxSold } });
  }
  // Gewinn absteigend, rotes Risiko unten (wie das Radar im Spiel)
  out.sort((a, b) => ((a.risk === 'high') - (b.risk === 'high')) || b.gain - a.gain);
  return out;
}

// Aufkauf im letzten Stand eines Markts, mit Namen
function buyoutFor(db, last, now, bands, shifts, sales) {
  if (!last) return { t: null, list: [] };
  const comm = new Map(db.prepare('SELECT key, commodity, variant FROM items').all().map((x) => [x.key, !x.variant && x.commodity === 1]));
  const list = buyout(rowsOf(db, last.id), { commodity: (k) => comm.get(k) === true, sales, shifts, bands, age: Math.max(0, now - last.t) });
  const info = itemInfo(db);
  for (const x of list) {
    const i = info(x.key);
    x.name = i.name; x.quality = i.quality; x.item = i.item_id;
  }
  return { t: last.t, list };
}

function itemInfo(db) {
  const get = db.prepare('SELECT name, quality, item_id, variant, vendor FROM items WHERE key = ?');
  return (key) => get.get(key) || { name: null, quality: null, item_id: Number(String(key).split(':')[0]), variant: null, vendor: null };
}

// F52 Fallend und Steigend; dayValues = Map key -> Map tag -> { value }
function moves(db, marketId, bands, dayValues, last, today) {
  if (!last) return { up: [], down: [] };
  const info = itemInfo(db);
  const up = [], down = [];
  for (const r of db.prepare('SELECT item_key, min, median, qty FROM item_snap WHERE snapshot_id = ?').iterate(last.id)) {
    const b = bands.get(r.item_key);
    // zu unruhig (Schwankung ueber 50 %): kein verlaesslicher Bereich fuer Fallend/Steigend
    if (!b || b.schw > 0.5 || r.median == null || r.median < 100 || r.qty < 3) continue;
    const change = r.median / b.lang - 1;
    const dump = r.min != null && r.min < b.lang * (1 - DUMP);
    const rising = r.median > high(b) && change >= MOVE;
    const falling = r.median < low(b) && change <= -MOVE;
    if (!rising && !falling) continue;
    const dv = dayValues.get(r.item_key) || new Map();
    const spark = [];
    for (let d = today - 13; d <= today; d++) { const v = dv.get(d); spark.push(v ? v.value : null); }
    const i = info(r.item_key);
    const row = { key: r.item_key, name: i.name, quality: i.quality, item: i.item_id, now: r.median, min: r.min, qty: r.qty,
      lang: b.lang, low: low(b), high: high(b), change, dump, days: b.days, spark };
    (rising ? up : down).push(row);
  }
  up.sort((a, b) => b.change - a.change);
  down.sort((a, b) => a.change - b.change);
  return { up, down };
}

// F53 Lohnend
function worth(db, bands, sales) {
  const info = itemInfo(db);
  const out = [];
  for (const [key, s] of sales) {
    const b = bands.get(key);
    if (!b || s.level < 2 || !(s.perDay > 0)) continue;
    if (s.sold > 0 && (s.maxSold ?? 0) < PROOF * low(b)) continue;   // verkauft wird nur weit unter dem Bereich
    const span = high(b) * (1 - CUT) - low(b);
    const i = info(key);
    out.push({ key, name: i.name, quality: i.quality, item: i.item_id, perDay: s.perDay, level: s.level, rate: s.rate,
      lang: b.lang, low: low(b), high: high(b), avgPrice: s.avgPrice, turnover: s.perDay * (s.avgPrice ?? b.lang), spanDay: span > 0 ? s.perDay * span : 0 });
  }
  out.sort((a, b) => b.spanDay - a.spanDay || b.turnover - a.turnover);
  return out;
}

module.exports = { moves, worth, rowsOf, low, high, buyout, buyoutFor, CUT, UNSURE, BUYOUT_MIN, BUYOUT_HOURS };
