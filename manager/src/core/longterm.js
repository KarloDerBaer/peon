'use strict';
// Peon Manager - Langzeit-Teil des ueblichen Bereichs fuer Broker (Rechenmodell Kapitel 8, F42).
// Gleiche Formeln wie Broker F35 bis F37 (Data.lua D.Band), aber aus den Tageswerten des Managers:
// TAGc = Mittel der Mediane aller eigenen Komplettscans eines Tages, sonst Broker-Tagesmittel (hist).

const { dayOf } = require('./broker');

const DAYS = 14, MIN_DAYS = 3, HALF = 3, MIN_SCHW = 0.05;

function median(list) {
  const s = [...list].sort((a, b) => a - b);
  const n = s.length;
  if (!n) return null;
  return n % 2 ? s[(n - 1) / 2] : (s[n / 2 - 1] + s[n / 2]) / 2;
}

// Tageswerte je Gegenstand: Map key -> Map tag -> { value, own }
// key: nur dieser Gegenstand (Verlauf des Bereichs in der Ansicht Gegenstand)
function dayValues(db, marketId, today, key = null, span = DAYS) {
  const from = today - span;   // Tage > from und <= today
  const k1 = key == null ? '' : ' AND item_key = ?';
  const kv = key == null ? [] : [key];
  const own = new Map();
  const add = (key, day, med, w) => {
    if (med == null || day <= from || day > today) return;
    let m = own.get(key);
    if (!m) { m = new Map(); own.set(key, m); }
    const x = m.get(day) || { sum: 0, n: 0 };
    x.sum += med * w; x.n += w; m.set(day, x);
  };
  // grob vorfiltern (ein Tag Spielraum fuer Zeitzonen), genau entscheidet dayOf
  const tFrom = (from - 1) * 86400;
  for (const r of db.prepare("SELECT item_key, t, median FROM item_snap WHERE market_id = ? AND source = 'scan' AND t >= ?" + k1).iterate(marketId, tFrom, ...kv)) {
    add(r.item_key, dayOf(r.t), r.median, 1);
  }
  for (const r of db.prepare("SELECT item_key, t, median, n FROM item_hour WHERE market_id = ? AND source = 'scan' AND t >= ?" + k1).iterate(marketId, tFrom, ...kv)) {
    add(r.item_key, dayOf(r.t), r.median, r.n);
  }
  const out = new Map();
  for (const [key, m] of own) {
    const d = new Map();
    for (const [day, x] of m) d.set(day, { value: x.sum / x.n, own: true });
    out.set(key, d);
  }
  for (const r of db.prepare("SELECT item_key, num, median FROM hist WHERE market_id = ? AND source = 'broker' AND period = 'day' AND num > ? AND num <= ?" + k1).iterate(marketId, from, today, ...kv)) {
    if (r.median == null) continue;
    let d = out.get(r.item_key);
    if (!d) { d = new Map(); out.set(r.item_key, d); }
    if (!d.has(r.num)) d.set(r.num, { value: r.median, own: false });
  }
  return out;
}

// F42 fuer einen Gegenstand; days = Map tag -> { value, own }
function compute(days, today) {
  const xs = [], ages = [];
  let own = false, broker = false;
  for (const [day, v] of days) {
    if (!(v.value > 0)) continue;
    xs.push(v.value); ages.push(today - day);
    if (v.own) own = true; else broker = true;
  }
  if (xs.length < MIN_DAYS) return null;
  const mitte = median(xs);                                                   // F35
  if (!(mitte > 0)) return null;
  const schw = Math.max(1.4826 * median(xs.map((x) => Math.abs(x - mitte))) / mitte, MIN_SCHW);   // F36
  const lo = mitte * (1 - 3 * schw), hi = mitte * (1 + 3 * schw);
  let sw = 0, sx = 0;                                                         // F37
  xs.forEach((x, i) => { const w = 0.5 ** (ages[i] / HALF); sw += w; sx += w * Math.max(lo, Math.min(hi, x)); });
  return { mitte, schw, lang: sx / sw, days: xs.length, src: (own ? 'e' : '') + (broker ? 'b' : '') };
}

// Alle Gegenstaende eines Markts. Rueckgabe Map key -> Ergebnis
function marketLongTerm(db, marketId, now = Math.floor(Date.now() / 1000)) {
  const today = dayOf(now);
  const out = new Map();
  for (const [key, days] of dayValues(db, marketId, today)) {
    const r = compute(days, today);
    if (r) out.set(key, r);
  }
  return { day: today, items: out };
}

// Verlauf des ueblichen Bereichs eines Gegenstands: je Tag der Stand, den Broker an diesem Tag bekommen haette
// (gleiche Rechnung, Tageswerte bis zu diesem Tag). Rueckgabe [{ day, lang, low, high }]
function itemBandHistory(db, marketId, key, fromDay, toDay) {
  const days = dayValues(db, marketId, toDay, key, toDay - fromDay + DAYS).get(key) || new Map();
  const out = [];
  for (let d = fromDay; d <= toDay; d++) {
    const win = new Map([...days].filter(([x]) => x > d - DAYS && x <= d));
    const r = compute(win, d);
    if (r) out.push({ day: d, lang: r.lang, low: Math.max(0, r.lang * (1 - r.schw)), high: r.lang * (1 + r.schw) });
  }
  return out;
}

// Text fuer Data.lua: "MITTE:SCHW:LANG:TAGE:Quelle" (Kupfer gerundet, SCHW in Zehntausendsteln)
function encode(r) {
  return `${Math.round(r.mitte)}:${Math.round(r.schw * 10000)}:${Math.round(r.lang)}:${r.days}:${r.src}`;
}

// Hinweis: toLua schreibt reine Zahlen-Schluessel als [2770] (Zahl wie in Broker), alle anderen als Text.

module.exports = { marketLongTerm, dayValues, itemBandHistory, compute, encode, median, DAYS, MIN_DAYS };
