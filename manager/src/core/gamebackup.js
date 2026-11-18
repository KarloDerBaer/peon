'use strict';
// Peon Manager - Sicherung der Spieldaten (ab 0.48.0). Sichert die SavedVariables der Peon-Addons (Ledger-Buch, Faenge,
// Broker, Einstellungen ...) aus <WoW-Ordner>\WTF\Account, gepackt im Datenordner unter "Spielsicherung".
//   Wann: vor jedem Installieren oder Aktualisieren von Addons (hoechstens alle 10 Minuten) und einmal am Tag.
//   Was:  Account\<Konto>\SavedVariables\Peon*.lua und Account\<Konto>\<Server>\<Charakter>\SavedVariables\Peon*.lua.
//   Wie viele: je Anlass die neuesten (KEEP), aeltere werden geloescht. Eigene Sicherungen (manuell) ebenso.
//   Wiederherstellen: nur bei geschlossenem WoW (das Spiel schreibt beim Beenden alles neu). Vorher sichert der Manager
//   den jetzigen Stand (Anlass "vor-wiederherstellen"), damit nichts verloren geht.
// Je Sicherung ein Ordner <Datum>_<Anlass> mit info.json und den Dateien als .gz unter ihrem Pfad ab Account.

const fs = require('node:fs');
const path = require('node:path');
const zlib = require('node:zlib');

const INFO = 'info.json';
const KINDS = ['update', 'taeglich', 'manuell', 'vor-wiederherstellen'];
const KEEP = { update: 5, taeglich: 7, manuell: 5, 'vor-wiederherstellen': 3 };
const DAILY_SEC = 20 * 3600;        // taeglich: wenn die letzte taegliche aelter ist
const UPDATE_GAP_SEC = 10 * 60;     // vor Updates hoechstens so oft
const FILE_RE = /^Peon[A-Za-z0-9_]*\.lua$/;
const ID_RE = /^\d{4}-\d{2}-\d{2}_\d{6}_[a-z-]+(-\d+)?$/;

