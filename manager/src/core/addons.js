'use strict';
// Peon Manager - Addons installieren und aktualisieren (Peon_GitHub_Design.md 5.3 bis 5.5).
// Ablauf je Addon: Zip laden, Groesse und SHA-256 gegen das Manifest pruefen, in einen Zwischenordner entpacken,
// Inhalt pruefen, alten Ordner in die Sicherung, neuen an seine Stelle, jede Datei pruefen, bei Fehler zuruecktauschen.
// Fremde Addons und WTF werden nie angefasst. Ist ein Ordner eine Junction, gilt er als Entwicklung (Repo) und bleibt, wie er ist.

const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { readZip } = require('./zip');
const { log } = require('./db');

const REPO_URL = 'https://github.com/KarloDerBaer/peon';
const API_URL = 'https://api.github.com/repos/KarloDerBaer/peon';
const NAME_RE = /^Peon(_[A-Za-z0-9]+)?$/;              // nur Peon-Addons
const FILE_RE = /^Peon(_[A-Za-z0-9]+)?-\d+\.\d+\.\d+\.zip$/;
const TAG_RE = /^v\d{4}\.\d{2}\.\d{2}(\.\d+)?(-test)?$/;
const VERSION_RE = /^\d+\.\d+\.\d+$/;
const MAX_ZIP = 64 * 1024 * 1024;
const MAX_MANIFEST = 2 * 1024 * 1024;
const MAX_NEWS_TEXT = 300;                             // Zeichen je Zeile "Was ist neu"
const DATA_FILE = 'Data.lua';                          // gehoert dem Manager, siehe Peon_Bridge
const PLACEHOLDER = '-- Peon_Bridge - Data.lua\n-- Platzhalter. Der Peon Manager ueberschreibt diese Datei mit seinen Werten (PeonBridgeData). Nie mit ausliefern.\n';

function cmpVersion(a, b) {
  const pa = String(a).split('.').map(Number), pb = String(b).split('.').map(Number);
  for (let i = 0; i < Math.max(pa.length, pb.length); i++) {
    const d = (pa[i] || 0) - (pb[i] || 0);
    if (d) return d;
  }
  return 0;
}

// Neuestes Release aus der Liste von GitHub. Die Reihenfolge dort ist nicht nach Datum (v2026.11.06 steht vor
// v2026.11.06.2-test), also zaehlt der Name: Datum, dann Nummer des Tages. Bei gleichem Stand geht das normale Release vor.
function newestTag(list) {
  const key = (tag) => {
    const m = tag.match(/^v(\d{4})\.(\d{2})\.(\d{2})(?:\.(\d+))?(-test)?$/);
    return [Number(m[1]), Number(m[2]), Number(m[3]), Number(m[4] || 1), m[5] ? 0 : 1];
  };
  const tags = list.filter((x) => x && !x.draft && TAG_RE.test(String(x.tag_name))).map((x) => x.tag_name);
  return tags.sort((a, b) => {
    const ka = key(a), kb = key(b);
    for (let i = 0; i < ka.length; i++) if (ka[i] !== kb[i]) return kb[i] - ka[i];
    return 0;
  })[0] || null;
}

