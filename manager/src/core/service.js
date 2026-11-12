'use strict';
// Peon Manager - Manager: Einstellungen, Manager-Module (Peon_GitHub_Design.md 5.2), eigene Datenbank peon.db
// (Zustand, Protokoll) und die Kanaele fuer Peon_Bridge. Die Module selbst stecken in eigenen Dateien
// (broker-client.js) und haben eigene Datenbanken. Ohne Electron nutzbar (Tests), main.js ruft nur diese Funktionen auf.

const fs = require('node:fs');
const path = require('node:path');
const { openManagerDb, migrateSplit, fileSize, removeDb, log } = require('./db');
const { writeData, addonDir } = require('./datalua');
const modules = require('./modules');
const backup = require('./backup');
const { BrokerClient } = require('./broker-client');
const { AddonManager } = require('./addons');
const { ReportStore } = require('./reports');

const DEFAULTS = {
  wowDir: 'C:\\Program Files (x86)\\World of Warcraft\\_forever_',   // ueblicher Ort von Battle.net, in den Einstellungen aenderbar
  modules: { 'broker-client': { enabled: false } },                  // Manager-Module, standardmaessig aus
  addons: { channel: 'stable' },                                     // Kanal der Addons: stable oder test
  setup: { done: false },                                            // erster Start (Vorschlag in der Ansicht Module)
  blizzard: { houses: {} },   // gewaehlte Auktionshaeuser: 'eu-111' -> { market, how }
  autostart: false,
  updateWindow: true,     // Update-Fenster beim Programmstart zeigen, wenn es Neues gibt
  updateCheckMin: 10,     // ab 0.20.0: so viele Minuten zwischen zwei Suchen nach Updates (UPDATE_CHECK_CHOICES)
  updateNotify: true,     // ab 0.20.0: Meldung von Windows, wenn die Suche etwas Neues findet
  shopNotify: true,       // Einkaufsliste: Meldung von Windows, wenn ein Angebot unter dem Hoechstpreis liegt
  market: '',             // gewaehlter Markt
  itemColumns: [],        // Spalten unter Gegenstaende, leer = Standard
  checklistHidden: false, // Einrichtungsliste ausgeblendet
  theme: 'dark',
  keepDays: 14,           // Momentaufnahmen vollstaendig aufheben (Tage, 0 = unbegrenzt)
  retentionV: 2,          // Stand der Standardwerte der Aufbewahrung (Umstellung im Konstruktor)
  chances: { days: 7, minProfit: 1000, quality: 0 },   // Ansicht Chancen: Zeitraum, Mindestgewinn je Tag (Kupfer), Qualitaet ab
  hourDays: 60,           // danach Stundenwerte bis zu so vielen Tagen, dann Tageswerte (mindestens 14, retention.js)
};

