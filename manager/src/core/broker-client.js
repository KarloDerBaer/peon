'use strict';
// Peon Manager - Modul "Peon Broker Client" (bis Manager 0.6.0 der ganze Dienst).
// Einlesen aus dem Spiel, Blizzard-API, Rueckgabe an Broker, Daten fuer die Ansichten. Eigene Datenbank broker-client.db.
// Einstellungen, Version, Zeit und die Kanaele fuer Data.lua kommen vom Manager (service.js, host).

const fs = require('node:fs');
const path = require('node:path');
const { openDb, log, dbSize, pruneLogs } = require('./db');
const game = require('./game');
const { writeData, dataMatches, addonDir } = require('./datalua');
const broker = require('./broker');
const history = require('./history');
const retention = require('./retention');
const longterm = require('./longterm');
const sales = require('./sales');
const chances = require('./chances');
const { BlizzardImport } = require('./blizzard-import');
const { ItemInfo } = require('./item-info');
const crypto = require('node:crypto');

class BrokerClient {
  constructor(host) {
    this.host = host;
    this.dbDir = host.dbDir;
    this.db = openDb(host.dbDir);
    this.lastImport = null;
    this.lastFiles = [];
    this.info = new ItemInfo(this.db, () => this.now());
    this.api = new BlizzardImport(this);
  }

  get settings() { return this.host.settings; }
  get version() { return this.host.version; }
  get fetchImpl() { return this.host.fetchImpl; }
  now() { return this.host.now(); }
  saveSettings(patch) { return this.host.saveSettings(patch); }

  meta(key, value) {
    if (value === undefined) {
      const r = this.db.prepare('SELECT value FROM meta WHERE key = ?').get(key);
      return r ? JSON.parse(r.value) : null;
    }
    this.db.prepare('INSERT INTO meta(key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value').run(key, JSON.stringify(value));
    return value;
  }

  // Alle Peon_Bridge.lua einlesen und die Bestaetigung (Data.lua) schreiben
  importGame() {
    const wow = this.settings.wowDir;
    const files = game.findFiles(wow);
    const sum = { t: this.now(), files: [], imported: 0, known: 0, failed: [], ack: null, error: null };
    const ids = [];
    for (const f of files) {
      try {
        const r = game.importFile(this.db, f.file, f.account);
        const st = fs.statSync(f.file);
        sum.files.push({ account: f.account, file: f.file, entries: r.ids.length + r.failed.length, mtime: Math.floor(st.mtimeMs / 1000) });
        sum.imported += r.imported; sum.known += r.known; sum.failed.push(...r.failed);
        ids.push(...r.ids);
        if (Array.isArray(r.gameErrors) && r.gameErrors.length) sum.gameErrors = r.gameErrors;
      } catch (e) {
        sum.failed.push({ file: f.file, error: e.message });
      }
    }
    if (files.length === 0) sum.error = 'Keine Peon_Bridge.lua gefunden';
    sum.broker = this.importBroker();
    const markets = this.buildMarkets();
    // Bestaetigen nur, was sicher in der Datenbank ist
    const known = ids.filter((id) => this.db.prepare('SELECT 1 FROM snapshots WHERE id = ?').get(id));
    const prev = this.meta('ack') || { ids: [] };
    const same = prev.ids.length === known.length && prev.ids.every((x, k) => x === known[k]);
    const hash = crypto.createHash('md5').update(JSON.stringify(markets.values)).digest('hex');
    const marks = this.host.reports.marks();
    if (!same || !prev.t || prev.hash !== hash || !dataMatches(wow, this.host.channels(), marks)) {
      try {
        const w = writeData(wow, { ack: known, markets: markets.lua, channels: this.host.channels(), version: this.version, now: this.now(), ...marks });
        sum.ack = { t: this.now(), count: known.length, file: w.file, items: markets.count, bytes: w.bytes };
        this.meta('ack', { ids: known, t: this.now(), file: w.file, hash, items: markets.count, sales: markets.salesCount, bytes: w.bytes, day: markets.day });
      } catch (e) {
        sum.failed.push({ file: path.join(addonDir(wow), 'Data.lua'), error: e.message });
      }
    }
    if (sum.imported > 0 || sum.failed.length > 0 || sum.error) {
      const text = sum.error || `${sum.imported} ${sum.imported === 1 ? 'neue Momentaufnahme' : 'neue Momentaufnahmen'}, ${sum.known} schon bekannt` + (sum.failed.length ? `, ${sum.failed.length} Fehler: ${sum.failed.map((x) => x.error).join('; ')}` : '');
      log(this.db, 'spiel', sum.failed.length === 0 && !sum.error, text);
    }
    this.lastImport = sum;
    this.lastFiles = sum.files;
    return sum;
  }

