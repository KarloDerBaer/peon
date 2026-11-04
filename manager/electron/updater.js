'use strict';
// Peon Manager - Selbst-Update (Peon_GitHub_Design.md 5.6). electron-updater laedt die neue Version im Hintergrund,
// vor dem Neustart wird gefragt. Quelle ist der Ordner des Release aus dem Manifest: Der GitHub-Weg von electron-updater
// verlangt Tags als Versionsnummern, unsere heissen vJJJJ.MM.TT.
// Nur im installierten Programm, nicht beim Entwickeln und nicht im Ordner mit DB daneben (wird von Hand getauscht).

function createUpdater({ enabled, svc, onChange, beforeInstall }) {
  const state = { status: enabled ? 'idle' : 'off', version: null, percent: 0, error: null };
  if (!enabled) return { state: () => ({ ...state }), check: () => {}, install: () => {} };

  const { autoUpdater } = require('electron-updater');
  autoUpdater.autoDownload = true;
  autoUpdater.autoInstallOnAppQuit = false;   // nie ungefragt, nur ueber den Knopf
  autoUpdater.logger = null;
  const set = (patch) => { Object.assign(state, patch); onChange(); };

  autoUpdater.on('update-available', (i) => set({ status: 'downloading', version: i.version, percent: 0, error: null }));
  autoUpdater.on('update-not-available', () => set({ status: 'idle', version: null }));
  autoUpdater.on('download-progress', (p) => {
    const step = Math.floor(p.percent / 10) * 10;
    if (step !== state.percent) set({ percent: step });
  });
  autoUpdater.on('update-downloaded', (i) => set({ status: 'ready', version: i.version, percent: 100 }));
  autoUpdater.on('error', (e) => {
    set({ status: 'error', error: String((e && e.message) || e).split('\n')[0] });
    svc.logManager('update', false, `Selbst-Update: ${state.error}`);
  });

  return {
    state: () => ({ ...state }),
    // Nach jeder Suche: Nennt das Manifest eine neuere Version, diese laden
    check() {
      const u = svc.addons.managerUpdate();
      if (!u || state.status === 'downloading' || (state.status === 'ready' && state.version === u.version)) return;
      // GitHub liefert je Abruf nur einen Bereich einer Datei
      autoUpdater.setFeedURL({ provider: 'generic', url: u.feed, useMultipleRangeRequest: false });
      autoUpdater.checkForUpdates().catch(() => { /* kommt auch als Ereignis error */ });
    },
    install(restart = true) {
      if (state.status !== 'ready') return;
      beforeInstall();
      autoUpdater.quitAndInstall(true, restart);
    },
  };
}

module.exports = { createUpdater };
