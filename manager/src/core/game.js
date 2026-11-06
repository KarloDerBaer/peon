'use strict';
// Peon Manager - Einleser "Spiel": Momentaufnahmen aus WTF\Account\<Konto>\SavedVariables\Peon_Bridge.lua
// (geschrieben vom Modul Peon_Bridge im Spiel, Format 1, Peon_Client_Design.md Abschnitt 6.3).
// Jede Momentaufnahme wird genau einmal uebernommen (ueber ihre id).

const fs = require('node:fs');
const path = require('node:path');
const zlib = require('node:zlib');
const { parseLua } = require('./lua');
const { parseRows, summarize, itemKey } = require('./stats');
const { tx, marketId } = require('./db');

const FILE = 'Peon_Bridge.lua';

// Alle Peon_Bridge.lua unter WTF\Account\*\SavedVariables
function findFiles(wowDir) {
  const base = path.join(wowDir, 'WTF', 'Account');
  let accounts = [];
  try { accounts = fs.readdirSync(base, { withFileTypes: true }).filter((d) => d.isDirectory()).map((d) => d.name); } catch { return []; }
  const out = [];
  for (const a of accounts) {
    const f = path.join(base, a, 'SavedVariables', FILE);
    if (fs.existsSync(f)) out.push({ account: a, file: f });
  }
  return out;
}

function readQueue(file) {
  const g = parseLua(fs.readFileSync(file));
  const db = g.PeonBridgeDB;
  if (!db || typeof db !== 'object') return { queue: [], fmt: null };
  const q = Array.isArray(db.queue) ? db.queue : Object.values(db.queue || {});
  return { queue: q, fmt: db.fmt ?? null, errors: db.errors, tipBox: db.tipBox };
}

// Eine Momentaufnahme in die Datenbank (ohne Transaktion, ruft importFile auf)
function importEntry(db, e, account) {
  const known = db.prepare('SELECT 1 FROM snapshots WHERE id = ?').get(String(e.id));
  if (known) return false;
  if (typeof e.market !== 'string' || typeof e.t !== 'number') throw new Error(`Momentaufnahme ${e.id}: Markt oder Zeit fehlt`);
  const mid = marketId(db, e.market, { realm: e.realm, faction: e.faction, region: e.region });
  const rows = parseRows(e.rows || '');
  const stats = summarize(rows);
  const source = e.kind === 'scan' ? 'scan' : 'live';
  const now = Math.floor(Date.now() / 1000);
  db.prepare(`INSERT INTO snapshots(id, market_id, source, art, t, char, build, broker, region, account,
      total, offers, lines, items, partial, item_key, commodity, rows, imported)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`)
    .run(String(e.id), mid, source, e.art || 'moment', e.t, e.char ?? null, e.build ?? null, e.broker ?? null, e.region ?? null, account ?? null,
      e.total ?? null, e.offers ?? rows.reduce((s, r) => s + r.n, 0), e.lines ?? rows.length, stats.size,
      e.partial ? 1 : 0, e.key ?? null, e.commodity == null ? null : (e.commodity ? 1 : 0),
      zlib.deflateSync(Buffer.from(e.rows || '', 'utf8')), now);

  const ins = db.prepare(`INSERT INTO item_snap(snapshot_id, market_id, item_key, t, source, min, median, p25, p75, qty, auctions)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`);
  for (const st of stats.values()) {
    // Teil-Ergebnis einer Live-Abfrage: Menge und Median sind zu niedrig -> nur Min behalten (wie Broker)
    const part = source === 'live' && e.partial;
    ins.run(String(e.id), mid, st.key, e.t, source, st.min, part ? null : st.median, part ? null : st.p25, part ? null : st.p75,
      part ? null : st.qty, part ? null : st.auctions);
  }
  // Live-Abfrage ohne Angebote: Gegenstand ist weg (Menge 0)
  if (source === 'live' && rows.length === 0 && !e.partial && e.key != null) {
    ins.run(String(e.id), mid, String(e.key), e.t, source, null, null, null, null, 0, 0);
  }

  // Namen, Qualitaet, ab Peon_Client 0.3.0 Haendlerpreis und Warenart: "Name|Qualitaet|Haendlerpreis|Massenware"
  const up = db.prepare(`INSERT INTO items(key, item_id, variant, name, quality, vendor, commodity, updated) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(key) DO UPDATE SET name = COALESCE(excluded.name, items.name),
        quality = COALESCE(excluded.quality, items.quality), vendor = COALESCE(excluded.vendor, items.vendor),
        commodity = COALESCE(excluded.commodity, items.commodity), updated = excluded.updated`);
  const names = e.names && typeof e.names === 'object' ? e.names : {};
  const seen = new Set();
  // Aus eigenen Daten lernen: Bonus-Nummer und voller Name, die Blizzard-API nennt nur die Nummer
  const learn = e.art === 'api' ? null : db.prepare('INSERT OR REPLACE INTO variant_names(item_id, bonus, name) VALUES (?, ?, ?)');
  for (const r of rows) {
    const key = itemKey(r);
    if (learn && r.bonus && r.name) learn.run(r.item, r.bonus, r.name);
    if (seen.has(key)) continue;
    seen.add(key);
    const info = parseName(names[r.item]);
    let name = r.name || info.name, quality = info.quality;
    // Haendlerpreis gilt fuer alle Varianten, Warenart nur fuer den Gegenstand ohne Zusatz
    up.run(key, r.item, r.name || null, name, quality, info.vendor, r.name ? 0 : info.commodity, now);
  }
  // Varianten bekommen den Haendlerpreis des Gegenstands
  for (const [id, v] of Object.entries(names)) {
    const info = parseName(v);
    if (info.vendor != null) db.prepare('UPDATE items SET vendor = ? WHERE item_id = ? AND vendor IS NULL').run(info.vendor, Number(id));
  }
  // Genaue Werte aus dem Spiel (Tooltip des Gegenstands, auch mit Zusatz), die Blizzard-API nennt sie nicht
  if (e.tips && typeof e.tips === 'object') {
    saveTips(db, e.tips, e.t);
  }
  // Live-Abfrage: Warenart vom Spiel
  if (source === 'live' && e.key != null && e.commodity != null) {
    db.prepare('UPDATE items SET commodity = ? WHERE key = ?').run(e.commodity ? 1 : 0, String(e.key));
  }
  return true;
}

