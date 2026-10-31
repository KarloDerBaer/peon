'use strict';
// Peon Manager - Manager: Einstellungen, Manager-Module (Peon_GitHub_Design.md 5.2), eigene Datenbank peon.db
// (Zustand, Protokoll) und die Kanaele fuer Peon_Bridge. Die Module selbst stecken in eigenen Dateien
// (broker-client.js) und haben eigene Datenbanken. Ohne Electron nutzbar (Tests), main.js ruft nur diese Funktionen auf.

const fs = require('node:fs');
const path = require('node:path');
const { openManagerDb, migrateSplit, fileSize, removeDb, log } = require('./db');
const { writeData, addonDir } = require('./datalua');
const modules = require('./modules');
const { BrokerClient } = require('./broker-client');

const DEFAULTS = {
  wowDir: 'C:\\Program Files (x86)\\World of Warcraft\\_forever_',   // ueblicher Ort von Battle.net, in den Einstellungen aenderbar
  modules: { 'broker-client': { enabled: false } },                  // Manager-Module, standardmaessig aus
  ahledger: { enabled: true, intervalMin: 30 },
  marketMap: {},          // Broker-Markt -> { ext: 'forever.normal.alliance.us', confirmed: false }
  autostart: false,
  theme: 'dark',
  keepDays: 30,           // Momentaufnahmen vollstaendig aufheben (Tage, 0 = unbegrenzt)
  chances: { days: 7, minProfit: 1000, quality: 0 },   // Ansicht Chancen: Zeitraum, Mindestgewinn je Tag (Kupfer), Qualitaet ab
  hourDays: 365,          // danach Stundenwerte bis zu so vielen Tagen, dann Tageswerte
};

function merge(def, cur) {
  const out = Array.isArray(def) ? [] : {};
  for (const k of Object.keys(def)) {
    const d = def[k], c = cur ? cur[k] : undefined;
    if (d && typeof d === 'object' && !Array.isArray(d) && Object.keys(d).length > 0) out[k] = merge(d, c);
    else out[k] = c === undefined || typeof c !== typeof d ? (d && typeof d === 'object' ? JSON.parse(JSON.stringify(d)) : d) : c;
  }
  if (cur && typeof cur === 'object') for (const k of Object.keys(cur)) if (!(k in out)) out[k] = cur[k];
  return out;
}

class Service {
  // enable: Liste von Modulen, die gleich eingeschaltet werden (fuer Tests)
  constructor({ dbDir, version = '0.0.0', fetchImpl, now, enable } = {}) {
    this.dbDir = dbDir;
    this.version = version;
    this.fetchImpl = fetchImpl || ((...a) => fetch(...a));
    this.now = now || (() => Math.floor(Date.now() / 1000));
    this.settingsFile = path.join(dbDir, 'settings.json');
    const existed = fs.existsSync(this.settingsFile);
    const moved = migrateSplit(dbDir);
    const raw = this.readSettings();
    this.settings = merge(DEFAULTS, raw);
    this.db = openManagerDb(dbDir);
    if (moved) log(this.db, 'manager', true, 'Daten des Peon Broker Client nach broker-client.db umgezogen');
    // Bis 0.6.0 gab es keine Module: Wer schon Einstellungen oder Daten hatte, nutzt den Broker Client weiter
    const on = new Set(enable || []);
    if (raw.modules === undefined && (existed || moved)) on.add('broker-client');
    if (on.size) {
      const mods = { ...this.settings.modules };
      for (const k of on) if (modules.find(k)) mods[k] = { enabled: true };
      this.saveSettings({ modules: mods });
    }
    this.broker = this.isActive('broker-client') ? new BrokerClient(this) : null;
  }

  readSettings() {
    try { return JSON.parse(fs.readFileSync(this.settingsFile, 'utf8')) || {}; } catch { return {}; }
  }

  saveSettings(patch) {
    const next = merge(DEFAULTS, { ...this.settings, ...patch });
    fs.mkdirSync(this.dbDir, { recursive: true });
    fs.writeFileSync(this.settingsFile + '.neu', JSON.stringify(next, null, 2), 'utf8');
    fs.renameSync(this.settingsFile + '.neu', this.settingsFile);
    this.settings = next;
    return next;
  }

  meta(key, value) {
    if (value === undefined) {
      const r = this.db.prepare('SELECT value FROM meta WHERE key = ?').get(key);
      return r ? JSON.parse(r.value) : null;
    }
    this.db.prepare('INSERT INTO meta(key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value').run(key, JSON.stringify(value));
    return value;
  }

