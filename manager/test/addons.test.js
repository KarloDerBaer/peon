'use strict';
// Tests fuer Installieren und Aktualisieren der Addons (Peon_GitHub_Design.md 5.3 bis 5.5).
// Ein lokaler Server spielt GitHub mit denselben Pfaden wie echte Releases.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const http = require('node:http');
const crypto = require('node:crypto');
const { Service } = require('../src/core/service');
const { makeZip, readZip } = require('../src/core/zip');
const { checkManifest, safeEntry, findWowDirs, PLACEHOLDER } = require('../src/core/addons');
const { parseLua } = require('../src/core/lua');

process.removeAllListeners('warning');
const tmp = () => fs.mkdtempSync(path.join(os.tmpdir(), 'peon-add-'));

function zipFor(name, version, extra = {}) {
  const toc = `## Interface: 16001\n## Version: ${version}\n\nMain.lua\n`;
  return makeZip([
    { name: `${name}/` },
    { name: `${name}/${name}.toc`, data: Buffer.from(toc) },
    { name: `${name}/Main.lua`, data: Buffer.from(`-- ${name} ${version}\n`) },
    { name: `${name}/Media/` },
    { name: `${name}/Media/bild.tga`, data: Buffer.from([1, 2, 3, 0, 255]) },
    ...Object.entries(extra).map(([n, d]) => ({ name: n, data: Buffer.from(d) })),
  ]);
}

// Release als Dateien: { tag: { 'manifest.json': Text, 'x.zip': Buffer } }
function makeRelease(tag, addons, { minVersion = '0.1.0' } = {}) {
  const files = {};
  const list = addons.map((a) => {
    const zip = a.zip || zipFor(a.name, a.version);
    const file = a.file || `${a.name}-${a.version}.zip`;
    files[file] = zip;
    return { name: a.name, title: a.name.replace('Peon_', ''), version: a.version, desc: `Beschreibung ${a.name}`, deps: a.deps || (a.name === 'Peon' ? [] : ['Peon']),
      api: 5, interface: 16001, file, sha256: a.sha256 || crypto.createHash('sha256').update(zip).digest('hex'), size: a.size || zip.length, notes: `Neu in ${a.version}`, managerOnly: !!a.managerOnly };
  });
  files['manifest.json'] = JSON.stringify({ fmt: 1, release: tag, date: '2026-11-04', discord: null, manager: { version: '0.8.0', minVersion }, addons: list, managerModules: [] });
  return files;
}

const BASE = [
  { name: 'Peon', version: '0.11.0' },
  { name: 'Peon_Bridge', version: '0.4.0', managerOnly: true },
  { name: 'Peon_Broker', version: '0.33.0' },
  { name: 'Peon_Tooltip', version: '0.7.2' },
];

