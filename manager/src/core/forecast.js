'use strict';
// Peon Manager - Prognosen (Konzept Peon_Manager_Chancen.md, Abschnitt 5, F60 bis F67).
// Eine Prognose sagt fuer einen Gegenstand Richtung (1 steigt, -1 faellt), Zeitraum (Tage) und Sicherheit
// (low, mid, high) und nennt die Signale, aus denen sie entsteht:
//   scarce  Knappheit (F61): Reichweite faellt, Absatz bleibt
//   glut    Schwemme (F62): viel neu eingestellt, Reichweite steigt
//   level   Stufenbereich (F64): im Bereich wird weniger eingestellt, verkauft wird kaum weniger
//   fest    Fest (F65): beim letzten gleichen Fest stieg oder fiel der Preis
//   week    Wochenrhythmus (5.3): Preis je Wochentag und Tageszeit mit festem Muster (nur im Steckbrief gerechnet)
// Jede Prognose wird gespeichert (forecast_log) und nach ihrem Zeitraum nachgeprueft (F67).

const { dayOf, dayTime } = require('./broker');
const { low, high } = require('./chances');

const CUT = 0.05;
const SIGNALS = {
  scarce: { label: 'Knappheit', dir: 1, days: 7 },
  glut: { label: 'Schwemme', dir: -1, days: 7 },
  level: { label: 'Stufenbereich', dir: 1, days: 14, maxSure: 'mid' },
  fest: { label: 'Fest', days: 14 },
  week: { label: 'Wochenrhythmus', days: 7 },
};
const SURE = ['low', 'mid', 'high'];
const SURE_TEXT = { low: 'niedrig', mid: 'mittel', high: 'hoch' };
// Startwerte (Abschnitt 5, KarloDerBaer 13.11.2026: wie im Konzept)
const P = {
  scarceDays: 5, scarceFalls: 4, scarcePart: 0.6,
  glutPart: 1.5, glutDays: 3,
  levelDrop: 0.25, levelSpan: 10,
  festPct: 0.2, festAhead: 14,
  weekPct: 0.1, weekWeeks: 3,
  newBelow: 20, offBelow: 0.4, highRate: 0.7, rateDays: 30,
};

const clampExpect = (x) => Math.max(0.1, Math.min(1.5, x));

// Absatz je Tag und Gegenstand (ueber sales_cmp und sales_day): Map key -> Map tag -> { sold, listed, expired, secs }
function salesDays(db, marketId, today, span = 28) {
  const out = new Map();
  const add = (r) => {
    let m = out.get(r.item_key);
    if (!m) { m = new Map(); out.set(r.item_key, m); }
    const x = m.get(r.day) || { sold: 0, listed: 0, expired: 0, secs: 0 };
    x.sold += r.sold || 0; x.listed += r.listed || 0; x.expired += r.expired || 0; x.secs += r.secs || 0;
    m.set(r.day, x);
  };
  for (const r of db.prepare('SELECT item_key, day, sold, listed, expired, secs FROM sales_cmp WHERE market_id = ? AND day > ? AND day <= ?').iterate(marketId, today - span, today)) add(r);
  for (const r of db.prepare('SELECT item_key, day, sold, listed, expired, secs FROM sales_day WHERE market_id = ? AND day > ? AND day <= ?').iterate(marketId, today - span, today)) add(r);
  return out;
}

const perDay = (x) => (x && x.secs > 0 ? x.sold / x.secs * 86400 : null);
const listedDay = (x) => (x && x.secs > 0 ? x.listed / x.secs * 86400 : null);
const mean = (l) => { const v = l.filter((x) => x != null && Number.isFinite(x)); return v.length ? v.reduce((a, b) => a + b, 0) / v.length : null; };

// F60 Reichweite je Tag: [{ day, reach }] der letzten span Tage (nur Tage mit Menge und Absatz)
function reachDays(qty, sd, today, span = 14, fallback = null) {
  const out = [];
  for (let d = today - span + 1; d <= today; d++) {
    const q = qty && qty.get(d);
    const pd = perDay(sd && sd.get(d)) ?? fallback;
    if (q == null || !(pd > 0)) continue;
    out.push({ day: d, reach: q / pd, qty: q, perDay: pd });
  }
  return out;
}

