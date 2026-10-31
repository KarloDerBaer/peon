'use strict';
// Peon Manager - Hauptteil (Electron): Fenster, Symbol im Infobereich, Manager-Module.
// Dateiwaechter, Zeitplan fuer AHledger und Aufraeumen laufen nur, wenn das Modul Peon Broker Client installiert ist.
// Rechnen und Speichern macht src/core (ohne Electron testbar).
// Sicherheit: Die Oberflaeche hat keinen Zugriff auf Node, nur auf die feste Befehlsliste aus preload.js,
// laedt keine fremden Seiten, alle Netzzugriffe macht dieser Teil.

const path = require('node:path');
const fs = require('node:fs');
const { app, BrowserWindow, Tray, Menu, ipcMain, nativeImage, shell, dialog, session } = require('electron');
const { Service } = require('../src/core/service');

process.removeAllListeners('warning');   // Hinweis "SQLite is experimental" nicht anzeigen

const ROOT = path.join(__dirname, '..');
const DEV = !app.isPackaged;
const HIDDEN = process.argv.includes('--hidden');

function dataDir() {
  if (process.env.PEON_MANAGER_DB) return process.env.PEON_MANAGER_DB;
  if (DEV) return path.join(ROOT, 'data');
  // <Programmordner>\Runtime\PeonManager.exe -> <Programmordner>\DB
  return path.join(path.dirname(process.execPath), '..', 'DB');
}