async function world(addons = BASE, opt = {}) {
  const state = { latest: 'v2026.11.04', releases: { 'v2026.11.04': makeRelease('v2026.11.04', addons, opt) }, list: null, etag: '"a"', requests: [] };
  const server = http.createServer((req, res) => {
    state.requests.push(req.url);
    const send = (code, body, h = {}) => { res.writeHead(code, h); res.end(body); };
    if (req.url.startsWith('/api/releases')) {
      if (req.headers['if-none-match'] === state.etag) return send(304);
      return send(200, JSON.stringify(state.list || []), { etag: state.etag });
    }
    let m = req.url.match(/^\/releases\/latest\/download\/(.+)$/);
    if (m) { const f = state.latest && state.releases[state.latest][m[1]]; return f ? send(200, f) : send(404, 'Not Found'); }
    m = req.url.match(/^\/releases\/download\/([^/]+)\/(.+)$/);
    if (m && state.releases[m[1]] && state.releases[m[1]][m[2]]) return send(200, state.releases[m[1]][m[2]]);
    return send(404, 'Not Found');
  });
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  const base = `http://127.0.0.1:${server.address().port}`;
  const wow = tmp();
  fs.writeFileSync(path.join(wow, 'Wow.exe'), 'x');
  const dir = tmp();
  const hook = { fn: null };
  const svc = new Service({ dbDir: dir, version: '0.8.0', releases: { releaseBase: base, apiBase: `${base}/api`, testHook: (...a) => hook.fn && hook.fn(...a) } });
  svc.saveSettings({ wowDir: wow });
  const addonsDir = path.join(wow, 'Interface', 'AddOns');
  return { state, server, svc, wow, dir, addonsDir, hook, close: () => { svc.close(); server.close(); } };
}
const version = (w, n) => { const t = fs.readFileSync(path.join(w.addonsDir, n, `${n}.toc`), 'utf8'); return t.match(/## Version: (\S+)/)[1]; };

test('Suchen: Manifest laden, Liste mit Status, noch nichts installiert', async () => {
  const w = await world();
  const r = await w.svc.addons.check();
  assert.equal(r.ok, true);
  const st = w.svc.addonState(true);
  assert.equal(st.release, 'v2026.11.04');
  assert.equal(st.missing, 4);
  assert.equal(st.wowRunning, true);
  assert.equal(st.items.find((a) => a.name === 'Peon_Bridge').managerOnly, true);
  assert.equal(st.items[0].notes, 'Neu in 0.11.0');
  w.close();
});

test('Noch kein Release: klare Antwort, kein Fehler', async () => {
  const w = await world();
  w.state.latest = null;
  const r = await w.svc.addons.check();
  assert.equal(r.noRelease, true);
  assert.equal(w.svc.addonState().check.noRelease, true);
  assert.equal(w.svc.addonState().items.length, 0);
  await assert.rejects(() => w.svc.addons.install(['Peon_Tooltip']), /Noch kein Manifest/);
  w.close();
});

test('Installieren: Abhaengigkeiten und Bridge automatisch, Inhalt richtig, Zwischenordner weg', async () => {
  const w = await world();
  await w.svc.addons.check();
  const res = await w.svc.addons.install(['Peon_Tooltip']);
  assert.deepEqual(res.failed, []);
  assert.deepEqual(res.done.map((d) => d.name).sort(), ['Peon', 'Peon_Bridge', 'Peon_Tooltip'], 'Peon und Bridge kommen mit');
  assert.ok(res.done.findIndex((d) => d.name === 'Peon') < res.done.findIndex((d) => d.name === 'Peon_Tooltip'), 'Peon zuerst');
  assert.equal(version(w, 'Peon_Tooltip'), '0.7.2');
  assert.deepEqual([...fs.readFileSync(path.join(w.addonsDir, 'Peon_Tooltip', 'Media', 'bild.tga'))], [1, 2, 3, 0, 255]);
  assert.ok(!fs.existsSync(path.join(w.addonsDir, 'Peon_Broker')), 'nicht gewaehlt: nicht installiert');
  assert.deepEqual(fs.existsSync(w.svc.addons.tmpDir) ? fs.readdirSync(w.svc.addons.tmpDir) : [], [], 'Zwischenordner aufgeraeumt');
  // Bridge: Platzhalter, danach schreibt der Manager Data.lua ohne Kanaele
  const d = parseLua(fs.readFileSync(path.join(w.addonsDir, 'Peon_Bridge', 'Data.lua'))).PeonBridgeData;
  assert.equal(d.fmt, 2);
  assert.deepEqual(d.channels, {});
  // zweites Mal: nichts zu tun
  const again = await w.svc.addons.install(['Peon_Tooltip']);
  assert.equal(again.done.length, 0);
  assert.equal(w.svc.addons.list().find((a) => a.name === 'Peon_Tooltip').status, 'current');
  w.close();
});

test('Aktualisieren: nur Geaendertes, alte Fassung in der Sicherung, Data.lua bleibt, fremde Addons und WTF unberuehrt', async () => {
  const w = await world();
  await w.svc.addons.check();
  await w.svc.addons.install(['Peon_Tooltip']);
  // eigene Werte in Data.lua, fremdes Addon, Einstellungen
  const data = path.join(w.addonsDir, 'Peon_Bridge', 'Data.lua');
  fs.writeFileSync(data, 'PeonBridgeData = { fmt = 2, t = 42 }\n');
  const fremd = path.join(w.addonsDir, 'Bagnon'); fs.mkdirSync(fremd); fs.writeFileSync(path.join(fremd, 'Bagnon.toc'), '## Version: 9\n');
  const wtf = path.join(w.wow, 'WTF', 'Account', 'K', 'SavedVariables'); fs.mkdirSync(wtf, { recursive: true }); fs.writeFileSync(path.join(wtf, 'Peon_Tooltip.lua'), 'PeonTooltipDB = {}');
  // eine Datei, die es in der neuen Fassung nicht mehr gibt
  fs.writeFileSync(path.join(w.addonsDir, 'Peon_Tooltip', 'Alt.lua'), '-- alt');

  w.state.releases['v2026.11.05'] = makeRelease('v2026.11.05', [
    { name: 'Peon', version: '0.11.0' }, { name: 'Peon_Bridge', version: '0.5.0', managerOnly: true },
    { name: 'Peon_Broker', version: '0.33.0' }, { name: 'Peon_Tooltip', version: '0.8.0' },
  ]);
  w.state.latest = 'v2026.11.05';
  await w.svc.addons.check();
  const st = w.svc.addonState();
  assert.equal(st.updates, 2);
  assert.equal(st.items.find((a) => a.name === 'Peon').status, 'current');
  // direkt nach dem Tausch steht die eigene Data.lua noch da (danach schreibt der Manager sie neu)
  let dataNachTausch = null;
  w.hook.fn = (step, name, target) => { if (name === 'Peon_Bridge') dataNachTausch = fs.readFileSync(path.join(target, 'Data.lua'), 'utf8'); };
  const res = await w.svc.addons.install(w.svc.addons.updates());
  w.hook.fn = null;
  assert.equal(dataNachTausch, 'PeonBridgeData = { fmt = 2, t = 42 }\n', 'Data.lua bleibt beim Aktualisieren erhalten');
  assert.deepEqual(res.done.map((d) => d.name).sort(), ['Peon_Bridge', 'Peon_Tooltip']);
  assert.equal(res.done.find((d) => d.name === 'Peon_Tooltip').from, '0.7.2');
  assert.equal(version(w, 'Peon_Tooltip'), '0.8.0');
  assert.ok(!fs.existsSync(path.join(w.addonsDir, 'Peon_Tooltip', 'Alt.lua')), 'alte Dateien sind weg');
  const bk = path.join(w.dir, 'backup', 'Peon_Tooltip-0.7.2');
  assert.ok(fs.existsSync(path.join(bk, 'Alt.lua')), 'alte Fassung in der Sicherung');
  assert.ok(fs.existsSync(path.join(fremd, 'Bagnon.toc')), 'fremdes Addon unberuehrt');
  assert.ok(fs.existsSync(path.join(wtf, 'Peon_Tooltip.lua')), 'WTF unberuehrt');
  w.close();
});

test('Data.lua im Zip der Bridge wird nicht uebernommen', async () => {
  const bad = zipFor('Peon_Bridge', '0.4.0', { 'Peon_Bridge/Data.lua': 'PeonBridgeData = { channels = { broker = true } }' });
  const w = await world([{ name: 'Peon', version: '0.11.0' }, { name: 'Peon_Bridge', version: '0.4.0', managerOnly: true, zip: bad }]);
  await w.svc.addons.check();
  const res = await w.svc.addons.install(['Peon']);
  assert.deepEqual(res.failed, []);
  const d = parseLua(fs.readFileSync(path.join(w.addonsDir, 'Peon_Bridge', 'Data.lua'))).PeonBridgeData;
  assert.deepEqual(d.channels, {}, 'nicht freigeschaltet durch ein manipuliertes Zip');
  w.close();
});

test('Falsche Pruefsumme oder Groesse: nichts wird angefasst', async () => {
  const w = await world([{ name: 'Peon', version: '0.11.0', sha256: 'a'.repeat(64) }]);
  await w.svc.addons.check();
  let res = await w.svc.addons.install(['Peon']);
  assert.match(res.failed[0].error, /Prüfsumme/);
  assert.ok(!fs.existsSync(path.join(w.addonsDir, 'Peon')));
  w.close();
  const w2 = await world([{ name: 'Peon', version: '0.11.0', size: 7 }]);
  await w2.svc.addons.check();
  res = await w2.svc.addons.install(['Peon']);
  assert.match(res.failed[0].error, /Größe/);
  w2.close();
});

test('Manipulierte Zips: Pfade nach aussen, falscher Ordner, keine TOC, falsche Version', async () => {
  const cases = [
    [makeZip([{ name: 'Peon/Peon.toc', data: Buffer.from('## Version: 0.11.0\n') }, { name: 'Peon/../../boese.lua', data: Buffer.from('x') }]), /Ungültiger Pfad/],
    [makeZip([{ name: 'Peon/Peon.toc', data: Buffer.from('## Version: 0.11.0\n') }, { name: 'Anderes/x.lua', data: Buffer.from('x') }]), /nur den Ordner Peon/],
    [makeZip([{ name: 'Peon/Peon.toc', data: Buffer.from('## Version: 0.11.0\n') }, { name: 'Peon\\..\\boese.lua', data: Buffer.from('x') }]), /Ungültiger Pfad/],
    [makeZip([{ name: 'Peon/x.lua', data: Buffer.from('x') }]), /fehlt Peon\.toc/],
    [makeZip([{ name: 'Peon/Peon.toc', data: Buffer.from('## Version: 9.9.9\n') }]), /Version im Zip/],
  ];
  for (const [zip, err] of cases) {
    const w = await world([{ name: 'Peon', version: '0.11.0', zip }]);
    await w.svc.addons.check();
    const res = await w.svc.addons.install(['Peon']);
    assert.match(res.failed[0].error, err);
    assert.ok(!fs.existsSync(path.join(w.addonsDir, 'Peon')), 'nichts installiert');
    assert.ok(!fs.existsSync(path.join(path.dirname(w.wow), 'boese.lua')));
    w.close();
  }
  assert.throws(() => safeEntry('Peon/C:/x.lua', 'Peon'), /Ungültiger Pfad/);
  assert.throws(() => safeEntry('/Peon/x.lua', 'Peon'), /Ungültiger Pfad/);
  assert.deepEqual(safeEntry('Peon/Media/a.tga', 'Peon'), { rel: 'Media/a.tga', dir: false });
});

test('Beschaedigtes Zip wird erkannt', () => {
  const z = zipFor('Peon', '1.0.0');
  assert.equal(readZip(z).length, 5);
  const kaputt = Buffer.from(z); kaputt[kaputt.indexOf(Buffer.from([1, 2, 3, 0, 255]))] ^= 0xff;   // ein Byte in den Daten von bild.tga
  assert.throws(() => readZip(kaputt), /Prüfsumme falsch/);
  assert.throws(() => readZip(Buffer.from('kein zip')), /Kein gültiges Zip/);
});

test('Manifest pruefen: nichts Gefaehrliches wird uebernommen', () => {
  const ok = JSON.parse(makeRelease('v2026.11.04', BASE)['manifest.json']);
  checkManifest(ok);
  const bad = (fn) => { const m = JSON.parse(JSON.stringify(ok)); fn(m); return () => checkManifest(m); };
  assert.throws(bad((m) => { m.fmt = 2; }), /Format/);
  assert.throws(bad((m) => { m.release = '../boese'; }), /Release/);
  assert.throws(bad((m) => { m.addons[1].name = '..\\Fremd'; }), /Addon-Name/);
  assert.throws(bad((m) => { m.addons[1].name = 'Bagnon'; }), /Addon-Name/);
  assert.throws(bad((m) => { m.addons[1].file = '../../x.zip'; }), /Datei/);
  assert.throws(bad((m) => { m.addons[1].sha256 = 'abc'; }), /Prüfsumme/);
  assert.throws(bad((m) => { m.addons[1].size = -1; }), /Größe/);
  assert.throws(bad((m) => { m.addons[2].deps = ['Peon_Fehlt']; }), /Peon_Fehlt/);
});

test('Kaputtes Manifest: Fehler gemeldet, letzter guter Stand bleibt', async () => {
  const w = await world();
  await w.svc.addons.check();
  w.state.releases['v2026.11.05'] = { 'manifest.json': '{ kaputt' };
  w.state.latest = 'v2026.11.05';
  const r = await w.svc.addons.check();
  assert.equal(r.ok, false);
  assert.match(r.error, /JSON/);
  assert.equal(w.svc.addons.manifest.release, 'v2026.11.04');
  assert.equal(w.svc.addonState().check.ok, false);
  w.close();
});

test('Fehler nach dem Tausch: alte Fassung kommt zurueck', async () => {
  const w = await world();
  await w.svc.addons.check();
  await w.svc.addons.install(['Peon_Tooltip']);
  w.state.releases['v2026.11.05'] = makeRelease('v2026.11.05', [
    { name: 'Peon', version: '0.11.0' }, { name: 'Peon_Bridge', version: '0.4.0', managerOnly: true }, { name: 'Peon_Broker', version: '0.33.0' }, { name: 'Peon_Tooltip', version: '0.8.0' },
  ]);
  w.state.latest = 'v2026.11.05';
  await w.svc.addons.check();
  // Windows verweigert das Schreiben: eine Datei ist danach anders als im Zip
  w.hook.fn = (step, name, target) => { if (step === 'afterCopy' && name === 'Peon_Tooltip') fs.writeFileSync(path.join(target, 'Main.lua'), 'kaputt'); };
  const res = await w.svc.addons.install(['Peon_Tooltip']);
  assert.match(res.failed[0].error, /nicht richtig geschrieben.*wiederhergestellt/);
  assert.equal(version(w, 'Peon_Tooltip'), '0.7.2', 'alte Version wieder da');
  assert.equal(fs.readFileSync(path.join(w.addonsDir, 'Peon_Tooltip', 'Main.lua'), 'utf8'), '-- Peon_Tooltip 0.7.2\n');
  // zweiter Versuch klappt
  w.hook.fn = null;
  assert.deepEqual((await w.svc.addons.install(['Peon_Tooltip'])).failed, []);
  assert.equal(version(w, 'Peon_Tooltip'), '0.8.0');
  assert.ok(fs.existsSync(path.join(w.dir, 'backup', 'Peon_Tooltip-0.7.2')));
  w.close();
});

test('Scheitert eine Abhaengigkeit, wird das Addon nicht installiert', async () => {
  const w = await world([{ name: 'Peon', version: '0.11.0', sha256: 'b'.repeat(64) }, { name: 'Peon_Tooltip', version: '0.7.2' }]);
  await w.svc.addons.check();
  const res = await w.svc.addons.install(['Peon_Tooltip']);
  assert.equal(res.failed.length, 2);
  assert.match(res.failed[1].error, /Peon fehlt/);
  assert.ok(!fs.existsSync(path.join(w.addonsDir, 'Peon_Tooltip')));
  w.close();
});

test('Entwicklermodus: Junction wird nie aktualisiert oder entfernt', async () => {
  const w = await world();
  await w.svc.addons.check();
  const repo = path.join(tmp(), 'Peon_Tooltip');
  fs.mkdirSync(repo);
  fs.writeFileSync(path.join(repo, 'Peon_Tooltip.toc'), '## Version: 0.1.0\n');
  fs.mkdirSync(w.addonsDir, { recursive: true });
  fs.symlinkSync(repo, path.join(w.addonsDir, 'Peon_Tooltip'), 'junction');
  const a = w.svc.addons.list().find((x) => x.name === 'Peon_Tooltip');
  assert.equal(a.status, 'dev');
  assert.equal(a.removable, false);
  const res = await w.svc.addons.install(['Peon_Tooltip']);
  assert.deepEqual(res.skipped.find((s) => s.name === 'Peon_Tooltip'), { name: 'Peon_Tooltip', why: 'Entwicklung (Repo)' });
  assert.equal(fs.readFileSync(path.join(repo, 'Peon_Tooltip.toc'), 'utf8'), '## Version: 0.1.0\n', 'Repo unberuehrt');
  assert.throws(() => w.svc.addons.remove('Peon_Tooltip'), /Entwicklung/);
  assert.ok(fs.existsSync(path.join(repo, 'Peon_Tooltip.toc')));
  w.close();
});

test('Entfernen: in die Sicherung, Abhaengigkeiten und Regeln beachtet, WTF bleibt', async () => {
  const w = await world();
  await w.svc.addons.check();
  await w.svc.addons.install(['Peon_Tooltip', 'Peon_Broker']);
  const wtf = path.join(w.wow, 'WTF', 'Account', 'K', 'SavedVariables'); fs.mkdirSync(wtf, { recursive: true }); fs.writeFileSync(path.join(wtf, 'Peon_Tooltip.lua'), 'x');
  assert.throws(() => w.svc.addons.remove('Peon'), /gebraucht von/);
  assert.throws(() => w.svc.addons.remove('Peon_Bridge'), /fest zum Peon Manager/);
  assert.throws(() => w.svc.addons.remove('Bagnon'), /verwaltet der Manager nicht/);
  w.svc.setModule('broker-client', true);
  assert.throws(() => w.svc.addons.remove('Peon_Broker'), /Modul Peon Broker Client/);
  w.svc.setModule('broker-client', false);
  w.svc.addons.remove('Peon_Broker');
  w.svc.addons.remove('Peon_Tooltip');
  assert.ok(!fs.existsSync(path.join(w.addonsDir, 'Peon_Tooltip')));
  assert.ok(fs.existsSync(path.join(w.dir, 'backup', 'Peon_Tooltip-0.7.2', 'Peon_Tooltip.toc')));
  assert.ok(fs.existsSync(path.join(wtf, 'Peon_Tooltip.lua')));
  w.svc.addons.remove('Peon');
  assert.throws(() => w.svc.addons.remove('Peon'), /Nicht installiert/);
  w.close();
});

test('Manager zu alt: Hinweis, nichts wird installiert', async () => {
  const w = await world(BASE, { minVersion: '9.0.0' });
  await w.svc.addons.check();
  assert.match(w.svc.addonState().tooOld, /mindestens Peon Manager 9\.0\.0/);
  await assert.rejects(() => w.svc.addons.install(['Peon']), /zuerst den Manager/);
  w.close();
});

test('Kein Spiel im WoW-Ordner: nichts wird angelegt', async () => {
  const w = await world();
  await w.svc.addons.check();
  const leer = tmp();
  w.svc.saveSettings({ wowDir: leer });
  assert.equal(w.svc.addonState().wowValid, false);
  await assert.rejects(() => w.svc.addons.install(['Peon']), /kein Spiel/);
  assert.deepEqual(fs.readdirSync(leer), []);
  w.close();
});

test('Kanal Test: Vorabversion ueber die Liste der Releases, mit ETag', async () => {
  const w = await world();
  w.state.releases['v2026.11.06-test'] = makeRelease('v2026.11.06-test', BASE.map((a) => (a.name === 'Peon' ? { ...a, version: '0.12.0' } : a)));
  w.state.list = [{ tag_name: 'v2026.11.07', draft: true }, { tag_name: 'v2026.11.06-test', prerelease: true }, { tag_name: 'v2026.11.04' }];
  await w.svc.addons.check();
  assert.equal(w.svc.addons.manifest.release, 'v2026.11.04', 'Stabil: letztes Release');
  w.svc.saveSettings({ addons: { channel: 'test' } });
  await w.svc.addons.check();
  assert.equal(w.svc.addons.manifest.release, 'v2026.11.06-test', 'Entwurf wird uebersprungen');
  assert.equal(w.svc.addons.list().find((a) => a.name === 'Peon').available, '0.12.0');
  const n = w.state.requests.length;
  await w.svc.addons.check();
  assert.ok(w.state.requests.slice(n).includes('/api/releases?per_page=10'));
  assert.equal(w.svc.addons.manifest.release, 'v2026.11.06-test', 'mit ETag: aus dem Zwischenspeicher');
  assert.deepEqual((await w.svc.addons.install(['Peon'])).failed, []);
  assert.equal(version(w, 'Peon'), '0.12.0');
  // zurueck nach Stabil: installierte Version ist neuer, nichts wird zurueckgestuft
  w.svc.saveSettings({ addons: { channel: 'stable' } });
  await w.svc.addons.check();
  assert.equal(w.svc.addons.list().find((a) => a.name === 'Peon').status, 'newer');
  assert.equal((await w.svc.addons.install(['Peon'])).done.length, 0);
  assert.equal(version(w, 'Peon'), '0.12.0');
  w.close();
});

test('Erster Start: Vorschlag, gewaehlte Addons, Modul installiert fehlende Addons, Vorschlag kommt nicht wieder', async () => {
  const w = await world();
  await w.svc.addons.check();
  assert.equal(w.svc.addonState().setup.done, false);
  const res = await w.svc.finishSetup({ addons: ['Peon_Tooltip'], modules: ['broker-client'] });
  assert.deepEqual(res.failed, []);
  assert.deepEqual(res.done.map((d) => d.name).sort(), ['Peon', 'Peon_Bridge', 'Peon_Broker', 'Peon_Tooltip']);
  assert.equal(w.svc.isActive('broker-client'), true);
  assert.equal(w.svc.addonState().setup.done, true);
  w.svc.broker.importGame();
  assert.deepEqual(parseLua(fs.readFileSync(path.join(w.addonsDir, 'Peon_Bridge', 'Data.lua'))).PeonBridgeData.channels, { broker: true });
  w.close();
});

test('Erster Start scheitert: Vorschlag bleibt', async () => {
  const w = await world([{ name: 'Peon', version: '0.11.0', sha256: 'c'.repeat(64) }]);
  await w.svc.addons.check();
  const res = await w.svc.finishSetup({ addons: ['Peon'] });
  assert.equal(res.failed.length, 1);
  assert.equal(w.svc.addonState().setup.done, false);
  w.close();
});

test('Wer schon Einstellungen hatte, sieht den ersten Start nicht', () => {
  const dir = tmp();
  fs.writeFileSync(path.join(dir, 'settings.json'), JSON.stringify({ wowDir: 'X:\\WoW' }));
  const svc = new Service({ dbDir: dir });
  assert.equal(svc.settings.setup.done, true);
  svc.close();
});

test('Vorschlag fuer den ersten Start entfaellt, sobald Peon da ist', async () => {
  const w = await world();
  await w.svc.addons.check();
  assert.equal(w.svc.addonState().setup.done, false);
  await w.svc.addons.install(['Peon']);
  assert.equal(w.svc.addonState().setup.done, true);
  w.close();
});

test('Release zurueckgezogen: altes Manifest wird vergessen, Installierte bleiben sichtbar', async () => {
  const w = await world();
  await w.svc.addons.check();
  await w.svc.addons.install(['Peon']);
  w.state.latest = null;
  await w.svc.addons.check();
  assert.equal(w.svc.addons.manifest, null);
  const st = w.svc.addonState();
  assert.equal(st.release, null);
  assert.equal(st.check.noRelease, true);
  assert.deepEqual(st.items.map((a) => [a.name, a.status]), [['Peon', 'unknown'], ['Peon_Bridge', 'unknown']]);
  await assert.rejects(() => w.svc.addons.install(['Peon_Tooltip']), /Noch kein Manifest/);
  w.close();
});

test('Selbst-Update: nur eine neuere Version aus dem Manifest, Quelle ist der Ordner des Release', async () => {
  const w = await world();
  assert.equal(w.svc.addons.managerUpdate(), null, 'ohne Manifest nichts');
  await w.svc.addons.check();
  assert.equal(w.svc.addons.managerUpdate(), null, 'gleiche Version');
  const rel = JSON.parse(w.state.releases['v2026.11.04']['manifest.json']);
  rel.manager.version = '0.10.0';   // 0.10 ist neuer als 0.8, auch wenn es als Text kleiner waere
  w.state.releases['v2026.11.04']['manifest.json'] = JSON.stringify(rel);
  await w.svc.addons.check();
  const u = w.svc.addons.managerUpdate();
  assert.equal(u.version, '0.10.0');
  assert.ok(u.feed.endsWith('/releases/download/v2026.11.04'));
  rel.manager.version = '0.7.0';
  w.state.releases['v2026.11.04']['manifest.json'] = JSON.stringify(rel);
  await w.svc.addons.check();
  assert.equal(w.svc.addons.managerUpdate(), null, 'aelter: nichts');
  w.close();
});

test('Einstellungen mit BOM-Markierung (Windows-Editor) bleiben gueltig', () => {
  const dir = tmp();
  fs.writeFileSync(path.join(dir, 'settings.json'), '\uFEFF' + JSON.stringify({ wowDir: 'X:\\WoW', keepDays: 45, setup: { done: false }, modules: {} }));
  const svc = new Service({ dbDir: dir });
  assert.equal(svc.settings.wowDir, 'X:\\WoW');
  assert.equal(svc.settings.keepDays, 45);
  assert.equal(svc.settings.setup.done, false);
  svc.close();
});

test('WoW-Ordner suchen: Registrierung zuerst, dann uebliche Orte', () => {
  const da = new Set(['X:\\Spiele\\Blizzard\\WoW\\_forever_\\Wow.exe', 'C:\\Program Files (x86)\\World of Warcraft\\_forever_\\Wow.exe', 'E:\\Games\\World of Warcraft\\_forever_\\Wow.exe']);
  const r = findWowDirs({ installPaths: ['X:\\Spiele\\Blizzard\\WoW\\_retail_\\'], exists: (p) => da.has(p) });
  assert.deepEqual(r, ['X:\\Spiele\\Blizzard\\WoW\\_forever_', 'C:\\Program Files (x86)\\World of Warcraft\\_forever_', 'E:\\Games\\World of Warcraft\\_forever_']);
  assert.deepEqual(findWowDirs({ exists: () => false }), []);
  assert.equal(PLACEHOLDER.includes('PeonBridgeData ='), false, 'Platzhalter setzt keine Werte');
});