// Manifest pruefen: Es kommt aus dem Netz, also jede Angabe, die in Pfade oder Adressen wandert
function checkManifest(m) {
  if (!m || typeof m !== 'object' || m.fmt !== 1) throw new Error('Manifest hat ein unbekanntes Format');
  if (!TAG_RE.test(String(m.release))) throw new Error('Manifest: Name des Release ungültig');
  if (!Array.isArray(m.addons) || !m.addons.length) throw new Error('Manifest enthält keine Addons');
  const seen = new Set();
  for (const a of m.addons) {
    if (!a || !NAME_RE.test(String(a.name))) throw new Error(`Manifest: Addon-Name ungültig: ${a && a.name}`);
    if (seen.has(a.name)) throw new Error(`Manifest: ${a.name} doppelt`);
    seen.add(a.name);
    if (!VERSION_RE.test(String(a.version))) throw new Error(`Manifest: Version von ${a.name} ungültig`);
    if (!FILE_RE.test(String(a.file)) || !a.file.startsWith(`${a.name}-`)) throw new Error(`Manifest: Datei von ${a.name} ungültig`);
    if (!/^[0-9a-f]{64}$/.test(String(a.sha256))) throw new Error(`Manifest: Prüfsumme von ${a.name} ungültig`);
    if (!Number.isInteger(a.size) || a.size <= 0 || a.size > MAX_ZIP) throw new Error(`Manifest: Größe von ${a.name} ungültig`);
    if (!Array.isArray(a.deps) || a.deps.some((d) => !NAME_RE.test(String(d)))) throw new Error(`Manifest: Abhängigkeiten von ${a.name} ungültig`);
  }
  for (const a of m.addons) for (const d of a.deps) if (!seen.has(d)) throw new Error(`Manifest: ${a.name} braucht ${d}, das fehlt`);
  return m;
}

// Eintrag des Zip pruefen und relativen Pfad liefern (Schutz gegen Pfade ausserhalb des Addon-Ordners)
function safeEntry(name, addon) {
  if (name.includes('\\') || name.includes(':') || name.startsWith('/') || name.includes('\0')) throw new Error(`Ungültiger Pfad im Zip: ${name}`);
  const parts = name.split('/');
  if (parts[0] !== addon) throw new Error(`Das Zip darf nur den Ordner ${addon} enthalten, gefunden: ${name}`);
  const rest = parts.slice(1);
  const dir = rest[rest.length - 1] === '';
  if (dir) rest.pop();
  if (rest.some((p) => p === '' || p === '.' || p === '..')) throw new Error(`Ungültiger Pfad im Zip: ${name}`);
  return { rel: rest.join('/'), dir };
}

// Kurze Texte aus dem Manifest: nur, was wirklich Text ist. installed gesetzt: nur Neueres, sonst die neueste Version.
// Ohne die Angabe news (Manifest von vor dem Update-Fenster) bleibt die Liste leer.
function newsSince(news, installed) {
  const clean = (Array.isArray(news) ? news : [])
    .filter((n) => n && VERSION_RE.test(String(n.version)) && Array.isArray(n.short))
    .map((n) => ({ version: n.version, short: n.short.filter((s) => typeof s === 'string' && s).map((s) => s.slice(0, MAX_NEWS_TEXT)) }))
    .filter((n) => n.short.length);
  return installed ? clean.filter((n) => cmpVersion(n.version, installed) > 0) : clean.slice(0, 1);
}

