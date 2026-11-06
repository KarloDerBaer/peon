'use strict';
// Peon Manager - Datenbanken (SQLite ueber node:sqlite) im Datenordner:
//   peon.db           Manager: Zustand (meta), Protokoll (log), Fehler (errors) und Rueckmeldungen (feedback)
//   broker-client.db  Modul Peon Broker Client: Maerkte, Momentaufnahmen, Verlauf, Absatz, Chancen
// Angebote einer Momentaufnahme liegen gepackt (zlib) in snapshots.rows, die Kennzahlen je Gegenstand
// in item_snap. So bleibt die Datei klein und alles laesst sich spaeter neu berechnen.

const path = require('node:path');
const fs = require('node:fs');
const { DatabaseSync } = require('node:sqlite');
const { sameMarket } = require('./markets');

const SCHEMA = 7;   // 7: Favoriten, Werte aus dem Spiel, Zwischenspeicher der Liste, andere Namen eines Markts, Merkliste entfernt; 2: hist (Broker-Verlauf), item_hour, item_day (Verdichtung); 3: Absatz, Chancen, Haendlerpreis, Warenart; 4: Blizzard-API, AHledger entfernt; 5: item_info (Tooltip)

const DDL = `
CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT);
CREATE TABLE IF NOT EXISTS markets (
  id INTEGER PRIMARY KEY, key TEXT UNIQUE NOT NULL, realm TEXT, faction TEXT, region INTEGER, created INTEGER);
CREATE TABLE IF NOT EXISTS items (
  key TEXT PRIMARY KEY, item_id INTEGER NOT NULL, variant TEXT, name TEXT, quality INTEGER, updated INTEGER);
CREATE INDEX IF NOT EXISTS items_id ON items(item_id);
CREATE TABLE IF NOT EXISTS snapshots (
  id TEXT PRIMARY KEY, market_id INTEGER NOT NULL, source TEXT NOT NULL, art TEXT NOT NULL,
  t INTEGER NOT NULL, char TEXT, build TEXT, broker TEXT, region INTEGER, account TEXT,
  total INTEGER, offers INTEGER, lines INTEGER, items INTEGER, partial INTEGER, item_key TEXT, commodity INTEGER,
  rows BLOB, imported INTEGER);
CREATE INDEX IF NOT EXISTS snapshots_mt ON snapshots(market_id, source, t);
CREATE TABLE IF NOT EXISTS item_snap (
  snapshot_id TEXT NOT NULL, market_id INTEGER NOT NULL, item_key TEXT NOT NULL, t INTEGER NOT NULL, source TEXT NOT NULL,
  min REAL, median REAL, p25 REAL, p75 REAL, qty INTEGER, auctions INTEGER,
  PRIMARY KEY (snapshot_id, item_key));
CREATE INDEX IF NOT EXISTS item_snap_mkt ON item_snap(market_id, item_key, t);
CREATE TABLE IF NOT EXISTS hist (
  market_id INTEGER NOT NULL, item_key TEXT NOT NULL, source TEXT NOT NULL, period TEXT NOT NULL, num INTEGER NOT NULL,
  t INTEGER NOT NULL, min REAL, median REAL, qty REAL, n INTEGER,
  PRIMARY KEY (market_id, item_key, source, period, num));
CREATE INDEX IF NOT EXISTS hist_t ON hist(market_id, source, t);
CREATE TABLE IF NOT EXISTS item_hour (
  market_id INTEGER NOT NULL, item_key TEXT NOT NULL, source TEXT NOT NULL, hour INTEGER NOT NULL, t INTEGER NOT NULL,
  min REAL, median REAL, p25 REAL, p75 REAL, qty REAL, auctions REAL, n INTEGER NOT NULL,
  PRIMARY KEY (market_id, item_key, source, hour));
CREATE TABLE IF NOT EXISTS item_day (
  market_id INTEGER NOT NULL, item_key TEXT NOT NULL, source TEXT NOT NULL, day INTEGER NOT NULL, t INTEGER NOT NULL,
  min REAL, median REAL, p25 REAL, p75 REAL, qty REAL, auctions REAL, n INTEGER NOT NULL,
  PRIMARY KEY (market_id, item_key, source, day));
CREATE INDEX IF NOT EXISTS item_snap_t ON item_snap(t);
CREATE INDEX IF NOT EXISTS item_hour_t ON item_hour(t);
CREATE TABLE IF NOT EXISTS sales_pair (
  id INTEGER PRIMARY KEY AUTOINCREMENT, market_id INTEGER NOT NULL, a_id TEXT NOT NULL, b_id TEXT NOT NULL,
  ta INTEGER NOT NULL, tb INTEGER NOT NULL, src TEXT NOT NULL, item_key TEXT, folded INTEGER NOT NULL DEFAULT 0);
CREATE INDEX IF NOT EXISTS sales_pair_m ON sales_pair(market_id, src, tb);
CREATE TABLE IF NOT EXISTS sales_cmp (
  pair_id INTEGER NOT NULL, market_id INTEGER NOT NULL, item_key TEXT NOT NULL, day INTEGER NOT NULL, tb INTEGER NOT NULL,
  secs INTEGER NOT NULL, sold REAL, expired REAL, cancelled REAL, listed REAL, value REAL, max_sold REAL,
  PRIMARY KEY (pair_id, item_key));
CREATE INDEX IF NOT EXISTS sales_cmp_m ON sales_cmp(market_id, day, item_key);
CREATE TABLE IF NOT EXISTS sales_day (
  market_id INTEGER NOT NULL, item_key TEXT NOT NULL, day INTEGER NOT NULL, secs INTEGER NOT NULL, cmp INTEGER NOT NULL,
  sold REAL, expired REAL, cancelled REAL, listed REAL, value REAL, max_sold REAL,
  PRIMARY KEY (market_id, day, item_key));
CREATE TABLE IF NOT EXISTS opp_snap (
  snapshot_id TEXT NOT NULL, market_id INTEGER NOT NULL, item_key TEXT NOT NULL, t INTEGER NOT NULL, kind TEXT NOT NULL,
  qty REAL NOT NULL, profit REAL NOT NULL, cost REAL NOT NULL, ref REAL,
  PRIMARY KEY (snapshot_id, item_key, kind));
CREATE INDEX IF NOT EXISTS opp_snap_m ON opp_snap(market_id, kind, t);
CREATE TABLE IF NOT EXISTS opp_scan (
  snapshot_id TEXT PRIMARY KEY, market_id INTEGER NOT NULL, t INTEGER NOT NULL, vendor_n INTEGER);
CREATE TABLE IF NOT EXISTS variant_names (
  item_id INTEGER NOT NULL, bonus TEXT NOT NULL, name TEXT NOT NULL, PRIMARY KEY (item_id, bonus));
CREATE TABLE IF NOT EXISTS item_info (
  item_id INTEGER PRIMARY KEY, source TEXT NOT NULL, tip TEXT, t INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS favorites (
  item_key TEXT PRIMARY KEY, added INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS item_tip (
  key TEXT PRIMARY KEY, lines TEXT NOT NULL, t INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS list_cache (
  market_id INTEGER PRIMARY KEY, sig TEXT NOT NULL, data BLOB NOT NULL);
CREATE TABLE IF NOT EXISTS market_alias (
  alias TEXT PRIMARY KEY, market_id INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS log (
  id INTEGER PRIMARY KEY AUTOINCREMENT, t INTEGER NOT NULL, kind TEXT NOT NULL, ok INTEGER NOT NULL, text TEXT);
`;

