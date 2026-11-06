'use strict';
// Peon Manager - Aufbewahrung (Peon_Client_Design.md Abschnitt 7.2):
// Momentaufnahmen keepDays Tage vollstaendig (Angebote und Kennzahlen je Scan), danach Stundenwerte
// bis hourDays, danach Tageswerte unbegrenzt. Die Kopfzeilen der Momentaufnahmen bleiben
// (Zeit, Angebote, Gegenstaende), nur die gepackten Angebote werden geloescht.
// Verdichtet wird in kleinen Zeitscheiben, damit das Programm dazwischen weiterarbeiten kann (pruneSteps).

const { tx } = require('./db');

// Der uebliche Bereich fuer Broker rechnet ueber 14 Tage und liest keine Tageswerte (longterm.js)
const MIN_HOUR_DAYS = 14;
const SLICE = 6 * 3600;                  // Groesse einer Zeitscheibe, ganze Stunden
const SHRINK_FROM = 16 * 1024 * 1024;    // Datei erst ab so viel freiem Platz verkleinern
const SHRINK_PAGES = 4096;               // Seiten je Schritt beim Verkleinern

const PRESETS = [
  { key: 'sparsam', label: 'Sparsam', keepDays: 7, hourDays: 30 },
  { key: 'ausgewogen', label: 'Ausgewogen', keepDays: 14, hourDays: 60 },
  { key: 'ausfuehrlich', label: 'Ausführlich', keepDays: 30, hourDays: 180 },
  { key: 'alles', label: 'Alles', keepDays: 30, hourDays: 365 },
];

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

// Zeitscheiben von first bis cut, an ganzen Stunden ausgerichtet
function* slices(first, cut) {
  let a = Math.floor(first / SLICE) * SLICE;
  while (a < cut) {
    const b = Math.min(a + SLICE, cut);
    yield [a, b];
    a = b;
  }
}

// Alles Aeltere als cut von den vollstaendigen Momentaufnahmen zu Stundenwerten
function* snapsToHours(db, cut, res) {
  const f = db.prepare('SELECT MIN(t) AS t FROM item_snap').get().t;
  const g = db.prepare('SELECT MIN(t) AS t FROM snapshots WHERE rows IS NOT NULL').get().t;
  if (f == null && g == null) return;
  const select = db.prepare(`SELECT market_id, item_key, source, CAST(t / 3600 AS INTEGER) AS unit, CAST(AVG(t) AS INTEGER) AS t,
      AVG(min) AS min, AVG(median) AS median, AVG(p25) AS p25, AVG(p75) AS p75, AVG(qty) AS qty, AVG(auctions) AS auctions, COUNT(*) AS n
      FROM item_snap WHERE t >= ? AND t < ? GROUP BY market_id, item_key, source, unit`);
  const del = db.prepare('DELETE FROM item_snap WHERE t >= ? AND t < ?');
  const blobs = db.prepare('UPDATE snapshots SET rows = NULL WHERE t >= ? AND t < ? AND rows IS NOT NULL');
  for (const [a, b] of slices(Math.min(f ?? g, g ?? f), cut)) {
    tx(db, () => {
      mergeInto(db, 'item_hour', 'hour', select.all(a, b));
      res.snaps += Number(del.run(a, b).changes);
      res.blobs += Number(blobs.run(a, b).changes);
    });
    yield;
  }
}

// Alles Aeltere als cut von den Stundenwerten zu Tageswerten. Tag = Stunde / 24 (UTC), fuer Tageswerte ueber Jahre genau genug
function* hoursToDays(db, cut, res) {
  const f = db.prepare('SELECT MIN(t) AS t FROM item_hour').get().t;
  if (f == null) return;
  const select = db.prepare(`SELECT market_id, item_key, source, CAST(hour / 24 AS INTEGER) AS unit, CAST(AVG(t) AS INTEGER) AS t,
      AVG(min) AS min, AVG(median) AS median, AVG(p25) AS p25, AVG(p75) AS p75, AVG(qty) AS qty, AVG(auctions) AS auctions, SUM(n) AS n
      FROM item_hour WHERE t >= ? AND t < ? GROUP BY market_id, item_key, source, unit`);
  const del = db.prepare('DELETE FROM item_hour WHERE t >= ? AND t < ?');
  for (const [a, b] of slices(f, cut)) {
    tx(db, () => {
      mergeInto(db, 'item_day', 'day', select.all(a, b));
      res.hours += Number(del.run(a, b).changes);
    });
    yield;
  }
}