// F61 Knappheit
function scarce(r, sd, today, b, price) {
  if (r.length < P.scarceDays + 1) return null;
  const last = r.slice(-(P.scarceDays + 1));
  let falls = 0;
  for (let i = 1; i < last.length; i++) if (last[i].reach < last[i - 1].reach) falls++;
  const avg = mean(r.map((x) => x.reach));
  const now = last[last.length - 1].reach;
  if (falls < P.scarceFalls || !(avg > 0) || now >= P.scarcePart * avg) return null;
  const recent = mean(last.slice(-3).map((x) => x.perDay)), before = mean(r.slice(0, -3).map((x) => x.perDay));
  if (recent != null && before != null && recent < before * 0.95) return null;   // Absatz gefallen: keine Knappheit
  return { id: 'scarce', dir: 1, days: 7, expect: clampExpect(b && price > 0 ? high(b) / price - 1 : 0.15),
    text: `Reichweite an ${falls} von ${P.scarceDays} Tagen gefallen, heute ${Math.round(now / avg * 100)} % ihres Mittels`, values: { falls, part: now / avg } };
}

// F62 Schwemme
function glut(r, sd, today, b, price) {
  if (!sd || r.length < 4) return null;
  const listed = [];
  for (let d = today - 13; d <= today; d++) listed.push(listedDay(sd.get(d)));
  const avg = mean(listed);
  if (!(avg > 0)) return null;
  const last = listed.slice(-P.glutDays);
  if (last.some((x) => x == null || x <= P.glutPart * avg)) return null;
  if (r[r.length - 1].reach <= r[Math.max(0, r.length - 4)].reach) return null;
  return { id: 'glut', dir: -1, days: 7, expect: clampExpect(b && price > 0 ? 1 - low(b) / price : 0.15),
    text: `${P.glutDays} Tage hintereinander mehr als ${Math.round(P.glutPart * 100)} % des Üblichen neu eingestellt, Reichweite gestiegen`, values: { part: mean(last) / avg } };
}

// F63 Index je Stufenbereich. levels = Map item_id -> { req, equip }. Rueckgabe Map band -> Zeile
function levelIndex(salesByKey, levels, values, bands, today) {
  const idx = new Map();
  for (const [key, days] of salesByKey) {
    const lv = levels.get(Number(String(key).split(':')[0]));
    if (!lv || !(lv.req > 0)) continue;
    const band = Math.floor((lv.req - 1) / P.levelSpan);
    const id = `${band}:${lv.equip ? 1 : 0}`;
    let x = idx.get(id);
    if (!x) { x = { id, band, from: band * P.levelSpan + 1, to: band * P.levelSpan + P.levelSpan, equip: !!lv.equip, items: 0, listedA: 0, listedB: 0, soldA: 0, soldB: 0, ratio: [], keys: [] }; idx.set(id, x); }
    x.items++;
    x.keys.push(key);
    let lA = 0, lB = 0, sA = 0, sB = 0, ex = 0;
    for (const [d, v] of days) {
      const f = v.secs > 0 ? 86400 / v.secs : 0;   // auf ganze Tage hochgerechnet
      if (d > today - 7) { lA += v.listed * f; sA += v.sold * f; ex += v.expired * f; } else if (d > today - 14) { lB += v.listed * f; sB += v.sold * f; }
    }
    x.listedA += lA; x.listedB += lB; x.soldA += sA; x.soldB += sB;
    const b = bands.get(key), dv = values.get(key);
    const v = dv && dv.get(today);
    if (b && v && b.lang > 0) x.ratio.push(v.value / b.lang);
    if (lA > 0 && sA > 0) (x.rank = x.rank || []).push({ key, listed: lA, sold: sA, rate: sA / (sA + ex) });
  }
  for (const x of idx.values()) {
    x.listedChange = x.listedB > 0 ? x.listedA / x.listedB - 1 : null;
    x.soldChange = x.soldB > 0 ? x.soldA / x.soldB - 1 : null;
    const r = [...x.ratio].sort((a, b) => a - b);
    x.price = r.length ? r[Math.floor(r.length / 2)] : null;
    delete x.ratio;
    // Rangliste: haeufig eingestellt (droppt oft) und trotzdem schnell verkauft
    x.rank = (x.rank || []).filter((y) => y.listed >= 7).sort((a, b) => b.rate * Math.log1p(b.listed) - a.rate * Math.log1p(a.listed)).slice(0, 10);
    x.signal = x.listedChange != null && x.listedChange <= -P.levelDrop && (x.soldChange == null || x.soldChange > x.listedChange);
  }
  return idx;
}

