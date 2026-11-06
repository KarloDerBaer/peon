'use strict';
// Peon Manager - Fehlerspeicher (Reiter Debug, gehoert zum Manager, nicht zu einem Modul).
// Liest die abgefangenen Fehler des Kerns (WTF\Account\<Konto>\SavedVariables\Peon.lua, PeonDB.errors) und die
// BugGrabber-Eintraege, die ein Peon-Addon nennen (!BugGrabber.lua, BugGrabberDB.errors), in die Tabelle errors von peon.db.
// Konto- und Charakternamen sowie Pfade werden schon beim Einlesen ersetzt, damit sie nie in einem Bericht landen.
//
// Leeren: Der Manager merkt sich den spaetesten geloeschten Zeitpunkt (meta errorsClearBefore) und schreibt ihn in Data.lua.
// Die Bridge loescht beim naechsten Laden im Spiel alles bis dahin. Bis das Spiel die Datei neu schreibt, ueberspringt der
// Manager diese Eintraege. Neuere Fehler bleiben auf beiden Seiten erhalten.

const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const { parseLua } = require('./lua');
const { log } = require('./db');

// Adresse des Workers (worker/peon-fehler). Leer: Senden ist nicht eingerichtet, der Export geht trotzdem.
const REPORT_URL = 'https://peon-fehler.karloderbaer.workers.dev/bericht';
const REPORT_FMT = 1;
const MAX_REPORT_BYTES = 50000;   // der Worker nimmt hoechstens 64 KB an
const MAX_STACK = 1500, MAX_MSG = 1000;

const CORE_FILE = 'Peon.lua', GRABBER_FILE = '!BugGrabber.lua';
const PEON_ADDON = /(?:AddOns[/\\]|AddOn '|tainted by ')(Peon(?:_\w+)?)/;
const NOT_NAMES = /^(peon|interface|addons|savedvariables|blizzard)$/i;

const list = (x) => (Array.isArray(x) ? x : x && typeof x === 'object' ? Object.values(x) : []);
const text = (x) => (x === undefined || x === null ? '' : String(x));
const escapeRe = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

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

class ErrorStore {
  constructor(host) {
    this.host = host;
    this.seen = new Map();   // Datei -> Zeitpunkt der letzten Aenderung
  }

  get db() { return this.host.db; }
  clearBefore() { return this.host.meta('errorsClearBefore') || 0; }

  files() {
    const base = path.join(this.host.settings.wowDir, 'WTF', 'Account');
    let accounts = [];
    try { accounts = fs.readdirSync(base, { withFileTypes: true }).filter((d) => d.isDirectory()).map((d) => d.name); } catch { return []; }
    const out = [];
    for (const a of accounts) {
      for (const name of [CORE_FILE, GRABBER_FILE]) {
        const file = path.join(base, a, 'SavedVariables', name);
        if (fs.existsSync(file)) out.push({ file, grabber: name === GRABBER_FILE });
      }
    }
    return out;
  }