// Freien Platz an Windows zurueckgeben, auch wenn nur Stundenwerte weggefallen sind
function* shrink(db) {
  const free = () => db.prepare('PRAGMA freelist_count').get().freelist_count;
  const page = db.prepare('PRAGMA page_size').get().page_size;
  if (free() * page < SHRINK_FROM) return;
  if (db.prepare('PRAGMA auto_vacuum').get().auto_vacuum !== 2) {
    // Umstellung beim Oeffnen hat nicht geklappt: Dann eben im Ganzen
    db.exec('VACUUM');
    return;
  }
  while (free() > 0) {
    db.exec(`PRAGMA incremental_vacuum(${SHRINK_PAGES})`);
    yield;
  }
  db.prepare('PRAGMA wal_checkpoint(TRUNCATE)').get();
}

// Schritte der Aufbewahrung, zwischen zwei Schritten darf anderes laufen. Das Ergebnis steht am Ende in res.
function* pruneSteps(db, { keepDays = 14, hourDays = 60, now = Math.floor(Date.now() / 1000) } = {}, res = { snaps: 0, hours: 0, blobs: 0 }) {
  if (keepDays > 0) yield* snapsToHours(db, now - keepDays * 86400, res);
  if (hourDays > 0) yield* hoursToDays(db, now - hourDays * 86400, res);
  yield* shrink(db);
  return res;
}

function prune(db, opts = {}) {
  const res = { snaps: 0, hours: 0, blobs: 0 };
  for (const _ of pruneSteps(db, opts, res)) { /* alle Schritte am Stueck */ }
  return res;
}

// Grundwerte der Schaetzung, gerechnet aus den eigenen Daten (einmal messen, dann beliebig viele Einstellungen rechnen)
function measure(db, { now = Math.floor(Date.now() / 1000), current = 0 } = {}) {
  const scan = db.prepare(`SELECT COUNT(*) AS n, AVG(LENGTH(rows)) AS blob, AVG(items) AS items
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
  return { current, now, perDay, items, ROW, perScan: blob + items * ROW, measured: scan.n > 0,
    oldestSnap: db.prepare('SELECT MIN(t) AS t FROM item_snap').get().t,
    oldestHour: db.prepare('SELECT MIN(t) AS t FROM item_hour').get().t };
}

// Speicherbedarf nach einem Jahr fuer eine Einstellung
function project(m, keepDays, hourDays) {
  const fine = m.perScan * m.perDay * keepDays;
  const hourRows = m.items * Math.min(24, m.perDay) * m.ROW;
  const hour = hourRows * Math.max(0, Math.min(365, hourDays) - keepDays);
  const dayPerYear = m.items * 365 * m.ROW;
  const dayFirstYear = (m.items * m.ROW) * Math.max(0, 365 - Math.max(keepDays, hourDays));
  return { fine: Math.round(fine), hour: Math.round(hour), dayPerYear: Math.round(dayPerYear), dayFirstYear: Math.round(dayFirstYear),
    total: Math.round(fine + hour + dayFirstYear) };
}

// Schaetzung fuer eine Einstellung, dazu die Vorlagen und ob beim Uebernehmen wirklich schon Daten verdichtet wuerden
function estimate(db, { keepDays = 14, hourDays = 60, now = Math.floor(Date.now() / 1000), current = 0 } = {}) {
  const m = measure(db, { now, current });
  const compact = (m.oldestSnap != null && keepDays > 0 && m.oldestSnap < now - keepDays * 86400)
    || (m.oldestHour != null && hourDays > 0 && m.oldestHour < now - hourDays * 86400);
  return { current, ...project(m, keepDays, hourDays), perScan: Math.round(m.perScan), scansPerDay: Math.round(m.perDay * 10) / 10,
    keepDays, hourDays, measured: m.measured, rowBytes: Math.round(m.ROW), wouldCompact: !!compact,
    presets: PRESETS.map((p) => ({ ...p, total: project(m, p.keepDays, p.hourDays).total })) };
}

module.exports = { prune, pruneSteps, estimate, MIN_HOUR_DAYS, PRESETS };
