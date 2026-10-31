'use strict';
// Peon Manager - Abfragen fuer die Ansichten Gegenstaende und Gegenstand (C3).
// Quellen: eigene Momentaufnahmen (item_snap: scan/live, item_hour, item_day) und Broker-Verlauf (hist).
// Liegen fuer einen Tag eigene Momentaufnahmen vor, gilt der Broker-Wert dieses Tages nicht (Design 5.7).

const zlib = require('node:zlib');
const { parseRows, itemKey, unitPrice } = require('./stats');
const { dayOf } = require('./broker');

function marketRow(db, key) {
  return db.prepare('SELECT id, key FROM markets WHERE key = ?').get(key) || null;
}

// Tagesmediane der letzten `days` Tage je Gegenstand: Map key -> Map tag -> median
function dailyMedians(db, mid, from) {
  const out = new Map();
  const put = (key, day, med) => {
    if (med == null) return;
    let m = out.get(key);
    if (!m) { m = new Map(); out.set(key, m); }
    const x = m.get(day);
    if (x) { x.sum += med; x.n++; } else m.set(day, { sum: med, n: 1, own: true });
  };
  for (const r of db.prepare("SELECT item_key, t, median FROM item_snap WHERE market_id = ? AND source = 'scan' AND t >= ?").iterate(mid, from)) {
    put(r.item_key, dayOf(r.t), r.median);
  }
  for (const r of db.prepare("SELECT item_key, t, median FROM item_hour WHERE market_id = ? AND source = 'scan' AND t >= ?").iterate(mid, from)) {
    put(r.item_key, dayOf(r.t), r.median);
  }
  for (const r of db.prepare("SELECT item_key, num, median FROM hist WHERE market_id = ? AND source = 'broker' AND period = 'day' AND t >= ?").iterate(mid, from)) {
    if (r.median == null) continue;
    let m = out.get(r.item_key);
    if (!m) { m = new Map(); out.set(r.item_key, m); }
    if (!m.has(r.num)) m.set(r.num, { sum: r.median, n: 1, own: false });
  }
  return out;
}

function avgOf(dayMap, fromDay, toDay) {
  let s = 0, n = 0;
  for (const [d, v] of dayMap) if (d > fromDay && d <= toDay) { s += v.sum / v.n; n++; }
  return n ? { value: s / n, days: n } : null;
}