// F65 Feste: fuer jedes Fest, das in den naechsten 14 Tagen beginnt, das letzte gleiche Fest suchen und den
// Preis damals vergleichen. Rueckgabe Map key -> [{ name, start, change }]
function festSignals(db, marketId, fests, now) {
  const out = new Map();
  const soon = fests.filter((f) => f.s > now && f.s - now <= P.festAhead * 86400);
  for (const f of soon) {
    const prev = fests.filter((x) => x.n === f.n && x.s < now && x.s < f.s).sort((a, b) => b.s - a.s)[0];
    if (!prev) continue;
    const avg = (from, to) => {
      const m = new Map();
      const put = (r) => { const x = m.get(r.item_key) || { s: 0, n: 0 }; x.s += r.m * r.n; x.n += r.n; m.set(r.item_key, x); };
      for (const r of db.prepare("SELECT item_key, AVG(median) AS m, COUNT(*) AS n FROM item_hour WHERE market_id = ? AND source = 'scan' AND t >= ? AND t < ? AND median > 0 GROUP BY item_key").iterate(marketId, from, to)) put(r);
      for (const r of db.prepare("SELECT item_key, AVG(median) AS m, COUNT(*) AS n FROM item_day WHERE market_id = ? AND source = 'scan' AND t >= ? AND t < ? AND median > 0 GROUP BY item_key").iterate(marketId, from, to)) put(r);
      for (const r of db.prepare("SELECT item_key, AVG(median) AS m, COUNT(*) AS n FROM item_snap WHERE market_id = ? AND source = 'scan' AND t >= ? AND t < ? AND median > 0 GROUP BY item_key").iterate(marketId, from, to)) put(r);
      return m;
    };
    const base = avg(prev.s - 14 * 86400, prev.s);
    const during = avg(prev.s - 7 * 86400, Math.max(prev.e || prev.s, prev.s + 86400));
    for (const [k, d] of during) {
      const b = base.get(k);
      if (!b || !(b.s > 0) || d.n < 3 || b.n < 3) continue;
      const change = (d.s / d.n) / (b.s / b.n) - 1;
      if (Math.abs(change) < P.festPct) continue;
      if (!out.has(k)) out.set(k, []);
      out.get(k).push({ name: f.n, start: f.s, end: f.e, change, prev: prev.s });
    }
  }
  return out;
}

// 5.3 Wochenrhythmus fuer einen Gegenstand: Raster 7 Wochentage x 8 Abschnitte (Mittel des Preises), dazu ein Signal,
// wenn guenstigste und teuerste Zeit nach Gebuehr mindestens 10 % auseinander liegen und das in 3 von 4 Wochen gleich war
function weekGrid(db, marketId, key, now) {
  const from = now - 28 * 86400;
  const cells = Array.from({ length: 7 }, () => Array.from({ length: 8 }, () => ({ s: 0, n: 0 })));
  const weeks = new Map();
  const put = (t, m) => {
    if (!(m > 0)) return;
    const d = new Date(t * 1000);
    const wd = (d.getDay() + 6) % 7, slot = Math.floor(d.getHours() / 3);
    cells[wd][slot].s += m; cells[wd][slot].n++;
    const w = Math.floor((t - from) / (7 * 86400));
    if (!weeks.has(w)) weeks.set(w, Array.from({ length: 7 }, () => ({ s: 0, n: 0 })));
    const x = weeks.get(w)[wd]; x.s += m; x.n++;
  };
  for (const r of db.prepare("SELECT t, median FROM item_snap WHERE market_id = ? AND item_key = ? AND source = 'scan' AND t >= ?").iterate(marketId, key, from)) put(r.t, r.median);
  for (const r of db.prepare("SELECT t, median FROM item_hour WHERE market_id = ? AND item_key = ? AND source = 'scan' AND t >= ?").iterate(marketId, key, from)) put(r.t, r.median);
  const grid = cells.map((row) => row.map((c) => (c.n ? c.s / c.n : null)));
  const days = grid.map((row) => mean(row));
  let lo = null, hi = null;
  days.forEach((v, i) => { if (v == null) return; if (lo == null || v < days[lo]) lo = i; if (hi == null || v > days[hi]) hi = i; });
  let signal = null;
  if (lo != null && hi != null && days[hi] * (1 - CUT) >= days[lo] * (1 + P.weekPct)) {
    let same = 0, n = 0;
    for (const w of weeks.values()) {
      const v = w.map((x) => (x.n ? x.s / x.n : null));
      if (v[lo] == null || v[hi] == null) continue;
      n++;
      if (v[hi] > v[lo]) same++;
    }
    if (n >= 3 && same >= P.weekWeeks) signal = { lo, hi, gap: days[hi] / days[lo] - 1, weeks: n, same };
  }
  return { grid, days, signal };
}