  // Werte fuer Broker je Markt: Langzeit-Teil (Kapitel 8) und Absatz (Kapitel 9). Dabei Absatz-Vergleiche und
  // Chancen der neuen Scans rechnen. values ohne Zeitstempel (fuer den Vergleich)
  buildMarkets() {
    const lua = {}, values = {};
    let count = 0, salesCount = 0;
    const now = this.now();
    const day = broker.dayOf(now);
    for (const m of this.db.prepare('SELECT id, key FROM markets').all()) {
      try { sales.updateMarket(this.db, m.id, now); } catch (e) { log(this.db, 'absatz', false, `${m.key}: ${e.message}`); }
      const lt = longterm.marketLongTerm(this.db, m.id, now);
      try { chances.updateMarket(this.db, m.id, lt.items, now); } catch (e) { log(this.db, 'chancen', false, `${m.key}: ${e.message}`); }
      const st = sales.marketStats(this.db, m.id, now);
      if (!lt.items.size && !st.size) continue;
      const items = {}, sl = {};
      for (const [k, r] of lt.items) items[k] = longterm.encode(r);
      for (const [k, s] of st) sl[k] = sales.encode(s);
      lua[m.key] = { t: now, day: lt.day, items, sales: sl };
      values[m.key] = { day: lt.day, items, sales: sl };
      count += lt.items.size;
      salesCount += st.size;
    }
    return { lua, values, count, salesCount, day };
  }

  marketId(marketKey) {
    const m = this.db.prepare('SELECT id FROM markets WHERE key = ?').get(marketKey);
    return m ? m.id : null;
  }

  // Ansicht Chancen (Rechenmodell 9.3)
  chances(marketKey, days) {
    const mid = this.marketId(marketKey);
    if (mid == null) return null;
    const now = this.now();
    const d = Math.max(1, Math.min(14, Number(days) || this.settings.chances.days || 7));
    const lt = longterm.marketLongTerm(this.db, mid, now);
    const st = sales.marketStats(this.db, mid, now);
    const last = this.db.prepare("SELECT id, t FROM snapshots WHERE market_id = ? AND source = 'scan' ORDER BY t DESC LIMIT 1").get(mid);
    const resale = chances.summarizeOpp(this.db, mid, 'r', d, now, st, last && last.id);
    const vendor = chances.summarizeOpp(this.db, mid, 'v', d, now, st, last && last.id);
    const mv = chances.moves(this.db, mid, lt.items, longterm.dayValues(this.db, mid, lt.day), last, lt.day);
    const vendorKnown = this.db.prepare('SELECT COUNT(*) AS n FROM items WHERE vendor IS NOT NULL').get().n;
    return { market: marketKey, days: d, now, lastScan: last ? last.t : null, bands: lt.items.size, salesItems: st.size,
      sure: [...st.values()].filter((s) => s.level >= 2).length, vendorKnown,
      resale, vendor, up: mv.up, down: mv.down, worth: chances.worth(this.db, lt.items, st) };
  }

  // Werte fuer einen Gegenstand (Anzeige im Manager)
  itemLongTerm(marketKey, key) {
    const m = this.db.prepare('SELECT id FROM markets WHERE key = ?').get(marketKey);
    if (!m) return null;
    const lt = longterm.marketLongTerm(this.db, m.id, this.now());
    return lt.items.get(key) || null;
  }