  // Geaenderte Dateien einlesen. Rueckgabe: true, wenn etwas eingelesen wurde
  scan() {
    let changed = false, names = null;
    for (const f of this.files()) {
      let mtime = 0;
      try { mtime = fs.statSync(f.file).mtimeMs; } catch { continue; }
      if (this.seen.get(f.file) === mtime) continue;
      names = names || privateNames(this.host.settings.wowDir);
      try {
        const g = parseLua(fs.readFileSync(f.file));
        const rows = f.grabber ? this.fromGrabber(g.BugGrabberDB, names) : this.fromCore(g.PeonDB, names);
        for (const r of rows) this.save(r);
        this.seen.set(f.file, mtime);
        changed = true;
      } catch (e) {
        log(this.db, 'fehler', false, `${path.basename(f.file)}: ${sanitize(e.message, names)}`);
        this.seen.set(f.file, mtime);   // erst bei der naechsten Aenderung wieder versuchen
      }
    }
    return changed;
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

  save(r) {
    if (r.last <= this.clearBefore()) return;
    const key = crypto.createHash('sha1').update([r.source, r.addon, r.where, r.msg].join('\n')).digest('hex');
    this.db.prepare(`INSERT INTO errors(key, source, addon, version, build, place, msg, stack, first, last, n)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(key) DO UPDATE SET first = MIN(first, excluded.first), n = MAX(n, excluded.n),
          version = CASE WHEN excluded.last >= last AND excluded.version <> '' THEN excluded.version ELSE version END,
          build = CASE WHEN excluded.last >= last AND excluded.build <> '' THEN excluded.build ELSE build END,
          last = MAX(last, excluded.last)`)
      .run(key, r.source, r.addon, r.version, r.build, r.where, r.msg.slice(0, MAX_MSG), r.stack.slice(0, MAX_STACK), r.first, r.last, r.n);
  }

  rows() { return this.db.prepare('SELECT * FROM errors ORDER BY last DESC').all(); }
  count() { return this.db.prepare('SELECT COUNT(*) AS n FROM errors').get().n; }
  reportUrl() { return process.env.PEON_MANAGER_REPORT_URL ?? REPORT_URL; }

  state() {
    this.scan();
    return { errors: this.rows(), canSend: !!this.reportUrl(), text: this.exportText() };
  }

  // Bericht fuer den Worker: neueste zuerst, was nicht mehr passt, wird nur gezaehlt
  report() {
    const out = { fmt: REPORT_FMT, manager: this.host.version, errors: [], omitted: 0 };
    let bytes = 200;
    for (const r of this.rows()) {
      const e = { source: r.source, addon: r.addon, version: r.version, build: r.build, where: r.place, msg: r.msg, stack: r.stack, first: r.first, last: r.last, n: r.n };
      bytes += Buffer.byteLength(JSON.stringify(e));
      if (bytes > MAX_REPORT_BYTES) out.omitted++;
      else out.errors.push(e);
    }
    return out;
  }

  // Lesbarer Text zum Weitergeben (Discord, Nachricht)
  exportText() {
    const rows = this.rows();
    if (!rows.length) return '';
    const day = (t) => new Date(t * 1000).toISOString().slice(0, 16).replace('T', ' ');
    const lines = [`Peon Fehlerbericht, Manager ${this.host.version}, ${rows.length} Fehler`];
    rows.forEach((r, i) => {
      lines.push('', `${i + 1}) ${r.addon}${r.version ? ` ${r.version}` : ''}, ${r.place}, ${r.n}x, zuletzt ${day(r.last)} UTC`, r.msg);
      if (r.stack) lines.push(...r.stack.split('\n').filter(Boolean).slice(0, 6));
    });
    return lines.join('\n');
  }

  // Bis zum spaetesten vorhandenen Fehler leeren, im Manager sofort, im Spiel nach dem naechsten Laden
  clear() {
    const r = this.db.prepare('SELECT MAX(last) AS t, COUNT(*) AS n FROM errors').get();
    if (!r.n) return 0;
    this.host.meta('errorsClearBefore', Math.max(this.clearBefore(), r.t));
    this.db.prepare('DELETE FROM errors WHERE last <= ?').run(r.t);
    log(this.db, 'fehler', true, `Fehlerspeicher geleert (${r.n})`);
    this.host.bridgeInstalled();   // Data.lua mit der neuen Marke schreiben
    return r.n;
  }

  // An den Worker senden, erst nach seiner Bestaetigung leeren
  async send() {
    const url = this.reportUrl();
    if (!url) throw new Error('Das Senden ist noch nicht eingerichtet. Nutze den Export als Text.');
    const report = this.report();
    if (!report.errors.length) throw new Error('Es gibt keine Fehler zum Senden.');
    let res;
    try {
      res = await this.host.fetchImpl(url, {
        method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(report), signal: AbortSignal.timeout(20000),
      });
    } catch (e) {
      throw new Error(`Senden fehlgeschlagen, der Fehlerspeicher bleibt erhalten: ${e.message}`);
    }
    if (res.status === 429) throw new Error('Gerade wurden zu viele Berichte gesendet. Der Fehlerspeicher bleibt erhalten, versuche es später noch einmal.');
    if (!res.ok) throw new Error(`Senden fehlgeschlagen (${res.status}), der Fehlerspeicher bleibt erhalten.`);
    log(this.db, 'fehler', true, `Fehlerbericht gesendet (${report.errors.length})`);
    this.clear();
    return { sent: report.errors.length, omitted: report.omitted };
  }
}

module.exports = { ErrorStore, sanitize, privateNames, REPORT_FMT };
