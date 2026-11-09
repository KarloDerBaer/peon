'use strict';
// Peon Manager - Arbeitsprozess fuer das Modul Peon Broker Client (ab Manager 0.23.0).
// Einlesen, Neurechnen und alle Abfragen der Marktdaten laufen hier, damit das Fenster nie haengt.
// Der Hauptteil spricht ueber broker-remote.js mit diesem Teil: { type: 'call', id, path, args, host } -> { id, result | error }.
// Einstellungen, Kanaele und Marken fuer Data.lua schickt der Hauptteil bei jedem Aufruf mit. Speichert das Modul
// Einstellungen (Blizzard-Haeuser), geht die Aenderung als { type: 'saveSettings', patch } an den Hauptteil.

const { parentPort, workerData } = require('node:worker_threads');
const { BrokerClient } = require('./broker-client');
const { BlizzardClient } = require('./blizzard');

process.removeAllListeners('warning');   // Hinweis "SQLite is experimental" nicht anzeigen

const state = { channels: workerData.channels || {}, marks: workerData.marks || {} };
const host = {
  dbDir: workerData.dbDir,
  version: workerData.version,
  settings: workerData.settings,
  fetchImpl: (...a) => fetch(...a),
  now: () => Math.floor(Date.now() / 1000),
  saveSettings(patch) {
    host.settings = { ...host.settings, ...patch };
    parentPort.postMessage({ type: 'saveSettings', patch });
    return host.settings;
  },
  channels: () => state.channels,
  reports: { marks: () => state.marks },
};

const broker = new BrokerClient(host);

// Blizzard-Zugang kommt als einfache Daten, der Client hier merkt sich seine Anmeldung
let blizzard = null;
function blizzardOf(ref) {
  const c = ref.__blizzard, o = ref.opts || {};
  const sig = JSON.stringify([c.clientId, c.clientSecret, c.region, o.oauthBase, o.apiBase]);
  if (!blizzard || blizzard.sig !== sig) blizzard = { sig, client: new BlizzardClient(c, o) };
  return blizzard.client;
}
const arg = (a) => (a && typeof a === 'object' && a.__blizzard ? blizzardOf(a) : a);

async function run(msg) {
  if (msg.host) {
    if (msg.host.settings) host.settings = msg.host.settings;
    if (msg.host.channels) state.channels = msg.host.channels;
    if (msg.host.marks) state.marks = msg.host.marks;
  }
  if (msg.path === '$get') return broker.get(msg.args[0]);
  const parts = String(msg.path).split('.');
  const name = parts.pop();
  const obj = parts.reduce((o, k) => (o == null ? undefined : o[k]), broker);
  if (!obj || typeof obj[name] !== 'function') throw new Error(`Unbekannter Aufruf: ${msg.path}`);
  return obj[name](...(msg.args || []).map(arg));
}

parentPort.on('message', async (msg) => {
  if (!msg || msg.type !== 'call') return;
  if (msg.path === 'close') {
    broker.close();
    parentPort.postMessage({ id: msg.id, result: true });
    parentPort.close();
    return;
  }
  try {
    const result = await run(msg);
    parentPort.postMessage({ id: msg.id, result });
  } catch (e) {
    parentPort.postMessage({ id: msg.id, error: (e && e.message) || String(e) });
  }
});
