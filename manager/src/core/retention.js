'use strict';
// Peon Manager - Aufbewahrung (Peon_Client_Design.md Abschnitt 7.2):
// Momentaufnahmen keepDays Tage vollstaendig (Angebote und Kennzahlen je Scan), danach Stundenwerte
// bis hourDays (Standard 365), danach Tageswerte unbegrenzt. Die Kopfzeilen der Momentaufnahmen bleiben
// (Zeit, Angebote, Gegenstaende), nur die gepackten Angebote werden geloescht.

const { tx } = require('./db');

// Mittel zweier Werte nach Gewicht, leere Werte zaehlen nicht
function wavg(a, na, b, nb) {
  if (a == null) return b;
  if (b == null) return a;
  return (a * na + b * nb) / (na + nb);
}

const FIELDS = ['min', 'median', 'p25', 'p75', 'qty', 'auctions'];

// Zeilen (je Gegenstand und Quelle) in eine Zieltabelle einrechnen
function mergeInto(db, table, unitCol, rows) {
  const get = db.prepare(`SELECT * FROM ${table} WHERE market_id = ? AND item_key = ? AND source = ? AND ${unitCol} = ?`);
  const put = db.prepare(`INSERT OR REPLACE INTO ${table}(market_id, item_key, source, ${unitCol}, t, min, median, p25, p75, qty, auctions, n)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`);
  for (const r of rows) {
    const old = get.get(r.market_id, r.item_key, r.source, r.unit);
    let v = r;
    if (old) {
      v = { ...r, n: old.n + r.n, t: Math.round(wavg(old.t, old.n, r.t, r.n)) };
      for (const f of FIELDS) v[f] = wavg(old[f], old.n, r[f], r.n);
    }
    put.run(v.market_id, v.item_key, v.source, v.unit, v.t, v.min, v.median, v.p25, v.p75, v.qty, v.auctions, v.n);
  }
}

function prune(db, { keepDays = 30, hourDays = 365, now = Math.floor(Date.now() / 1000) } = {}) {
  const res = { snaps: 0, hours: 0, blobs: 0 };
  if (keepDays > 0) {
    const cut = now - keepDays * 86400;
    tx(db, () => {
      const rows = db.prepare(`SELECT market_id, item_key, source, CAST(t / 3600 AS INTEGER) AS unit, CAST(AVG(t) AS INTEGER) AS t,
          AVG(min) AS min, AVG(median) AS median, AVG(p25) AS p25, AVG(p75) AS p75, AVG(qty) AS qty, AVG(auctions) AS auctions, COUNT(*) AS n
          FROM item_snap WHERE t < ? GROUP BY market_id, item_key, source, unit`).all(cut);
      mergeInto(db, 'item_hour', 'hour', rows);
      res.snaps = Number(db.prepare('DELETE FROM item_snap WHERE t < ?').run(cut).changes);
      res.blobs = Number(db.prepare('UPDATE snapshots SET rows = NULL WHERE t < ? AND rows IS NOT NULL').run(cut).changes);
    });
  }
  if (hourDays > 0) {
    const cut = now - hourDays * 86400;
    tx(db, () => {
      // Tag = Stunde / 24 (UTC); fuer Tageswerte ueber Jahre genau genug
      const rows = db.prepare(`SELECT market_id, item_key, source, CAST(hour / 24 AS INTEGER) AS unit, CAST(AVG(t) AS INTEGER) AS t,
          AVG(min) AS min, AVG(median) AS median, AVG(p25) AS p25, AVG(p75) AS p75, AVG(qty) AS qty, AVG(auctions) AS auctions, SUM(n) AS n
          FROM item_hour WHERE t < ? GROUP BY market_id, item_key, source, unit`).all(cut);
      mergeInto(db, 'item_day', 'day', rows);
      res.hours = Number(db.prepare('DELETE FROM item_hour WHERE t < ?').run(cut).changes);
    });
  }
  // Datei nur nach groesserem Aufraeumen verkleinern (dauert etwas)
  if (res.snaps > 200000 || res.blobs > 50) db.exec('VACUUM');
  return res;
}

// Schaetzung des Speicherbedarfs fuer eine Aufbewahrung von keepDays Tagen, gerechnet aus den eigenen Daten
function estimate(db, { keepDays = 30, hourDays = 365, now = Math.floor(Date.now() / 1000), current = 0 } = {}) {
  const scan = db.prepare(`SELECT COUNT(*) AS n, AVG(LENGTH(rows)) AS blob, AVG(items) AS items, MIN(t) AS t0, MAX(t) AS t1
      FROM snapshots WHERE source = 'scan' AND rows IS NOT NULL`).get();
  const week = db.prepare("SELECT COUNT(*) AS n, MIN(t) AS t0 FROM snapshots WHERE source = 'scan' AND t >= ?").get(now - 7 * 86400);
  const span = week.n > 1 ? Math.max(1, (now - week.t0) / 86400) : 1;
  const perDay = week.n > 0 ? Math.max(1, week.n / Math.min(7, span)) : 1;
  const blob = scan.blob || 100 * 1024;
  const items = scan.items || 3000;
  // Platz je Kennzahl-Zeile samt Suchverzeichnissen aus den eigenen Daten messen (sonst Annahme 240 Bytes)
  let ROW = 240;
  const rowsN = db.prepare('SELECT COUNT(*) AS n FROM item_snap').get().n;
  const blobs = db.prepare('SELECT COALESCE(SUM(LENGTH(rows)), 0) AS b FROM snapshots').get().b;
  const other = db.prepare('SELECT COUNT(*) AS n FROM hist').get().n + db.prepare('SELECT COUNT(*) AS n FROM item_hour').get().n
    + db.prepare('SELECT COUNT(*) AS n FROM item_day').get().n;
  if (rowsN > 5000 && current > 0) ROW = Math.min(600, Math.max(80, (current - blobs - 200 * 1024) / (rowsN + other)));
  const perScan = blob + items * ROW;
  const fine = perScan * perDay * keepDays;
  const hoursPerDay = Math.min(24, perDay);
  const hour = items * hoursPerDay * Math.max(0, hourDays - keepDays) * ROW;
  const dayPerYear = items * 365 * ROW;
  return { current, perScan: Math.round(perScan), scansPerDay: Math.round(perDay * 10) / 10, fine: Math.round(fine), hour: Math.round(hour),
    dayPerYear: Math.round(dayPerYear), total: Math.round(fine + hour + dayPerYear), keepDays, hourDays, measured: scan.n > 0, rowBytes: Math.round(ROW) };
}

module.exports = { prune, estimate };