// Abstand der Suche nach Updates in Minuten: nur diese Werte, sonst der Standard
const UPDATE_CHECK_CHOICES = [10, 30, 60, 360];
function updateCheckMs(min) {
  return (UPDATE_CHECK_CHOICES.includes(min) ? min : DEFAULTS.updateCheckMin) * 60 * 1000;
}

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
  // releases: { releaseBase, apiBase, testHook } andere Quelle fuer Addons (Tests, nachgebautes Release)
  // brokerFactory (ab 0.23.0): baut das Modul Peon Broker Client. Im Programm laeuft es im Arbeitsprozess (broker-remote.js),
  // dann liefern seine Aufrufe Promises. Standard (Tests): direkt hier.
  constructor({ dbDir, version = '0.0.0', fetchImpl, now, enable, releases, brokerFactory } = {}) {
    this.dbDir = dbDir;
    this.brokerFactory = brokerFactory || ((host) => new BrokerClient(host));
    this.version = version;
    this.fetchImpl = fetchImpl || ((...a) => fetch(...a));
    this.now = now || (() => Math.floor(Date.now() / 1000));
    this.settingsFile = path.join(dbDir, 'settings.json');
    const existed = fs.existsSync(this.settingsFile);
    this.restored = backup.applyPending(dbDir);   // eingespielte Sicherung, vor dem Oeffnen der Datenbanken
    const moved = migrateSplit(dbDir);
    const raw = this.readSettings();
    delete raw.ahledger; delete raw.marketMap;   // AHledger ist entfernt
    delete raw.watchNotify;                      // Merkliste ist entfernt
    this.settings = merge(DEFAULTS, raw);
    this.db = openManagerDb(dbDir);
    if (moved) log(this.db, 'manager', true, 'Daten des Peon Broker Client nach broker-client.db umgezogen');
    if (this.restored) log(this.db, 'sicherung', this.restored.ok, this.restored.ok ? 'Sicherung eingespielt, der bisherige Stand liegt im Datenordner unter vor-Wiederherstellung' : `Sicherung nicht eingespielt: ${this.restored.error}`);
    // Bis 0.6.0 gab es keine Module: Wer schon Einstellungen oder Daten hatte, nutzt den Broker Client weiter
    const on = new Set(enable || []);
    if (raw.modules === undefined && (existed || moved)) on.add('broker-client');
    if (on.size) {
      const mods = { ...this.settings.modules };
      for (const k of on) if (modules.find(k)) mods[k] = { enabled: true };
      this.saveSettings({ modules: mods });
    }
    // Wer schon Einstellungen hatte, sieht den Vorschlag fuer den ersten Start nicht
    if (raw.setup === undefined && existed) this.saveSettings({ setup: { done: true } });
    // Bis 0.14.0 waren es fest 365 Tage Stundenwerte, ohne Einstellung dafuer: also von niemandem gewaehlt und einmalig neu.
    // keepDays liess sich schon einstellen und bleibt.
    if (raw.retentionV === undefined && existed) {
      this.saveSettings(raw.hourDays === 365 ? { hourDays: DEFAULTS.hourDays, retentionV: DEFAULTS.retentionV } : { retentionV: DEFAULTS.retentionV });
    }
    this.reports = new ReportStore(this);
    this.broker = this.isActive('broker-client') ? this.brokerFactory(this) : null;
    this.addons = new AddonManager(this, releases || {});
  }

  readSettings() {
    // Windows-Editoren setzen gern eine BOM-Markierung an den Anfang, die Datei gilt trotzdem
    try { return JSON.parse(fs.readFileSync(this.settingsFile, 'utf8').replace(/^﻿/, '')) || {}; } catch { return {}; }
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
        key: m.key, title: m.title, navTitle: m.navTitle, desc: m.desc, needs: m.needs, channels: m.channels, views: m.views,
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
        this.broker = this.brokerFactory(this);
        quiet(this.broker.meta('ack', null));   // Data.lua beim naechsten Einlesen neu schreiben (Kanal wieder frei)
      } else if (this.broker) {
        quiet(this.broker.close());
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
      const w = writeData(wow, { ack: [], markets: {}, channels: this.channels(), version: this.version, now: this.now(), ...this.reports.marks() });
      this.meta('bridge', 'leer');
      return w;
    } catch (e) {
      log(this.db, 'bridge', false, `Data.lua: ${e.message}`);
      return null;
    }
  }

  logManager(kind, ok, text) { log(this.db, kind, ok, text); }

  // Peon_Bridge wurde neu installiert oder aktualisiert: Data.lua passend zu den Modulen schreiben
  bridgeInstalled() {
    if (this.broker) {
      quiet(this.broker.meta('ack', null));
      quiet(this.broker.importGame());
    } else {
      this.syncBridge(true);
    }
  }

  // Zustand fuer die Ansicht Module, Gruppe Addons
  addonState(wowRunning = false) {
    const a = this.addons;
    const m = a.manifest;
    let tooOld = null;
    try { a.checkManagerVersion(); } catch (e) { tooOld = e.message; }
    const items = a.list();
    return {
      channel: this.settings.addons.channel,
      check: this.meta('addonCheck'),
      release: m ? m.release : null,
      items,
      updates: items.filter((x) => x.status === 'update').length,
      missing: items.filter((x) => x.status === 'missing').length,
      busy: a.busy,
      wowRunning: !!wowRunning,
      wowValid: a.wowValid(),
      wowDir: this.settings.wowDir,
      // Der Vorschlag fuer den ersten Start entfaellt, sobald Peon da ist (auch von Hand oder per Junction)
      setup: { done: this.settings.setup.done || a.installed('Peon').present },
      tooOld,
    };
  }

  // Erster Start: gewaehlte Addons und Module installieren, danach kommt der Vorschlag nicht wieder
  async finishSetup({ addons = [], modules: mods = [] } = {}) {
    const needs = [];
    for (const k of mods) {
      const m = modules.find(k);
      if (!m) throw new Error(`Unbekanntes Modul: ${k}`);
      needs.push(...m.needs);
    }
    const res = await this.addons.install([...new Set([...addons, ...needs])]);
    for (const k of mods) this.setModule(k, true);
    if (!res.failed.length) this.saveSettings({ setup: { done: true } });
    return res;
  }

  // ---------- Datensicherung ----------
  async createBackup(target) {
    const open = { 'peon.db': this.db };
    if (this.broker) open['broker-client.db'] = (to) => this.broker.backupTo(to);
    const r = await backup.create({ dbDir: this.dbDir, open, target, version: this.version, now: this.now() });
    log(this.db, 'sicherung', true, `Sicherung angelegt (${Math.round(r.bytes / 1024 / 1024)} MB)`);
    return r;
  }

  // ---------- Update-Fenster ----------
  // Inhalt des Fensters. updater = Zustand des Selbst-Updates, ready = die erste Suche seit dem Start ist durch.
  // popup: beim Programmstart zeigen? Nur wenn etwas dabei ist, das dort noch nicht stand.
  updateInfo(updater = { status: 'off' }, ready = true) {
    const a = this.addons;
    const addons = a.newsEntries();
    let manager = null;
    const u = a.managerUpdate();
    if (updater.status !== 'off' && (u || updater.status === 'ready')) {
      const version = updater.status === 'ready' && updater.version ? updater.version : u.version;
      manager = { kind: 'manager', name: 'Peon Manager', title: 'Peon Manager', version, installed: this.version, news: a.managerNews(), release: a.managerRelease(),
        status: updater.status, percent: updater.percent || 0, error: updater.error || null };
    }
    const keys = [...(manager ? [`Peon Manager@${manager.version}`] : []), ...addons.map((x) => `${x.name}@${x.version}`)];
    const shown = this.meta('updatesShown') || [];
    const setupDone = this.settings.setup.done || a.installed('Peon').present;
    return { manager, addons, count: keys.length, ready, popup: !!(ready && setupDone && this.settings.updateWindow && keys.some((k) => !shown.includes(k))) };
  }

  // Das Fenster wurde geschlossen: Was drin stand, kommt beim naechsten Start nicht wieder von selbst
  updatesShown(updater) {
    const info = this.updateInfo(updater);
    this.meta('updatesShown', [...(info.manager ? [`Peon Manager@${info.manager.version}`] : []), ...info.addons.map((x) => `${x.name}@${x.version}`)]);
    this.addons.markSeen();
  }

  // ---------- Daten fuer die Oberflaeche ----------
  overview() { return this.overviewFrom(this.broker && this.broker.overview(), this.broker && this.broker.get('pruning'), this.broker && this.broker.sync()); }

  // Wie overview, fuer das Modul im Arbeitsprozess (ab 0.23.0)
  async overviewAsync() {
    if (!this.broker) return this.overviewFrom(null);
    const [b, pruning, sync] = await Promise.all([this.broker.overview(), this.broker.get('pruning'), this.broker.sync()]);
    return this.overviewFrom(b, pruning, sync);
  }

  overviewFrom(b, pruning, sync) {
    this.reports.scan();
    const base = {
      reportCount: this.reports.count(),
      version: this.version,
      now: this.now(),
      dbDir: this.dbDir,
      wowDir: this.settings.wowDir,
      wowOk: fs.existsSync(path.join(addonDir(this.settings.wowDir), 'Peon_Bridge.toc')),
      modules: this.moduleList(),
      views: modules.views(this.settings),
      addonUpdates: this.addons.updates().length,
    };
    const own = this.db.prepare('SELECT t, kind, ok, text FROM log ORDER BY id DESC LIMIT 40').all();
    if (!b) {
      return { ...base, dbSize: fileSize(this.db.file), markets: [], game: { files: [], lastImport: null }, back: null,
        log: own, brokerHist: null };
    }
    const merged = [...b.log, ...own].sort((x, y) => y.t - x.t).slice(0, 40);
    return { ...base, ...b, log: merged, pruning: !!pruning, sync };
  }

  close() {
    if (this.broker) quiet(this.broker.close());
    try { this.db.close(); } catch { /* schon zu */ }
  }
}

// Aufruf, dessen Ergebnis niemand braucht: Fehler aus dem Arbeitsprozess nicht unbehandelt lassen
function quiet(r) { if (r && typeof r.catch === 'function') r.catch(() => {}); return r; }

module.exports = { Service, DEFAULTS, merge, updateCheckMs, UPDATE_CHECK_CHOICES };
