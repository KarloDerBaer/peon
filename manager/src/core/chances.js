'use strict';
// Peon Manager - Chancen (Rechenmodell Kapitel 9.3, F50 bis F53).
// Beim Einlesen wird je Komplettscan festgehalten, welche Angebote sich zum Wiederverkauf (unter der Untergrenze)
// oder beim Haendler lohnen (opp_snap). Die Reiter fassen das ueber den gewaehlten Zeitraum zusammen.

const zlib = require('node:zlib');
const { parseRows, itemKey, unitPrice, summarize } = require('./stats');
const { dayOf } = require('./broker');
const { tx } = require('./db');

const CUT = 0.05;          // Auktionshaus-Gebuehr beim Verkauf (F11)
const MARGIN = 0.20;       // Wiederverkauf: Gewinn mindestens 20 % des Einkaufs (wie Broker dealMargin)
const MOVE = 0.15;         // Fallend/Steigend: mindestens 15 % vom Langzeitwert
const DUMP = 0.30;         // Dumping: Min unter 70 % vom Langzeitwert (wie Broker dumpPct)
const SLOTS = 8;           // 3-Stunden-Abschnitte
const PROOF = 0.8;         // in 14 Tagen mindestens einmal zu 80 % des Zielpreises verkauft, sonst zweifelhaft (Scherzpreise)

function low(b) { return Math.max(0, b.lang * (1 - b.schw)); }
function high(b) { return b.lang * (1 + b.schw); }

// Haendlerpreise aller bekannten Gegenstaende: Map key -> Kupfer
function vendorMap(db) {
  const out = new Map();
  for (const r of db.prepare('SELECT key, vendor FROM items WHERE vendor > 0').iterate()) out.set(r.key, r.vendor);
  return out;
}

// F50, F51 fuer einen Scan. bands = Map key -> Langzeit-Teil (longterm), vendors = Map key -> Haendlerpreis
// shifts = Map key -> neues Preisniveau (F54): faellt der Preis gerade, kein Wiederverkauf
// Ab Manager 0.21.0 (F50a): Wiederverkauf hoechstens zum Median der Angebote dieses Scans. Liegen alle Angebote
// gleich tief, ist das guenstigste kein Schnaeppchen (wie Broker: Verkauf hoechstens zum naechsten Angebot).
function scanOpp(rows, bands, vendors, shifts = null) {
  const res = new Map();   // "key|kind" -> { key, kind, qty, profit, cost, ref }
  const sum = bands.size ? summarize(rows) : new Map();
  const add = (key, kind, q, g, p, ref) => {
    const k = key + '|' + kind;
    const x = res.get(k) || { key, kind, qty: 0, profit: 0, cost: 0, ref };
    x.qty += q; x.profit += q * g; x.cost += q * p;
    res.set(k, x);
  };
  for (const r of rows) {
    const p = unitPrice(r);
    if (p == null || !(r.qty > 0)) continue;
    const key = itemKey(r);
    const q = r.qty * r.n;
    const b = bands.get(key);
    const sh = shifts && shifts.get(key);
    if (b && !(sh && sh.dir === 'down')) {
      const s = sum.get(key);
      const sell = s && s.median > 0 ? Math.min(low(b), s.median) : low(b);
      const g = sell * (1 - CUT) - p;
      if (sell > 0 && g >= MARGIN * p && g > 0) add(key, 'r', q, g, p, sell);
    }
    const hp = vendors.get(key) ?? vendors.get(String(r.item));
    if (hp && p < hp) add(key, 'v', q, hp - p, p, hp);
  }
  return [...res.values()];
}

function rowsOf(db, id) {
  const r = db.prepare('SELECT rows FROM snapshots WHERE id = ?').get(id);
  if (!r || !r.rows) return null;
  return parseRows(zlib.inflateSync(Buffer.from(r.rows)).toString('utf8'));
}

// Neue Scans auswerten; bei neuen Haendlerpreisen die Haendler-Treffer der letzten 14 Tage neu rechnen
function updateMarket(db, marketId, bands, now, shifts = null) {
  const vendors = vendorMap(db);
  // Stand der Haendlerpreise (Anzahl und Summe): aendert sich einer, werden die Haendler-Treffer neu gerechnet
  let sum = 0;
  for (const v of vendors.values()) sum = (sum + v) % 1e9;
  const vn = vendors.size * 1e9 + sum;
  const res = { scans: 0, vendor: 0 };
  tx(db, () => {
    const ins = db.prepare('INSERT OR REPLACE INTO opp_snap(snapshot_id, market_id, item_key, t, kind, qty, profit, cost, ref) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)');
    const mark = db.prepare('INSERT OR REPLACE INTO opp_scan(snapshot_id, market_id, t, vendor_n) VALUES (?, ?, ?, ?)');
    const from = now - 14 * 86400;
    const todo = db.prepare(`SELECT s.id, s.t, o.vendor_n FROM snapshots s LEFT JOIN opp_scan o ON o.snapshot_id = s.id
        WHERE s.market_id = ? AND s.source = 'scan' AND s.rows IS NOT NULL AND s.t >= ? AND (o.snapshot_id IS NULL OR o.vendor_n <> ?)`).all(marketId, from, vn);
    for (const s of todo) {
      const rows = rowsOf(db, s.id);
      if (!rows) continue;
      const fresh = s.vendor_n == null;
      let list = scanOpp(rows, fresh ? bands : new Map(), vendors, shifts);
      if (!fresh) { db.prepare("DELETE FROM opp_snap WHERE snapshot_id = ? AND kind = 'v'").run(s.id); res.vendor++; }
      else res.scans++;
      for (const x of list) ins.run(s.id, marketId, x.key, s.t, x.kind, x.qty, x.profit, x.cost, x.ref);
      mark.run(s.id, marketId, s.t, vn);
    }
  });
  return res;
}

