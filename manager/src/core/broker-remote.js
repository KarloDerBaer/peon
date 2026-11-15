'use strict';
// Peon Manager - Modul Peon Broker Client im Arbeitsprozess (ab Manager 0.23.0, KarloDerBaer 09.11.2026).
// Nach jedem neuen Stand rechnet das Modul alle Maerkte neu. Das dauerte mit einigen Tagen Blizzard-Daten rund 10 Sekunden,
// in denen das Fenster nicht reagierte. Jetzt laeuft das Modul in eigenen Threads (broker-worker.js).
// Jeder Aufruf liefert ein Promise: remote.importGame(), remote.api.tick(client), remote.get('pruning').
// Ein BlizzardClient als Argument geht als einfache Daten hinueber, der Arbeitsprozess baut seinen eigenen.
//
// ab Manager 0.44.0 (KarloDerBaer 15.11.2026: Schreiben und Rechnen trennen) drei Prozesse:
// - Schreib-Prozess (worker, Rolle write): Einlesen, alle Eingaben, Aufbewahrung, Data.lua. Er rechnet nichts Abgeleitetes,
//   eine Eingabe wartet so nie hinter einer Rechnung.
// - Rechen-Prozess (Rolle calc): nach jedem Einlesen Bereich, Absatz, Chancen, Liste und Marktuebersicht (calcMarkets), nach
//   dem Aufraeumen Vergleiche, Muster und Tageswerte (maintainInBackground). Ergebnisse legt er in der Datenbank ab
//   (calc_cache, list_cache), danach schreibt der Schreib-Prozess Data.lua (bridgeFromCalc).
// - Lese-Prozess (Rolle read, ab 0.42.0): Ansichten aus der Datenbank und den gespeicherten Ergebnissen.
// Faellt der Rechen- oder Lese-Prozess aus, macht der Schreib-Prozess deren Arbeit wie bis 0.41.0. Nach SIDE_RETRY_MS wird
// der Prozess neu gestartet. Beide starten erst, wenn der Schreib-Prozess bereit ist (er stellt die Datenbank beim Oeffnen um).

const path = require('node:path');
const { Worker } = require('node:worker_threads');
const { BlizzardClient } = require('./blizzard');

// Im fertigen Programm liegt der Code in app.asar. Threads laden ihn aus dem entpackten Ordner (asarUnpack).
function workerFile() {
  return path.join(__dirname, 'broker-worker.js').replace(/app\.asar([\\/])/, 'app.asar.unpacked$1');
}

const SIDE_RETRY_MS = 60 * 1000;
const CALC_TIMEOUT_MS = 10 * 60 * 1000;       // Rechnung nach einem Stand, mit echten Daten etwa 10 bis 20 Sek.
const MAINTAIN_TIMEOUT_MS = 30 * 60 * 1000;   // nach dem Aufraeumen, in Schritten
const RECALC_DELAY_MS = 1000;
// Aufrufe, die die ganze Rechnung eines Markts brauchen: im Rechen-Prozess, der sie schon im Speicher hat
const CALC_CALLS = new Set(['chanceItem', 'brief', 'chanceView', 'marketOverview']);
// Eingaben, nach denen die Chancen neu zu rechnen sind (Data.lua bekommt die neuen Kandidaten)
const RULE_CALLS = new Set(['setChanceRules', 'resetChanceRules', 'setOverride', 'setEvents', 'rateChance', 'deleteChanceRating']);

// Zweiter oder dritter Arbeitsprozess (Lesen, Rechnen). send liefert null, wenn es ihn gerade nicht gibt.
class Side {
  constructor(remote, role, label) {
    this.remote = remote;
    this.role = role;
    this.label = label;
    this.worker = null;
    this.down = 0;
    this.waiting = new Map();
  }

  start() {
    const r = this.remote;
    if (this.worker || r.closed || !r.writerUp) return false;
    if (this.down && Date.now() - this.down < SIDE_RETRY_MS) return false;
    let w;
    try {
      w = new Worker(r.file, { workerData: { ...r.baseData(), role: this.role, readOnly: this.role === 'read' } });
    } catch (e) { this.failed(e); return false; }
    this.worker = w;
    w.on('message', (m) => {
      if (!m || m.type === 'saveSettings') return;   // speichert keine Einstellungen, das macht der Schreib-Prozess
      const x = this.waiting.get(m.id);
      if (!x) return;
      this.waiting.delete(m.id);
      clearTimeout(x.timer);
      if (m.error !== undefined) x.reject(new Error(m.error)); else x.resolve(m.result);
    });
    w.on('error', (e) => this.failed(e, w));
    w.on('exit', (code) => this.failed(new Error(`beendet (${code})`), w));
    return true;
  }

