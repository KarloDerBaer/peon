'use strict';
// Feste Befehlsliste fuer die Oberflaeche (kein Zugriff auf Node oder Dateien)
const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('peon', {
  overview: () => ipcRenderer.invoke('overview'),
  importNow: () => ipcRenderer.invoke('import'),
  fetchAhledger: () => ipcRenderer.invoke('ahledger'),
  ahledgerMarkets: () => ipcRenderer.invoke('ahledgerMarkets'),
  settings: () => ipcRenderer.invoke('settings'),
  items: (market) => ipcRenderer.invoke('items', market),
  item: (market, key, range) => ipcRenderer.invoke('item', market, key, range),
  chances: (market, days) => ipcRenderer.invoke('chances', market, days),
  retention: (keepDays) => ipcRenderer.invoke('retention', keepDays),
  saveSettings: (patch) => ipcRenderer.invoke('saveSettings', patch),
  pickFolder: () => ipcRenderer.invoke('pickFolder'),
  openFolder: (which) => ipcRenderer.invoke('openFolder', which),
  openLink: (url) => ipcRenderer.invoke('openLink', url),
  onChanged: (fn) => { ipcRenderer.on('changed', (_e, info) => fn(info)); },
});