const MANAGER_DDL = `
CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT);
CREATE TABLE IF NOT EXISTS log (
  id INTEGER PRIMARY KEY AUTOINCREMENT, t INTEGER NOT NULL, kind TEXT NOT NULL, ok INTEGER NOT NULL, text TEXT);
CREATE TABLE IF NOT EXISTS errors (
  key TEXT PRIMARY KEY, source TEXT NOT NULL, addon TEXT NOT NULL, version TEXT, build TEXT, place TEXT, msg TEXT NOT NULL, stack TEXT,
  first INTEGER NOT NULL, last INTEGER NOT NULL, n INTEGER NOT NULL,
  note TEXT NOT NULL DEFAULT '', base_first INTEGER, base_n INTEGER);
CREATE TABLE IF NOT EXISTS feedback (
  key TEXT PRIMARY KEY, origin TEXT NOT NULL, module TEXT NOT NULL, kind TEXT NOT NULL, area TEXT, prio TEXT NOT NULL, text TEXT NOT NULL,
  ver TEXT, zone TEXT, market TEXT, t INTEGER NOT NULL, edited INTEGER NOT NULL);
`;

const BROKER_FILE = 'broker-client.db';
const MANAGER_FILE = 'peon.db';

function open(dir, name, ddl) {
  fs.mkdirSync(dir, { recursive: true });
  const file = path.join(dir, name);
  const db = new DatabaseSync(file);
  db.exec('PRAGMA journal_mode = WAL; PRAGMA synchronous = NORMAL; PRAGMA foreign_keys = OFF;');
  db.exec(ddl);
  db.file = file;
  db.logDir = path.join(dir, 'logs');
  return db;
}

