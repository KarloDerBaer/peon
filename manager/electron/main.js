'use strict';
// Peon Manager - Hauptteil (Electron): Fenster, Symbol im Infobereich, Manager-Module.
// Dateiwaechter, Zeitplan fuer die Blizzard-API und Aufraeumen laufen nur, wenn das Modul Peon Broker Client installiert ist.
// Rechnen und Speichern macht src/core (ohne Electron testbar).
// Sicherheit: Die Oberflaeche hat keinen Zugriff auf Node, nur auf die feste Befehlsliste aus preload.js,
// laedt keine fremden Seiten, alle Netzzugriffe macht dieser Teil.

const path = require('node:path');
const fs = require('node:fs');
const { execFile } = require('node:child_process');
const { app, BrowserWindow, Tray, Menu, ipcMain, nativeImage, shell, dialog, session, safeStorage, Notification } = require('electron');
const { Service, updateCheckMs } = require('../src/core/service');
const { BrokerRemote } = require('../src/core/broker-remote');
const { createUpdater } = require('./updater');
const backup = require('../src/core/backup');
const { money: shopMoney } = require('../src/core/shopping');
const blizzard = require('../src/core/blizzard');
const { BlizzardWatch } = require('../src/core/blizzard-watch');
const { findWowDirs, REPO_URL } = require('../src/core/addons');
const modules = require('../src/core/modules');

process.removeAllListeners('warning');   // Hinweis "SQLite is experimental" nicht anzeigen

const ROOT = path.join(__dirname, '..');
const DEV = !app.isPackaged;
const HIDDEN = process.argv.includes('--hidden');
// Addons und Manager: beim Start und dann im eingestellten Abstand (updateCheckMin, Standard 10 Minuten) nach Updates suchen,
// installiert wird nur per Klick
// Beobachter der Blizzard-API, nur in der Testfassung: 1 = alle 10 Minuten, sonst Abstand in Millisekunden
const WATCH_MS = process.env.PEON_MANAGER_BLIZZARD_WATCH ? (Number(process.env.PEON_MANAGER_BLIZZARD_WATCH) > 1 ? Number(process.env.PEON_MANAGER_BLIZZARD_WATCH) : 10 * 60 * 1000) : 0;

// Ordner mit Runtime und DB nebeneinander: wird von Hand getauscht, kein Selbst-Update
const SIDE_DB = path.join(path.dirname(process.execPath), '..', 'DB');
const BESIDE = !DEV && fs.existsSync(SIDE_DB);

function dataDir() {
  if (process.env.PEON_MANAGER_DB) return process.env.PEON_MANAGER_DB;
  if (DEV) return path.join(ROOT, 'data');
  if (BESIDE) return SIDE_DB;                            // <Programmordner>\Runtime\PeonManager.exe -> <Programmordner>\DB
  return path.join(app.getPath('userData'), 'Daten');    // installiert: %APPDATA%\Peon Manager\Daten
}

app.setAppUserModelId('de.peon.manager');   // sonst zeigt Windows keine Meldungen

