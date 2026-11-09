'use strict';
// Peon Manager - Modul Peon Broker Client im Arbeitsprozess (ab Manager 0.23.0, KarloDerBaer 09.11.2026).
// Nach jedem neuen Stand rechnet das Modul alle Maerkte neu. Das dauerte mit einigen Tagen Blizzard-Daten rund 10 Sekunden,
// in denen das Fenster nicht reagierte. Jetzt laeuft das Modul in einem eigenen Thread (broker-worker.js).
// Jeder Aufruf liefert ein Promise: remote.importGame(), remote.api.tick(client), remote.get('pruning').
// Ein BlizzardClient als Argument geht als einfache Daten hinueber, der Arbeitsprozess baut seinen eigenen.

const path = require('node:path');
const { Worker } = require('node:worker_threads');
const { BlizzardClient } = require('./blizzard');

// Im fertigen Programm liegt der Code in app.asar. Threads laden ihn aus dem entpackten Ordner (asarUnpack).
function workerFile() {
  return path.join(__dirname, 'broker-worker.js').replace(/app\.asar([\\/])/, 'app.asar.unpacked$1');
}

class BrokerRemote {
  constructor(host, { file = workerFile(), onError } = {}) {
    this.host = host;
    this.file = file;
    this.onError = onError || (() => {});
    this.seq = 0;
    this.waiting = new Map();
    this.closed = false;
    this.start();
    const self = this;
    // remote.api.tick(...) -> Aufruf "api.tick"
    this.api = new Proxy({}, { get: (_t, p) => (p === 'then' ? undefined : (...a) => self.call(`api.${String(p)}`, ...a)) });
    return new Proxy(this, {
      get(t, p) {
        if (p in t || typeof p === 'symbol' || p === 'then') return t[p];
        return (...a) => t.call(String(p), ...a);
      },
    });
  }

  start() {
    const h = this.host;
    this.worker = new Worker(this.file, {
      workerData: { dbDir: h.dbDir, version: h.version, settings: h.settings, channels: h.channels(), marks: h.reports.marks() },
    });
    this.worker.on('message', (m) => this.onMessage(m));
    this.worker.on('error', (e) => { this.onError(e); this.failAll(e); });
    this.worker.on('exit', (code) => {
      this.worker = null;
      if (!this.closed) { this.failAll(new Error(`Arbeitsprozess beendet (${code})`)); this.onError(new Error(`Arbeitsprozess beendet (${code})`)); }
    });
  }

  onMessage(m) {
    if (!m) return;
    if (m.type === 'saveSettings') { this.host.saveSettings(m.patch); return; }
    const w = this.waiting.get(m.id);
    if (!w) return;
    this.waiting.delete(m.id);
    if (m.error !== undefined) w.reject(new Error(m.error)); else w.resolve(m.result);
  }

  failAll(e) {
    for (const w of this.waiting.values()) w.reject(e);
    this.waiting.clear();
  }

  call(name, ...args) {
    if (this.closed) return Promise.reject(new Error('Peon Broker Client ist beendet'));
    if (!this.worker) this.start();   // nach einem Absturz beim naechsten Aufruf neu starten
    const id = ++this.seq;
    const h = this.host;
    const plain = args.map((a) => (a instanceof BlizzardClient
      ? { __blizzard: { clientId: a.clientId, clientSecret: a.clientSecret, region: a.region }, opts: { oauthBase: a.oauthBase, apiBase: a.apiBase } } : a));
    return new Promise((resolve, reject) => {
      this.waiting.set(id, { resolve, reject });
      this.worker.postMessage({ type: 'call', id, path: name, args: plain, host: { settings: h.settings, channels: h.channels(), marks: h.reports.marks() } });
    });
  }

  get(name) { return this.call('$get', name); }

  // Sicherung: der Arbeitsprozess schreibt die Kopie seiner offenen Datenbank
  backupTo(file) { return this.call('backupTo', file); }

  close() {
    if (this.closed) return Promise.resolve(true);
    const p = this.worker ? this.call('close') : Promise.resolve(true);
    this.closed = true;   // erst nach dem Senden: call() nimmt danach nichts mehr an
    return p.catch(() => true);
  }
}

module.exports = { BrokerRemote, workerFile };