  failed(e, w = this.worker) {
    if (w !== this.worker || !w) return;
    this.worker = null;
    w.terminate().catch(() => {});
    if (this.remote.closed) return;
    this.down = Date.now();
    this.remote.onError(new Error(`${this.label}: ${(e && e.message) || e}`));
    const open = [...this.waiting.values()];
    this.waiting.clear();
    for (const x of open) { clearTimeout(x.timer); x.reject(e); }
  }

  send(name, args, timeout = 0) {
    if (!this.worker) this.start();
    if (!this.worker) return null;
    const w = this.worker;
    const id = ++this.remote.seq;
    return new Promise((resolve, reject) => {
      const x = { resolve, reject, timer: null };
      if (timeout) x.timer = setTimeout(() => this.failed(new Error(`keine Antwort nach ${Math.round(timeout / 60000)} Min.`), w), timeout);
      this.waiting.set(id, x);
      w.postMessage({ type: 'call', id, path: name, args, host: this.remote.hostMsg() });
    });
  }

  close() {
    const w = this.worker;
    this.worker = null;
    if (!w) return;
    try { w.postMessage({ type: 'call', id: ++this.remote.seq, path: 'close', args: [] }); } catch { /* schon weg */ }
    setTimeout(() => { w.terminate().catch(() => {}); }, 2000).unref();
  }
}

class BrokerRemote {
  constructor(host, { file = workerFile(), onError, reader = true, calc = true } = {}) {
    this.host = host;
    this.file = file;
    this.onError = onError || (() => {});
    this.seq = 0;
    this.waiting = new Map();
    this.closed = false;
    this.writerUp = false;
    this.gameRunning = null;   // ab 0.43.0, aus noteGame
    this.useCalc = !!calc;
    this.readSide = reader ? new Side(this, 'read', 'Lese-Prozess') : null;
    this.calcSide = calc ? new Side(this, 'calc', 'Rechen-Prozess') : null;
    this.calcBusy = null;
    this.calcAgain = false;
    this.calcTimer = null;
    this.maintaining = false;
    this.start();
    const self = this;
    // remote.api.tick(...) -> Aufruf "api.tick"
    this.api = new Proxy({}, { get: (_t, p) => (p === 'then' ? undefined : (...a) => self.call(`api.${String(p)}`, ...a)) });
    return new Proxy(this, {
      get(t, p) {
        if (p in t || typeof p === 'symbol' || p === 'then') return t[p];
        const name = String(p);
        if (CALC_CALLS.has(name)) return (...a) => t.calcCall(name, ...a);
        if (RULE_CALLS.has(name)) return (...a) => t.call(name, ...a).then((r) => { t.recalcSoon(); return r; });
        return (...a) => t.call(name, ...a);
      },
    });
  }

  get reader() { return this.readSide ? this.readSide.worker : null; }
  get calcer() { return this.calcSide ? this.calcSide.worker : null; }

  baseData() {
    const h = this.host;
    return { dbDir: h.dbDir, version: h.version, settings: h.settings, channels: h.channels(), marks: h.reports.marks() };
  }

  hostMsg() {
    const h = this.host;
    const game = this.gameRunning == null ? null : { running: this.gameRunning, mt: 0 };
    return { settings: h.settings, channels: h.channels(), marks: h.reports.marks(), game };
  }

  start() {
    this.worker = new Worker(this.file, { workerData: { ...this.baseData(), role: this.useCalc ? 'write' : 'all' } });
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
    if (!this.writerUp) {
      this.writerUp = true;
      if (this.readSide) this.readSide.start();
      if (this.calcSide) this.calcSide.start();
    }
    const w = this.waiting.get(m.id);
    if (!w) return;
    this.waiting.delete(m.id);
    if (m.error !== undefined) w.reject(new Error(m.error)); else w.resolve(m.result);
  }

  failAll(e) {
    for (const w of this.waiting.values()) w.reject(e);
    this.waiting.clear();
  }

  // Schreib-Prozess
  call(name, ...args) {
    if (this.closed) return Promise.reject(new Error('Peon Broker Client ist beendet'));
    if (!this.worker) this.start();   // nach einem Absturz beim naechsten Aufruf neu starten
    const id = ++this.seq;
    const plain = args.map((a) => (a instanceof BlizzardClient
      ? { __blizzard: { clientId: a.clientId, clientSecret: a.clientSecret, region: a.region }, opts: { oauthBase: a.oauthBase, apiBase: a.apiBase } } : a));
    return new Promise((resolve, reject) => {
      this.waiting.set(id, { resolve, reject });
      this.worker.postMessage({ type: 'call', id, path: name, args: plain, host: this.hostMsg() });
    });
  }