if (!app.requestSingleInstanceLock()) {
  app.quit();
} else {
  let win = null, tray = null, svc = null, quitting = false;
  const watchers = [];
  let lastSeen = new Map();
  let pending = null;
  let busy = false;
  let lastAhl = 0;

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

  // Menue im Infobereich: Eintraege des Broker Client nur, wenn er installiert ist
  function updateTray() {
    if (!tray) return;
    const items = [{ label: 'Fenster öffnen', click: showWindow }];
    if (svc.broker) {
      items.push({ label: 'Jetzt einlesen', click: () => runImport('Infobereich') });
      items.push({ label: 'AHledger abrufen', click: () => runAhledger(true) });
    }
    items.push({ type: 'separator' }, { label: 'Beenden', click: () => { quitting = true; app.quit(); } });
    tray.setContextMenu(Menu.buildFromTemplate(items));
  }

  // ---------- Einlesen ----------
  function runImport(why) {
    if (!svc.broker) { svc.syncBridge(); return { inactive: true }; }
    if (busy) { pending = pending || setTimeout(() => { pending = null; runImport(why); }, 1000); return null; }
    busy = true;
    try {
      const r = svc.broker.importGame();
      for (const f of r.files) lastSeen.set(f.file, f.mtime);
      for (const f of require('../src/core/broker').findFiles(svc.settings.wowDir)) {
        try { lastSeen.set(f.file, Math.floor(fs.statSync(f.file).mtimeMs / 1000)); } catch { /* weg */ }
      }
      if (r.imported > 0 && tray) tray.setToolTip(`Peon Manager: ${r.imported} neue Momentaufnahmen`);
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

  // ---------- AHledger ----------
  async function runAhledger(force) {
    if (!svc.broker) return [];
    const a = svc.settings.ahledger;
    if (!a.enabled && !force) return [];
    const now = Date.now();
    if (!force && now - lastAhl < a.intervalMin * 60 * 1000) return [];
    lastAhl = now;
    const r = await svc.broker.fetchAhledger();
    send('changed', { what: 'ahledger' });
    return r;
  }

  function applyAutostart() {
    if (DEV) return;
    try { app.setLoginItemSettings({ openAtLogin: !!svc.settings.autostart, args: ['--hidden'] }); } catch { /* egal */ }
  }

  // ---------- Befehle fuer die Oberflaeche ----------
  function registerIpc() {
    ipcMain.handle('overview', () => svc.overview());
    ipcMain.handle('import', () => runImport('Knopf'));
    ipcMain.handle('ahledger', () => runAhledger(true));
    ipcMain.handle('ahledgerMarkets', () => (svc.broker ? svc.broker.ahledgerMarkets() : null));
    ipcMain.handle('settings', () => svc.settings);
    ipcMain.handle('items', (_e, market) => (svc.broker ? svc.broker.itemList(String(market)) : null));
    ipcMain.handle('item', (_e, market, key, range) => (svc.broker ? svc.broker.itemDetail(String(market), String(key), String(range || '30d')) : null));
    ipcMain.handle('chances', (_e, market, days) => (svc.broker ? svc.broker.chances(String(market), Number(days) || null) : null));
    ipcMain.handle('retention', (_e, keepDays) => (svc.broker ? svc.broker.retention(keepDays == null ? null : Number(keepDays)) : null));
    // Manager-Module: Installieren schaltet ein, Entfernen schaltet aus, Daten loeschen nur ausgeschaltet
    ipcMain.handle('modules', () => svc.moduleList());
    ipcMain.handle('setModule', (_e, key, on) => {
      const list = svc.setModule(String(key), !!on);
      setupWatch();
      updateTray();
      if (svc.broker) { runImport('Modul installiert'); try { svc.broker.prune(); } catch { /* steht im Protokoll */ } runAhledger(false).catch(() => {}); }
      send('changed', { what: 'module' });
      return list;
    });
    ipcMain.handle('clearModuleData', (_e, key) => {
      const list = svc.clearModuleData(String(key));
      send('changed', { what: 'module' });
      return list;
    });
    ipcMain.handle('saveSettings', (_e, patch) => {
      const before = svc.settings.wowDir, keepBefore = svc.settings.keepDays;
      const s = svc.saveSettings(patch || {});
      if (s.wowDir !== before) { setupWatch(); runImport('Ordner geändert'); }
      if (s.keepDays !== keepBefore && svc.broker) { try { svc.broker.prune(); } catch (e) { /* steht im Protokoll */ } }
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
      if (typeof url === 'string' && /^https:\/\/(www\.)?ahledger\.com(\/|$)/.test(url)) shell.openExternal(url);
    });
  }

  app.whenReady().then(() => {
    // keine Woerterbuecher fuer die Rechtschreibpruefung aus dem Netz laden
    try { session.defaultSession.setSpellCheckerEnabled(false); session.defaultSession.setSpellCheckerLanguages([]); } catch { /* egal */ }
    svc = new Service({ dbDir: dataDir(), version: app.getVersion() });
    registerIpc();
    createTray();
    createWindow();
    if (!HIDDEN) win.__userOpened = true;
    runImport('Start');
    if (svc.broker) { try { svc.broker.prune(); } catch { /* steht im Protokoll */ } }
    setInterval(() => {
      if (!svc.broker) return;
      const t = svc.broker.meta('pruneAt') || 0;
      if (svc.now() - t > 86400) { try { svc.broker.prune(); } catch { /* egal */ } }
    }, 60 * 60 * 1000);
    setupWatch();
    setInterval(poll, 60 * 1000);
    // Tageswechsel: Werte fuer Broker neu rechnen (Alter der Tage verschiebt sich), schreibt nur bei Aenderung
    setInterval(() => {
      if (!svc.broker) return;
      const a = svc.broker.meta('ack');
      if (!a || a.day !== require('../src/core/broker').dayOf(svc.now())) runImport('Tageswechsel');
    }, 60 * 60 * 1000);
    runAhledger(false).catch(() => {});
    setInterval(() => runAhledger(false).catch(() => {}), 60 * 1000);
    applyAutostart();
    // Selbsttest (nur fuer Tests): Bildschirmfoto und Uebersicht schreiben, dann beenden
    if (process.env.PEON_MANAGER_SELFTEST) {
      const out = process.env.PEON_MANAGER_SELFTEST;
      win.webContents.once('did-finish-load', () => setTimeout(async () => {
        try {
          const img = await win.webContents.capturePage();
          fs.writeFileSync(path.join(out, 'electron.png'), img.toPNG());
          const ov = svc.overview();
          fs.writeFileSync(path.join(out, 'electron.json'), JSON.stringify({ markets: ov.markets.length, back: ov.back, log: ov.log, peon: await win.webContents.executeJavaScript('typeof window.peon + "/" + typeof window.require'),
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
