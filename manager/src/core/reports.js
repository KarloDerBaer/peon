'use strict';
// Peon Manager - Rueckmeldungen und Fehler (Reiter Rueckmeldungen, gehoert zum Manager, nicht zu einem Modul).
// Der Manager fuehrt: Was aus dem Spiel kommt, wandert einmal in peon.db (Tabellen feedback, errors) und wird hier bearbeitet,
// geloescht und gesendet. Quellen unter WTF\Account\<Konto>\SavedVariables:
//   Peon.lua            PeonDB.errors (abgefangene Fehler), PeonDB.feedbackAreas (Bereiche je Modul)
//   !BugGrabber.lua     BugGrabberDB.errors, nur Eintraege, die ein Peon-Addon nennen, ohne die Spalte locals
//   Peon_Feedback.lua   PeonFeedbackDB.entries, ohne den Charakter
//
// Uebergabe: Nach dem Einlesen merkt sich der Manager den spaetesten Zeitpunkt je Art (meta errorsClearBefore,
// feedbackClearBefore) und schreibt ihn in Data.lua. Das Spiel loescht beim naechsten Laden alles bis dahin, der Manager
// ueberspringt es bis dahin. Spaetere Aenderungen im Spiel sind neuer und kommen deshalb an.
//
// Private Daten: Konto- und Charakternamen, Spieler-Kennungen und Pfade werden beim Einlesen und vor dem Senden ersetzt.

const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const { parseLua } = require('./lua');
const { log } = require('./db');

// Adresse des Workers (worker/peon-fehler). Leer: Senden ist nicht eingerichtet.
const REPORT_URL = 'https://peon-fehler.karloderbaer.workers.dev/bericht';
const REPORT_FMT = 2;
const MAX_ITEMS = 20;             // je Senden, der Rest bleibt fuer das naechste Mal
const MAX_REPORT_BYTES = 50000;   // der Worker nimmt hoechstens 64 KB an
const MAX_TEXT = 2000, MAX_STACK = 1500, MAX_MSG = 1000;

const CORE_FILE = 'Peon.lua', GRABBER_FILE = '!BugGrabber.lua', FEEDBACK_FILE = 'Peon_Feedback.lua';
const PEON_ADDON = /(?:AddOns[/\\]|AddOn '|tainted by ')(Peon(?:_\w+)?)/;
const PEON_MODULE = /^Peon(_\w+)?$/;
const NOT_NAMES = /^(peon|interface|addons|savedvariables|blizzard)$/i;

const MANAGER_MODULE = 'Peon_Manager';
const MANAGER_AREAS = ['Übersicht', 'Markt', 'Einkaufen', 'Radar', 'Datenlage', 'Module', 'Rückmeldungen', 'Einstellungen'];   // ab 0.26.0 wie im Spiel
const OTHER_AREA = 'Sonstiges';
const KINDS = [{ key: 'bug', label: 'Fehler' }, { key: 'improve', label: 'Verbesserung' }, { key: 'idea', label: 'Neue Idee' }, { key: 'other', label: 'Sonstiges' }];
const PRIOS = [{ key: 'low', label: 'Niedrig' }, { key: 'mid', label: 'Mittel' }, { key: 'high', label: 'Hoch' }];
const labelOf = (items, key) => (items.find((x) => x.key === key) || { label: key }).label;

const list = (x) => (Array.isArray(x) ? x : x && typeof x === 'object' ? Object.values(x) : []);
const text = (x) => (x === undefined || x === null ? '' : String(x));
const escapeRe = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const sha = (...parts) => crypto.createHash('sha1').update(parts.join('\n')).digest('hex');
const day = (t) => new Date(t * 1000).toISOString().slice(0, 16).replace('T', ' ');

// Konten und Charaktere unter WTF\Account: <Konto>\<Realm>\<Charakter>
function privateNames(wowDir) {
  const base = path.join(wowDir, 'WTF', 'Account');
  const dirs = (d) => { try { return fs.readdirSync(d, { withFileTypes: true }).filter((e) => e.isDirectory()).map((e) => e.name); } catch { return []; } };
  const names = new Set();
  for (const a of dirs(base)) {
    if (a === 'SavedVariables') continue;
    names.add(a);
    for (const r of dirs(path.join(base, a))) {
      if (r === 'SavedVariables') continue;
      for (const c of dirs(path.join(base, a, r))) if (c !== 'SavedVariables') names.add(c);
    }
  }
  return [...names].filter((n) => n.length >= 3 && !NOT_NAMES.test(n)).sort((x, y) => y.length - x.length);
}