function stamp(now) {
  const d = new Date(now * 1000);
  const p = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}_${p(d.getHours())}${p(d.getMinutes())}${p(d.getSeconds())}`;
}

function dirs(p) {
  try { return fs.readdirSync(p, { withFileTypes: true }).filter((d) => d.isDirectory()).map((d) => d.name); } catch { return []; }
}

function luaFiles(p) {
  try { return fs.readdirSync(p, { withFileTypes: true }).filter((d) => d.isFile() && FILE_RE.test(d.name)).map((d) => d.name); } catch { return []; }
}

class GameBackup {
  // host: { settings: { wowDir }, dbDir, now(), log(ok, text) }
  constructor(host) {
    this.host = host;
    this.dir = path.join(host.dbDir, 'Spielsicherung');
  }

  accountDir() {
    const w = this.host.settings && this.host.settings.wowDir;
    return w ? path.join(w, 'WTF', 'Account') : null;
  }

  // Alle Peon-Dateien: [{ rel: 'Konto/SavedVariables/Peon.lua', abs }]
  sources() {
    const base = this.accountDir();
    if (!base) return [];
    const out = [];
    for (const acc of dirs(base)) {
      const sv = path.join(base, acc, 'SavedVariables');
      for (const f of luaFiles(sv)) out.push({ rel: [acc, 'SavedVariables', f].join('/'), abs: path.join(sv, f) });
      for (const realm of dirs(path.join(base, acc))) {
        if (realm === 'SavedVariables') continue;
        for (const ch of dirs(path.join(base, acc, realm))) {
          const csv = path.join(base, acc, realm, ch, 'SavedVariables');
          for (const f of luaFiles(csv)) out.push({ rel: [acc, realm, ch, 'SavedVariables', f].join('/'), abs: path.join(csv, f) });
        }
      }
    }
    return out;
  }

  list() {
    const out = [];
    for (const id of dirs(this.dir)) {
      if (!ID_RE.test(id)) continue;
      try {
        const info = JSON.parse(fs.readFileSync(path.join(this.dir, id, INFO), 'utf8'));
        out.push({ id, t: info.t, kind: info.kind, files: info.files.length, bytes: info.bytes, raw: info.raw });
      } catch { /* halbe oder fremde Ordner nicht zeigen */ }
    }
    return out.sort((a, b) => b.t - a.t || (a.id < b.id ? 1 : -1));
  }

  // Sicherung anlegen. Rueckgabe { id, files, bytes } oder null (keine Peon-Dateien)
  create(kind = 'manuell') {
    if (!KINDS.includes(kind)) throw new Error(`Unbekannter Anlass: ${kind}`);
    const src = this.sources();
    if (!src.length) return null;
    const now = this.host.now();
    let id = `${stamp(now)}_${kind}`;
    for (let i = 2; fs.existsSync(path.join(this.dir, id)); i++) id = `${stamp(now)}_${kind}-${i}`;
    const target = path.join(this.dir, id);
    fs.mkdirSync(target, { recursive: true });
    try {
      let bytes = 0, raw = 0;
      const files = [];
      for (const f of src) {
        let data;
        try { data = fs.readFileSync(f.abs); } catch { continue; }   // gerade geschrieben oder gesperrt: ueberspringen
        const gz = zlib.gzipSync(data);
        const to = path.join(target, ...f.rel.split('/')) + '.gz';
        fs.mkdirSync(path.dirname(to), { recursive: true });
        fs.writeFileSync(to, gz);
        bytes += gz.length; raw += data.length;
        files.push(f.rel);
      }
      fs.writeFileSync(path.join(target, INFO), JSON.stringify({ app: 'Peon Manager', t: now, kind, files, bytes, raw }, null, 1));
      this.prune(kind);
      this.log(true, `Spieldaten gesichert (${kind}): ${files.length} Dateien`);
      return { id, files: files.length, bytes };
    } catch (e) {
      fs.rmSync(target, { recursive: true, force: true });
      this.log(false, `Spieldaten sichern (${kind}): ${e.message}`);
      throw e;
    }
  }

  // Aeltere Sicherungen eines Anlasses loeschen
  prune(kind) {
    const keep = KEEP[kind] || 5;
    const same = this.list().filter((b) => b.kind === kind);
    for (const b of same.slice(keep)) fs.rmSync(path.join(this.dir, b.id), { recursive: true, force: true });
  }

  // Vor Updates: hoechstens alle 10 Minuten. Fehler duerfen ein Update nie aufhalten.
  beforeUpdate() {
    const last = this.list().find((b) => b.kind === 'update');
    if (last && this.host.now() - last.t < UPDATE_GAP_SEC) return null;
    try { return this.create('update'); } catch { return null; }
  }

  // Einmal am Tag (beim Start und im Takt des Managers)
  dailyIfDue() {
    const last = this.list().find((b) => b.kind === 'taeglich');
    if (last && this.host.now() - last.t < DAILY_SEC) return null;
    try { return this.create('taeglich'); } catch { return null; }
  }

  // Wiederherstellen. wowRunning: WoW laeuft (dann nie). Rueckgabe { ok, files, before } oder { ok: false, error }
  restore(id, wowRunning) {
    if (wowRunning) return { ok: false, error: 'WoW läuft. Bitte WoW zuerst beenden, sonst überschreibt das Spiel beim Beenden alles wieder.' };
    if (typeof id !== 'string' || !ID_RE.test(id)) return { ok: false, error: 'Diese Sicherung gibt es nicht.' };
    const dir = path.join(this.dir, id);
    let info;
    try { info = JSON.parse(fs.readFileSync(path.join(dir, INFO), 'utf8')); } catch { return { ok: false, error: 'Diese Sicherung gibt es nicht.' }; }
    const base = this.accountDir();
    if (!base || !fs.existsSync(base)) return { ok: false, error: 'Im WoW-Ordner gibt es kein WTF\\Account.' };
    let before = null;
    try { before = this.create('vor-wiederherstellen'); } catch (e) { return { ok: false, error: `Der jetzige Stand ließ sich nicht sichern: ${e.message}` }; }
    let n = 0;
    for (const rel of info.files) {
      const parts = String(rel).split('/');
      // nur Pfade, wie create sie schreibt: kein .., Datei Peon*.lua im Ordner SavedVariables
      if (parts.some((p) => !p || p === '.' || p === '..') || !FILE_RE.test(parts[parts.length - 1]) || parts[parts.length - 2] !== 'SavedVariables') continue;
      const from = path.join(dir, ...parts) + '.gz';
      const to = path.join(base, ...parts);
      try {
        const data = zlib.gunzipSync(fs.readFileSync(from));
        fs.mkdirSync(path.dirname(to), { recursive: true });
        fs.writeFileSync(`${to}.neu`, data);
        fs.renameSync(`${to}.neu`, to);
        n++;
      } catch (e) {
        this.log(false, `Spieldaten wiederherstellen ${rel}: ${e.message}`);
      }
    }
    this.log(true, `Spieldaten wiederhergestellt aus ${id}: ${n} Dateien`);
    return { ok: true, files: n, before: before && before.id };
  }

  remove(id) {
    if (typeof id !== 'string' || !ID_RE.test(id) || !fs.existsSync(path.join(this.dir, id))) return false;
    fs.rmSync(path.join(this.dir, id), { recursive: true, force: true });
    return true;
  }

  log(ok, text) {
    try { if (this.host.log) this.host.log(ok, text); } catch { /* Protokoll ist nicht wichtig genug */ }
  }
}

module.exports = { GameBackup, KEEP, KINDS };
