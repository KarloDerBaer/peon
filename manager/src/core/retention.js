'use strict';
// Peon Manager - Aufbewahrung (Peon_Client_Design.md Abschnitt 7.2):
// Kennzahlen je Stand keepDays Tage, danach 3-Stunden-Werte (ab Manager 0.41.0, vorher Stundenwerte) bis hourDays, danach
// Tageswerte unbegrenzt. Die Angebote selbst nur API_BLOB_DAYS bzw. SCAN_BLOB_DAYS (ab 0.40.0). Die Kopfzeilen der
// Momentaufnahmen bleiben (Zeit, Angebote, Gegenstaende).
// Verdichtet wird in kleinen Zeitscheiben, damit das Programm dazwischen weiterarbeiten kann (pruneSteps).

const { tx, slotHour, mergeLiveHours } = require('./db');

// Der uebliche Bereich fuer Broker rechnet ueber 14 Tage, die Muster ueber 28 Tage, beide lesen keine Tageswerte
const MIN_HOUR_DAYS = 28;
const SLICE = 6 * 3600;                  // Groesse einer Zeitscheibe, ganze Stunden
const SHRINK_FROM = 16 * 1024 * 1024;    // Datei erst ab so viel freiem Platz verkleinern
const SHRINK_PAGES = 4096;               // Seiten je Schritt beim Verkleinern
// ab Manager 0.40.0 (Messung mit echten Daten 15.11.2026): Die Angebote eines Stands der Blizzard-API (rund 2 MB je Stand
// und Haus) braucht nur der Vergleich mit dem naechsten Stand und die Ansicht des neuesten. Eigene Scans sind klein.
// Live-Abfragen aus Broker zeigen den neuesten Preis, fuer Verlauf und Absatz zaehlen sie nicht mehr.
const API_BLOB_DAYS = 2;
const SCAN_BLOB_DAYS = 14;
const LIVE_DAYS = 7;