// Trefferquote je Signal (F67) aus forecast_log der letzten 30 Tage: Map id -> { n, hit, rate }
function signalRates(db, marketId, now) {
  const out = new Map();
  for (const id of Object.keys(SIGNALS)) out.set(id, { n: 0, hit: 0, rate: null });
  for (const r of db.prepare('SELECT signals, outcome FROM forecast_log WHERE market_id = ? AND checked IS NOT NULL AND t >= ?').iterate(marketId, now - P.rateDays * 86400)) {
    let sig = [];
    try { sig = JSON.parse(r.signals); } catch { /* alt */ }
    for (const s of sig) {
      const x = out.get(s.id || s);
      if (!x) continue;
      x.n++;
      if (r.outcome === 'hit') x.hit++;
    }
  }
  for (const x of out.values()) x.rate = x.n ? x.hit / x.n : null;
  return out;
}

// F66 Sicherheit aus den Signalen. switches = { [id]: true | false | 'force' }, rates = signalRates
function combine(signals, rates, switches = {}) {
  const live = [];
  for (const s of signals) {
    const sw = switches[s.id];
    if (sw === false) continue;
    const r = rates.get(s.id) || { n: 0, rate: null };
    const isNew = r.n < P.newBelow;
    if (!isNew && r.rate < P.offBelow && sw !== 'force') continue;   // bewaehrt sich nicht: aus, bis KarloDerBaer es einschaltet
    live.push({ ...s, label: SIGNALS[s.id].label, n: r.n, rate: r.rate, isNew });
  }
  if (!live.length) return null;
  const up = live.filter((s) => s.dir > 0), down = live.filter((s) => s.dir < 0);
  if (up.length === down.length) return null;   // gegenlaeufig: heben sich auf
  const dir = up.length > down.length ? 1 : -1;
  const own = dir > 0 ? up : down;
  const proven = own.filter((s) => !s.isNew).length - (dir > 0 ? down : up).filter((s) => !s.isNew).length;
  let sure = 'low';
  if (proven >= 3 || own.some((s) => !s.isNew && s.rate > P.highRate)) sure = 'high';
  else if (proven >= 2) sure = 'mid';
  const cap = Math.min(...own.map((s) => SURE.indexOf(SIGNALS[s.id].maxSure || 'high')));
  if (SURE.indexOf(sure) > cap) sure = SURE[cap];
  const ex = own.map((s) => s.expect).filter((x) => x > 0).sort((a, b) => a - b);
  return { dir, days: Math.max(...own.map((s) => s.days)), sure, expect: ex.length ? ex[Math.floor(ex.length / 2)] : 0.1, signals: live };
}