function readTocVersion(file) {
  try {
    const m = fs.readFileSync(file, 'utf8').match(/^##\s*Version\s*:\s*(\S+)/m);
    return m ? m[1] : null;
  } catch { return null; }
}

function sha256(buf) { return crypto.createHash('sha256').update(buf).digest('hex'); }

// Ordner verschieben, auch ueber Laufwerke hinweg
function moveDir(from, to) {
  fs.mkdirSync(path.dirname(to), { recursive: true });
  try {
    fs.renameSync(from, to);
  } catch (e) {
    if (e.code !== 'EXDEV') throw e;
    fs.cpSync(from, to, { recursive: true });
    fs.rmSync(from, { recursive: true });
  }
}

// WoW-Ordner suchen: aus der Registrierung (installPaths) und an den ueblichen Orten. Rueckgabe: Liste, beste zuerst
function findWowDirs({ installPaths = [], drives = ['C', 'D', 'E', 'F', 'G', 'H'], exists = fs.existsSync } = {}) {
  const out = [];
  const add = (d) => { if (d && !out.some((x) => x.toLowerCase() === d.toLowerCase()) && exists(path.win32.join(d, 'Wow.exe'))) out.push(d); };
  for (const p of installPaths) {
    const base = p.replace(/[\\/]+$/, '');
    add(path.win32.basename(base).toLowerCase() === '_forever_' ? base : path.win32.join(base, '_forever_'));
    add(path.win32.join(path.win32.dirname(base), '_forever_'));
  }
  for (const d of drives) {
    for (const s of ['Program Files (x86)', 'Program Files', '', 'Games', 'Spiele', 'Battle.net']) {
      add(path.win32.join(`${d}:\\`, s, 'World of Warcraft', '_forever_'));
    }
  }
  return out;
}

class AddonManager {
  constructor(host, { releaseBase = REPO_URL, apiBase = API_URL, testHook = null } = {}) {
    this.host = host;
    this.releaseBase = releaseBase.replace(/\/+$/, '');
    this.apiBase = apiBase.replace(/\/+$/, '');
    this.testHook = testHook;
    this.busy = false;
  }

  get addonsDir() { return path.join(this.host.settings.wowDir, 'Interface', 'AddOns'); }
  get backupDir() { return path.join(this.host.dbDir, 'backup'); }
  get tmpDir() { return path.join(this.host.dbDir, 'tmp'); }
  get manifest() { return this.host.meta('manifest'); }

  // Liegt unter dem WoW-Ordner wirklich ein Spiel? (Vor dem ersten Start von WoW fehlt Interface noch)
  wowValid() {
    const w = this.host.settings.wowDir;
    return fs.existsSync(path.join(w, 'Wow.exe')) || fs.existsSync(path.join(w, 'Interface'));
  }

  // Zustand im AddOns-Ordner: { present, version, dev, target }
  installed(name) {
    const dir = path.join(this.addonsDir, name);
    let st;
    try { st = fs.lstatSync(dir); } catch { return { present: false, version: null, dev: false }; }
    const dev = st.isSymbolicLink();
    return { present: true, dev, version: readTocVersion(path.join(dir, name + '.toc')) };
  }

  async get(url, headers = {}) {
    const r = await this.host.fetchImpl(url, { headers: { 'User-Agent': 'PeonManager', ...headers } });
    return r;
  }

  // Neues Manifest holen. Rueckgabe: { ok, manifest, error, noRelease }. Der letzte gute Stand bleibt gemerkt.
  async check() {
    const channel = this.host.settings.addons.channel;
    const at = this.host.now();
    try {
      const m = channel === 'test' ? await this.fetchTestManifest() : await this.fetchManifestUrl(`${this.releaseBase}/releases/latest/download/manifest.json`);
      if (!m) {
        // Kein Release (mehr): Das alte Manifest zeigt auf Dateien, die es nicht mehr gibt
        this.host.meta('manifest', null);
        this.host.meta('addonCheck', { t: at, ok: true, noRelease: true, channel });
        return { ok: true, noRelease: true };
      }
      checkManifest(m);
      this.host.meta('manifest', m);
      this.host.meta('addonCheck', { t: at, ok: true, channel, release: m.release });
      return { ok: true, manifest: m };
    } catch (e) {
      this.host.meta('addonCheck', { t: at, ok: false, channel, error: e.message });
      log(this.host.db, 'addons', false, `Nach Updates suchen: ${e.message}`);
      return { ok: false, error: e.message };
    }
  }

  async fetchManifestUrl(url) {
    const r = await this.get(url, { Accept: 'application/json, application/octet-stream' });
    if (r.status === 404) return null;
    if (r.status !== 200) throw new Error(`Antwort ${r.status}`);
    const text = await r.text();
    if (text.length > MAX_MANIFEST) throw new Error('Manifest ist zu groß');
    try { return JSON.parse(text); } catch { throw new Error('Manifest ist kein gültiges JSON'); }
  }

  // Kanal Test: Liste der Releases (Schnittstelle von GitHub, 60 Abfragen je Stunde), mit ETag und Zwischenspeicher
  async fetchTestManifest() {
    const cache = this.host.meta('releasesCache') || {};
    const r = await this.get(`${this.apiBase}/releases?per_page=10`, {
      Accept: 'application/vnd.github+json', ...(cache.etag ? { 'If-None-Match': cache.etag } : {}),
    });
    let tag = cache.tag || null;
    if (r.status === 200) {
      const list = JSON.parse(await r.text());
      tag = Array.isArray(list) ? newestTag(list) : null;
      const etag = r.headers && r.headers.get ? r.headers.get('etag') : null;
      this.host.meta('releasesCache', { etag: etag || null, tag });
    } else if (r.status !== 304 && r.status !== 404) {
      throw new Error(`Antwort ${r.status}`);
    }
    if (!tag) return null;
    return this.fetchManifestUrl(`${this.releaseBase}/releases/download/${tag}/manifest.json`);
  }

  // Liste fuer die Ansicht Module
  list() {
    const m = this.manifest;
    const out = [];
    if (m) {
      for (const a of m.addons) {
        const i = this.installed(a.name);
        let status = 'missing';
        if (i.dev) status = 'dev';
        else if (i.present) status = i.version && cmpVersion(i.version, a.version) >= 0 ? (i.version === a.version ? 'current' : 'newer') : 'update';
        out.push({ name: a.name, title: a.title, desc: a.desc, available: a.version, installed: i.version, present: i.present, dev: i.dev, status,
          news: newsSince(a.news, status === 'update' ? i.version : null), deps: a.deps, size: a.size, managerOnly: !!a.managerOnly, removable: this.removeBlock(a.name) === null });
      }
    } else {
      // ohne Manifest: nur zeigen, was da ist (Name mit Peon, eigene TOC)
      let names = [];
      try { names = fs.readdirSync(this.addonsDir).filter((n) => NAME_RE.test(n)); } catch { /* fehlt */ }
      for (const n of names.sort()) {
        const i = this.installed(n);
        if (!i.version) continue;
        out.push({ name: n, title: n, desc: '', available: null, installed: i.version, present: true, dev: i.dev, status: i.dev ? 'dev' : 'unknown', news: [], deps: [], size: 0, managerOnly: false, removable: false });
      }
    }
    return out;
  }

  // Grund, warum ein Addon nicht entfernt werden darf, sonst null
  removeBlock(name) {
    const m = this.manifest;
    const a = m && m.addons.find((x) => x.name === name);
    if (!a) return 'Dieses Addon verwaltet der Manager nicht.';
    const i = this.installed(name);
    if (!i.present) return 'Nicht installiert.';
    if (i.dev) return 'Entwicklung (Repo): bleibt, wie es ist.';
    if (a.managerOnly) return 'Gehört fest zum Peon Manager.';
    const users = m.addons.filter((x) => x.deps.includes(name) && !x.managerOnly && this.installed(x.name).present).map((x) => x.name);
    if (users.length) return `Wird noch gebraucht von ${users.join(', ')}.`;
    for (const mod of this.host.moduleList()) {
      if (mod.enabled && mod.needs.includes(name)) return `Wird vom Modul ${mod.title} gebraucht.`;
    }
    return null;
  }

  // Reihenfolge: erst Abhaengigkeiten, Peon_Bridge immer mit
  plan(names) {
    const m = this.manifest;
    if (!m) throw new Error('Noch kein Manifest geladen. Bitte erst nach Updates suchen.');
    const out = [];
    const visit = (n, stack) => {
      if (out.includes(n)) return;
      if (stack.includes(n)) throw new Error(`Abhängigkeit im Kreis: ${n}`);
      const a = m.addons.find((x) => x.name === n);
      if (!a) throw new Error(`Unbekanntes Addon: ${n}`);
      for (const d of a.deps) visit(d, [...stack, n]);
      out.push(n);
    };
    for (const n of names) visit(n, []);
    for (const a of m.addons) if (a.managerOnly) visit(a.name, []);
    return out;
  }

  checkManagerVersion() {
    const m = this.manifest;
    const min = m && m.manager && m.manager.minVersion;
    if (min && VERSION_RE.test(min) && cmpVersion(this.host.version, min) < 0) {
      throw new Error(`Dieses Release braucht mindestens Peon Manager ${min}. Bitte zuerst den Manager aktualisieren.`);
    }
  }

  // Installieren und Aktualisieren. Rueckgabe: { done: [{ name, version, from }], skipped: [{ name, why }], failed: [{ name, error }] }
  async install(names) {
    if (this.busy) throw new Error('Es läuft schon eine Installation.');
    this.busy = true;
    const res = { done: [], skipped: [], failed: [] };
    try {
      if (!this.wowValid()) throw new Error(`Im WoW-Ordner liegt kein Spiel: ${this.host.settings.wowDir}`);
      this.checkManagerVersion();
      const m = this.manifest;
      for (const n of this.plan(names)) {
        const a = m.addons.find((x) => x.name === n);
        const i = this.installed(n);
        if (i.dev) { res.skipped.push({ name: n, why: 'Entwicklung (Repo)' }); continue; }
        if (i.present && i.version && cmpVersion(i.version, a.version) >= 0) { res.skipped.push({ name: n, why: 'aktuell' }); continue; }
        // Fehlt eine Abhaengigkeit, weil sie gescheitert ist, das Addon nicht installieren
        const missing = a.deps.filter((d) => res.failed.some((f) => f.name === d));
        if (missing.length) { res.failed.push({ name: n, error: `${missing.join(', ')} fehlt` }); continue; }
        try {
          await this.installOne(a, m.release, i);
          res.done.push({ name: n, version: a.version, from: i.version });
          log(this.host.db, 'addons', true, `${n} ${a.version} installiert${i.version ? ` (vorher ${i.version})` : ''}`);
        } catch (e) {
          res.failed.push({ name: n, error: e.message });
          log(this.host.db, 'addons', false, `${n} ${a.version}: ${e.message}`);
        }
      }
      if (res.done.some((d) => m.addons.find((x) => x.name === d.name).managerOnly)) this.host.bridgeInstalled();
    } finally {
      this.busy = false;
    }
    return res;
  }

  async installOne(a, tag, was) {
    const url = `${this.releaseBase}/releases/download/${tag}/${a.file}`;
    const r = await this.get(url);
    if (r.status !== 200) throw new Error(`Laden fehlgeschlagen (Antwort ${r.status})`);
    const zip = Buffer.from(await r.arrayBuffer());
    if (zip.length !== a.size) throw new Error('Größe stimmt nicht mit dem Manifest überein');
    if (sha256(zip) !== a.sha256) throw new Error('Prüfsumme stimmt nicht mit dem Manifest überein');
    const entries = readZip(zip);
    if (!entries.length) throw new Error('Das Zip ist leer');

    const work = path.join(this.tmpDir, `${a.name}-${crypto.randomBytes(4).toString('hex')}`);
    const target = path.join(this.addonsDir, a.name);
    let backup = null;
    let swapped = false;
    try {
      // In den Zwischenordner entpacken und Inhalt pruefen
      const files = [];
      for (const e of entries) {
        const { rel, dir } = safeEntry(e.name, a.name);
        if (dir || rel === '') continue;
        if (rel.toLowerCase() === DATA_FILE.toLowerCase() && a.managerOnly) continue;   // gehoert dem Manager
        const f = path.join(work, a.name, ...rel.split('/'));
        fs.mkdirSync(path.dirname(f), { recursive: true });
        fs.writeFileSync(f, e.data);
        files.push({ rel, hash: sha256(e.data) });
      }
      const toc = path.join(work, a.name, a.name + '.toc');
      if (!fs.existsSync(toc)) throw new Error(`Im Zip fehlt ${a.name}.toc`);
      if (readTocVersion(toc) !== a.version) throw new Error('Version im Zip passt nicht zum Manifest');

      // Data.lua der Bridge bleibt erhalten, sonst Platzhalter
      if (a.managerOnly) {
        const old = path.join(target, DATA_FILE);
        const f = path.join(work, a.name, DATA_FILE);
        if (fs.existsSync(old)) fs.copyFileSync(old, f);
        else fs.writeFileSync(f, PLACEHOLDER, 'utf8');
      }

      // Tausch: alter Ordner in die Sicherung, neuer an seine Stelle
      fs.mkdirSync(this.addonsDir, { recursive: true });
      if (was.present) {
        backup = this.backupPath(a.name, was.version);
        moveDir(target, backup);
      }
      swapped = true;
      fs.cpSync(path.join(work, a.name), target, { recursive: true });
      if (this.testHook) this.testHook('afterCopy', a.name, target);
      // Jede Datei nach dem Tausch pruefen (Windows hat im AddOns-Ordner schon Schreiben verweigert)
      for (const x of files) {
        const f = path.join(target, ...x.rel.split('/'));
        if (!fs.existsSync(f) || sha256(fs.readFileSync(f)) !== x.hash) throw new Error(`Datei nicht richtig geschrieben: ${x.rel}`);
      }
    } catch (e) {
      if (swapped) {
        try {
          fs.rmSync(target, { recursive: true, force: true });
          if (backup) moveDir(backup, target);
        } catch (e2) {
          throw new Error(`${e.message}. Zurücktauschen schlug auch fehl (${e2.message}), die alte Fassung liegt in ${backup}`);
        }
        throw new Error(`${e.message}. Alte Fassung wiederhergestellt.`);
      }
      throw e;
    } finally {
      fs.rmSync(work, { recursive: true, force: true });
    }
  }

  backupPath(name, version) {
    const base = path.join(this.backupDir, `${name}-${version || 'unbekannt'}`);
    if (!fs.existsSync(base)) return base;
    for (let i = 2; ; i++) if (!fs.existsSync(`${base}-${i}`)) return `${base}-${i}`;
  }

  // Entfernen: Der Ordner wandert in die Sicherung, die Einstellungen in WTF bleiben
  remove(name) {
    if (this.busy) throw new Error('Es läuft gerade eine Installation.');
    const block = this.removeBlock(name);
    if (block) throw new Error(block);
    const i = this.installed(name);
    moveDir(path.join(this.addonsDir, name), this.backupPath(name, i.version));
    log(this.host.db, 'addons', true, `${name} ${i.version || ''} entfernt`);
    return true;
  }

  // Neuere Version des Managers laut Manifest: { version, feed } (feed = Ordner des Release mit latest.yml), sonst null
  managerUpdate() {
    const m = this.manifest;
    const v = m && m.manager && m.manager.version;
    if (!v || !VERSION_RE.test(v) || cmpVersion(v, this.host.version) <= 0) return null;
    return { version: v, feed: `${this.releaseBase}/releases/download/${m.release}` };
  }

  // Was laesst sich gerade aktualisieren (ohne fehlende Addons)
  updates() { return this.list().filter((a) => a.status === 'update').map((a) => a.name); }

  // Kurze Texte der neuen Manager-Version seit der laufenden
  managerNews() {
    const m = this.manifest;
    return m && m.manager ? newsSince(m.manager.news, this.host.version) : [];
  }

  // Inhalt des Update-Fensters: Updates und neue Addons. Ein Addon gilt als neu, bis es einmal vorgestellt wurde,
  // sonst kaeme ein bewusst nicht installiertes immer wieder. Was das Manifest beim ersten Mal schon nennt, ist nicht neu.
  newsEntries() {
    const m = this.manifest;
    if (!m) return [];
    let seen = this.host.meta('addonsSeen');
    if (!Array.isArray(seen)) {
      seen = m.addons.map((a) => a.name);
      this.host.meta('addonsSeen', seen);
    }
    const out = [];
    for (const a of this.list()) {
      if (a.status === 'update') out.push({ kind: 'update', name: a.name, title: a.title, version: a.available, installed: a.installed, desc: a.desc, news: a.news });
      else if (a.status === 'missing' && !a.managerOnly && !seen.includes(a.name)) out.push({ kind: 'new', name: a.name, title: a.title, version: a.available, installed: null, desc: a.desc, news: a.news });
    }
    return out;
  }

  // Das Fenster hat alles gezeigt: Neue Addons sind ab jetzt bekannt
  markSeen() {
    const seen = new Set(this.host.meta('addonsSeen') || []);
    for (const a of (this.manifest ? this.manifest.addons : [])) seen.add(a.name);
    this.host.meta('addonsSeen', [...seen]);
  }
}

module.exports = { AddonManager, newestTag, checkManifest, safeEntry, findWowDirs, cmpVersion, REPO_URL, PLACEHOLDER };