// Pfade, Spieler-Kennungen und die eigenen Namen ersetzen. Im Ordner steht "Name-Reich", im Spiel oft "Name Reich".
function sanitize(value, names = []) {
  let s = text(value)
    .replace(/[A-Za-z]:[\\/][^\s"'<>|)\]]*/g, '<Pfad>')
    .replace(/Player-\d+-[0-9A-Fa-f]+/g, '<Spieler>');
  for (const n of names) {
    const flexible = n.split('-').map(escapeRe).join('[- ]');
    s = s.replace(new RegExp(`(?<![\\p{L}\\d])${flexible}(?![\\p{L}\\d])`, 'giu'), '<Name>');
  }
  return s;
}

class ReportStore {
  constructor(host) {
    this.host = host;
    this.seen = new Map();   // Datei -> Zeitpunkt der letzten Aenderung
    this.areas = {};         // Addon -> Bereiche, vom Kern im Spiel gemeldet
    // Manager 0.13 kannte Notiz und Zaehlstand noch nicht
    const have = new Set(this.db.prepare('PRAGMA table_info(errors)').all().map((c) => c.name));
    for (const [col, type] of [['note', "TEXT NOT NULL DEFAULT ''"], ['base_first', 'INTEGER'], ['base_n', 'INTEGER']]) {
      if (!have.has(col)) this.db.exec(`ALTER TABLE errors ADD COLUMN ${col} ${type}`);
    }
  }

  get db() { return this.host.db; }
  marks() {
    return { errorsClearBefore: this.host.meta('errorsClearBefore') || 0, feedbackClearBefore: this.host.meta('feedbackClearBefore') || 0 };
  }

  files() {
    const base = path.join(this.host.settings.wowDir, 'WTF', 'Account');
    let accounts = [];
    try { accounts = fs.readdirSync(base, { withFileTypes: true }).filter((d) => d.isDirectory()).map((d) => d.name); } catch { return []; }
    const out = [];
    for (const account of accounts) {
      for (const name of [CORE_FILE, GRABBER_FILE, FEEDBACK_FILE]) {
        const file = path.join(base, account, 'SavedVariables', name);
        if (fs.existsSync(file)) out.push({ file, name, account });
      }
    }
    return out;
  }

  // Geaenderte Dateien einlesen und die Uebergabe ans Spiel schreiben. Rueckgabe: true, wenn etwas eingelesen wurde
  scan() {
    let changed = false, names = null;
    const start = this.marks();
    const next = { ...start };
    for (const f of this.files()) {
      let mtime = 0;
      try { mtime = fs.statSync(f.file).mtimeMs; } catch { continue; }
      if (this.seen.get(f.file) === mtime) continue;
      names = names || privateNames(this.host.settings.wowDir);
      try {
        const g = parseLua(fs.readFileSync(f.file));
        if (f.name === FEEDBACK_FILE) {
          for (const e of this.fromFeedback(g.PeonFeedbackDB, names, f.account)) {
            if (e.stamp <= start.feedbackClearBefore) continue;
            this.saveFeedback(e);
            next.feedbackClearBefore = Math.max(next.feedbackClearBefore, e.stamp);
          }
        } else {
          if (f.name === CORE_FILE) this.readAreas(g.PeonDB);
          const rows = f.name === GRABBER_FILE ? this.fromGrabber(g.BugGrabberDB, names) : this.fromCore(g.PeonDB, names);
          for (const r of rows) {
            if (r.last <= start.errorsClearBefore) continue;
            this.saveError(r);
            next.errorsClearBefore = Math.max(next.errorsClearBefore, r.last);
          }
        }
        changed = true;
      } catch (e) {
        log(this.db, 'rueckmeldung', false, `${f.name}: ${sanitize(e.message, names)}`);
      }
      this.seen.set(f.file, mtime);   // bei einem Fehler erst nach der naechsten Aenderung wieder versuchen
    }
    if (next.errorsClearBefore !== start.errorsClearBefore || next.feedbackClearBefore !== start.feedbackClearBefore) {
      this.host.meta('errorsClearBefore', next.errorsClearBefore);
      this.host.meta('feedbackClearBefore', next.feedbackClearBefore);
      try { this.host.bridgeInstalled(); } catch (e) { log(this.db, 'rueckmeldung', false, `Data.lua: ${e.message}`); }
    }
    return changed;
  }

  readAreas(db) {
    const a = db && db.feedbackAreas;
    if (!a || typeof a !== 'object') return;
    for (const [addon, areas] of Object.entries(a)) this.areas[addon] = list(areas).map(text).filter(Boolean);
  }

  fromCore(db, names) {
    return list(db && db.errors).map((e) => ({
      source: 'peon', addon: text(e.addon), version: text(e.version), build: text(e.build),
      where: sanitize(e.where, names), msg: sanitize(e.msg, names), stack: '',
      first: Number(e.first) || 0, last: Number(e.last) || 0, n: Number(e.n) || 1,
    })).filter((r) => r.msg);
  }

  // Nur Meldung und Aufrufkette: Die Spalte locals von BugGrabber kann alles Moegliche enthalten
  fromGrabber(db, names) {
    const out = [];
    for (const e of list(db && db.errors)) {
      const msg = text(e.message), stack = text(e.stack);
      const m = PEON_ADDON.exec(msg) || PEON_ADDON.exec(stack);
      if (!m) continue;
      const t = Number(e.time) || 0;
      out.push({ source: 'buggrabber', addon: m[1], version: '', build: '', where: 'BugGrabber',
        msg: sanitize(msg, names), stack: sanitize(stack, names), first: t, last: t, n: Number(e.counter) || 1 });
    }
    return out;
  }

  // Der Charakter bleibt im Spiel
  fromFeedback(db, names, account) {
    return list(db && db.entries).filter((e) => e && text(e.text).trim() && e.id != null).map((e) => ({
      key: sha('spiel', account, e.id), origin: 'game', module: PEON_MODULE.test(text(e.module)) ? text(e.module) : 'Peon',
      kind: KINDS.some((k) => k.key === e.kind) ? e.kind : 'other', area: sanitize(e.area, names) || OTHER_AREA,
      prio: PRIOS.some((p) => p.key === e.prio) ? e.prio : 'mid', text: sanitize(e.text, names).slice(0, MAX_TEXT),
      ver: text(e.ver), zone: sanitize(e.zone, names), market: sanitize(e.market, names),
      t: Number(e.t) || 0, stamp: Number(e.edited) || Number(e.t) || 0,
    }));
  }

  // Gleicher Fehler: Der Zaehler im Spiel laeuft weiter, bis das Spiel ihn loescht. Addiert wird nur der Zuwachs.
  saveError(r) {
    const key = sha(r.source, r.addon, r.where, r.msg);
    const row = this.db.prepare('SELECT n, last, base_first, base_n FROM errors WHERE key = ?').get(key);
    if (!row) {
      this.db.prepare(`INSERT INTO errors(key, source, addon, version, build, place, msg, stack, first, last, n, base_first, base_n)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`)
        .run(key, r.source, r.addon, r.version, r.build, r.where, r.msg.slice(0, MAX_MSG), r.stack.slice(0, MAX_STACK), r.first, r.last, r.n, r.first, r.n);
      return;
    }
    const grown = row.base_first === r.first ? r.n - (row.base_n || 0) : r.n;
    this.db.prepare(`UPDATE errors SET n = ?, last = ?, base_first = ?, base_n = ?,
        version = CASE WHEN ? <> '' THEN ? ELSE version END, build = CASE WHEN ? <> '' THEN ? ELSE build END WHERE key = ?`)
      .run(row.n + Math.max(grown, 0), Math.max(row.last, r.last), r.first, r.n, r.version, r.version, r.build, r.build, key);
  }

  saveFeedback(e) {
    this.db.prepare(`INSERT INTO feedback(key, origin, module, kind, area, prio, text, ver, zone, market, t, edited)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(key) DO UPDATE SET module = excluded.module, kind = excluded.kind, area = excluded.area, prio = excluded.prio,
          text = excluded.text, ver = excluded.ver, zone = excluded.zone, market = excluded.market, edited = excluded.edited`)
      .run(e.key, e.origin, e.module, e.kind, e.area, e.prio, e.text, e.ver, e.zone, e.market, e.t, e.stamp);
  }

  // ---------- Bearbeiten im Manager ----------
  moduleVersion(name) {
    if (name === MANAGER_MODULE) return this.host.version;
    try {
      const toc = fs.readFileSync(path.join(this.host.settings.wowDir, 'Interface', 'AddOns', name, `${name}.toc`), 'utf8');
      const m = /^##\s*Version:\s*(.+?)\s*$/m.exec(toc);
      return m ? m[1] : '';
    } catch { return ''; }
  }

  // Module fuer die Auswahl: Manager und Kern zuerst, dann installierte Peon-Addons
  modules() {
    const withOther = (areas) => [...areas.filter((a) => a !== OTHER_AREA), OTHER_AREA];
    const out = [{ key: MANAGER_MODULE, title: 'Peon Manager', areas: withOther(MANAGER_AREAS) }];
    let names = [];
    try {
      names = fs.readdirSync(path.join(this.host.settings.wowDir, 'Interface', 'AddOns'))
        .filter((n) => PEON_MODULE.test(n) && this.moduleVersion(n)).sort((a, b) => (a === 'Peon' ? -1 : b === 'Peon' ? 1 : a.localeCompare(b)));
    } catch { /* WoW-Ordner fehlt: nur der Manager */ }
    for (const n of names) out.push({ key: n, title: n === 'Peon' ? 'Peon (Kern)' : n.replace(/^Peon_/, ''), areas: withOther(this.areas[n] || []) });
    return out;
  }

  checkFeedback(f) {
    const body = text(f && f.text).trim();
    if (!body) throw new Error('Bitte eine Beschreibung eingeben.');
    if (!PEON_MODULE.test(text(f.module))) throw new Error('Bitte ein Modul wählen.');
    if (!KINDS.some((k) => k.key === f.kind)) throw new Error('Bitte eine Art wählen.');
    if (!PRIOS.some((p) => p.key === f.prio)) throw new Error('Bitte eine Priorität wählen.');
    return { module: f.module, kind: f.kind, prio: f.prio, area: text(f.area).trim() || OTHER_AREA, text: body.slice(0, MAX_TEXT) };
  }

  addFeedback(f) {
    const v = this.checkFeedback(f);
    const t = this.host.now();
    const key = sha('manager', t, crypto.randomUUID());
    this.db.prepare(`INSERT INTO feedback(key, origin, module, kind, area, prio, text, ver, zone, market, t, edited)
        VALUES (?, 'manager', ?, ?, ?, ?, ?, ?, '', '', ?, ?)`)
      .run(key, v.module, v.kind, v.area, v.prio, v.text, this.moduleVersion(v.module), t, t);
    return key;
  }

  updateFeedback(key, f) {
    const v = this.checkFeedback(f);
    const row = this.db.prepare('SELECT module, ver FROM feedback WHERE key = ?').get(text(key));
    if (!row) throw new Error('Diese Rückmeldung gibt es nicht mehr.');
    const ver = row.module === v.module ? row.ver : this.moduleVersion(v.module);
    this.db.prepare('UPDATE feedback SET module = ?, kind = ?, area = ?, prio = ?, text = ?, ver = ?, edited = ? WHERE key = ?')
      .run(v.module, v.kind, v.area, v.prio, v.text, ver, this.host.now(), text(key));
  }

  deleteFeedback(key) { this.db.prepare('DELETE FROM feedback WHERE key = ?').run(text(key)); }
  deleteError(key) { this.db.prepare('DELETE FROM errors WHERE key = ?').run(text(key)); }
  setNote(key, note) { this.db.prepare('UPDATE errors SET note = ? WHERE key = ?').run(text(note).slice(0, MAX_TEXT), text(key)); }
  deleteAll() {
    const n = this.count();
    this.db.exec('DELETE FROM errors; DELETE FROM feedback;');
    if (n) log(this.db, 'rueckmeldung', true, `Alle Rückmeldungen und Fehler gelöscht (${n})`);
    return n;
  }

  // ---------- Lesen ----------
  errorRows() { return this.db.prepare('SELECT key, source, addon, version, build, place, msg, stack, first, last, n, note FROM errors ORDER BY last DESC').all(); }
  feedbackRows() { return this.db.prepare('SELECT key, origin, module, kind, area, prio, text, ver, zone, market, t, edited FROM feedback ORDER BY edited DESC').all(); }
  count() {
    return this.db.prepare('SELECT COUNT(*) AS n FROM errors').get().n + this.db.prepare('SELECT COUNT(*) AS n FROM feedback').get().n;
  }
  reportUrl() { return process.env.PEON_MANAGER_REPORT_URL ?? REPORT_URL; }

  state() {
    this.scan();
    const bridge = fs.existsSync(path.join(this.host.settings.wowDir, 'Interface', 'AddOns', 'Peon_Bridge', 'Peon_Bridge.toc'));
    return { errors: this.errorRows(), feedback: this.feedbackRows(), kinds: KINDS, prios: PRIOS, modules: this.modules(),
      canSend: !!this.reportUrl(), bridge, preview: this.preview() };
  }

  // Was als Naechstes gesendet wird: die aeltesten zuerst, so viele wie passen. Namen auch aus Selbstgeschriebenem ersetzt.
  nextItems() {
    const names = privateNames(this.host.settings.wowDir);
    const clean = (v) => sanitize(v, names);
    const all = [
      ...this.feedbackRows().map((r) => ({ key: r.key, at: r.edited, table: 'feedback', item: {
        type: 'feedback', module: r.module, kind: r.kind, area: clean(r.area), prio: r.prio, text: clean(r.text), version: r.ver || '',
        zone: clean(r.zone), market: clean(r.market), origin: r.origin, t: r.t } })),
      ...this.errorRows().map((r) => ({ key: r.key, at: r.last, table: 'errors', item: {
        type: 'error', addon: r.addon, version: r.version || '', build: r.build || '', where: clean(r.place), msg: clean(r.msg), stack: clean(r.stack),
        note: clean(r.note), source: r.source, first: r.first, last: r.last, n: r.n } })),
    ].sort((a, b) => a.at - b.at);
    const out = [];
    let bytes = 200;
    for (const e of all) {
      bytes += Buffer.byteLength(JSON.stringify(e.item)) + 20;
      if (out.length >= MAX_ITEMS || bytes > MAX_REPORT_BYTES) break;
      out.push(e);
    }
    return { next: out, left: all.length - out.length };
  }

  preview() {
    const { next, left } = this.nextItems();
    const parts = next.map(({ item: i }, k) => {
      const head = `${k + 1}) `;
      if (i.type === 'error') {
        const lines = [`${head}Fehler, ${i.addon}${i.version ? ` ${i.version}` : ''}, ${i.where}, ${i.n}x, zuletzt ${day(i.last)} UTC`, i.msg];
        if (i.stack) lines.push(i.stack);
        if (i.note) lines.push(`Notiz: ${i.note}`);
        return lines.join('\n');
      }
      const where = [i.zone && `Zone ${i.zone}`, i.market && `Markt ${i.market}`].filter(Boolean).join(', ');
      return [`${head}${labelOf(KINDS, i.kind)}, ${i.module}${i.version ? ` ${i.version}` : ''}, ${i.area}, Priorität ${labelOf(PRIOS, i.prio)}${where ? `, ${where}` : ''}`, i.text].join('\n');
    });
    return { text: parts.join('\n\n'), count: next.length, left };
  }

  // An den Worker senden, geloescht wird nur, was er bestaetigt
  async send() {
    const url = this.reportUrl();
    if (!url) throw new Error('Das Senden ist noch nicht eingerichtet.');
    const { next, left } = this.nextItems();
    if (!next.length) throw new Error('Es gibt nichts zu senden.');
    const report = { fmt: REPORT_FMT, manager: this.host.version, items: next.map((e, ref) => ({ ...e.item, ref })) };
    const keep = 'Deine Einträge bleiben erhalten.';
    let res;
    try {
      res = await this.host.fetchImpl(url, {
        method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(report), signal: AbortSignal.timeout(60000),
      });
    } catch (e) {
      throw new Error(`Senden fehlgeschlagen: ${e.message}. ${keep}`);
    }
    if (res.status === 429) throw new Error(`Gerade wurde zu viel gesendet, versuche es später noch einmal. ${keep}`);
    if (!res.ok) throw new Error(`Senden fehlgeschlagen (${res.status}). ${keep}`);
    let done = [];
    try { const b = await res.json(); done = Array.isArray(b.done) ? b.done : []; } catch { /* unten als Fehler gemeldet */ }
    for (const ref of done) {
      const e = next[ref];
      if (e) this.db.prepare(`DELETE FROM ${e.table} WHERE key = ?`).run(e.key);
    }
    if (!done.length) throw new Error(`Senden fehlgeschlagen. ${keep}`);
    log(this.db, 'rueckmeldung', done.length === next.length, `${done.length} von ${next.length} Einträgen gesendet`);
    return { sent: done.length, failed: next.length - done.length, left };
  }
}

module.exports = { ReportStore, sanitize, privateNames, MANAGER_MODULE, REPORT_FMT, MAX_ITEMS };
