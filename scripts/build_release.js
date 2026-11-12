#!/usr/bin/env node
'use strict';
// Peon - Release-Pakete bauen (Peon_GitHub_Design.md, Abschnitt 6).
// Je Addon ein Zip <Name>-<Version>.zip mit dem Ordner <Name>\ darin, dazu manifest.json und notes.md (Text fuer das Release).
// Laeuft unter Windows und auf GitHub (nur Node, keine Pakete).
//
// Aufruf:  node scripts/build_release.js [--tag v2026.11.04] [--test] [--prev alte/manifest.json] [--out build/release] [--dirty]
//   --tag    Name des Release, Standard v<heute> (vJJJJ.MM.TT)
//   --test   Vorabversion fuer den Kanal Test (Tag bekommt -test)
//   --prev   Manifest des letzten Release: "Was ist neu" enthaelt dann alle Versionen seitdem, ohne bleibt es leer (erstes Release)
//   --dirty  auch bauen, wenn addons/ ungespeicherte Aenderungen hat (nur zum Ausprobieren)
//
// Text fuer das Release (notes.md): Tabelle aller Addons und des Managers mit alter und neuer Version und Anmerkung,
// darunter je geaendertem Teil die Punkte Neu, Geaendert, Behoben, Entfernt. Beides steht in docs/releases/*.md:
//   ## Peon_Broker 0.81.0
//   Anmerkung: Neues Fenster, Aufkauf
//   - Neu: ...
//   - Behoben: ...
// Der Abschnitt gilt fuer genau diese Version, egal in welcher Datei (Vorabversion und normales Release teilen ihn).
// Fehlt er fuer einen geaenderten Teil, bricht der Bau ab. Neue Addons brauchen keinen (Anmerkung "Neu").
//
// Die Zips sind immer gleich gebaut (feste Zeit, sortierte Eintraege): Ein Addon, das sich nicht geaendert hat,
// bekommt in jedem Release dasselbe Zip mit derselben Pruefsumme.

const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { execFileSync } = require('node:child_process');

const { makeZip, readZip } = require('../manager/src/core/zip');

const REPO = path.join(__dirname, '..');

const MAX_NEWS = 20;   // so viele Versionen mit kurzem Text stehen im Manifest