if (!app.requestSingleInstanceLock()) {
  app.quit();
} else {
  let win = null, tray = null, svc = null, quitting = false, updater = null, blizzardAccess = null, blizzardWatch = null;
  const watchers = [];
  let lastSeen = new Map();
  let pending = null;
  let busy = false;
  let addonsChecked = false;   // die erste Suche nach Updates seit dem Start ist durch (Update-Fenster)

  const icon = nativeImage.createFromPath(path.join(ROOT, 'electron', 'icon.png'));

  function send(ch, payload) { if (win && !win.isDestroyed()) win.webContents.send(ch, payload); }

  function showWindow() {
    if (!win || win.isDestroyed()) createWindow();
    win.show();
    win.focus();
  }

  function createWindow() {
    win = new BrowserWindow({
      width: 1280, height: 820, minWidth: 980, minHeight: 640,
      backgroundColor: svc.settings.theme === 'light' ? '#f3f5f1' : '#0e110f',
      title: 'Peon Manager', icon, show: false, autoHideMenuBar: true,
      webPreferences: { preload: path.join(__dirname, 'preload.js'), contextIsolation: true, sandbox: true, nodeIntegration: false, spellcheck: false },
    });
    win.removeMenu();
    win.loadFile(path.join(ROOT, 'dist', 'index.html'));
    win.once('ready-to-show', () => { if (!HIDDEN || win.__userOpened) win.show(); });
    win.webContents.setWindowOpenHandler(() => ({ action: 'deny' }));
    win.webContents.on('will-navigate', (e) => e.preventDefault());
    win.on('close', (e) => { if (!quitting) { e.preventDefault(); win.hide(); } });
  }

  function createTray() {
    tray = new Tray(icon.resize({ width: 16, height: 16 }));
    tray.setToolTip('Peon Manager');
    updateTray();
    tray.on('click', showWindow);
  }

  // Menue im Infobereich
  function updateTray() {
    if (!tray) return;
    const items = [{ label: 'Fenster öffnen', click: showWindow }];
    items.push({ type: 'separator' }, { label: 'Beenden', click: () => { quitting = true; app.quit(); } });
    tray.setContextMenu(Menu.buildFromTemplate(items));
  }

  // Einkaufsliste: Meldung von Windows, wenn ein Angebot unter dem Hoechstpreis liegt. Ein Klick oeffnet den Gegenstand.
  async function notifyShop() {
    if (!svc.broker) return;
    const hits = await svc.broker.shopCheck();
    if (!hits.length || !svc.settings.shopNotify || !Notification.isSupported()) return;
    for (const h of hits.slice(0, 5)) {
      const n = new Notification({ title: 'Peon Manager: Einkaufsliste', body: `${h.name} gibt es ab ${shopMoney(h.min)}, dein Höchstpreis ist ${shopMoney(h.limit)} (${h.label}).`, icon });
      n.on('click', () => { showWindow(); send('openItem', { market: h.market, key: h.key }); });
      n.show();
    }
    if (hits.length > 5) new Notification({ title: 'Peon Manager: Einkaufsliste', body: `Dazu ${hits.length - 5} weitere auf deinen Listen.`, icon }).show();
  }

  // Beobachten (ab 0.32.0): Meldung von Windows, wenn ein Preis eine Grenze mit Glocke erreicht.
  // Ein Klick waehlt das Konto und oeffnet die Seite Beobachten mit dieser Zeile.
  async function notifyWatch() {
    if (!svc.broker) return;
    const hits = await svc.broker.watchCheck();
    if (!hits.length || !svc.settings.watchNotify || !Notification.isSupported()) return;
    for (const h of hits.slice(0, 5)) {
      const body = h.which === 'buy'
        ? `${h.name} gibt es ab ${shopMoney(h.price)}, Kaufen bis ist ${shopMoney(h.limit)} (${h.label}).`
        : `${h.name} steht bei ${shopMoney(h.price)}, dein Zielpreis ist ${shopMoney(h.limit)} (${h.label}).`;
      const n = new Notification({ title: h.which === 'buy' ? 'Peon Manager: Kaufen' : 'Peon Manager: Verkaufen', body: h.acctName ? `${body} Konto ${h.acctName}.` : body, icon });
      n.on('click', async () => { showWindow(); if (h.acct) await svc.broker.selectAccount(h.acct); send('openWatch', { market: h.market, key: h.key }); });
      n.show();
    }
    if (hits.length > 5) new Notification({ title: 'Peon Manager: Beobachten', body: `Dazu ${hits.length - 5} weitere Grenzen erreicht.`, icon }).show();
  }

  // Laeuft WoW? Daraus folgt der Hinweis in der Kopfleiste
  async function watchGame() {
    if (!svc.broker) return;
    if (await svc.broker.noteGame(await wowRunning())) send('changed', { what: 'spielstand' });
  }

  // ---------- Einlesen ----------
  // Ab 0.23.0 im Arbeitsprozess: das Fenster bleibt bedienbar, waehrend gerechnet wird
  async function runImport(why) {
    if (!svc.broker) { svc.syncBridge(); return { inactive: true }; }
    if (busy) { pending = pending || setTimeout(() => { pending = null; runImport(why); }, 1000); return null; }
    busy = true;
    try {
      const r = await svc.broker.importGame();
      for (const f of r.files) lastSeen.set(f.file, f.mtime);
      for (const f of require('../src/core/broker').findFiles(svc.settings.wowDir)) {
        try { lastSeen.set(f.file, Math.floor(fs.statSync(f.file).mtimeMs / 1000)); } catch { /* weg */ }
      }
      if (r.imported > 0 && tray) tray.setToolTip(`Peon Manager: ${r.imported} neue Momentaufnahmen`);
      notifyShop().catch(() => {});
      notifyWatch().catch(() => {});
      send('changed', { what: 'spiel', why, imported: r.imported });
      return r;
    } catch (e) {
      send('changed', { what: 'fehler', text: e.message });
      return { error: e.message };
    } finally { busy = false; }
  }

  // Das Spiel schreibt die Datei in einem Zug. Erst einlesen, wenn Groesse und Zeit 2 Sek. gleich bleiben.
  const stable = new Map();
  function onFileEvent(file) {
    const check = () => {
      let st;
      try { st = fs.statSync(file); } catch { return; }
      const sig = `${st.size}:${st.mtimeMs}`;
      const prev = stable.get(file);
      if (prev && prev.sig === sig) { stable.delete(file); runImport('Datei geändert'); return; }
      if (prev) clearTimeout(prev.timer);
      stable.set(file, { sig, timer: setTimeout(check, 2000) });
    };
    const prev = stable.get(file);
    if (prev) clearTimeout(prev.timer);
    stable.set(file, { sig: null, timer: setTimeout(check, 2000) });
  }

  function setupWatch() {
    while (watchers.length) { try { watchers.pop().close(); } catch { /* egal */ } }
    if (!svc.broker) return;
    const base = path.join(svc.settings.wowDir, 'WTF', 'Account');
    try {
      watchers.push(fs.watch(base, { recursive: true }, (ev, name) => {
        const n = name ? String(name).toLowerCase() : '';
        if (n.endsWith('peon_bridge.lua') || n.endsWith('peon_broker.lua')) onFileEvent(path.join(base, String(name)));
      }));
    } catch { /* Ordner fehlt: Abfrage jede Minute reicht */ }
  }

  // Rueckfall: jede Minute nachsehen
  function poll() {
    if (!svc.broker) return;
    const files = [...require('../src/core/game').findFiles(svc.settings.wowDir), ...require('../src/core/broker').findFiles(svc.settings.wowDir)];
    for (const f of files) {
      let m = 0;
      try { m = Math.floor(fs.statSync(f.file).mtimeMs / 1000); } catch { continue; }
      if (lastSeen.get(f.file) !== m) { onFileEvent(f.file); }
    }
  }

  // ---------- Addons ----------
  // Laeuft WoW Forever? (Programmname Wow.exe, Peon_GitHub_Design.md 5.4)
  function wowRunning() {
    return new Promise((resolve) => {
      execFile('tasklist', ['/FI', 'IMAGENAME eq Wow.exe', '/NH'], { windowsHide: true, timeout: 5000 }, (err, out) => {
        resolve(!err && /^wow\.exe\s/im.test(String(out)));
      });
    });
  }

  // Ort von WoW aus der Registrierung (Eintrag von Battle.net), leer wenn nicht vorhanden
  function registryPaths() {
    const keys = ['HKLM\\SOFTWARE\\WOW6432Node\\Blizzard Entertainment\\World of Warcraft', 'HKLM\\SOFTWARE\\Blizzard Entertainment\\World of Warcraft'];
    return Promise.all(keys.map((k) => new Promise((resolve) => {
      execFile('reg', ['query', k, '/v', 'InstallPath'], { windowsHide: true, timeout: 5000 }, (err, out) => {
        const m = !err && /InstallPath\s+REG_\w+\s+(.+)/i.exec(String(out));
        resolve(m ? m[1].trim() : null);
      });
    }))).then((r) => r.filter(Boolean));
  }

  async function findWow() { return findWowDirs({ installPaths: await registryPaths() }); }

  async function addonState() { return { ...svc.addonState(await wowRunning()), manager: { version: svc.version, ...updater.state() } }; }

  let lastAddonCheck = 0;
  async function checkAddons() {
    lastAddonCheck = Date.now();
    const r = await svc.addons.check();
    updater.check();
    const first = !addonsChecked;
    addonsChecked = true;
    send('changed', { what: 'addons' });
    notifyUpdates(first);
    return r;
  }

  // Meldung von Windows, wenn die Suche etwas Neues findet (ab 0.20.0, abschaltbar mit updateNotify). Jede Version wird
  // nur einmal gemeldet. Zeigt der Start das Update-Fenster ohnehin, meldet die erste Suche nichts. Der Manager selbst
  // wird erst gemeldet, wenn er geladen ist und neu starten kann. Ein Klick oeffnet das Update-Fenster.
  const notified = new Set();
  function notifyUpdates(first = false) {
    let info;
    try { info = svc.updateInfo(updater.state(), addonsChecked); } catch { return; }
    const list = [];
    if (info.manager && info.manager.status === 'ready') list.push({ key: `Peon Manager@${info.manager.version}`, text: `Peon Manager ${info.manager.version}` });
    for (const a of info.addons) list.push({ key: `${a.name}@${a.version}`, text: `${a.title} ${a.version}` });
    const fresh = list.filter((x) => !notified.has(x.key));
    for (const x of fresh) notified.add(x.key);
    if (!fresh.length || (first && info.popup) || !svc.settings.updateNotify || !Notification.isSupported()) return;
    const n = new Notification({ title: 'Peon Manager: Neues für Peon', body: `${fresh.map((x) => x.text).join(', ')}. Klick öffnet das Update-Fenster.`, icon });
    n.on('click', () => { showWindow(); send('openUpdates'); });
    n.show();
  }

  // Erster Start: stimmt der WoW-Ordner nicht, den gefundenen eintragen
  async function firstStart() {
    if (svc.settings.setup.done || svc.addons.wowValid()) return;
    const found = await findWow();
    if (found.length) { svc.saveSettings({ wowDir: found[0] }); send('changed', { what: 'settings' }); }
  }

  function afterInstall(res) {
    // Bridge neu: Bei aktivem Broker Client hat der Manager Data.lua schon geschrieben (bridgeInstalled)
    send('changed', { what: 'addons' });
    return res;
  }

  const names = (list) => (Array.isArray(list) ? list.map(String) : []);

  // ---------- Blizzard-API ----------
  // Pruefabruf mit dem gespeicherten Zugang. Client-ID und Secret bleiben in diesem Teil, die Oberflaeche sieht sie nie.
  function blizzardOptions() {
    const test = process.env.PEON_MANAGER_BLIZZARD;   // nachgebautes Blizzard (nur zum Testen)
    return { fetchImpl: svc.fetchImpl, ...(test ? { oauthBase: test, apiBase: test } : {}) };
  }

  function blizzardState() {
    return { ...blizzardAccess.state(), watch: WATCH_MS ? (blizzardWatch ? blizzardWatch.summary() : { checks: 0, stands: 0, gaps: [] }) : null };
  }

  // Abfragen mit dem gespeicherten Zugang, der Client merkt sich seine Anmeldung
  let apiClient = null;
  function blizzardClient() {
    const c = blizzardAccess.load();
    if (!c) { apiClient = null; return null; }
    if (!apiClient || apiClient.clientId !== c.clientId || apiClient.clientSecret !== c.clientSecret || apiClient.region !== c.region) {
      apiClient = new blizzard.BlizzardClient(c, blizzardOptions());
    }
    return apiClient;
  }

  // Gewaehlte Auktionshaeuser abrufen, wenn sie dran sind. Neue Staende laufen wie Scans durch die Auswertung.
  async function runBlizzard(force = false) {
    if (!svc.broker) return null;
    const client = blizzardClient();
    if (!client) return null;
    const r = await svc.broker.api.tick(client, { force });
    if (r.imported) runImport('Blizzard-API');
    else if (r.checked) send('changed', { what: 'blizzard' });
    return r;
  }

  async function blizzardHouses() {
    const client = svc.broker ? blizzardClient() : null;
    return client ? svc.broker.api.view(client) : { saved: !!blizzardAccess.load(), houses: [], known: [] };
  }

  async function checkBlizzard() {
    const c = blizzardAccess.load();
    if (!c) throw new Error('Bitte zuerst den Zugang speichern.');
    const report = await blizzard.probe(c, blizzardOptions());
    blizzardAccess.saveReport(report);
    svc.logManager('blizzard', report.result === 'auctions', `Prüfabruf ${c.region}: ${report.text}`);
    return blizzardState();
  }

  // Beobachter: ohne Zugang tut er nichts, ein neuer Zugang gilt ab dem naechsten Lauf
  async function watchBlizzard() {
    if (!WATCH_MS) return;
    const c = blizzardAccess.load();
    if (!c) { blizzardWatch = null; return; }
    if (!blizzardWatch || blizzardWatch.client.clientId !== c.clientId || blizzardWatch.client.region !== c.region) {
      blizzardWatch = new BlizzardWatch({ client: new blizzard.BlizzardClient(c, blizzardOptions()), dir: path.join(svc.dbDir, 'blizzard-beobachter'), log: (ok, text) => svc.logManager('blizzard', ok, text) });
    }
    await blizzardWatch.tick();
    send('changed', { what: 'blizzard' });
  }

  function applyAutostart() {
    if (DEV) return;
    try { app.setLoginItemSettings({ openAtLogin: !!svc.settings.autostart, args: ['--hidden'] }); } catch { /* egal */ }
  }

  // Aufbewahrung anwenden, ohne das Programm anzuhalten. Die Oberflaeche erfaehrt Anfang (pruning) und Ende.
  function pruneNow() {
    if (!svc.broker) return;
    const run = svc.broker.pruneInBackground();
    send('changed', { what: 'aufbewahrung' });
    run.catch(() => null).then(() => send('changed', { what: 'aufbewahrung' }));
  }

  // Ein Modul wurde ein- oder ausgeschaltet: Hintergrundaufgaben und Menue nachziehen
  function moduleChanged() {
    setupWatch();
    updateTray();
    if (svc.broker) { runImport('Modul installiert'); pruneNow(); }
    send('changed', { what: 'module' });
  }

  // ---------- Befehle fuer die Oberflaeche ----------
  function registerIpc() {
    ipcMain.handle('overview', () => svc.overviewAsync());
    ipcMain.handle('blizzardState', () => blizzardState());
    ipcMain.handle('blizzardSave', (_e, c) => { blizzardAccess.save(c); watchBlizzard().catch(() => {}); return blizzardState(); });
    ipcMain.handle('blizzardClear', () => { blizzardAccess.clear(); blizzardWatch = null; return blizzardState(); });
    ipcMain.handle('blizzardCheck', () => checkBlizzard());
    ipcMain.handle('blizzardHouses', () => blizzardHouses());
    ipcMain.handle('blizzardSetHouse', async (_e, house, on, name) => {
      const client = svc.broker && blizzardClient();
      if (!client) throw new Error('Bitte zuerst den Zugang speichern.');
      await svc.broker.api.setHouse(client.region, Number(house), !!on, name == null ? null : String(name));
      runBlizzard(false).catch(() => {});
      return blizzardHouses();
    });
    ipcMain.handle('blizzardSuggest', async () => {
      const client = svc.broker && blizzardClient();
      if (!client) throw new Error('Bitte zuerst den Zugang speichern.');
      const result = await svc.broker.api.suggest(client);
      runBlizzard(false).catch(() => {});
      return { result, view: await blizzardHouses() };
    });
    ipcMain.handle('blizzardFetch', async () => { const r = await runBlizzard(true); return { result: r, view: await blizzardHouses() }; });
    ipcMain.handle('reports', () => svc.reports.state());
    ipcMain.handle('reportAdd', (_e, f) => svc.reports.addFeedback(f));
    ipcMain.handle('reportUpdate', (_e, key, f) => svc.reports.updateFeedback(key, f));
    ipcMain.handle('reportDelete', (_e, key) => svc.reports.deleteFeedback(key));
    ipcMain.handle('errorNote', (_e, key, note) => svc.reports.setNote(key, note));
    ipcMain.handle('errorDelete', (_e, key) => svc.reports.deleteError(key));
    ipcMain.handle('reportsClear', () => svc.reports.deleteAll());
    ipcMain.handle('reportsSend', () => svc.reports.send());
    ipcMain.handle('settings', () => svc.settings);
    ipcMain.handle('items', (_e, market) => (svc.broker ? svc.broker.itemList(String(market)) : null));
    ipcMain.handle('item', (_e, market, key, range) => (svc.broker ? svc.broker.itemDetail(String(market), String(key), String(range || '30d')) : null));
    ipcMain.handle('itemInfo', (_e, key) => (svc.broker ? svc.broker.itemTip(String(key), blizzardClient()) : null));
    ipcMain.handle('chances', (_e, market, days) => (svc.broker ? svc.broker.chances(String(market), Number(days) || null) : null));
    ipcMain.handle('favorites', () => (svc.broker ? svc.broker.favorites() : []));
    ipcMain.handle('vendors', (_e, market) => (svc.broker ? svc.broker.vendorView(String(market)) : { rows: [], vendors: 0, offers: 0 }));
    ipcMain.handle('setFavorite', (_e, key, on) => svc.broker.setFavorite(String(key), !!on));
    // Konten (ab 0.29.0): Einkaufslisten und Beobachtung je WoW-Konto
    ipcMain.handle('accounts', () => (svc.broker ? svc.broker.accounts() : { list: [], waiting: [], selected: null }));
    ipcMain.handle('accountSelect', async (_e, id) => { const r = await svc.broker.selectAccount(String(id)); send('changed', { what: 'konto' }); return r; });
    ipcMain.handle('accountName', async (_e, id, name) => { const r = await svc.broker.nameAccount(String(id), String(name || '')); send('changed', { what: 'konto' }); return r; });
    // Seite Beobachten (ab 0.32.0)
    const watchChanged = async (r) => { const v = await r; notifyWatch().catch(() => {}); return v; };
    ipcMain.handle('watchView', (_e, market) => (svc.broker ? svc.broker.watchView(String(market)) : { rows: [] }));
    ipcMain.handle('watchSetBuy', (_e, key, kind, value) => watchChanged(svc.broker.setWatchBuy(String(key), kind || null, value == null ? null : Number(value))));
    ipcMain.handle('watchSetUp', (_e, key, value) => watchChanged(svc.broker.setWatchUp(String(key), value == null ? null : Number(value))));
    ipcMain.handle('watchSetBell', (_e, key, which, on) => watchChanged(svc.broker.setWatchBell(String(key), which || null, !!on)));
    // Abgleich nachvollziehen (ab 0.31.0): Protokoll, Geloeschtes, Wiederherstellen
    ipcMain.handle('syncLog', (_e, area, origin) => (svc.broker ? svc.broker.syncLog({ area: area || null, origin: origin || null }) : []));
    ipcMain.handle('syncTrash', (_e, area) => (svc.broker ? svc.broker.syncTrash({ area: area || null }) : []));
    ipcMain.handle('syncRestore', async (_e, id) => { const r = await svc.broker.restoreTrash(Number(id)); if (r && r.ok) send('changed', { what: 'wiederhergestellt' }); return r; });
    const shopChanged = async (r) => { const v = await r; send('changed', { what: 'einkaufsliste' }); return v; };
    ipcMain.handle('shopView', (_e, market) => (svc.broker ? svc.broker.shopView(String(market)) : { lists: [] }));
    ipcMain.handle('shopBuyable', (_e, market) => (svc.broker ? svc.broker.shopBuyable(String(market)) : []));
    ipcMain.handle('shopLists', (_e, key) => (svc.broker ? svc.broker.shopLists(key == null ? null : String(key)) : []));
    ipcMain.handle('shopNewList', (_e, name) => shopChanged(svc.broker.newShopList(name == null ? '' : String(name))));
    ipcMain.handle('shopDeleteList', (_e, id) => shopChanged(svc.broker.deleteShopList(id)));
    ipcMain.handle('shopUpdateList', (_e, id, patch) => shopChanged(svc.broker.updateShopList(id, patch || {})));
    ipcMain.handle('shopAdd', async (_e, id, key) => { const r = await svc.broker.addShopItem(id, key); notifyShop().catch(() => {}); return shopChanged(r); });
    ipcMain.handle('shopRemove', (_e, id, key) => shopChanged(svc.broker.removeShopItem(id, key)));
    ipcMain.handle('shopSet', async (_e, id, key, patch) => { const r = await svc.broker.setShopItem(id, key, patch || {}); notifyShop().catch(() => {}); return shopChanged(r); });
    ipcMain.handle('backupCreate', async () => {
      const r = await dialog.showOpenDialog(win, { title: 'Wohin soll die Sicherung?', properties: ['openDirectory', 'createDirectory'] });
      if (r.canceled || !r.filePaths[0]) return null;
      const res = await svc.createBackup(r.filePaths[0]);
      send('changed', { what: 'sicherung' });
      return res;
    });
    ipcMain.handle('backupPick', async () => {
      const r = await dialog.showOpenDialog(win, { title: 'Ordner der Sicherung wählen', properties: ['openDirectory'] });
      if (r.canceled || !r.filePaths[0]) return null;
      return { dir: r.filePaths[0], ...backup.inspect(r.filePaths[0]) };
    });
    ipcMain.handle('backupRestore', (_e, dir) => {
      backup.request(svc.dbDir, String(dir));
      quitting = true;
      app.relaunch();
      app.quit();
      return true;
    });
    ipcMain.handle('retention', (_e, keepDays, hourDays) => (svc.broker ? svc.broker.retention(keepDays == null ? null : Number(keepDays), hourDays == null ? null : Number(hourDays)) : null));
    // Manager-Module: Installieren schaltet ein, Entfernen schaltet aus, Daten loeschen nur ausgeschaltet
    ipcMain.handle('modules', () => svc.moduleList());
    ipcMain.handle('setModule', async (_e, key, on) => {
      // Installieren holt fehlende Addons des Moduls, wenn ein Release bekannt ist. Scheitert das, ist das Modul trotzdem an.
      let install = null;
      const m = modules.find(String(key));
      if (on && m && svc.addons.manifest) {
        const missing = m.needs.filter((n) => !svc.addons.installed(n).present);
        if (missing.length) { try { install = await svc.addons.install(missing); } catch (e) { install = { done: [], skipped: [], failed: missing.map((name) => ({ name, error: e.message })) }; } }
      }
      const list = svc.setModule(String(key), !!on);
      moduleChanged();
      return { list, install };
    });
    // Addons
    ipcMain.handle('addons', () => addonState());
    ipcMain.handle('checkAddons', () => checkAddons());
    ipcMain.handle('installAddons', async (_e, list) => afterInstall(await svc.addons.install(names(list))));
    ipcMain.handle('removeAddon', (_e, name) => { svc.addons.remove(String(name)); send('changed', { what: 'addons' }); return true; });
    ipcMain.handle('setAddonChannel', async (_e, channel) => {
      if (channel !== 'stable' && channel !== 'test') throw new Error('Unbekannter Kanal');
      svc.saveSettings({ addons: { ...svc.settings.addons, channel } });
      return checkAddons();
    });
    ipcMain.handle('installManagerUpdate', () => updater.install());
    ipcMain.handle('updateInfo', () => svc.updateInfo(updater.state(), addonsChecked));
    ipcMain.handle('updatesShown', () => { svc.updatesShown(updater.state()); send('changed', { what: 'addons' }); return true; });
    ipcMain.handle('findWow', () => findWow());
    ipcMain.handle('finishSetup', async (_e, plan) => {
      const res = await svc.finishSetup({ addons: names(plan && plan.addons), modules: names(plan && plan.modules) });
      moduleChanged();
      return res;
    });
    ipcMain.handle('clearModuleData', (_e, key) => {
      const list = svc.clearModuleData(String(key));
      send('changed', { what: 'module' });
      return list;
    });
    ipcMain.handle('saveSettings', (_e, patch) => {
      const before = svc.settings.wowDir, keepBefore = svc.settings.keepDays, hourBefore = svc.settings.hourDays;
      const s = svc.saveSettings(patch || {});
      if (s.wowDir !== before) { setupWatch(); runImport('Ordner geändert'); }
      if (s.keepDays !== keepBefore || s.hourDays !== hourBefore) pruneNow();
      applyAutostart();
      send('changed', { what: 'settings' });
      return s;
    });
    ipcMain.handle('pickFolder', async () => {
      const r = await dialog.showOpenDialog(win, { properties: ['openDirectory'], defaultPath: svc.settings.wowDir });
      return r.canceled ? null : r.filePaths[0];
    });
    ipcMain.handle('openFolder', (_e, which) => {
      const p = which === 'db' ? svc.dbDir : which === 'wow' ? svc.settings.wowDir : null;
      if (p) shell.openPath(p);
    });
    ipcMain.handle('openLink', (_e, url) => {
      if (typeof url !== 'string') return;
      const repo = url === REPO_URL || url.startsWith(`${REPO_URL}/`);
      if (repo || /^https:\/\/discord\.(gg|com)\//.test(url) || /^https:\/\/(develop|community\.developer)\.battle\.net\//.test(url)) shell.openExternal(url);
    });
  }

  app.whenReady().then(() => {
    // keine Woerterbuecher fuer die Rechtschreibpruefung aus dem Netz laden
    try { session.defaultSession.setSpellCheckerEnabled(false); session.defaultSession.setSpellCheckerLanguages([]); } catch { /* egal */ }
    // PEON_MANAGER_RELEASES: nachgebautes Release statt GitHub (nur zum Testen)
    const rel = process.env.PEON_MANAGER_RELEASES;
    // Modul Peon Broker Client im Arbeitsprozess (ab 0.23.0), Fehler dort landen im Protokoll
    const brokerFactory = (host) => new BrokerRemote(host, { onError: (e) => { try { host.logManager('manager', false, `Arbeitsprozess: ${e.message}`); } catch { /* egal */ } } });
    svc = new Service({ dbDir: dataDir(), version: app.getVersion(), releases: rel ? { releaseBase: rel, apiBase: `${rel}/api` } : undefined, brokerFactory });
    updater = createUpdater({ enabled: app.isPackaged && !BESIDE, svc, onChange: () => { send('changed', { what: 'update' }); if (updater && updater.state().status === 'ready') notifyUpdates(); }, beforeInstall: () => { quitting = true; } });
    blizzardAccess = new blizzard.BlizzardAccess({ keyFile: path.join(svc.dbDir, 'blizzard-zugang.dat'), reportFile: path.join(svc.dbDir, 'blizzard-pruefung.json'),
      encrypt: (s) => safeStorage.encryptString(s), decrypt: (b) => safeStorage.decryptString(b), available: () => safeStorage.isEncryptionAvailable() });
    registerIpc();
    createTray();
    createWindow();
    if (!HIDDEN) win.__userOpened = true;
    runImport('Start');
    pruneNow();
    setInterval(async () => {
      if (!svc.broker) return;
      const t = (await svc.broker.meta('pruneAt').catch(() => 0)) || 0;
      if (svc.now() - t > 86400) pruneNow();
    }, 60 * 60 * 1000);
    setupWatch();
    setInterval(poll, 60 * 1000);
    watchGame().catch(() => {});
    setInterval(() => watchGame().catch(() => {}), 30 * 1000);
    // Rueckmeldungen: gehoeren zu keinem Modul, einmal je Minute nach Neuem sehen (liest nur geaenderte Dateien)
    setInterval(() => { try { if (svc.reports.scan()) send('changed', { what: 'rueckmeldungen' }); } catch { /* steht im Protokoll */ } }, 60 * 1000);
    // Tageswechsel: Werte fuer Broker neu rechnen (Alter der Tage verschiebt sich), schreibt nur bei Aenderung
    setInterval(async () => {
      if (!svc.broker) return;
      const a = await svc.broker.meta('ack').catch(() => null);
      if (!a || a.day !== require('../src/core/broker').dayOf(svc.now())) runImport('Tageswechsel');
    }, 60 * 60 * 1000);
    applyAutostart();
    firstStart().catch(() => {}).then(() => checkAddons()).catch(() => {});
    // Jede Minute nachsehen, ob der eingestellte Abstand um ist. So gilt eine geaenderte Einstellung gleich.
    setInterval(() => {
      if (Date.now() - lastAddonCheck >= updateCheckMs(svc.settings.updateCheckMin)) checkAddons().catch(() => {});
    }, 60 * 1000);
    // Blizzard-API: einmal je Minute nachsehen, ob ein Haus dran ist. Abgefragt wird nur, wenn ein neuer Stand zu erwarten ist.
    runBlizzard().catch(() => {});
    setInterval(() => runBlizzard().catch(() => {}), 60 * 1000);
    if (WATCH_MS) {
      watchBlizzard().catch(() => {});
      setInterval(() => watchBlizzard().catch(() => {}), WATCH_MS);
    }
    // Selbsttest (nur fuer Tests): Bildschirmfoto und Uebersicht schreiben, dann beenden
    if (process.env.PEON_MANAGER_SELFTEST) {
      const out = process.env.PEON_MANAGER_SELFTEST;
      win.webContents.once('did-finish-load', () => setTimeout(async () => {
        try {
          // Addons installieren (PEON_MANAGER_SELFTEST_INSTALL = Namen mit Komma) und Ansicht Module zeigen
          let install = null;
          const wanted = process.env.PEON_MANAGER_SELFTEST_INSTALL;
          if (wanted) {
            install = await win.webContents.executeJavaScript(`(async () => { await window.peon.checkAddons(); return window.peon.installAddons(${JSON.stringify(wanted.split(','))}); })()`);
            fs.writeFileSync(path.join(out, 'install.json'), JSON.stringify({ install, state: await addonState() }, null, 1));
          }
          // Selbst-Update pruefen: warten, bis die neue Version geladen ist, dann ohne Neustart einspielen
          if (process.env.PEON_MANAGER_SELFTEST_UPDATE) {
            await checkAddons();
            for (let i = 0; i < 240 && !['ready', 'error'].includes(updater.state().status); i++) await new Promise((r) => setTimeout(r, 500));
            fs.writeFileSync(path.join(out, 'update.json'), JSON.stringify(updater.state()));
            if (updater.state().status === 'ready') { updater.install(false); return; }
          }
          // Pruefabruf ueber die Befehlsliste: PEON_MANAGER_SELFTEST_BLIZZARD = id:secret
          if (process.env.PEON_MANAGER_SELFTEST_BLIZZARD) {
            const [clientId, clientSecret] = process.env.PEON_MANAGER_SELFTEST_BLIZZARD.split(':');
            const result = await win.webContents.executeJavaScript(`(async () => { const saved = await window.peon.blizzardSave(${JSON.stringify({ clientId, clientSecret, region: 'eu' })}); return { saved, checked: await window.peon.blizzardCheck() }; })()`);
            fs.writeFileSync(path.join(out, 'blizzard.json'), JSON.stringify(result, null, 1));
          }
          // Blizzard-API: Vorschlag ueber die Befehlsliste, warten, bis der Abruf fertig ist (Zugang muss gespeichert sein)
          if (process.env.PEON_MANAGER_SELFTEST_SUGGEST) {
            const t0 = Date.now();
            const result = await win.webContents.executeJavaScript('window.peon.blizzardSuggest()');
            await new Promise((r) => setTimeout(r, 500));
            while (await svc.broker.get('api.busy')) await new Promise((r) => setTimeout(r, 500));
            fs.writeFileSync(path.join(out, 'suggest.json'), JSON.stringify({ result, ms: Date.now() - t0, view: await blizzardHouses() }, null, 1));
          }
          if (process.env.PEON_MANAGER_SELFTEST_VIEW) {
            await win.webContents.executeJavaScript(`[...document.querySelectorAll('button.nav')].find((b) => b.textContent.trim().startsWith(${JSON.stringify(process.env.PEON_MANAGER_SELFTEST_VIEW)})).click()`);
            await new Promise((r) => setTimeout(r, 800));
          }
          if (process.env.PEON_MANAGER_SELFTEST_SCROLL) await win.webContents.executeJavaScript(`document.querySelector('.page').scrollTop = 1e6`);
          // sonst liefert ein verdecktes Fenster manchmal ein altes Bild
          win.webContents.invalidate();
          await new Promise((r) => setTimeout(r, 500));
          const img = await win.webContents.capturePage();
          fs.writeFileSync(path.join(out, 'electron.png'), img.toPNG());
          const ov = await svc.overviewAsync();
          fs.writeFileSync(path.join(out, 'electron.json'), JSON.stringify({ markets: ov.markets.length, back: ov.back, log: ov.log, view: await win.webContents.executeJavaScript(`(document.querySelector('button.nav.on') || {}).textContent`), peon: await win.webContents.executeJavaScript('typeof window.peon + "/" + typeof window.require'),
            ipc: await win.webContents.executeJavaScript(`(async () => { const o = await window.peon.overview(); const m = o.markets[0]; if (!m) return null;
              const l = await window.peon.items(m.key); const d = await window.peon.item(m.key, '2770', 'all'); const r = await window.peon.retention(30);
              return { items: l.items.length, broker: d ? d.broker.length : null, own: d ? d.own.length : null, perScan: r.perScan }; })()`) }));
        } catch (e) { fs.writeFileSync(path.join(out, 'electron.err'), String(e && e.stack || e)); }
        quitting = true; app.quit();
      }, Number(process.env.PEON_MANAGER_SELFTEST_MS || 2500)));
    }
  });

  app.on('second-instance', showWindow);
  app.on('window-all-closed', () => { /* bleibt im Infobereich */ });
  app.on('before-quit', () => { quitting = true; if (svc) svc.close(); });
}