// Datenbank des Moduls Peon Broker Client
function openDb(dir) {
  const db = open(dir, BROKER_FILE, DDL);
  // Schema 3: Haendlerpreis und Warenart je Gegenstand
  const cols = new Set(db.prepare('PRAGMA table_info(items)').all().map((c) => c.name));
  if (!cols.has('vendor')) db.exec('ALTER TABLE items ADD COLUMN vendor INTEGER');
  if (!cols.has('commodity')) db.exec('ALTER TABLE items ADD COLUMN commodity INTEGER');
  // Schema 4: AHledger ist entfernt (05.11.2026)
  db.exec('DROP TABLE IF EXISTS ext_ahledger; DROP TABLE IF EXISTS ext_fetch;');
  // Schema 7: Die Merkliste ist entfernt, die Einkaufsliste ersetzt sie (06.11.2026)
  db.exec('DROP TABLE IF EXISTS watchlist;');
  // Datei laesst sich schrittweise verkleinern, ohne das Programm anzuhalten. Einmalig umstellen, klappt es nicht, geht es ohne weiter
  if (db.prepare('PRAGMA auto_vacuum').get().auto_vacuum !== 2) {
    try { db.exec('PRAGMA auto_vacuum = INCREMENTAL; VACUUM;'); } catch { /* retention.js verkleinert dann im Ganzen */ }
  }
  db.prepare("INSERT INTO meta(key, value) VALUES ('schema', ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value").run(String(SCHEMA));
  return db;
}

// Datenbank des Managers (Zustand, Protokoll)
function openManagerDb(dir) {
  return open(dir, MANAGER_FILE, MANAGER_DDL);
}

// Bis Manager 0.6.0 lag alles in peon.db. Liegen dort Daten des Broker Clients, wird die Datei einmalig
// zu broker-client.db (mit -wal und -shm). Rueckgabe: true, wenn umgezogen.
function migrateSplit(dir) {
  const old = path.join(dir, MANAGER_FILE), neu = path.join(dir, BROKER_FILE);
  if (!fs.existsSync(old) || fs.existsSync(neu)) return false;
  const db = new DatabaseSync(old);
  let broker = false;
  try { broker = !!db.prepare("SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'snapshots'").get(); } finally { db.close(); }
  if (!broker) return false;
  for (const ext of ['', '-wal', '-shm']) {
    if (fs.existsSync(old + ext)) fs.renameSync(old + ext, neu + ext);
  }
  return true;
}

// Groesse einer Datenbankdatei samt -wal, auch wenn sie nicht offen ist
function fileSize(file) {
  let size = 0;
  for (const f of [file, file + '-wal']) {
    try { size += fs.statSync(f).size; } catch { /* fehlt */ }
  }
  return size;
}

