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
// Ab Manager 0.22.0 (KarloDerBaer 08.11.2026, Beispiele Robuster Stein und Umhang des Huegelwaechters):
const DEPTH = 1;           // F50b: unter dem Verkaufsziel hoechstens so viel Ware wie in DEPTH Tagen verkauft wird
const UNSURE = 0.4;        // F50c: Schwankung ueber 40 %: Bereich zu breit, kein Wiederverkauf

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
// Ab Manager 0.22.0: F50b Menge unter dem Ziel (sales = Map key -> Absatz, nur ab Stufe 2 geprueft): Liegt unter dem
// Verkaufsziel mehr Ware, als in einem Tag verkauft wird, muesste man den Markt leer kaufen. Das ist der Marktpreis,
// keine Chance. F50c: Bei Schwankung ueber 40 % ist der Bereich zu breit fuer ein Verkaufsziel.
function scanOpp(rows, bands, vendors, shifts = null, sales = null) {
  const res = new Map();   // "key|kind" -> { key, kind, qty, profit, cost, ref }
  const sum = bands.size ? summarize(rows) : new Map();
  // Verkaufsziel je Gegenstand (F50a) und Menge darunter (F50b)
  const target = new Map();
  for (const [key, s] of sum) {
    const b = bands.get(key);
    const sh = shifts && shifts.get(key);
    if (!b || b.schw > UNSURE || (sh && sh.dir === 'down')) continue;
    target.set(key, { sell: s && s.median > 0 ? Math.min(low(b), s.median) : low(b), below: 0 });
  }
  for (const r of rows) {
    const x = target.get(itemKey(r));
    const p = unitPrice(r);
    if (x && p != null && r.qty > 0 && p < x.sell) x.below += r.qty * r.n;
  }
  for (const [key, x] of target) {
    const s = sales && sales.get(key);
    if (s && s.level >= 2 && s.perDay != null && x.below > DEPTH * s.perDay) target.delete(key);
  }
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
    const t = target.get(key);
    if (t) {
      const sell = t.sell;
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
function updateMarket(db, marketId, bands, now, shifts = null, sales = null) {
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
      let list = scanOpp(rows, fresh ? bands : new Map(), vendors, shifts, sales);
      if (!fresh) { db.prepare("DELETE FROM opp_snap WHERE snapshot_id = ? AND kind = 'v'").run(s.id); res.vendor++; }
      else res.scans++;
      for (const x of list) ins.run(s.id, marketId, x.key, s.t, x.kind, x.qty, x.profit, x.cost, x.ref);
      mark.run(s.id, marketId, s.t, vn);
    }
  });
  return res;
}

// Stand der Regeln fuer Wiederverkauf. Gespeicherte Treffer (opp_snap) werden nur einmal je Scan gerechnet.
// Aendern sich die Regeln, gelten die alten Treffer nicht mehr (Manager 0.21.1: sonst zeigte „Beste Chancen jetzt“
// noch Treffer nach den Regeln vor 0.21.0, zum Beispiel Robuster Stein). Dann alle Wiederverkaufs-Treffer loeschen
// und den letzten Scan jedes Markts neu auswerten lassen. Die Trefferquote beginnt damit neu, nur mit den neuen Regeln.
const RULES = 3;   // 3: Manager 0.22.0 (F50b, F50c)
function resetRules(db, current) {
  if (current === RULES) return false;
  tx(db, () => {
    db.prepare("DELETE FROM opp_snap WHERE kind = 'r'").run();
    for (const r of db.prepare('SELECT o.snapshot_id FROM opp_scan o WHERE o.t = (SELECT MAX(t) FROM opp_scan x WHERE x.market_id = o.market_id)').all()) {
      db.prepare('DELETE FROM opp_snap WHERE snapshot_id = ?').run(r.snapshot_id);
      db.prepare('DELETE FROM opp_scan WHERE snapshot_id = ?').run(r.snapshot_id);
    }
  });
  return true;
}

function slotOf(t) { return Math.floor(new Date(t * 1000).getHours() / 3); }

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

// Treffer eines Typs (r/v). Ab Manager 0.22.0 (KarloDerBaer 08.11.2026) nur, was der letzte Scan ergeben hat, mit
// den Preisen aus diesem Scan. Der Zeitraum zeigt nur noch, wie oft der Gegenstand dabei war und wann meistens.
function summarizeOpp(db, marketId, kind, days, now, sales, lastId) {
  const from = now - days * 86400;
  const scans = db.prepare('SELECT COUNT(*) AS n FROM opp_scan WHERE market_id = ? AND t >= ?').get(marketId, from).n;
  if (!scans || !lastId) return { scans, list: [] };
  const by = new Map();
  for (const r of db.prepare('SELECT item_key, qty, profit, cost, ref FROM opp_snap WHERE snapshot_id = ? AND kind = ?').iterate(lastId, kind)) {
    if (r.qty > 0) by.set(r.item_key, { key: r.item_key, qty: r.qty, profit: r.profit, cost: r.cost, ref: r.ref, hits: 0, slots: new Array(SLOTS).fill(0) });
  }
  for (const r of db.prepare('SELECT item_key, t FROM opp_snap WHERE market_id = ? AND kind = ? AND t >= ?').iterate(marketId, kind, from)) {
    const x = by.get(r.item_key);
    if (!x) continue;
    x.hits++;
    x.slots[slotOf(r.t)]++;
  }
  const info = itemInfo(db);
  const list = [];
  for (const x of by.values()) {
    const s = sales.get(x.key) || null;
    const per = x.profit / x.qty;
    const best = x.slots.indexOf(Math.max(...x.slots));
    // Wiederverkauf nur, wenn zu diesem Preis auch verkauft wird (hoechster Verkauf in 14 Tagen mindestens 80 % des Ziels)
    const doubt = kind === 'r' && s && s.sold > 0 && (s.maxSold ?? 0) < PROOF * x.ref;
    const value = kind === 'v' ? x.qty * per : (s && s.perDay != null && !doubt ? Math.min(s.perDay, x.qty) * per : null);
    const i = info(x.key);
    list.push({ key: x.key, name: i.name, quality: i.quality, item: i.item_id, share: Math.min(1, x.hits / scans), hits: x.hits, qty: x.qty,
      perPiece: per, buy: x.cost / x.qty, sell: x.ref, perDay: value, rough: x.qty * per,
      sales: s ? { perDay: s.perDay, level: s.level, rate: s.rate, avgPrice: s.avgPrice, maxSold: s.maxSold } : null, doubt: !!doubt, slot: x.slots[best] ? best : null,
      now: { qty: x.qty, profit: x.profit, price: x.cost / x.qty } });
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

module.exports = { scanOpp, updateMarket, summarizeOpp, moves, worth, hitRate, resetRules, rowsOf, low, high, buyout, buyoutFor,
  CUT, MARGIN, SLOTS, HOLD, RULES, DEPTH, UNSURE, BUYOUT_MIN, BUYOUT_HOURS };