function slotOf(t) { return Math.floor(new Date(t * 1000).getHours() / 3); }

function itemInfo(db) {
  const get = db.prepare('SELECT name, quality, item_id, variant, vendor FROM items WHERE key = ?');
  return (key) => get.get(key) || { name: null, quality: null, item_id: Number(String(key).split(':')[0]), variant: null, vendor: null };
}

// Treffer eines Typs (r/v) zusammenfassen
function summarizeOpp(db, marketId, kind, days, now, sales, lastId) {
  const from = now - days * 86400;
  const scans = db.prepare('SELECT COUNT(*) AS n FROM opp_scan WHERE market_id = ? AND t >= ?').get(marketId, from).n;
  if (!scans) return { scans: 0, list: [] };
  const by = new Map();
  for (const r of db.prepare('SELECT snapshot_id, item_key, t, qty, profit, cost, ref FROM opp_snap WHERE market_id = ? AND kind = ? AND t >= ?').iterate(marketId, kind, from)) {
    let x = by.get(r.item_key);
    if (!x) { x = { key: r.item_key, hits: 0, qty: 0, profit: 0, cost: 0, ref: r.ref, refT: r.t, slots: new Array(SLOTS).fill(0), now: null }; by.set(r.item_key, x); }
    x.hits++; x.qty += r.qty; x.profit += r.profit; x.cost += r.cost;
    x.slots[slotOf(r.t)]++;
    if (r.t >= x.refT) { x.ref = r.ref; x.refT = r.t; }
    if (r.snapshot_id === lastId) x.now = { qty: r.qty, profit: r.profit, price: r.cost / r.qty };
  }
  const info = itemInfo(db);
  const list = [];
  for (const x of by.values()) {
    const s = sales.get(x.key) || null;
    const perScan = x.qty / scans;
    const per = x.profit / x.qty;
    const best = x.slots.indexOf(Math.max(...x.slots));
    // Wiederverkauf nur, wenn zu diesem Preis auch verkauft wird (hoechster Verkauf in 14 Tagen mindestens 80 % des Ziels)
    const doubt = kind === 'r' && s && s.sold > 0 && (s.maxSold ?? 0) < PROOF * x.ref;
    const value = kind === 'v' ? perScan * per : (s && s.perDay != null && !doubt ? Math.min(s.perDay, perScan) * per : null);
    const i = info(x.key);
    list.push({ key: x.key, name: i.name, quality: i.quality, item: i.item_id, share: x.hits / scans, hits: x.hits, perScan,
      perPiece: per, buy: x.cost / x.qty, sell: x.ref, perDay: value, rough: perScan * per,
      sales: s ? { perDay: s.perDay, level: s.level, rate: s.rate, avgPrice: s.avgPrice, maxSold: s.maxSold } : null, doubt: !!doubt, slot: x.slots[best] ? best : null, now: x.now });
  }
  list.sort((a, b) => (b.perDay ?? -1) - (a.perDay ?? -1) || b.rough - a.rough);
  return { scans, list };
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

// F55 Treffer der Wiederverkaufs-Vorschlaege (ab Manager 0.21.0, KarloDerBaer 08.11.2026): Jeder Gegenstand zaehlt
// hoechstens einmal je Tag (erster Treffer des Tages). Danach HOLD Tage lang geschaut, wie hoch das guenstigste Angebot
// der Median der Angebote gestiegen ist (das guenstigste Angebot waere ja gekauft): bis zum Verkaufsziel (hit),
// immerhin ueber Kaufpreis plus Gebuehr (even) oder nicht (miss).
// Gezaehlt werden nur Vorschlaege, deren HOLD Tage vorbei sind, aus den letzten days Tagen davor.
const HOLD = 3;
function hitRate(db, marketId, now, days = 14) {
  const to = now - HOLD * 86400, from = to - days * 86400;
  const first = new Map();   // "key|tag" -> erster Treffer
  for (const r of db.prepare("SELECT item_key, t, qty, cost, ref FROM opp_snap WHERE market_id = ? AND kind = 'r' AND t > ? AND t <= ? ORDER BY t").iterate(marketId, from, to)) {
    const k = r.item_key + '|' + dayOf(r.t);
    if (!first.has(k) && r.qty > 0) first.set(k, { key: r.item_key, t: r.t, buy: r.cost / r.qty, ref: r.ref });
  }
  const snap = db.prepare("SELECT MAX(median) AS m FROM item_snap WHERE market_id = ? AND item_key = ? AND source = 'scan' AND t > ? AND t <= ?");
  const hour = db.prepare("SELECT MAX(median) AS m FROM item_hour WHERE market_id = ? AND item_key = ? AND source = 'scan' AND t > ? AND t <= ?");
  const res = { days, hold: HOLD, n: 0, hit: 0, even: 0, miss: 0 };
  for (const x of first.values()) {
    const a = snap.get(marketId, x.key, x.t, x.t + HOLD * 86400).m;
    const b = hour.get(marketId, x.key, x.t, x.t + HOLD * 86400).m;
    const best = Math.max(a ?? -1, b ?? -1);
    if (best < 0) continue;   // danach kein Stand mit Angeboten: nicht bewertbar
    res.n++;
    if (x.ref > 0 && best >= x.ref) res.hit++;
    else if (best * (1 - CUT) >= x.buy) res.even++;
    else res.miss++;
  }
  return res;
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

module.exports = { scanOpp, updateMarket, summarizeOpp, moves, worth, hitRate, low, high, CUT, MARGIN, SLOTS, HOLD };