  get(name) {
    if (name === 'pruning' && this.maintaining) return Promise.resolve(true);
    return this.call('$get', name);
  }

  // ab 0.43.0: Laeuft WoW? Der Lese-Prozess bekommt den Zustand mit jeder Anfrage (Beobachten, Einkaufen)
  noteGame(running) {
    this.gameRunning = !!running;
    return this.call('noteGame', running);
  }

  // Rechen-Prozess, ohne ihn (oder bei einem Fehler dort) der Schreib-Prozess
  calcCall(name, ...args) {
    if (this.closed) return Promise.reject(new Error('Peon Broker Client ist beendet'));
    const timeout = name === 'maintainInBackground' ? MAINTAIN_TIMEOUT_MS : name === 'calcMarkets' ? CALC_TIMEOUT_MS : 0;
    const p = this.calcSide && this.calcSide.send(name, args, timeout);
    if (!p) return this.call(name, ...args);
    return p.catch(() => (this.closed ? null : this.call(name, ...args)));
  }

  // Abfrage fuer eine Ansicht: ueber den Lese-Prozess. Ohne ihn, oder wenn er sie nicht beantworten kann (Schreiben, kein
  // passendes Ergebnis), der Rechen- oder der Schreib-Prozess. Dessen Antwort gilt.
  read(name, ...args) {
    if (this.closed) return Promise.reject(new Error('Peon Broker Client ist beendet'));
    const other = () => (CALC_CALLS.has(name) ? this.calcCall(name, ...args) : this.call(name, ...args));
    const p = this.readSide && this.readSide.send(name, args);
    if (!p) return other();
    return p.catch(() => other());
  }

  // ab 0.44.0: Einlesen im Schreib-Prozess, danach rechnet der Rechen-Prozess, danach schreibt der Schreib-Prozess Data.lua.
  // Das Promise endet wie bisher erst nach der Rechnung (Benachrichtigungen, Ansichten neu laden).
  async importGame() {
    const sum = await this.call('importGame');
    if (this.useCalc) await this.recalc();
    return sum;
  }

  async pruneInBackground() {
    const r = await this.call('pruneInBackground');
    if (!this.useCalc || !r || this.closed) return r;
    this.maintaining = true;
    try { await this.calcCall('maintainInBackground'); } finally { this.maintaining = false; }
    await this.recalc();
    return r;
  }

  // Eine Rechnung zur Zeit. Kommt waehrenddessen ein Wunsch dazu, wird danach noch einmal gerechnet.
  recalc() {
    if (!this.useCalc) return Promise.resolve(null);
    if (this.calcBusy) { this.calcAgain = true; return this.calcBusy; }
    this.calcBusy = (async () => {
      try {
        do {
          this.calcAgain = false;
          await this.calcCall('calcMarkets');
          if (this.closed) return;
          await this.call('bridgeFromCalc');
        } while (this.calcAgain && !this.closed);
      } catch (e) {
        if (!this.closed) this.onError(new Error(`Rechnen: ${(e && e.message) || e}`));
      } finally { this.calcBusy = null; }
    })();
    return this.calcBusy;
  }

  // nach Eingaben zu den Chancen, mehrere kurz nacheinander ergeben eine Rechnung
  recalcSoon() {
    if (!this.useCalc || this.closed) return;
    clearTimeout(this.calcTimer);
    this.calcTimer = setTimeout(() => { this.recalc(); }, RECALC_DELAY_MS);
    if (this.calcTimer.unref) this.calcTimer.unref();
  }

  // Sicherung: der Arbeitsprozess schreibt die Kopie seiner offenen Datenbank
  backupTo(file) { return this.call('backupTo', file); }

  close() {
    if (this.closed) return Promise.resolve(true);
    clearTimeout(this.calcTimer);
    if (this.readSide) this.readSide.close();
    if (this.calcSide) this.calcSide.close();
    const p = this.worker ? this.call('close') : Promise.resolve(true);
    this.closed = true;   // erst nach dem Senden: call() nimmt danach nichts mehr an
    return p.catch(() => true);
  }
}

module.exports = { BrokerRemote, workerFile, CALC_CALLS, RULE_CALLS };