  // Broker-Verlauf (Peon_Broker.lua), nur wenn die Datei sich geaendert hat
  importBroker(force = false) {
    const out = [];
    const seen = this.meta('brokerFiles') || {};
    for (const f of broker.findFiles(this.settings.wowDir)) {
      let mt = 0;
      try { mt = Math.floor(fs.statSync(f.file).mtimeMs); } catch { continue; }
      if (!force && seen[f.file] === mt) continue;
      try {
        const r = broker.importFile(this.db, f.file);
        seen[f.file] = mt;
        out.push({ file: f.file, markets: r.markets });
        const n = r.markets.reduce((a, m) => a + m.items, 0);
        log(this.db, 'broker', true, `Broker-Verlauf: ${n} Gegenstände in ${r.markets.length} ${r.markets.length === 1 ? 'Markt' : 'Märkten'}`);
      } catch (e) {
        out.push({ file: f.file, error: e.message });
        log(this.db, 'broker', false, `Broker-Verlauf: ${e.message}`);
      }
    }
    this.meta('brokerFiles', seen);
    return out;
  }

  // Aufbewahrung anwenden (beim Start, einmal am Tag, nach Aenderung der Einstellung)
  prune() {
    const r = retention.prune(this.db, { keepDays: this.settings.keepDays, hourDays: this.settings.hourDays, now: this.now() });
    r.pairs = sales.prune(this.db, this.now());
    pruneLogs(this.db, 30, this.now() * 1000);
    this.db.prepare('DELETE FROM opp_snap WHERE t < ?').run(this.now() - 30 * 86400);
    this.db.prepare('DELETE FROM opp_scan WHERE t < ?').run(this.now() - 30 * 86400);
    if (r.snaps || r.hours) log(this.db, 'aufbewahrung', true, `${r.snaps} Kennzahlen zu Stundenwerten, ${r.hours} Stundenwerte zu Tageswerten verdichtet`);
    this.meta('pruneAt', this.now());
    return r;
  }

  retention(keepDays) {
    const k = keepDays == null ? this.settings.keepDays : keepDays;
    return retention.estimate(this.db, { keepDays: k, hourDays: this.settings.hourDays, now: this.now(), current: dbSize(this.db) });
  }

  itemList(marketKey) {
    const r = history.itemList(this.db, marketKey, this.now());
    const mid = this.marketId(marketKey);
    if (mid != null) {
      const st = sales.marketStats(this.db, mid, this.now());
      const lt = longterm.marketLongTerm(this.db, mid, this.now()).items;
      const comm = new Map(this.db.prepare('SELECT key, commodity, variant FROM items').all().map((x) => [x.key, x.variant ? 0 : x.commodity]));
      for (const it of r.items) {
        const s = st.get(it.key);
        it.sales = s ? { perDay: s.perDay, level: s.level, rate: s.rate } : null;
        const b = lt.get(it.key);
        it.band = b ? { low: Math.max(0, b.lang * (1 - b.schw)), high: b.lang * (1 + b.schw), lang: b.lang, days: b.days } : null;
        it.commodity = comm.has(it.key) ? comm.get(it.key) : null;
      }
    }
    return r;
  }

  itemDetail(marketKey, key, range) {
    const days = { '1d': 1, '7d': 7, '30d': 30, '90d': 90 }[range];
    const from = days ? this.now() - days * 86400 : null;
    const d = history.itemDetail(this.db, marketKey, key, { from, now: this.now() });
    if (d) {
      d.longterm = this.itemLongTerm(marketKey, key);
      const mid = this.marketId(marketKey);
      const s = sales.marketStats(this.db, mid, this.now(), key).get(key) || null;
      d.sales = s;
      // Bereich und Absatz je Tag fuer das Diagramm, im gewaehlten Zeitraum (Alles: hoechstens ein Jahr)
      const today = broker.dayOf(this.now());
      const first = [...d.own, ...d.hours, ...d.days, ...d.broker].reduce((m, x) => Math.min(m, x.t), this.now());
      const fromDay = Math.max(today - 365, broker.dayOf(from != null ? from : first));
      d.bands = longterm.itemBandHistory(this.db, mid, key, fromDay, today).map((b) => ({ ...b, t: broker.dayTime(b.day) }));
      d.salesDays = sales.itemDays(this.db, mid, key, fromDay).filter((x) => x.secs > 0)
        .map((x) => ({ day: x.day, t: broker.dayTime(x.day), perDay: x.sold / x.secs * 86400, minutes: x.secs / 60 }));
      const v = this.db.prepare('SELECT vendor, commodity FROM items WHERE key = ?').get(key);
      d.vendor = v ? v.vendor : null;
      d.commodity = v ? v.commodity : null;
    }
    return d;
  }