// Werte speichern. Leerer Text: Das Spiel kennt den Gegenstand gerade nicht, dann eine Marke statt vorhandene Werte zu ersetzen
function saveTips(db, tips, t) {
  const put = db.prepare('INSERT OR REPLACE INTO item_tip(key, lines, t) VALUES (?, ?, ?)');
  const has = db.prepare("SELECT 1 FROM item_tip WHERE key = ? AND lines <> '[]'");
  for (const [k, v] of Object.entries(tips)) {
    const lines = parseTip(v);
    if (lines.length) put.run(String(k), JSON.stringify(lines), t);
    else if (!has.get(String(k))) put.run(String(k), '[]', t);
  }
}

const TIP_KIND = { g: 'good', y: 'level', m: 'muted' };

// Zeilen aus der Bridge: je Zeile "links\trechts\tArt" (g gruen, y gelb, m grau). Ergebnis wie toTip in item-info.js
function parseTip(v) {
  if (typeof v !== 'string') return [];
  const out = [];
  for (const line of v.split('\n')) {
    const [l, r, c] = line.split('\t');
    if (!l && !r) continue;
    const x = { l: l || '' };
    if (r) x.r = r;
    if (TIP_KIND[c]) x.c = TIP_KIND[c];
    out.push(x);
  }
  return out;
}

// "Name|Qualitaet" (bis 0.2) oder "Name|Qualitaet|Haendlerpreis|Massenware" (ab Peon_Client 0.3.0)
function parseName(v) {
  const out = { name: null, quality: null, vendor: null, commodity: null };
  if (typeof v !== 'string') return out;
  const f = v.split('|');
  const num = (x) => (x === undefined || x === '' || !Number.isFinite(Number(x)) ? null : Number(x));
  out.name = f[0] || null;
  out.quality = num(f[1]);
  out.vendor = num(f[2]);
  const c = num(f[3]);
  out.commodity = c == null ? null : (c ? 1 : 0);
  return out;
}

// Ganze Datei einlesen. Rueckgabe: { file, account, ids (alle in der Datei), imported, known, failed: [{id, error}] }
function importFile(db, file, account, now = Math.floor(Date.now() / 1000)) {
  const { queue, errors, tipBox } = readQueue(file);
  const res = { file, account, ids: [], imported: 0, known: 0, failed: [], gameErrors: errors };
  for (const e of queue) {
    if (!e || e.id == null) continue;
    try {
      const done = tx(db, () => importEntry(db, e, account));
      if (done) res.imported++; else res.known++;
      res.ids.push(String(e.id));
    } catch (err) {
      res.failed.push({ id: String(e.id), error: err.message });
    }
  }
  // Bestellte Werte, die das Spiel im Hintergrund gelesen hat
  if (tipBox && typeof tipBox === 'object') tx(db, () => saveTips(db, tipBox, now));
  return res;
}

// Angebote einer Momentaufnahme wieder lesen
function snapshotRows(db, id) {
  const r = db.prepare('SELECT rows FROM snapshots WHERE id = ?').get(String(id));
  if (!r || !r.rows) return [];
  return parseRows(zlib.inflateSync(Buffer.from(r.rows)).toString('utf8'));
}

module.exports = { findFiles, readQueue, importEntry, importFile, snapshotRows, parseName, parseTip, saveTips, FILE };