// ---------------------------------------------------------------------------
// TOC und Changelog lesen
// ---------------------------------------------------------------------------
function readToc(dir, name) {
  const file = path.join(dir, name + '.toc');
  if (!fs.existsSync(file)) throw new Error(`${name}: TOC fehlt (${file})`);
  const meta = {}, files = [];
  for (const raw of fs.readFileSync(file, 'utf8').split(/\r?\n/)) {
    const line = raw.trim();
    const m = line.match(/^##\s*([\w-]+)\s*:\s*(.*)$/);
    if (m) meta[m[1]] = m[2];
    else if (line && !line.startsWith('#')) files.push(line.replace(/\\/g, '/'));
  }
  return { meta, files };
}

function cmpVersion(a, b) {
  const pa = String(a).split('.').map(Number), pb = String(b).split('.').map(Number);
  for (let i = 0; i < Math.max(pa.length, pb.length); i++) {
    const d = (pa[i] || 0) - (pb[i] || 0);
    if (d) return d;
  }
  return 0;
}

// Abschnitte "## x.y.z" eines Changelogs: [{ version, text, short }]. Zeilen "Kurz: ..." sind der Text fuer Nutzer
// (Update-Fenster und "Was ist neu" im Manager), alles andere ist der Verlauf fuer Entwickler.
function readChangelog(file) {
  if (!fs.existsSync(file)) return [];
  const out = [];
  let cur = null;
  for (const line of fs.readFileSync(file, 'utf8').split(/\r?\n/)) {
    const m = line.match(/^## (\d+\.\d+\.\d+)\s*$/);
    if (m) { cur = { version: m[1], lines: [], short: [] }; out.push(cur); continue; }
    if (line.startsWith('# ') || !cur) continue;
    const k = line.match(/^Kurz:\s*(.+?)\s*$/);
    if (k) cur.short.push(k[1]);
    else cur.lines.push(line);
  }
  return out.map((s) => ({ version: s.version, text: s.lines.join('\n').trim(), short: s.short }));
}

// Kurze Texte je Version, neueste oben. So sieht auch, wer Releases uebersprungen hat, was seit seiner Version neu ist.
function newsFor(sections, version) {
  return sections.filter((s) => s.short.length && cmpVersion(s.version, version) <= 0)
    .sort((a, b) => cmpVersion(b.version, a.version)).slice(0, MAX_NEWS).map((s) => ({ version: s.version, short: s.short }));
}

// Eine neue Version braucht einen kurzen Text. Das erste Release (ohne Vorgaenger) ist davon ausgenommen.
function requireShort(what, sections, version, file) {
  const s = sections.find((x) => x.version === version);
  if (!s || !s.short.length) throw new Error(`${what} ${version}: keine Zeile "Kurz: ..." im Abschnitt "## ${version}" in docs/changelog/${file}.md`);
}

// "Was ist neu": alle Versionen nach prev bis einschliesslich version, neueste oben
function notesFor(sections, version, prev) {
  const pick = sections.filter((s) => cmpVersion(s.version, version) <= 0 && (prev ? cmpVersion(s.version, prev) > 0 : cmpVersion(s.version, version) === 0));
  pick.sort((a, b) => cmpVersion(b.version, a.version));
  return pick.map((s) => `### ${s.version}\n\n${s.text}`).join('\n\n');
}

// ---------------------------------------------------------------------------
// Text fuer das Release: docs/releases/*.md lesen
// ---------------------------------------------------------------------------
const KINDS = ['Neu', 'Geändert', 'Behoben', 'Entfernt'];
const MANAGER = 'Peon Manager';

// Abschnitte "## <Name> <Version>" aller Dateien: { "<Name> <Version>": { note, items: [{ kind, text }] } }.
// Spaetere Dateien (nach Name sortiert) ersetzen fruehere.
function readReleaseNotes(dir) {
  const out = {};
  if (!dir || !fs.existsSync(dir)) return out;
  for (const f of fs.readdirSync(dir).filter((x) => x.endsWith('.md') && x.toLowerCase() !== 'readme.md').sort()) {
    let cur = null;
    fs.readFileSync(path.join(dir, f), 'utf8').split(/\r?\n/).forEach((raw, i) => {
      const line = raw.trim();
      const h = line.match(/^## (.+?) (\d+\.\d+\.\d+)$/);
      if (h) { cur = { note: '', items: [] }; out[`${h[1]} ${h[2]}`] = cur; return; }
      if (!cur || !line || line.startsWith('#')) return;
      const n = line.match(/^Anmerkung:\s*(.+)$/);
      if (n) { cur.note = n[1].trim(); return; }
      const it = line.match(/^[-*]\s*([^:]+):\s*(.+)$/);
      if (it && KINDS.includes(it[1].trim())) { cur.items.push({ kind: it[1].trim(), text: it[2].trim() }); return; }
      throw new Error(`docs/releases/${f} Zeile ${i + 1}: erwartet "Anmerkung: ..." oder "- ${KINDS.join('|')}: ...", gefunden: ${line}`);
    });
  }
  return out;
}

// Zeile der Tabelle und Punkte fuer einen Teil. Geaendert ohne Abschnitt bricht ab, neu ohne Abschnitt heisst "Neu".
function releaseEntry(rel, name, version, prevVersion, hasPrev) {
  const e = rel[`${name} ${version}`];
  if (!hasPrev) return { prev: '', note: e ? e.note : '', items: e ? e.items : [] };
  if (prevVersion === version) return { prev: prevVersion, note: 'unverändert', items: [] };
  if (!prevVersion) return { prev: '', note: (e && e.note) || 'Neu', items: e ? e.items : [] };
  if (!e || !e.note) throw new Error(`${name} ${version}: kein Abschnitt "## ${name} ${version}" mit "Anmerkung: ..." in docs/releases/*.md`);
  if (!e.items.length) throw new Error(`${name} ${version}: keine Punkte (- Neu: ..., - Geändert: ...) in docs/releases/*.md`);
  return { prev: prevVersion, note: e.note, items: e.items };
}

// Fuer das Update-Fenster im Manager (ab Manager 0.27.0): nur geaenderte Teile, from = Version des letzten normalen Release
function releaseForManifest(t, hasPrev) {
  if (!hasPrev || t.prev === t.version) return null;
  return { from: t.prev || null, note: t.note, items: t.items.map((x) => ({ kind: x.kind, text: x.text })) };
}

function coreApi(dir) {
  const m = fs.readFileSync(path.join(dir, 'Core.lua'), 'utf8').match(/^Peon\.API\s*=\s*(\d+)/m);
  if (!m) throw new Error('Peon: Peon.API in Core.lua nicht gefunden');
  return Number(m[1]);
}

// ---------------------------------------------------------------------------
// Dateien eines Addons: was Git kennt (keine lokalen Dateien wie Data.lua), ohne Ausnahmen
// ---------------------------------------------------------------------------
function gitFiles(repo, rel) {
  const out = execFileSync('git', ['-C', repo, 'ls-files', '-z', '--', rel], { encoding: 'utf8' });
  return out.split('\0').filter(Boolean).map((f) => f.slice(rel.length + 1));
}

function addonEntries(dir, name, files, exclude) {
  const ex = new Set((exclude || []).map((x) => x.toLowerCase()));
  const keep = files.filter((f) => !ex.has(f.toLowerCase())).sort();
  const dirs = new Set([name + '/']);
  for (const f of keep) {
    const parts = f.split('/');
    for (let i = 1; i < parts.length; i++) dirs.add(name + '/' + parts.slice(0, i).join('/') + '/');
  }
  const entries = [...dirs].sort().map((d) => ({ name: d }));
  for (const f of keep) entries.push({ name: `${name}/${f}`, data: fs.readFileSync(path.join(dir, f)) });
  entries.sort((a, b) => (a.name < b.name ? -1 : a.name > b.name ? 1 : 0));
  return { entries, files: keep };
}

// ---------------------------------------------------------------------------
// Bauen
// ---------------------------------------------------------------------------
function today() {
  const d = new Date();
  return `${d.getFullYear()}.${String(d.getMonth() + 1).padStart(2, '0')}.${String(d.getDate()).padStart(2, '0')}`;
}

function build(opts = {}) {
  const repo = opts.repo || REPO;
  const addonsDir = opts.addonsDir || path.join(repo, 'addons');
  const changelogDir = opts.changelogDir || path.join(repo, 'docs', 'changelog');
  const releasesDir = opts.releasesDir || path.join(repo, 'docs', 'releases');
  const config = opts.config || JSON.parse(fs.readFileSync(path.join(repo, 'scripts', 'release.json'), 'utf8'));
  const listFiles = opts.listFiles || ((name) => gitFiles(repo, `addons/${name}`));
  let tag = opts.tag || `v${today()}`;
  if (opts.test && !tag.endsWith('-test')) tag += '-test';
  if (!/^v\d{4}\.\d{2}\.\d{2}(\.\d+)?(-test)?$/.test(tag)) throw new Error(`Tag passt nicht zu vJJJJ.MM.TT: ${tag}`);
  const date = tag.slice(1, 11).replace(/\./g, '-');
  const prev = opts.prev || null;
  const prevVersions = {};
  if (prev && Array.isArray(prev.addons)) for (const a of prev.addons) prevVersions[a.name] = a.version;

  if (!opts.dirty && !opts.listFiles) {
    const st = execFileSync('git', ['-C', repo, 'status', '--porcelain', '--', 'addons', 'docs/changelog', 'docs/releases', 'scripts/release.json'], { encoding: 'utf8' }).trim();
    if (st) throw new Error('Ungespeicherte Aenderungen in addons/, docs/changelog/ oder docs/releases/ (erst committen oder --dirty):\n' + st);
  }

  const out = path.join(opts.out || path.join(repo, 'build', 'release'), tag);
  fs.mkdirSync(out, { recursive: true });

  const pkg = JSON.parse(fs.readFileSync(path.join(repo, 'manager', 'package.json'), 'utf8'));
  const managerLog = readChangelog(path.join(changelogDir, 'Peon_Manager.md'));
  if (prev && prev.manager && prev.manager.version !== pkg.version) requireShort('Peon Manager', managerLog, pkg.version, 'Peon_Manager');
  const manifest = {
    fmt: config.fmt || 1,
    release: tag,
    date,
    prerelease: tag.endsWith('-test'),
    discord: config.discord || null,
    manager: { version: pkg.version, minVersion: config.managerMinVersion || pkg.version, news: newsFor(managerLog, pkg.version) },
    addons: [],
    managerModules: config.managerModules || [],
  };
  const rel = readReleaseNotes(releasesDir);
  const table = [{ name: MANAGER, version: pkg.version, ...releaseEntry(rel, MANAGER, pkg.version, prev && prev.manager ? prev.manager.version : undefined, !!prev) }];
  const rm = releaseForManifest(table[0], !!prev);
  if (rm) manifest.manager.release = rm;

  const names = Object.keys(config.addons).sort();
  for (const name of fs.readdirSync(addonsDir, { withFileTypes: true }).filter((d) => d.isDirectory()).map((d) => d.name)) {
    if (!config.addons[name]) throw new Error(`${name}: fehlt in scripts/release.json`);
  }
  for (const name of names) {
    const cfg = config.addons[name];
    const dir = path.join(addonsDir, name);
    const { meta, files: tocFiles } = readToc(dir, name);
    const version = meta.Version;
    if (!version) throw new Error(`${name}: keine Version in der TOC`);
    const all = listFiles(name);
    const { entries, files } = addonEntries(dir, name, all, cfg.exclude);
    // jede Datei aus der TOC muss mit, ausser den ausgenommenen (die legt spaeter der Manager an)
    for (const f of tocFiles) {
      const excluded = (cfg.exclude || []).some((x) => x.toLowerCase() === f.toLowerCase());
      if (!excluded && !files.some((x) => x.toLowerCase() === f.toLowerCase())) throw new Error(`${name}: Datei aus der TOC fehlt im Repo: ${f}`);
    }
    const sections = readChangelog(path.join(changelogDir, name + '.md'));
    if (!sections.some((s) => s.version === version)) throw new Error(`${name} ${version}: kein Abschnitt "## ${version}" in docs/changelog/${name}.md`);
    if (prev && prevVersions[name] !== version) requireShort(name, sections, version, name);
    const zip = makeZip(entries);
    const file = `${name}-${version}.zip`;
    fs.writeFileSync(path.join(out, file), zip);
    const title = (meta.Title || name).replace(/\|c[0-9a-fA-F]{8}|\|r/g, '').replace(/^Peon\s+(?=\S)/, '').trim() || name;
    manifest.addons.push({
      name,
      title,
      version,
      desc: meta['Notes-deDE'] || meta.Notes || '',
      deps: (meta.Dependencies || '').split(',').map((s) => s.trim()).filter(Boolean),
      api: cfg.api === 'core' ? coreApi(dir) : cfg.api,
      interface: Number(meta.Interface) || null,
      file,
      sha256: crypto.createHash('sha256').update(zip).digest('hex'),
      size: zip.length,
      // erstes Release: nichts "neu", die Changelogs sind fuer Erstinstallationen zu technisch
      notes: prev ? notesFor(sections, version, prevVersions[name]) : '',
      news: newsFor(sections, version),
      managerOnly: !!cfg.managerOnly,
      changed: prevVersions[name] !== version,
    });
    const t = { name, version, ...releaseEntry(rel, name, version, prevVersions[name], !!prev) };
    table.push(t);
    const ra = releaseForManifest(t, !!prev);
    if (ra) manifest.addons[manifest.addons.length - 1].release = ra;
  }

  fs.writeFileSync(path.join(out, 'manifest.json'), JSON.stringify(manifest, null, 2) + '\n');
  const notes = releaseNotes(manifest, table);
  fs.writeFileSync(path.join(out, 'notes.md'), notes);
  check(out, manifest, config);
  return { out, manifest, notes, table };
}

// Text fuer das Release auf GitHub: Tabelle mit alter und neuer Version, darunter die Punkte je geaendertem Teil.
// table: [{ name, version, prev, note, items }], Manager zuerst (ohne table nur die Addons des Manifests ohne Angaben)
function releaseNotes(m, table) {
  table = table || m.addons.map((a) => ({ name: a.name, version: a.version, prev: '', note: '', items: [] }));
  const cell = (s) => String(s || '').replace(/\|/g, '\\|');
  const lines = [`Peon ${m.release}${m.prerelease ? ' (Vorabversion, Kanal Test)' : ''}`, ''];
  lines.push(`Installation: \`PeonManager-Setup-${m.manager.version}.exe\` laden und starten, der Peon Manager installiert und aktualisiert die Addons. Anleitung in der README.`, '');
  lines.push('| Addon/Modul | Version alt | Version neu | Anmerkung |', '|---|---|---|---|');
  for (const t of table) lines.push(`| ${cell(t.name)} | ${cell(t.prev) || '–'} | ${cell(t.version)} | ${cell(t.note)} |`);
  for (const t of table.filter((x) => x.items.length)) {
    lines.push('', `## ${t.name} ${t.version}`, '');
    const sorted = [...t.items].sort((a, b) => KINDS.indexOf(a.kind) - KINDS.indexOf(b.kind));
    for (const it of sorted) lines.push(`- **${it.kind}:** ${it.text}`);
  }
  return lines.join('\n') + '\n';
}

// Pruefung nach dem Bau: Zip entpackbar, genau ein Ordner mit TOC, ausgenommene Dateien (Data.lua) nicht drin, Pruefsumme und Groesse stimmen
function check(out, manifest, config) {
  for (const a of manifest.addons) {
    const buf = fs.readFileSync(path.join(out, a.file));
    if (buf.length !== a.size) throw new Error(`${a.file}: Groesse stimmt nicht`);
    if (crypto.createHash('sha256').update(buf).digest('hex') !== a.sha256) throw new Error(`${a.file}: Pruefsumme stimmt nicht`);
    const entries = readZip(buf);
    const tops = new Set(entries.map((e) => e.name.split('/')[0]));
    if (tops.size !== 1 || !tops.has(a.name)) throw new Error(`${a.file}: muss genau den Ordner ${a.name} enthalten`);
    if (!entries.some((e) => e.name === `${a.name}/${a.name}.toc`)) throw new Error(`${a.file}: TOC fehlt`);
    for (const x of (config.addons[a.name] && config.addons[a.name].exclude) || []) {
      if (entries.some((e) => e.name.toLowerCase() === `${a.name}/${x}`.toLowerCase())) throw new Error(`${a.file}: ${x} darf nicht ausgeliefert werden`);
    }
  }
}

module.exports = { build, makeZip, readZip, readToc, readChangelog, notesFor, cmpVersion, releaseNotes, readReleaseNotes };

if (require.main === module) {
  const args = process.argv.slice(2);
  const opts = {};
  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    if (a === '--tag') opts.tag = args[++i];
    else if (a === '--out') opts.out = path.resolve(args[++i]);
    else if (a === '--prev') opts.prev = JSON.parse(fs.readFileSync(args[++i], 'utf8'));
    else if (a === '--test') opts.test = true;
    else if (a === '--dirty') opts.dirty = true;
    else { console.error(`Unbekannte Angabe: ${a}`); process.exit(2); }
  }
  try {
    const { out, manifest } = build(opts);
    for (const a of manifest.addons) console.log(`${a.file.padEnd(32)} ${String(a.size).padStart(8)} Byte  ${a.sha256.slice(0, 12)}${a.managerOnly ? '  (nur Manager)' : ''}`);
    console.log(`\n${manifest.addons.length} Addons, Manager ${manifest.manager.version}, geprueft. Ausgabe: ${out}`);
  } catch (e) {
    console.error('FEHLER: ' + e.message);
    process.exit(1);
  }
}
