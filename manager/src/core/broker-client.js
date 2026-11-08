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
const shopping = require('./shopping');
const zlib = require('node:zlib');
const { parseLua } = require('./lua');
const { parseRows, itemKey, unitPrice } = require('./stats');
const { marketLabel } = require('./markets');
const longterm = require('./longterm');
const sales = require('./sales');
const chances = require('./chances');
const { BlizzardImport } = require('./blizzard-import');
const { ItemInfo } = require('./item-info');
const crypto = require('node:crypto');

const TIP_WANT_MAX = 1000;        // so viele genaue Werte je Laden im Spiel bestellen, der Rest kommt danach
const TIP_RETRY = 7 * 86400;      // Kennt das Spiel etwas nicht, so lange nicht erneut fragen
// Link wie im Spiel (Felder 9 und 10: Stufe und Spezialisierung, Feld 13: Anzahl der Boni). Im Spiel bestaetigt am 06.11.2026
const tipLink = (item, bonus) => { const b = String(bonus || '').split(',').filter(Boolean); return b.length ? `item:${item}::::::::20:1488:::${b.length}:${b.join(':')}` : `item:${item}`; };

const MOVES_MIN_BANDS = 20;   // ab so vielen Gegenstaenden mit ueblichem Bereich zaehlt der als Vergleich

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
        const r = game.importFile(this.db, f.file, f.account, this.now());
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
    if (sum.broker.some((b) => b.shop)) this.shopFromGame(sum.broker);
    const markets = this.buildMarkets();
    // Bestaetigen nur, was sicher in der Datenbank ist
    const known = ids.filter((id) => this.db.prepare('SELECT 1 FROM snapshots WHERE id = ?').get(id));
    const prev = this.meta('ack') || { ids: [] };
    const same = prev.ids.length === known.length && prev.ids.every((x, k) => x === known[k]);
    const shop = this.shopForGame();
    const aliases = this.aliases();
    const tipWant = this.tipWants();
    const hash = crypto.createHash('md5').update(JSON.stringify([markets.values, shop, aliases, tipWant])).digest('hex');
    const marks = this.host.reports.marks();
    if (!same || !prev.t || prev.hash !== hash || !dataMatches(wow, this.host.channels(), marks)) {
      try {
        const w = writeData(wow, { ack: known, markets: markets.lua, channels: this.host.channels(), version: this.version, now: this.now(), aliases, shop, tipWant, ...marks });
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
  // Neue Regeln fuer Chancen (chances.RULES): alte Wiederverkaufs-Treffer verwerfen
  checkRules() {
    if (chances.resetRules(this.db, this.meta('oppRules'))) {
      this.meta('oppRules', chances.RULES);
      log(this.db, 'chancen', true, 'Neue Regeln: Wiederverkauf neu gerechnet, die Trefferquote beginnt neu');
    }
  }

  buildMarkets() {
    this.checkRules();
    const lua = {}, values = {};
    let count = 0, salesCount = 0;
    const now = this.now();
    const day = broker.dayOf(now);
    for (const m of this.db.prepare('SELECT id, key FROM markets').all()) {
      try { sales.updateMarket(this.db, m.id, now); } catch (e) { log(this.db, 'absatz', false, `${m.key}: ${e.message}`); }
      const lt = this.bands(m.id);
      const st = sales.marketStats(this.db, m.id, now);
      try { chances.updateMarket(this.db, m.id, lt.items, now, lt.shifts, st); } catch (e) { log(this.db, 'chancen', false, `${m.key}: ${e.message}`); }
      this.listOf(m.id, m.key);   // Liste fuer die Ansichten gleich mitrechnen, dann oeffnet sie sofort
      const cur = this.currentOf(m.id);
      if (!lt.items.size && !st.size && !cur) continue;
      const items = {}, sl = {};
      for (const [k, r] of lt.items) items[k] = longterm.encode(r);
      for (const [k, s] of st) sl[k] = sales.encode(s);
      lua[m.key] = { t: now, day: lt.day, items, sales: sl };
      values[m.key] = { day: lt.day, items, sales: sl };
      if (cur) { lua[m.key].cur = cur; values[m.key].cur = cur; }
      count += lt.items.size;
      salesCount += st.size;
    }
    this.lastLua = lua;
    return { lua, values, count, salesCount, day };
  }

  // Aktueller Stand fuer Broker (ab Manager 0.18.0, Wunsch KarloDerBaer 07.11.2026): Preise des neuesten vollstaendigen
  // Stands, Blizzard-API oder Scan. Broker nimmt sie, wenn sie neuer sind als sein eigener Scan.
  // items[key] = "min:median:menge:angebote" (Kupfer je Stueck, gerundet), nur Gegenstaende mit Angeboten.
  currentOf(mid) {
    const last = this.db.prepare("SELECT id, t, art FROM snapshots WHERE market_id = ? AND source = 'scan' AND partial = 0 ORDER BY t DESC LIMIT 1").get(mid);
    if (!last) return null;
    const items = {};
    let n = 0;
    for (const r of this.db.prepare('SELECT item_key, min, median, qty, auctions FROM item_snap WHERE snapshot_id = ? AND qty > 0 AND min > 0').iterate(last.id)) {
      items[r.item_key] = `${Math.round(r.min)}:${Math.round(r.median > 0 ? r.median : r.min)}:${r.qty}:${r.auctions || 0}`;
      n++;
    }
    if (!n) return null;
    return { t: last.t, src: last.art === 'api' ? 'api' : 'scan', items };
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
    const lt = this.bands(mid);
    // noch nicht ausgewertete Scans (etwa nach neuen Regeln) gleich auswerten, damit „jetzt“ stimmt
    this.checkRules();
    const st = sales.marketStats(this.db, mid, now);
    try { chances.updateMarket(this.db, mid, lt.items, now, lt.shifts, st); } catch (e) { log(this.db, 'chancen', false, `${marketKey}: ${e.message}`); }
    const last = this.db.prepare("SELECT id, t FROM snapshots WHERE market_id = ? AND source = 'scan' ORDER BY t DESC LIMIT 1").get(mid);
    const resale = chances.summarizeOpp(this.db, mid, 'r', d, now, st, last && last.id);
    const vendor = chances.summarizeOpp(this.db, mid, 'v', d, now, st, last && last.id);
    const mv = chances.moves(this.db, mid, lt.items, lt.days, last, lt.day);
    const vendorKnown = this.db.prepare('SELECT COUNT(*) AS n FROM items WHERE vendor IS NOT NULL').get().n;
    return { market: marketKey, days: d, now, lastScan: last ? last.t : null, bands: lt.items.size, salesItems: st.size,
      sure: [...st.values()].filter((s) => s.level >= 2).length, vendorKnown,
      resale, vendor, up: mv.up, down: mv.down, worth: chances.worth(this.db, lt.items, st), hits: chances.hitRate(this.db, mid, now) };
  }

  // Werte fuer einen Gegenstand (Anzeige im Manager)
  itemLongTerm(marketKey, key) {
    const m = this.db.prepare('SELECT id FROM markets WHERE key = ?').get(marketKey);
    if (!m) return null;
    const today = broker.dayOf(this.now());
    const days = longterm.dayValues(this.db, m.id, today, key).get(key);
    return days ? longterm.compute(days, today) : null;
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
        out.push({ file: f.file, markets: r.markets, shop: r.shop });
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
    const res = { snaps: 0, hours: 0, blobs: 0 };
    for (const _ of this.pruneSteps(res)) { /* alle Schritte am Stueck */ }
    return res;
  }

  // Wie prune, aber zwischen den Schritten laeuft das Programm weiter. Laeuft es schon, gibt es keinen zweiten Lauf.
  // Kommt eine neue Einstellung waehrend eines Laufs, wird danach erneut aufgeraeumt.
  async pruneInBackground() {
    if (this.pruning) { this.pruneAgain = true; return null; }
    this.pruning = true;
    const res = { snaps: 0, hours: 0, blobs: 0 };
    try {
      do {
        this.pruneAgain = false;
        for (const _ of this.pruneSteps(res)) {
          await new Promise((done) => setImmediate(done));
          if (this.closed) return res;
        }
      } while (this.pruneAgain);
      return res;
    } catch (e) {
      if (!this.closed) log(this.db, 'aufbewahrung', false, `Aufräumen: ${e.message}`);
      return null;
    } finally {
      this.pruning = false;
    }
  }

  * pruneSteps(res) {
    const hourDays = this.settings.hourDays > 0 ? Math.max(retention.MIN_HOUR_DAYS, this.settings.hourDays) : 0;
    yield* retention.pruneSteps(this.db, { keepDays: this.settings.keepDays, hourDays, now: this.now() }, res);
    res.pairs = sales.prune(this.db, this.now());
    pruneLogs(this.db, 30, this.now() * 1000);
    this.db.prepare('DELETE FROM opp_snap WHERE t < ?').run(this.now() - 30 * 86400);
    this.db.prepare('DELETE FROM opp_scan WHERE t < ?').run(this.now() - 30 * 86400);
    if (res.snaps || res.hours) log(this.db, 'aufbewahrung', true, `${res.snaps} Kennzahlen zu Stundenwerten, ${res.hours} Stundenwerte zu Tageswerten verdichtet`);
    this.meta('pruneAt', this.now());
  }

  retention(keepDays, hourDays) {
    const k = keepDays == null ? this.settings.keepDays : keepDays;
    const h = hourDays == null ? this.settings.hourDays : hourDays;
    return retention.estimate(this.db, { keepDays: k, hourDays: h, now: this.now(), current: dbSize(this.db) });
  }

  // Stand der Daten eines Markts: Aendert er sich, sind fertig gerechnete Listen und Bereiche alt
  dataSig(mid) {
    const last = this.db.prepare("SELECT id FROM snapshots WHERE market_id = ? AND source = 'scan' ORDER BY t DESC LIMIT 1").get(mid);
    const n = this.db.prepare('SELECT COUNT(*) AS n FROM snapshots WHERE market_id = ?').get(mid).n;
    return `${broker.dayOf(this.now())}|${last ? last.id : ''}|${n}|${JSON.stringify(this.meta('brokerFiles') || {})}`;
  }

  // Ueblicher Bereich aller Gegenstaende eines Markts, einmal je Stand gerechnet
  bands(mid) {
    const sig = this.dataSig(mid);
    this.bandCache = this.bandCache || new Map();
    const c = this.bandCache.get(mid);
    if (c && c.sig === sig) return c.value;
    const days = longterm.dayValues(this.db, mid, broker.dayOf(this.now()));
    const value = { ...longterm.marketLongTerm(this.db, mid, this.now(), days), days };
    value.shifts = longterm.shifts(this.db, mid, this.now(), value.items);   // F54
    this.bandCache.set(mid, { sig, value });
    return value;
  }

  // Ganze Gegenstandsliste rechnen (teuer, ueber alle Momentaufnahmen)
  computeList(marketKey, mid) {
    const r = history.itemList(this.db, marketKey, this.now());
    const st = sales.marketStats(this.db, mid, this.now());
    const bd = this.bands(mid);
    const lt = bd.items;
    const comm = new Map(this.db.prepare('SELECT key, commodity, variant FROM items').all().map((x) => [x.key, x.variant ? 0 : x.commodity]));
    for (const it of r.items) {
      const s = st.get(it.key);
      it.sales = s ? { perDay: s.perDay, level: s.level, rate: s.rate } : null;
      const b = lt.get(it.key);
      it.band = b ? { low: Math.max(0, b.lang * (1 - b.schw)), high: b.lang * (1 + b.schw), lang: b.lang, days: b.days } : null;
      const sh = b && bd.shifts.get(it.key);   // F54: Bereich veraltet, Preis hat ein neues Niveau
      if (sh) it.band.shift = sh.dir;
      if (b && b.schw > chances.UNSURE) it.band.unsure = true;   // F50c: Bereich zu breit
      it.commodity = comm.has(it.key) ? comm.get(it.key) : null;
    }
    return r;
  }

  // Fertige Liste aus dem Speicher oder der Datenbank, nur bei neuen Daten neu gerechnet
  listOf(mid, marketKey) {
    const sig = this.dataSig(mid);
    this.listCache = this.listCache || new Map();
    const mem = this.listCache.get(mid);
    if (mem && mem.sig === sig) return mem.value;
    const row = this.db.prepare('SELECT sig, data FROM list_cache WHERE market_id = ?').get(mid);
    let value;
    if (row && row.sig === sig) {
      value = JSON.parse(zlib.inflateSync(Buffer.from(row.data)).toString('utf8'));
    } else {
      value = this.computeList(marketKey, mid);
      this.db.prepare('INSERT OR REPLACE INTO list_cache(market_id, sig, data) VALUES (?, ?, ?)').run(mid, sig, zlib.deflateSync(Buffer.from(JSON.stringify(value), 'utf8')));
    }
    this.listCache.set(mid, { sig, value });
    return value;
  }

  itemList(marketKey) {
    const mid = this.marketId(marketKey);
    if (mid == null) return { market: marketKey, items: [], lastScan: null };
    return this.listOf(mid, marketKey);
  }

  itemDetail(marketKey, key, range) {
    const days = { '1d': 1, '7d': 7, '30d': 30, '90d': 90 }[range];
    const from = days ? this.now() - days * 86400 : null;
    const d = history.itemDetail(this.db, marketKey, key, { from, now: this.now() });
    if (d) {
      d.longterm = this.itemLongTerm(marketKey, key);
      const mid = this.marketId(marketKey);
      d.shift = d.longterm ? longterm.shifts(this.db, mid, this.now(), new Map([[key, d.longterm]]), key).get(key) || null : null;   // F54
      const s = sales.marketStats(this.db, mid, this.now(), key).get(key) || null;
      d.sales = s;
      d.depth = d.longterm ? this.itemDepth(mid, key, d.longterm) : null;
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
      d.others = this.otherMarkets(mid, key);
    }
    return d;
  }

  // F50b fuer die Gegenstandsseite (Manager 0.22.0): wie viel Ware liegt im letzten Scan unter dem ueblichen Bereich?
  // Rueckgabe { below, t } oder null (kein Scan, nichts darunter)
  itemDepth(mid, key, b) {
    const last = this.db.prepare("SELECT id, t FROM snapshots WHERE market_id = ? AND source = 'scan' AND rows IS NOT NULL ORDER BY t DESC LIMIT 1").get(mid);
    if (!last) return null;
    const rows = chances.rowsOf(this.db, last.id);
    if (!rows) return null;
    const lo = chances.low(b);
    let below = 0;
    for (const r of rows) {
      if (itemKey(r) !== key || !(r.qty > 0)) continue;
      const p = unitPrice(r);
      if (p != null && p < lo) below += r.qty * r.n;
    }
    return below > 0 ? { below, t: last.t } : null;
  }

  // ---------- Daten fuer die Oberflaeche ----------
  overview() {
    const db = this.db;
    const markets = db.prepare('SELECT id, key, region FROM markets ORDER BY key').all().map((m) => this.marketInfoCached(m));
    const ack = this.meta('ack');
    return {
      dbSize: dbSize(db),
      tips: this.tipStats(),
      markets,
      game: { files: this.lastFiles, lastImport: this.lastImport },
      api: this.api.summary(),
      back: ack ? { t: ack.t, count: ack.ids.length, file: ack.file, items: ack.items || 0, sales: ack.sales || 0, bytes: ack.bytes || 0, day: ack.day || null } : null,
      log: db.prepare('SELECT t, kind, ok, text FROM log ORDER BY id DESC LIMIT 40').all(),
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
    return { key: m.key, label: marketLabel(m.key), region: m.region, lastScan: last || null, scans, stands, lives, items, history, moves: last ? this.moves(m.id, last) : null };
  }

  // Marktdaten einmal je Stand, die Zaehlungen laufen sonst bei jedem Neuladen ueber alle Zeilen
  marketInfoCached(m) {
    const sig = this.dataSig(m.id);
    this.infoCache = this.infoCache || new Map();
    const c = this.infoCache.get(m.id);
    if (c && c.sig === sig) return c.value;
    const value = this.marketInfo(m);
    this.infoCache.set(m.id, { sig, value });
    return value;
  }

  // Derselbe Gegenstand in den anderen Maerkten, die der Manager kennt
  otherMarkets(mid, key) {
    const out = [];
    for (const m of this.db.prepare('SELECT id, key FROM markets WHERE id <> ? ORDER BY key').all(mid)) {
      const last = this.db.prepare("SELECT id, t FROM snapshots WHERE market_id = ? AND source = 'scan' ORDER BY t DESC LIMIT 1").get(m.id);
      const c = last && this.db.prepare('SELECT min, median, qty, auctions FROM item_snap WHERE snapshot_id = ? AND item_key = ?').get(last.id, key);
      if (c && c.qty > 0) out.push({ market: m.key, label: marketLabel(m.key), t: last.t, min: c.min, median: c.median, qty: c.qty, auctions: c.auctions });
    }
    return out;
  }

  // Andere interne Namen eines Markts fuer Data.lua
  aliases() {
    const out = {};
    for (const a of this.db.prepare('SELECT a.alias, m.key FROM market_alias a JOIN markets m ON m.id = a.market_id').all()) out[a.alias] = a.key;
    return out;
  }

  // ---------- Favoriten ----------
  favorites() { return this.db.prepare('SELECT item_key AS key FROM favorites ORDER BY added').all().map((r) => r.key); }

  setFavorite(key, on) {
    if (on) this.db.prepare('INSERT OR IGNORE INTO favorites(item_key, added) VALUES (?, ?)').run(String(key), this.now());
    else this.db.prepare('DELETE FROM favorites WHERE item_key = ?').run(String(key));
    return this.favorites();
  }

  // ---------- Einkaufslisten ----------
  shopDoc() { return shopping.clean(this.meta('shop') || shopping.empty()); }

  shopForGame() {
    const d = this.shopDoc();
    if (!d.lists.length && !Object.keys(d.gone.lists).length && !Object.keys(d.gone.items).length) return null;
    return shopping.forGame(d);
  }

  // Was das Spiel in Peon_Broker.lua geschrieben hat einmischen
  shopFromGame(results) {
    const d = this.shopDoc();
    let changed = shopping.purge(d, this.now());
    for (const r of results) if (r.shop && shopping.merge(d, r.shop)) changed = true;
    if (changed) this.meta('shop', d);
    return changed;
  }

  // Eingabe im Manager: speichern und gleich fuer das Spiel bereitlegen. Die Werte fuer Broker rechnet das nicht neu.
  shopEdit(fn) {
    const d = this.shopDoc();
    const r = fn(d, this.now());
    this.meta('shop', d);
    this.writeBridgeShop();
    return r;
  }

  writeBridgeShop() {
    const ack = this.meta('ack');
    const lua = this.lastLua || this.buildMarkets().lua;
    try {
      const shop = this.shopForGame();
      const marks = this.host.reports.marks();
      const w = writeData(this.settings.wowDir, { ack: ack ? ack.ids : [], markets: lua, channels: this.host.channels(), version: this.version, now: this.now(), aliases: this.aliases(), shop, tipWant: this.lastWant, ...marks });
      // Der Vergleich beim naechsten Einlesen schreibt sonst noch einmal, das schadet nicht
      if (ack) this.meta('ack', { ...ack, t: this.now(), bytes: w.bytes, hash: null });
      return true;
    } catch (e) {
      log(this.db, 'einkaufsliste', false, `Data.lua: ${e.message}`);
      return false;
    }
  }

  newShopList(name) { return this.shopEdit((d, now) => shopping.newList(d, name, now).id); }
  deleteShopList(id) { return this.shopEdit((d, now) => shopping.deleteList(d, String(id), now)); }
  updateShopList(id, patch) { return this.shopEdit((d, now) => !!shopping.updateList(d, String(id), patch, now)); }

  addShopItem(id, key) {
    const n = this.db.prepare('SELECT name, quality FROM items WHERE key = ?').get(String(key));
    return this.shopEdit((d, now) => !!shopping.addItem(d, String(id), String(key), { name: n && n.name, quality: n && n.quality }, now));
  }

  removeShopItem(id, key) { return this.shopEdit((d, now) => shopping.removeItem(d, String(id), String(key), now)); }
  setShopItem(id, key, patch) { return this.shopEdit((d, now) => !!shopping.setItem(d, String(id), String(key), patch, now)); }

  // In welchen Listen steht ein Gegenstand? Fuer den Knopf im Gegenstandsfenster
  shopLists(key) {
    return this.shopDoc().lists.map((l) => ({ id: l.id, name: l.name, on: !!(key != null && l.items[String(key)]) }));
  }

  // Bestand aller Charaktere (Taschen und Bank) aus Peon_Ledger.lua, gelesen nur bei neuer Datei. Map itemID -> Stueck, null ohne Ledger
  ledgerStock() {
    const base = path.join(this.settings.wowDir, 'WTF', 'Account');
    let accounts = [];
    try { accounts = fs.readdirSync(base); } catch { return null; }
    const files = [];
    for (const a of accounts) {
      const f = path.join(base, a, 'SavedVariables', 'Peon_Ledger.lua');
      try { files.push({ f, mt: fs.statSync(f).mtimeMs }); } catch { /* kein Ledger */ }
    }
    if (!files.length) return null;
    const sig = JSON.stringify(files);
    if (this.stockCache && this.stockCache.sig === sig) return this.stockCache.value;
    const out = new Map();
    for (const { f } of files) {
      try {
        const realms = (parseLua(fs.readFileSync(f)).PeonLedgerDB || {}).realms || {};
        for (const r of Object.values(realms)) {
          for (const c of Object.values((r && r.chars) || {})) {
            for (const place of ['bags', 'bank']) {
              const items = c && c.places && c.places[place] && c.places[place].items;
              if (items) for (const [id, n] of Object.entries(items)) out.set(Number(id), (out.get(Number(id)) || 0) + (Number(n) || 0));
            }
          }
        }
      } catch { /* Datei kaputt: dann eben ohne */ }
    }
    this.stockCache = { sig, value: out };
    return out;
  }

  // Preisstufen des letzten Stands fuer wenige Gegenstaende: Map Schluessel -> [{ price, qty }]
  levelsOf(mid, keys) {
    const out = new Map();
    const last = this.db.prepare("SELECT rows FROM snapshots WHERE market_id = ? AND source = 'scan' AND rows IS NOT NULL ORDER BY t DESC LIMIT 1").get(mid);
    if (!last || !keys.size) return out;
    for (const r of parseRows(zlib.inflateSync(Buffer.from(last.rows)).toString('utf8'))) {
      const k = itemKey(r);
      if (!keys.has(k)) continue;
      const p = unitPrice(r);
      if (p == null) continue;
      if (!out.has(k)) out.set(k, []);
      out.get(k).push({ price: p, qty: r.qty * r.n });
    }
    return out;
  }

  // Zeile einer Einkaufsliste mit den Werten eines Markts (wie im Spiel, Broker F28 bis F30).
  // Hoechstpreis = eigene Vorgabe, sonst Vergleichspreis abzueglich des Rabatts der Liste.
  shopRow(key, it, list, cur, levels, stock) {
    const ref = cur ? (cur.avg7 ?? cur.median) : null;
    const rule = ref != null ? Math.floor(ref * (1 - (Number(list.pct) || 0) / 100)) : null;
    const limit = it.max != null ? it.max : rule;
    const lv = levels.get(key) || [];
    let hits = 0;
    if (limit != null) for (const l of lv) if (l.price <= limit) hits += l.qty;
    const item = cur ? cur.item : Number(String(key).split(':')[0]);
    return { key, item, name: (cur && cur.name) || it.name || null, quality: cur ? cur.quality : it.q ?? null, wish: it.wish ?? null, max: it.max ?? null, limit, rule,
      cheapest: cur && cur.inLast ? cur.min : null, median: cur && cur.inLast ? cur.median : null, qty: cur && cur.inLast ? cur.qty : 0, hits,
      stock: stock ? (stock.get(item) || 0) : null };
  }

  // Ansicht Einkaufsliste fuer einen Markt
  shopView(marketKey) {
    const d = this.shopDoc();
    const mid = this.marketId(marketKey);
    const list = mid == null ? { items: [] } : this.listOf(mid, marketKey);
    const byKey = new Map(list.items.map((x) => [x.key, x]));
    const keys = new Set(d.lists.flatMap((l) => Object.keys(l.items)));
    const levels = mid == null ? new Map() : this.levelsOf(mid, keys);
    const stock = this.ledgerStock();
    return { hasLedger: !!stock, lists: d.lists.map((l) => ({ id: l.id, name: l.name, pct: l.pct,
      items: Object.entries(l.items).map(([k, it]) => this.shopRow(k, it, l, byKey.get(k), levels, stock))
        .sort((a, b) => Number(b.hits > 0) - Number(a.hits > 0) || String(a.name || a.key).localeCompare(String(b.name || b.key), 'de')) })) };
  }

  // Fuer die Uebersicht: was ist gerade unter dem Hoechstpreis zu haben?
  shopBuyable(marketKey) {
    const seen = new Map();
    for (const l of this.shopView(marketKey).lists) {
      for (const r of l.items) {
        if (!(r.hits > 0) || (r.wish != null && r.stock != null && r.stock >= r.wish)) continue;
        const old = seen.get(r.key);
        if (!old || r.limit > old.limit) seen.set(r.key, { ...r, list: l.name });
      }
    }
    return [...seen.values()];
  }

  // Nach neuen Daten: Was liegt gerade unter dem Hoechstpreis? Gemeldet wird einmal und wieder, nachdem der Preis darueber lag.
  shopCheck() {
    const d = this.shopDoc();
    if (!d.lists.length) return [];
    const was = this.meta('shopHits') || {};
    const next = {}, out = [];
    for (const m of this.db.prepare('SELECT id, key FROM markets').all()) {
      const byKey = new Map(this.listOf(m.id, m.key).items.map((x) => [x.key, x]));
      for (const l of d.lists) {
        for (const [k, it] of Object.entries(l.items)) {
          const cur = byKey.get(k);
          if (!cur || !cur.inLast || cur.min == null) continue;
          const row = this.shopRow(k, it, l, cur, new Map(), null);
          if (row.limit == null || cur.min > row.limit) continue;
          const id = `${m.id}|${l.id}|${k}`;
          next[id] = 1;
          if (!was[id]) out.push({ market: m.key, label: marketLabel(m.key), key: k, name: row.name || k, min: cur.min, limit: row.limit, list: l.name });
        }
      }
    }
    this.meta('shopHits', next);
    return out;
  }

  // ---------- Stand des Austauschs mit dem Spiel ----------
  // Der Hauptteil meldet regelmaessig, ob WoW laeuft. Ein Speichern von Peon_Bridge.lua bei laufendem WoW heisst Neuladen oder neuer Charakter,
  // danach hat das Spiel Data.lua gelesen. Ebenso beim Start von WoW.
  noteGame(running) {
    let mt = 0;
    for (const f of game.findFiles(this.settings.wowDir)) { try { mt = Math.max(mt, Math.floor(fs.statSync(f.file).mtimeMs / 1000)); } catch { /* weg */ } }
    const was = this.gameState;
    this.gameState = { running: !!running, mt };
    if (!was) return false;
    let load = null;
    if (running && !was.running) load = this.now();
    else if (running && mt > was.mt) load = mt;
    if (load) this.meta('gameLoadAt', load);
    return !!load || was.running !== !!running;
  }

  sync() {
    const since = this.meta('gameLoadAt') || 0;
    const ack = this.meta('ack');
    const inputs = shopping.pending(this.shopDoc(), since);
    return { inputs, running: !!(this.gameState && this.gameState.running), values: !!(ack && ack.t > since) };
  }

  // Genaue Werte, die der Manager noch nicht hat: Schluessel -> Link fuer das Spiel. Die Blizzard-API nennt je Angebot Gegenstand und Bonus,
  // daraus entsteht der Link, das Spiel liest den Tooltip im Hintergrund. Zuerst Favoriten und Einkaufslisten, dann Gegenstaende mit Zusatz.
  // Ausruestung ab Selten, Massenware und Einfaches nur, wenn es jemand gemerkt hat. Kennt das Spiel etwas nicht, wird es 7 Tage nicht erneut bestellt.
  tipWants() {
    const known = new Set();
    for (const r of this.db.prepare('SELECT key, lines, t FROM item_tip').iterate()) {
      if (r.lines !== '[]' || this.now() - r.t < TIP_RETRY) known.add(r.key);
    }
    const quality = new Map(this.db.prepare('SELECT key, quality FROM items').all().map((x) => [x.key, x.quality]));
    const first = new Set([...this.favorites(), ...this.shopDoc().lists.flatMap((l) => Object.keys(l.items))]);
    const found = new Map();
    for (const m of this.db.prepare('SELECT id FROM markets').all()) {
      const last = this.db.prepare("SELECT rows FROM snapshots WHERE market_id = ? AND source = 'scan' AND rows IS NOT NULL ORDER BY t DESC LIMIT 1").get(m.id);
      if (!last) continue;
      for (const r of parseRows(zlib.inflateSync(Buffer.from(last.rows)).toString('utf8'))) {
        const k = itemKey(r);
        if (known.has(k) || found.has(k)) continue;
        if (r.name && !r.bonus) continue;   // Variante ohne Bonus-Nummer: daraus laesst sich kein Link bauen
        if (r.bonus || first.has(k) || (quality.get(k) ?? 0) >= 2) found.set(k, { rank: first.has(k) ? 0 : r.bonus ? 1 : 2, link: tipLink(r.item, r.bonus) });
      }
    }
    for (const k of first) {
      if (!known.has(k) && !found.has(k) && /^\d+$/.test(k)) found.set(k, { rank: 0, link: tipLink(k, '') });
    }
    const want = {};
    for (const [k, v] of [...found].sort((a, b) => a[1].rank - b[1].rank || (a[0] < b[0] ? -1 : 1)).slice(0, TIP_WANT_MAX)) want[k] = v.link;
    this.lastWant = want;
    this.lastWantTotal = found.size;
    return want;
  }

  tipStats() {
    return { known: this.db.prepare("SELECT COUNT(*) AS n FROM item_tip WHERE lines <> '[]'").get().n, open: this.lastWantTotal || 0 };
  }

  // Tooltip eines Gegenstands: genaue Werte aus dem Spiel, wenn vorhanden, dazu Haendlerpreis und Name von Blizzard
  async itemTip(key, client) {
    const k = String(key);
    const info = await this.info.get(parseInt(k, 10), client);
    const row = this.db.prepare("SELECT lines FROM item_tip WHERE key = ? AND lines <> '[]'").get(k);
    if (!row) return info;
    const base = (info && info.tip) || {};
    return { state: 'ok', tip: { name: base.name || null, quality: base.quality ?? null, sell: base.sell ?? null, source: 'game', exact: true, lines: JSON.parse(row.lines) } };
  }

  // Groesste Bewegungen gegenueber dem ueblichen Preis, gerechnet einmal je Stand. In den ersten Tagen gibt es den noch nicht,
  // dann gegen einen Scan etwa einen Tag vorher (sonst den vorigen).
  moves(marketId, last) {
    const key = `${marketId}:${last.id}`;
    if (!this.movesCache || this.movesCache.key !== key) this.movesCache = { key, value: this.computeMoves(marketId, last) };
    return this.movesCache.value;
  }

  computeMoves(marketId, last) {
    const db = this.db;
    const bands = this.bands(marketId).items;
    if (bands.size >= MOVES_MIN_BANDS) {
      const rows = [];
      for (const r of db.prepare(`SELECT a.item_key AS key, a.median AS now, a.qty AS qty, i.name AS name, i.quality AS quality, i.item_id AS item
          FROM item_snap a LEFT JOIN items i ON i.key = a.item_key WHERE a.snapshot_id = ? AND a.median >= 100 AND a.qty >= 3`).iterate(last.id)) {
        const b = bands.get(r.key);
        if (!b || !(b.lang > 0) || b.schw > 0.5) continue;   // zu unruhig: kein verlaesslicher Vergleich
        rows.push({ ...r, before: b.lang, pct: r.now / b.lang - 1 });
      }
      return { mode: 'band', base: last.t, up: rows.filter((r) => r.pct > 0).sort((x, y) => y.pct - x.pct).slice(0, 6),
        down: rows.filter((r) => r.pct < 0).sort((x, y) => x.pct - y.pct).slice(0, 6) };
    }
    let base = db.prepare("SELECT id, t FROM snapshots WHERE market_id = ? AND source = 'scan' AND t <= ? ORDER BY t DESC LIMIT 1").get(marketId, last.t - 20 * 3600);
    if (!base) base = db.prepare("SELECT id, t FROM snapshots WHERE market_id = ? AND source = 'scan' AND t < ? ORDER BY t DESC LIMIT 1").get(marketId, last.t);
    if (!base) return { mode: 'scan', base: null, up: [], down: [] };
    const rows = db.prepare(`SELECT a.item_key AS key, a.median AS now, b.median AS before, a.qty AS qty, i.name AS name, i.quality AS quality, i.item_id AS item
        FROM item_snap a JOIN item_snap b ON b.snapshot_id = ? AND b.item_key = a.item_key
        LEFT JOIN items i ON i.key = a.item_key
        WHERE a.snapshot_id = ? AND a.median >= 100 AND b.median >= 100 AND a.qty >= 3 AND b.qty >= 3`).all(base.id, last.id);
    for (const r of rows) r.pct = (r.now - r.before) / r.before;
    const up = rows.filter((r) => r.pct > 0).sort((x, y) => y.pct - x.pct).slice(0, 6);
    const down = rows.filter((r) => r.pct < 0).sort((x, y) => x.pct - y.pct).slice(0, 6);
    return { mode: 'scan', base: base.t, up, down };
  }

  close() { this.closed = true; try { this.db.close(); } catch { /* schon zu */ } }
}

module.exports = { BrokerClient };