// ab 0.41.0 (KarloDerBaer 15.11.2026): 7 Tage je Stand, damit eine Woche Stunde fuer Stunde zu sehen ist
const PRESETS = [
  { key: 'sparsam', label: 'Sparsam', keepDays: 3, hourDays: 28 },
  { key: 'ausgewogen', label: 'Ausgewogen', keepDays: 7, hourDays: 28 },
  { key: 'ausfuehrlich', label: 'Ausführlich', keepDays: 14, hourDays: 90 },
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

// 3-Stunden-Werte einrechnen: gewichtet nach Zahl der Staende, dazu tiefster und hoechster Median (ab Schema 14)
function mergeSlots(db, rows) {
  const get = db.prepare('SELECT * FROM item_hour WHERE market_id = ? AND hour = ? AND item_key = ? AND source = ?');
  const put = db.prepare(`INSERT OR REPLACE INTO item_hour(market_id, hour, item_key, source, t, min, median, p25, p75, qty, auctions, n, med_lo, med_hi)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`);
  for (const r of rows) {
    const old = get.get(r.market_id, r.hour, r.item_key, r.source);
    let v = r;
    if (old) {
      v = { ...r, n: old.n + r.n, t: Math.round(wavg(old.t, old.n, r.t, r.n)) };
      for (const f of FIELDS) v[f] = wavg(old[f], old.n, r[f], r.n);
      v.med_lo = old.med_lo == null ? r.med_lo : r.med_lo == null ? old.med_lo : Math.min(old.med_lo, r.med_lo);
      v.med_hi = old.med_hi == null ? r.med_hi : r.med_hi == null ? old.med_hi : Math.max(old.med_hi, r.med_hi);
    }
    put.run(v.market_id, v.hour, v.item_key, v.source, v.t, v.min, v.median, v.p25, v.p75, v.qty, v.auctions, v.n, v.med_lo, v.med_hi);
  }
}

// Kennzahlen der Scans und API-Staende aelter als cut zu 3-Stunden-Werten (Ortszeit, wie die Muster). Ein Schritt je Markt
// und Abschnitt. Live-Abfragen bleiben bis zum Loeschen nach LIVE_DAYS (dropOld).
function* snapsToHours(db, cut, res) {
  const snaps = db.prepare("SELECT sid, market_id, t FROM snapshots WHERE source = 'scan' AND t < ? ORDER BY market_id, t").all(cut);
  const has = db.prepare('SELECT 1 FROM item_snap WHERE sid = ? LIMIT 1');
  const rowsOf = db.prepare('SELECT item_key, source, t, min, median, p25, p75, qty, auctions FROM item_snap WHERE sid = ?');
  const del = db.prepare('DELETE FROM item_snap WHERE sid = ?');
  const groups = new Map();
  for (const x of snaps) {
    if (!has.get(x.sid)) continue;
    const k = `${x.market_id}|${slotHour(x.t)}`;
    if (!groups.has(k)) groups.set(k, { market_id: x.market_id, hour: slotHour(x.t), sids: [] });
    groups.get(k).sids.push(x.sid);
  }
  for (const g of groups.values()) {
    tx(db, () => {
      const acc = new Map();
      for (const sid of g.sids) {
        for (const r of rowsOf.iterate(sid)) {
          const k = `${r.item_key}|${r.source}`;
          let a = acc.get(k);
          if (!a) { a = { market_id: g.market_id, hour: g.hour, item_key: r.item_key, source: r.source, ts: 0, n: 0, s: {}, c: {}, med_lo: null, med_hi: null }; acc.set(k, a); }
          a.ts += r.t; a.n++;
          for (const f of FIELDS) if (r[f] != null) { a.s[f] = (a.s[f] || 0) + r[f]; a.c[f] = (a.c[f] || 0) + 1; }
          if (r.median != null) {
            a.med_lo = a.med_lo == null ? r.median : Math.min(a.med_lo, r.median);
            a.med_hi = a.med_hi == null ? r.median : Math.max(a.med_hi, r.median);
          }
        }
        res.snaps += Number(del.run(sid).changes);
      }
      const rows = [...acc.values()].map((a) => {
        const v = { market_id: a.market_id, hour: a.hour, item_key: a.item_key, source: a.source, t: Math.round(a.ts / a.n), n: a.n, med_lo: a.med_lo, med_hi: a.med_hi };
        for (const f of FIELDS) v[f] = a.c[f] ? a.s[f] / a.c[f] : null;
        return v;
      });
      mergeSlots(db, rows);
    });
    yield;
  }
}

// ab 0.40.0: Angebote der Staende frueher loeschen (die Kennzahlen bleiben), Live-Abfragen nach LIVE_DAYS ganz
function* dropOld(db, now, res) {
  // in kleinen Gruppen, beim ersten Mal sind es einige hundert MB
  const pick = db.prepare(`SELECT id FROM snapshots WHERE rows IS NOT NULL AND source = 'scan'
      AND ((art = 'api' AND t < ?) OR (art <> 'api' AND t < ?)) LIMIT 20`);
  const clear = db.prepare('UPDATE snapshots SET rows = NULL WHERE id = ?');
  for (;;) {
    const ids = pick.all(now - API_BLOB_DAYS * 86400, now - SCAN_BLOB_DAYS * 86400);
    if (!ids.length) break;
    tx(db, () => { for (const x of ids) clear.run(x.id); });
    res.blobs += ids.length;
    yield;
  }
  const old = db.prepare("SELECT id FROM snapshots WHERE source = 'live' AND t < ? LIMIT 500");
  const delRows = db.prepare('DELETE FROM item_snap WHERE sid = (SELECT sid FROM snapshots WHERE id = ?)');
  const delSnap = db.prepare('DELETE FROM snapshots WHERE id = ?');
  for (;;) {
    const ids = old.all(now - LIVE_DAYS * 86400);
    if (!ids.length) break;
    tx(db, () => { for (const x of ids) { delRows.run(x.id); delSnap.run(x.id); } });
    res.live = (res.live || 0) + ids.length;
    yield;
  }
  // ab 0.57.0: Live-Abfragen je Gegenstand und Stunde zusammenfassen (laufende Stunde nicht), Nummern nach LIVE_DAYS weg
  const merged = tx(db, () => mergeLiveHours(db, now));
  if (merged) res.liveMerged = (res.liveMerged || 0) + merged;
  db.prepare('DELETE FROM live_ids WHERE t < ?').run(now - LIVE_DAYS * 86400);
  yield;
}

// Alles Aeltere als cut von den 3-Stunden-Werten zu Tageswerten. Tag = Stunde / 24 (UTC), fuer Tageswerte ueber Jahre genau
// genug. Je Markt in Scheiben ueber den Schluessel (Markt, Abschnitt).
function* hoursToDays(db, cut, res) {
  const select = db.prepare(`SELECT market_id, item_key, source, CAST(hour / 24 AS INTEGER) AS unit, CAST(SUM(t * n) / SUM(n) AS INTEGER) AS t,
      AVG(min) AS min, AVG(median) AS median, AVG(p25) AS p25, AVG(p75) AS p75, AVG(qty) AS qty, AVG(auctions) AS auctions, SUM(n) AS n
      FROM item_hour WHERE market_id = ? AND hour >= ? AND hour < ? GROUP BY item_key, source, unit`);
  const del = db.prepare('DELETE FROM item_hour WHERE market_id = ? AND hour >= ? AND hour < ?');
  const cutHour = Math.floor(cut / 3600 / 24) * 24;   // nur ganze Tage
  for (const m of db.prepare('SELECT id FROM markets').all()) {
    const f = db.prepare('SELECT MIN(hour) AS h FROM item_hour WHERE market_id = ?').get(m.id).h;
    if (f == null) continue;
    for (let a = Math.floor(f / 24) * 24; a < cutHour; a += 24) {
      tx(db, () => {
        mergeInto(db, 'item_day', 'day', select.all(m.id, a, a + 24));
        res.hours += Number(del.run(m.id, a, a + 24).changes);
      });
      yield;
    }
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
  yield* dropOld(db, now, res);
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
  const api = !!db.prepare("SELECT 1 FROM snapshots WHERE art = 'api' AND t >= ? LIMIT 1").get(now - 7 * 86400);
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
  const oldestHour = db.prepare('SELECT MIN(h) AS h FROM (SELECT (SELECT MIN(hour) FROM item_hour WHERE market_id = m.id) AS h FROM markets m)').get().h;
  return { current, now, perDay, items, ROW, blob, blobDays: api ? API_BLOB_DAYS : SCAN_BLOB_DAYS, perScan: blob + items * ROW, measured: scan.n > 0,
    oldestSnap: (db.prepare("SELECT t FROM snapshots s WHERE source = 'scan' AND EXISTS (SELECT 1 FROM item_snap i WHERE i.sid = s.sid) ORDER BY t LIMIT 1").get() || {}).t ?? null,
    oldestHour: oldestHour == null ? null : oldestHour * 3600 };
}

// Speicherbedarf nach einem Jahr fuer eine Einstellung
// ab 0.41.0: Angebote nur blobDays, danach je Tag 8 Abschnitte statt 24 Stunden
function project(m, keepDays, hourDays) {
  const fine = keepDays > 0 ? m.items * m.ROW * m.perDay * keepDays + m.blob * m.perDay * Math.min(keepDays, m.blobDays) : 0;   // 0 = waechst weiter
  const hourRows = m.items * Math.min(8, m.perDay) * m.ROW;
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

module.exports = { prune, pruneSteps, estimate, MIN_HOUR_DAYS, PRESETS, API_BLOB_DAYS, SCAN_BLOB_DAYS, LIVE_DAYS };