// Alle Prognosen eines Markts. ctx: { db, mid, now, today, bands, values (dayValues), qty (dayQty), sales (marketStats),
// levels, fests, switches }. Rueckgabe { list: Map key -> Prognose, index: Map band -> Zeile, rates }
function marketForecasts(ctx) {
  const { db, mid, now, today, bands, values, qty, sales } = ctx;
  const sd = salesDays(db, mid, today);
  const rates = signalRates(db, mid, now);
  const index = levelIndex(sd, ctx.levels || new Map(), values, bands, today);
  const fest = festSignals(db, mid, ctx.fests || [], now);
  const sigs = new Map();
  const add = (k, s) => { if (!sigs.has(k)) sigs.set(k, []); sigs.get(k).push(s); };
  const priceOf = (k) => { const dv = values.get(k); const v = dv && (dv.get(today) || dv.get(today - 1)); return v ? v.value : null; };
  for (const [k, q] of qty) {
    const st = sales.get(k);
    if (!st || !(st.perDay > 0)) continue;
    const r = reachDays(q, sd.get(k), today, 14, st.perDay);
    const b = bands.get(k), price = priceOf(k);
    const a = scarce(r, sd.get(k), today, b, price); if (a) add(k, a);
    const g = glut(r, sd.get(k), today, b, price); if (g) add(k, g);
  }
  for (const x of index.values()) {
    if (!x.signal) continue;
    for (const k of x.keys) {
      const st = sales.get(k);
      if (!st || (st.level ?? 1) < 2) continue;
      add(k, { id: 'level', dir: 1, days: 14, expect: clampExpect(x.listedB > 0 ? (x.listedB / Math.max(1, x.listedA) - 1) * 0.5 : 0.15),
        text: `Stufe ${x.from} bis ${x.to}: ${Math.round(-x.listedChange * 100)} % weniger eingestellt als in der Woche davor${x.soldChange != null ? `, verkauft ${x.soldChange >= 0 ? '+' : ''}${Math.round(x.soldChange * 100)} %` : ''}`, values: { listed: x.listedChange, sold: x.soldChange } });
    }
  }
  for (const [k, l] of fest) {
    for (const f of l) {
      const days = Math.max(1, Math.ceil((f.start - now) / 86400) + Math.max(1, Math.ceil(((f.end || f.start) - f.start) / 86400)));
      add(k, { id: 'fest', dir: f.change > 0 ? 1 : -1, days, expect: clampExpect(Math.abs(f.change)), fest: f.name,
        text: `${f.name} ab ${new Date(f.start * 1000).toLocaleDateString('de-DE')}: beim letzten Mal ${f.change > 0 ? '+' : ''}${Math.round(f.change * 100)} %`, values: { change: f.change } });
    }
  }
  const list = new Map();
  for (const [k, s] of sigs) {
    const c = combine(s, rates, ctx.switches || {});
    if (c) list.set(k, { key: k, ...c, price: priceOf(k) });
  }
  return { list, index, rates };
}

// Prognosen des Tages speichern (je Gegenstand einmal am Tag)
function logForecasts(db, mid, list, now) {
  const ins = db.prepare(`INSERT OR IGNORE INTO forecast_log(market_id, item_key, day, t, dir, days, sure, signals, price, expect)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`);
  const day = dayOf(now);
  for (const f of list.values()) {
    if (f.price == null) continue;
    ins.run(mid, f.key, day, now, f.dir, f.days, f.sure, JSON.stringify(f.signals.map((s) => ({ id: s.id }))), f.price, f.expect);
  }
}

// F67: abgelaufene Prognosen nachpruefen. Preis am Ende = Mittel der Mediane einen Tag um das Ende
function checkForecasts(db, mid, now) {
  const open = db.prepare('SELECT id, item_key, t, dir, days, price, expect FROM forecast_log WHERE market_id = ? AND checked IS NULL AND t + days * 86400 <= ?').all(mid, now);
  const q1 = db.prepare("SELECT AVG(median) AS m FROM item_snap WHERE market_id = ? AND item_key = ? AND source = 'scan' AND t >= ? AND t <= ?");
  const q2 = db.prepare("SELECT AVG(median) AS m FROM item_hour WHERE market_id = ? AND item_key = ? AND source = 'scan' AND t >= ? AND t <= ?");
  const up = db.prepare('UPDATE forecast_log SET outcome = ?, checked = ? WHERE id = ?');
  let n = 0;
  for (const f of open) {
    const end = f.t + f.days * 86400;
    const m = q1.get(mid, f.item_key, end - 86400, end + 86400).m ?? q2.get(mid, f.item_key, end - 86400, end + 86400).m;
    if (m == null || !(f.price > 0)) { if (now - end > 3 * 86400) up.run('none', now, f.id); continue; }
    const move = f.dir * (m / f.price - 1);
    up.run(move >= (f.expect || 0.1) / 2 ? 'hit' : 'miss', now, f.id);
    n++;
  }
  db.prepare('DELETE FROM forecast_log WHERE t < ?').run(now - 60 * 86400);
  return n;
}

module.exports = { SIGNALS, SURE, SURE_TEXT, P, salesDays, reachDays, scarce, glut, levelIndex, festSignals, weekGrid, signalRates, combine,
  marketForecasts, logForecasts, checkForecasts, dayTime };
