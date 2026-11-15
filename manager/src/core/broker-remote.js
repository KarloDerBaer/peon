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

// ab Manager 0.42.0 (Stufe 3 der Beschleunigung, KarloDerBaer 15.11.2026): ein zweiter Arbeitsprozess nur zum Lesen. Ansichten
// wie Gegenstandsseite und Liste (read) warten so nie hinter Einlesen und Neurechnen. Er startet, sobald der erste Prozess
// bereit ist (der stellt die Datenbank beim Oeffnen um). Faellt er aus, geht alles wie bisher ueber den ersten Prozess,
// nach READER_RETRY_MS versucht es read erneut.
const READER_RETRY_MS = 60 * 1000;

class BrokerRemote {
  constructor(host, { file = workerFile(), onError, reader = true } = {}) {
    this.host = host;
    this.file = file;
    this.onError = onError || (() => {});
    this.seq = 0;
    this.waiting = new Map();
    this.closed = false;
    this.useReader = reader;
    this.reader = null;
    this.readerDown = 0;
    this.readWaiting = new Map();
    this.writerUp = false;
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
    if (!this.writerUp) { this.writerUp = true; this.startReader(); }
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

  startReader() {
    if (!this.useReader || this.reader || this.closed || !this.writerUp) return;
    if (this.readerDown && Date.now() - this.readerDown < READER_RETRY_MS) return;
    const h = this.host;
    let w;
    try {
      w = new Worker(this.file, { workerData: { dbDir: h.dbDir, version: h.version, settings: h.settings, channels: h.channels(), marks: h.reports.marks(), readOnly: true } });
    } catch (e) { this.readerFailed(e); return; }
    this.reader = w;
    w.on('message', (m) => {
      if (!m || m.type === 'saveSettings') return;   // liest nur, speichert nichts
      const x = this.readWaiting.get(m.id);
      if (!x) return;
      this.readWaiting.delete(m.id);
      if (m.error !== undefined) {
        // Fehler im Lese-Prozess: dieselbe Anfrage beim ersten Prozess, dessen Antwort gilt
        this.call(x.name, ...x.args).then(x.resolve, x.reject);
      } else x.resolve(m.result);
    });
    w.on('error', (e) => this.readerFailed(e));
    w.on('exit', (code) => { if (this.reader === w) this.readerFailed(new Error(`Lese-Prozess beendet (${code})`)); });
  }

  readerFailed(e) {
    if (this.closed) return;
    this.reader = null;
    this.readerDown = Date.now();
    this.onError(new Error(`Lese-Prozess: ${(e && e.message) || e}`));
    const open = [...this.readWaiting.values()];
    this.readWaiting.clear();
    for (const x of open) this.call(x.name, ...x.args).then(x.resolve, x.reject);
  }

  // Abfrage fuer eine Ansicht: ueber den Lese-Prozess, solange es ihn nicht gibt ueber den ersten
  read(name, ...args) {
    if (this.closed) return Promise.reject(new Error('Peon Broker Client ist beendet'));
    if (!this.reader) this.startReader();
    if (!this.reader) return this.call(name, ...args);
    const id = ++this.seq;
    const h = this.host;
    return new Promise((resolve, reject) => {
      this.readWaiting.set(id, { resolve, reject, name, args });
      this.reader.postMessage({ type: 'call', id, path: name, args, host: { settings: h.settings, channels: h.channels(), marks: h.reports.marks() } });
    });
  }

  // Sicherung: der Arbeitsprozess schreibt die Kopie seiner offenen Datenbank
  backupTo(file) { return this.call('backupTo', file); }

  close() {
    if (this.closed) return Promise.resolve(true);
    if (this.reader) {
      const r = this.reader;
      this.reader = null;
      try { r.postMessage({ type: 'call', id: ++this.seq, path: 'close', args: [] }); } catch { /* schon weg */ }
      setTimeout(() => { r.terminate().catch(() => {}); }, 2000).unref();
    }
    const p = this.worker ? this.call('close') : Promise.resolve(true);
    this.closed = true;   // erst nach dem Senden: call() nimmt danach nichts mehr an
    return p.catch(() => true);
  }
}

module.exports = { BrokerRemote, workerFile };