// Liste aller Gegenstaende eines Markts mit dem letzten Stand
function itemList(db, marketKey, now = Math.floor(Date.now() / 1000)) {
  const m = marketRow(db, marketKey);
  if (!m) return { market: marketKey, items: [], lastScan: null };
  const last = db.prepare("SELECT id, t FROM snapshots WHERE market_id = ? AND source = 'scan' ORDER BY t DESC LIMIT 1").get(m.id);
  const cur = new Map();
  if (last) for (const r of db.prepare('SELECT * FROM item_snap WHERE snapshot_id = ?').iterate(last.id)) cur.set(r.item_key, r);
  // zuletzt gesehen (mit Angeboten) je Gegenstand aus allen eigenen Daten und dem Broker-Verlauf
  const seen = new Map();
  const see = (k, t, row) => { const x = seen.get(k); if (!x || t > x.t) seen.set(k, { t, row }); };
  for (const r of db.prepare('SELECT item_key, MAX(t) AS t, min, median, qty, auctions FROM item_snap WHERE market_id = ? AND qty > 0 GROUP BY item_key').iterate(m.id)) see(r.item_key, r.t, r);
  for (const r of db.prepare("SELECT item_key, MAX(t) AS t, min, median, qty FROM hist WHERE market_id = ? AND source = 'broker' GROUP BY item_key").iterate(m.id)) see(r.item_key, r.t, r);
  const counts = new Map();
  for (const r of db.prepare('SELECT item_key, source, COUNT(*) AS n FROM item_snap WHERE market_id = ? GROUP BY item_key, source').iterate(m.id)) {
    const c = counts.get(r.item_key) || {}; c[r.source] = r.n; counts.set(r.item_key, c);
  }
  for (const r of db.prepare("SELECT item_key, COUNT(*) AS n FROM hist WHERE market_id = ? AND source = 'broker' GROUP BY item_key").iterate(m.id)) {
    const c = counts.get(r.item_key) || {}; c.broker = r.n; counts.set(r.item_key, c);
  }
  const today = dayOf(now);
  const daily = dailyMedians(db, m.id, now - 9 * 86400);
  const names = new Map();
  for (const r of db.prepare('SELECT key, item_id, name, quality FROM items').iterate()) names.set(r.key, r);
  const keys = new Set([...cur.keys(), ...seen.keys()]);
  const items = [];
  for (const k of keys) {
    const c = cur.get(k);
    const s = seen.get(k);
    const nm = names.get(k);
    const base = c && c.qty > 0 ? c : s ? s.row : null;
    const a7 = daily.get(k) ? avgOf(daily.get(k), today - 7, today) : null;
    const med = c && c.qty > 0 ? c.median : null;
    items.push({
      key: k, item: nm ? nm.item_id : Number(String(k).split(':')[0]), name: nm && nm.name ? nm.name : null, quality: nm ? nm.quality : null,
      min: base ? base.min : null, median: base ? base.median : null, qty: c ? c.qty : 0, auctions: c ? c.auctions : 0,
      inLast: !!(c && c.qty > 0), seen: s ? s.t : null,
      avg7: a7 ? a7.value : null, trend: med != null && a7 && a7.value > 0 && a7.days >= 2 ? med / a7.value - 1 : null,
      sources: counts.get(k) || {},
    });
  }
  return { market: marketKey, lastScan: last ? last.t : null, items };
}

