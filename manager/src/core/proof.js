'use strict';
// Peon Manager - Belegte Verkaeufe (Konzept Peon_Manager_Chancen.md, D1, D2, F56, F58).
// Beim Vergleich zweier Staende der Blizzard-API (sales.js, Angebotsnummern) wird jeder Verkauf festgehalten:
//   D1 sale_px:   Stueck je Gegenstand, Tag und Preisstufe (Preis gerundet auf Schritte von 2 %)
//   D2 sale_life: dazu die Stunden, die das verkaufte Angebot im Markt stand (seit dem ersten Stand mit dieser Nummer)
// auc_first merkt je Angebotsnummer den ersten Stand, in dem sie vorkam. Angebote laufen hoechstens 48 Std.,
// deshalb reichen 3 Tage. Angebote aus dem allerersten Stand nach dem Einbau haben keine bekannte Standzeit.
// Aeltere Tage lassen sich nicht nachrechnen, die Zahlen beginnen mit dem Einbau (Manager 0.35.0).

const STEP = Math.log(1.02);   // Preisstufen zu 2 %
const KEEP = 30;               // Tage, die D1 und D2 aufgehoben werden
const FIRST_KEEP = 3 * 86400;  // so lange werden Angebotsnummern gemerkt
const DAYS = 14;               // Zeitraum fuer F56 und F58
const MAX_H = 72;              // Standzeit hoechstens so viele Stunden (laenger gibt es nicht)

const bucket = (p) => Math.round(Math.log(Math.max(1, p)) / STEP);
const priceOf = (b) => Math.exp(b * STEP);

// Angebotsnummern eines Stands merken (nur neue). rows aus stats.parseRows
function noteSeen(db, marketId, rows, t) {
  const ins = db.prepare('INSERT OR IGNORE INTO auc_first(market_id, id, t) VALUES (?, ?, ?)');
  for (const r of rows) if (r.id) ins.run(marketId, r.id, t);
  const k = `aucStart:${marketId}`;
  if (!db.prepare('SELECT 1 FROM meta WHERE key = ?').get(k)) db.prepare('INSERT INTO meta(key, value) VALUES (?, ?)').run(k, JSON.stringify(t));
}

function startOf(db, marketId) {
  const r = db.prepare('SELECT value FROM meta WHERE key = ?').get(`aucStart:${marketId}`);
  return r ? JSON.parse(r.value) : null;
}

// Verkaeufe eines Vergleichs speichern. sold = [{ p, q, id }] aus sales.compare, tA/tB = Zeiten der beiden Staende
function record(db, marketId, key, day, sold, tA, tB, start) {
  if (!sold || !sold.length) return 0;
  const px = db.prepare(`INSERT INTO sale_px(market_id, item_key, day, b, qty) VALUES (?, ?, ?, ?, ?)
      ON CONFLICT(market_id, item_key, day, b) DO UPDATE SET qty = qty + excluded.qty`);
  const life = db.prepare(`INSERT INTO sale_life(market_id, item_key, day, b, h, qty) VALUES (?, ?, ?, ?, ?, ?)
      ON CONFLICT(market_id, item_key, day, b, h) DO UPDATE SET qty = qty + excluded.qty`);
  const first = db.prepare('SELECT t FROM auc_first WHERE market_id = ? AND id = ?');
  const mid = (tA + tB) / 2;
  let n = 0;
  for (const s of sold) {
    if (!(s.q > 0) || !(s.p > 0)) continue;
    const b = bucket(s.p);
    px.run(marketId, key, day, b, s.q);
    n++;
    if (!s.id) continue;
    const f = first.get(marketId, s.id);
    if (!f || (start != null && f.t <= start)) continue;   // seit dem ersten Stand da: Standzeit unbekannt
    const h = Math.max(0, Math.min(MAX_H, Math.round((mid - f.t) / 3600)));
    life.run(marketId, key, day, b, h, s.q);
  }
  return n;
}

// Gewichteter Median aus [{ v, w }]
function wMedian(list) {
  const l = list.filter((x) => x.w > 0).sort((a, b) => a.v - b.v);
  const total = l.reduce((a, x) => a + x.w, 0);
  if (!total) return null;
  let acc = 0;
  for (const x of l) { acc += x.w; if (acc >= total / 2) return x.v; }
  return l[l.length - 1].v;
}