  // ---------- Daten fuer die Oberflaeche ----------
  overview() {
    const db = this.db;
    const markets = db.prepare('SELECT id, key, region FROM markets ORDER BY key').all().map((m) => this.marketInfo(m));
    const ack = this.meta('ack');
    return {
      dbSize: dbSize(db),
      markets,
      game: { files: this.lastFiles, lastImport: this.lastImport },
      api: this.api.summary(),
      back: ack ? { t: ack.t, count: ack.ids.length, file: ack.file, items: ack.items || 0, sales: ack.sales || 0, bytes: ack.bytes || 0, day: ack.day || null } : null,
      log: db.prepare('SELECT t, kind, ok, text FROM log ORDER BY id DESC LIMIT 12').all(),
      brokerHist: db.prepare("SELECT COUNT(DISTINCT item_key) AS items, COUNT(DISTINCT num) AS days, MIN(t) AS t0, MAX(t) AS t1 FROM hist WHERE source = 'broker' AND period = 'day'").get(),
    };
  }

  marketInfo(m) {
    const db = this.db;
    const last = db.prepare("SELECT id, t, offers, items, char, art FROM snapshots WHERE market_id = ? AND source = 'scan' ORDER BY t DESC LIMIT 1").get(m.id);
    const scans = db.prepare("SELECT COUNT(*) AS n FROM snapshots WHERE market_id = ? AND source = 'scan' AND art <> 'api'").get(m.id).n;
    const stands = db.prepare("SELECT COUNT(*) AS n FROM snapshots WHERE market_id = ? AND art = 'api'").get(m.id).n;
    const lives = db.prepare("SELECT COUNT(*) AS n FROM snapshots WHERE market_id = ? AND source = 'live'").get(m.id).n;
    const items = db.prepare('SELECT COUNT(DISTINCT item_key) AS n FROM item_snap WHERE market_id = ?').get(m.id).n;
    const since = (last ? last.t : this.now()) - 30 * 86400;
    const history = db.prepare("SELECT t, offers, items FROM snapshots WHERE market_id = ? AND source = 'scan' AND t >= ? ORDER BY t").all(m.id, since);
    return { key: m.key, region: m.region, lastScan: last || null, scans, stands, lives, items, history, moves: last ? this.moves(m.id, last) : null };
  }

  // Groesste Bewegungen: Median des letzten Scans gegen einen Scan etwa einen Tag vorher (sonst den vorigen)
  moves(marketId, last) {
    const db = this.db;
    let base = db.prepare("SELECT id, t FROM snapshots WHERE market_id = ? AND source = 'scan' AND t <= ? ORDER BY t DESC LIMIT 1").get(marketId, last.t - 20 * 3600);
    if (!base) base = db.prepare("SELECT id, t FROM snapshots WHERE market_id = ? AND source = 'scan' AND t < ? ORDER BY t DESC LIMIT 1").get(marketId, last.t);
    if (!base) return { base: null, up: [], down: [] };
    const rows = db.prepare(`SELECT a.item_key AS key, a.median AS now, b.median AS before, a.qty AS qty, i.name AS name, i.quality AS quality, i.item_id AS item
        FROM item_snap a JOIN item_snap b ON b.snapshot_id = ? AND b.item_key = a.item_key
        LEFT JOIN items i ON i.key = a.item_key
        WHERE a.snapshot_id = ? AND a.median >= 100 AND b.median >= 100 AND a.qty >= 3 AND b.qty >= 3`).all(base.id, last.id);
    for (const r of rows) r.pct = (r.now - r.before) / r.before;
    const up = rows.filter((r) => r.pct > 0).sort((x, y) => y.pct - x.pct).slice(0, 6);
    const down = rows.filter((r) => r.pct < 0).sort((x, y) => x.pct - y.pct).slice(0, 6);
    return { base: base.t, up, down };
  }

  close() { try { this.db.close(); } catch { /* schon zu */ } }
}

module.exports = { BrokerClient };