// Einzelheiten eines Gegenstands. from = Beginn des Zeitraums (Sekunden), null = alles
function itemDetail(db, marketKey, key, { from = null, now = Math.floor(Date.now() / 1000) } = {}) {
  const m = marketRow(db, marketKey);
  if (!m) return null;
  const f = from == null ? 0 : from;
  const nm = db.prepare('SELECT item_id, name, quality, variant FROM items WHERE key = ?').get(key);
  const own = db.prepare(`SELECT t, source, min, median, p25, p75, qty, auctions FROM item_snap
      WHERE market_id = ? AND item_key = ? AND t >= ? ORDER BY t`).all(m.id, key, f);
  const hours = db.prepare(`SELECT t, source, min, median, p25, p75, qty, auctions, n FROM item_hour
      WHERE market_id = ? AND item_key = ? AND t >= ? ORDER BY t`).all(m.id, key, f);
  const days = db.prepare(`SELECT t, source, min, median, p25, p75, qty, auctions, n FROM item_day
      WHERE market_id = ? AND item_key = ? AND t >= ? ORDER BY t`).all(m.id, key, f);
  const ownDays = new Set([...own, ...hours, ...days].filter((x) => x.source === 'scan').map((x) => dayOf(x.t)));
  const broker = db.prepare(`SELECT period, num, t, min, median, qty, n FROM hist
      WHERE market_id = ? AND item_key = ? AND source = 'broker' AND t >= ? ORDER BY t`).all(m.id, key, f)
    .filter((x) => x.period !== 'day' || !ownDays.has(x.num));

  // aktueller Stand: letzter eigener Scan, sonst letzte Live-Abfrage
  const lastScan = db.prepare("SELECT id, t FROM snapshots WHERE market_id = ? AND source = 'scan' ORDER BY t DESC LIMIT 1").get(m.id);
  const curScan = lastScan ? db.prepare('SELECT * FROM item_snap WHERE snapshot_id = ? AND item_key = ?').get(lastScan.id, key) : null;
  const lastLive = db.prepare("SELECT * FROM item_snap WHERE market_id = ? AND item_key = ? AND source = 'live' ORDER BY t DESC LIMIT 1").get(m.id, key);
  let current = null;
  if (curScan) current = { ...curScan, source: 'scan' };
  if (lastLive && (!current || lastLive.t > current.t)) current = { ...lastLive, min: lastLive.min ?? (current && current.min), source: 'live' };
  if (!current && lastScan) current = { t: lastScan.t, source: 'scan', qty: 0, auctions: 0, min: null, median: null, gone: true };

  // Tagesmediane fuer 7 und 14 Tage
  const today = dayOf(now);
  const dm = dailyMedians(db, m.id, now - 16 * 86400).get(key) || new Map();
  const a7 = avgOf(dm, today - 7, today);
  const d14 = [...dm].filter(([d]) => d > today - 14).map(([, v]) => v.sum / v.n);

  // Muster: Median im Verhaeltnis zum Mittel aller Scans, je Wochentag und Uhrzeit (eigene Scans, 60 Tage)
  const pat = db.prepare(`SELECT t, median FROM item_snap WHERE market_id = ? AND item_key = ? AND source = 'scan' AND median IS NOT NULL AND t >= ?`)
    .all(m.id, key, now - 60 * 86400);
  let pattern = null;
  if (pat.length) {
    const mean = pat.reduce((s, x) => s + x.median, 0) / pat.length;
    const cells = Array.from({ length: 7 }, () => Array.from({ length: 8 }, () => ({ sum: 0, n: 0 })));
    for (const x of pat) {
      const d = new Date(x.t * 1000);
      const wd = (d.getDay() + 6) % 7;            // Montag = 0
      const slot = Math.floor(d.getHours() / 3);  // 3-Stunden-Abschnitte
      cells[wd][slot].sum += x.median / mean; cells[wd][slot].n++;
    }
    pattern = { scans: pat.length, cells: cells.map((row) => row.map((c) => (c.n ? { rel: c.sum / c.n - 1, n: c.n } : null))) };
  }

  // Preisstufen im letzten Scan, in dem der Gegenstand vorkam
  let levels = null;
  const lsnap = db.prepare(`SELECT s.id, s.t, s.rows FROM item_snap i JOIN snapshots s ON s.id = i.snapshot_id
      WHERE i.market_id = ? AND i.item_key = ? AND i.source = 'scan' AND i.qty > 0 AND s.rows IS NOT NULL ORDER BY i.t DESC LIMIT 1`).get(m.id, key);
  if (lsnap) {
    const rows = parseRows(zlib.inflateSync(Buffer.from(lsnap.rows)).toString('utf8')).filter((r) => itemKey(r) === key);
    const by = new Map();
    for (const r of rows) {
      const p = unitPrice(r);
      if (p == null) continue;
      const pr = Math.round(p);
      const x = by.get(pr) || { price: pr, qty: 0, auctions: 0 };
      x.qty += r.qty * r.n; x.auctions += r.n; by.set(pr, x);
    }
    let cum = 0;
    const list = [...by.values()].sort((a, b) => a.price - b.price).map((x) => { cum += x.qty; return { ...x, cum }; });
    levels = { t: lsnap.t, list };
  }

  const counts = { scan: own.filter((x) => x.source === 'scan').length, live: own.filter((x) => x.source === 'live').length,
    hour: hours.length, day: days.length, broker: broker.length };
  return {
    market: marketKey, key, item: nm ? nm.item_id : Number(String(key).split(':')[0]), name: nm && nm.name ? nm.name : null,
    quality: nm ? nm.quality : null, variant: nm ? nm.variant : null,
    current, median7: a7 ? a7.value : null, days7: a7 ? a7.days : 0,
    low14: d14.length ? Math.min(...d14) : null, high14: d14.length ? Math.max(...d14) : null, days14: d14.length,
    own, hours, days, broker, pattern, levels, counts,
  };
}

module.exports = { itemList, itemDetail, dailyMedians };