// F56 fuer alle Gegenstaende eines Markts: Map key -> { median, n, max } (Median der Verkaufspreise der letzten 14 Tage)
function soldPrices(db, marketId, today, onlyKey = null) {
  const by = new Map();
  const sql = `SELECT item_key, b, SUM(qty) AS q FROM sale_px WHERE market_id = ? AND day > ? AND day <= ?${onlyKey != null ? ' AND item_key = ?' : ''} GROUP BY item_key, b`;
  const args = onlyKey != null ? [marketId, today - DAYS, today, onlyKey] : [marketId, today - DAYS, today];
  for (const r of db.prepare(sql).iterate(...args)) {
    let x = by.get(r.item_key);
    if (!x) { x = []; by.set(r.item_key, x); }
    x.push({ v: priceOf(r.b), w: r.q });
  }
  const out = new Map();
  for (const [k, l] of by) {
    const n = l.reduce((a, x) => a + x.w, 0);
    out.set(k, { median: Math.round(wMedian(l)), n: Math.round(n * 10) / 10, max: Math.round(Math.max(...l.map((x) => x.v))) });
  }
  return out;
}

// F58 Haltbarkeit: Median der Stunden, die verkaufte Angebote unter 80 % des belegten Verkaufspreises standen.
// Rueckgabe { hours, n } oder null (keine solchen Verkaeufe mit bekannter Standzeit)
function durability(db, marketId, key, ref, today, part = 0.8) {
  if (!(ref > 0)) return null;
  const top = bucket(ref * part);
  const l = db.prepare('SELECT h, SUM(qty) AS q FROM sale_life WHERE market_id = ? AND item_key = ? AND day > ? AND day <= ? AND b <= ? GROUP BY h')
    .all(marketId, key, today - DAYS, today, top).map((r) => ({ v: r.h, w: r.q }));
  if (!l.length) return null;
  return { hours: wMedian(l), n: Math.round(l.reduce((a, x) => a + x.w, 0)) };
}

// Haltbarkeit aller Gegenstaende auf einmal (fuer die Liste): Map key -> { hours, n }, ref = Map key -> belegter Preis
function durabilityAll(db, marketId, refs, today, part = 0.8) {
  const by = new Map();
  for (const r of db.prepare('SELECT item_key, b, h, SUM(qty) AS q FROM sale_life WHERE market_id = ? AND day > ? AND day <= ? GROUP BY item_key, b, h').iterate(marketId, today - DAYS, today)) {
    const ref = refs.get(r.item_key);
    if (!ref || r.b > bucket(ref * part)) continue;
    let x = by.get(r.item_key);
    if (!x) { x = []; by.set(r.item_key, x); }
    x.push({ v: r.h, w: r.q });
  }
  const out = new Map();
  for (const [k, l] of by) out.set(k, { hours: wMedian(l), n: Math.round(l.reduce((a, x) => a + x.w, 0)) });
  return out;
}

// Verkaeufe je Tag fuer den Steckbrief: [{ day, price, qty }] (eine Zeile je Preisstufe)
function salesOf(db, marketId, key, fromDay) {
  return db.prepare('SELECT day, b, qty FROM sale_px WHERE market_id = ? AND item_key = ? AND day >= ? ORDER BY day, b')
    .all(marketId, key, fromDay).map((r) => ({ day: r.day, price: Math.round(priceOf(r.b)), qty: r.qty }));
}

// Standzeiten fuer den Steckbrief: Anteil der Verkaeufe nach Stunden (0-1, 1-6, 6-24, ueber 24)
function lifeOf(db, marketId, key, today) {
  const groups = [[0, 0], [1, 5], [6, 23], [24, MAX_H]].map(([a, b]) => ({ from: a, to: b, qty: 0 }));
  for (const r of db.prepare('SELECT h, SUM(qty) AS q FROM sale_life WHERE market_id = ? AND item_key = ? AND day > ? GROUP BY h').iterate(marketId, key, today - DAYS)) {
    const g = groups.find((x) => r.h >= x.from && r.h <= x.to);
    if (g) g.qty += r.q;
  }
  return groups;
}

function prune(db, now, today) {
  db.prepare('DELETE FROM auc_first WHERE t < ?').run(now - FIRST_KEEP);
  db.prepare('DELETE FROM sale_px WHERE day < ?').run(today - KEEP);
  db.prepare('DELETE FROM sale_life WHERE day < ?').run(today - KEEP);
}

module.exports = { noteSeen, startOf, record, soldPrices, durability, durabilityAll, salesOf, lifeOf, prune, wMedian, bucket, priceOf, DAYS, KEEP };