// Datenbankdatei samt -wal und -shm loeschen (nur geschlossen)
function removeDb(file) {
  let n = 0;
  for (const ext of ['', '-wal', '-shm']) {
    try { fs.unlinkSync(file + ext); n++; } catch { /* fehlt */ }
  }
  return n;
}

function tx(db, fn) {
  db.exec('BEGIN');
  try {
    const r = fn();
    db.exec('COMMIT');
    return r;
  } catch (e) {
    db.exec('ROLLBACK');
    throw e;
  }
}

// Protokoll: in der Datenbank (Uebersicht) und als Datei je Tag in <Daten>\logs (Design Abschnitt 10)
function log(db, kind, ok, text) {
  const now = new Date();
  db.prepare('INSERT INTO log(t, kind, ok, text) VALUES (?, ?, ?, ?)').run(Math.floor(now.getTime() / 1000), kind, ok ? 1 : 0, String(text));
  if (db.logDir) {
    try {
      const p2 = (n) => String(n).padStart(2, '0');
      const day = `${now.getFullYear()}-${p2(now.getMonth() + 1)}-${p2(now.getDate())}`;
      const line = `${p2(now.getHours())}:${p2(now.getMinutes())}:${p2(now.getSeconds())} ${ok ? 'ok    ' : 'FEHLER'} ${kind}: ${String(text).replace(/\r?\n/g, ' ')}\r\n`;
      fs.mkdirSync(db.logDir, { recursive: true });
      fs.appendFileSync(path.join(db.logDir, `${day}.log`), line, 'utf8');
    } catch { /* Protokoll darf nie stoeren */ }
  }
  db.prepare('DELETE FROM log WHERE id < (SELECT MAX(id) - 500 FROM log)').run();
}

function marketId(db, key, info = {}) {
  const r = db.prepare('SELECT id FROM markets WHERE key = ?').get(key);
  if (r) {
    if (info.region != null) db.prepare('UPDATE markets SET region = ? WHERE id = ?').run(info.region, r.id);
    return r.id;
  }
  // Anderer interner Name fuer denselben Markt: kein zweiter Markt, Data.lua nennt den Namen als Verweis
  const al = db.prepare('SELECT market_id FROM market_alias WHERE alias = ?').get(key);
  if (al) return al.market_id;
  const twin = db.prepare('SELECT id, key, region FROM markets').all().find((m) => sameMarket(m.key, m.region, key, info.region));
  if (twin) {
    db.prepare('INSERT INTO market_alias(alias, market_id) VALUES (?, ?)').run(key, twin.id);
    return twin.id;
  }
  const res = db.prepare('INSERT INTO markets(key, realm, faction, region, created) VALUES (?, ?, ?, ?, ?)')
    .run(key, info.realm ?? null, info.faction ?? null, info.region ?? null, Math.floor(Date.now() / 1000));
  return Number(res.lastInsertRowid);
}

// Groesse der Datenbank inkl. WAL-Datei
function dbSize(db) {
  return fileSize(db.file);
}

// Logdateien aelter als `days` Tage loeschen
function pruneLogs(db, days = 30, now = Date.now()) {
  if (!db.logDir) return 0;
  let n = 0;
  let files = [];
  try { files = fs.readdirSync(db.logDir); } catch { return 0; }
  for (const f of files) {
    const m = /^(\d{4})-(\d{2})-(\d{2})\.log$/.exec(f);
    if (!m) continue;
    const t = new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3])).getTime();
    if (now - t > days * 86400000) { try { fs.unlinkSync(path.join(db.logDir, f)); n++; } catch { /* egal */ } }
  }
  return n;
}

module.exports = { openDb, openManagerDb, migrateSplit, fileSize, removeDb, BROKER_FILE, MANAGER_FILE, tx, log, marketId, dbSize, pruneLogs, SCHEMA };