  // ---------- Manager-Module ----------
  isActive(key) { return modules.enabled(this.settings, key); }

  // Kanaele fuer Data.lua aus den aktiven Modulen
  channels() { return modules.channels(this.settings); }

  addonPresent(name) {
    return fs.existsSync(path.join(this.settings.wowDir, 'Interface', 'AddOns', name, name + '.toc'));
  }

  moduleList() {
    return modules.MODULES.map((m) => {
      const file = path.join(this.dbDir, m.dataFile);
      return {
        key: m.key, title: m.title, desc: m.desc, needs: m.needs, channels: m.channels, views: m.views,
        enabled: this.isActive(m.key),
        dataBytes: fileSize(file), hasData: fs.existsSync(file),
        addons: m.needs.map((n) => ({ name: n, present: this.addonPresent(n) })),
      };
    });
  }

  // "Installieren" schaltet ein, "Entfernen" schaltet aus. Die Daten bleiben beim Entfernen liegen.
  setModule(key, on) {
    const m = modules.find(key);
    if (!m) throw new Error(`Unbekanntes Modul: ${key}`);
    on = !!on;
    if (this.isActive(key) === on) return this.moduleList();
    this.saveSettings({ modules: { ...this.settings.modules, [key]: { enabled: on } } });
    if (key === 'broker-client') {
      if (on) {
        this.broker = new BrokerClient(this);
        this.broker.meta('ack', null);   // Data.lua beim naechsten Einlesen neu schreiben (Kanal wieder frei)
      } else if (this.broker) {
        this.broker.close();
        this.broker = null;
      }
    }
    log(this.db, 'module', true, `${m.title} ${on ? 'installiert' : 'entfernt'}`);
    this.syncBridge(true);
    return this.moduleList();
  }

  // Daten eines ausgeschalteten Moduls loeschen (eigener Knopf in der Ansicht Module)
  clearModuleData(key) {
    const m = modules.find(key);
    if (!m) throw new Error(`Unbekanntes Modul: ${key}`);
    if (this.isActive(key)) throw new Error(`${m.title} ist noch installiert. Erst entfernen, dann die Daten löschen.`);
    const bytes = fileSize(path.join(this.dbDir, m.dataFile));
    removeDb(path.join(this.dbDir, m.dataFile));
    log(this.db, 'module', true, `Daten von ${m.title} gelöscht (${Math.round(bytes / 1024)} KB)`);
    return this.moduleList();
  }

  // Data.lua fuer die Bridge, wenn kein Modul sie schreibt: keine Kanaele frei, damit die Bridge nichts aufzeichnet.
  // Mit aktivem Broker Client schreibt das Modul selbst (beim Einlesen). force: auch wenn schon geschrieben.
  syncBridge(force = false) {
    if (this.broker) { this.meta('bridge', 'modul'); return null; }
    if (!force && this.meta('bridge') === 'leer') return null;
    const wow = this.settings.wowDir;
    if (!fs.existsSync(path.join(addonDir(wow), 'Peon_Bridge.toc'))) return null;   // Bridge nicht installiert
    try {
      const w = writeData(wow, { ack: [], markets: {}, channels: this.channels(), version: this.version, now: this.now() });
      this.meta('bridge', 'leer');
      return w;
    } catch (e) {
      log(this.db, 'bridge', false, `Data.lua: ${e.message}`);
      return null;
    }
  }

  // ---------- Daten fuer die Oberflaeche ----------
  overview() {
    const base = {
      version: this.version,
      now: this.now(),
      dbDir: this.dbDir,
      wowDir: this.settings.wowDir,
      wowOk: fs.existsSync(path.join(addonDir(this.settings.wowDir), 'Peon_Bridge.toc')),
      modules: this.moduleList(),
      views: modules.views(this.settings),
    };
    const own = this.db.prepare('SELECT t, kind, ok, text FROM log ORDER BY id DESC LIMIT 12').all();
    if (!this.broker) {
      return { ...base, dbSize: fileSize(this.db.file), markets: [], game: { files: [], lastImport: null }, back: null,
        ahledger: null, log: own, brokerHist: null };
    }
    const b = this.broker.overview();
    const merged = [...b.log, ...own].sort((x, y) => y.t - x.t).slice(0, 12);
    return { ...base, ...b, log: merged };
  }

  close() {
    if (this.broker) this.broker.close();
    try { this.db.close(); } catch { /* schon zu */ }
  }
}

module.exports = { Service, DEFAULTS, merge };
