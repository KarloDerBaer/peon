'use strict';
// Tests fuer scripts/build_release.js: node --test scripts/test/
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const crypto = require('node:crypto');
const R = require('../build_release');

function tmp(name) { return fs.mkdtempSync(path.join(os.tmpdir(), 'peon-rel-' + name + '-')); }

// Nachgebautes Repo: zwei Addons, eines nur fuer den Manager mit Data.lua
function fakeRepo({ brokerVersion = '0.33.0', bridgeExtra = '' } = {}) {
  const repo = tmp('repo');
  const w = (rel, text) => { const f = path.join(repo, rel); fs.mkdirSync(path.dirname(f), { recursive: true }); fs.writeFileSync(f, text); };
  w('manager/package.json', JSON.stringify({ name: 'peon-manager', version: '0.6.0' }));
  w('addons/Peon/Peon.toc', '## Interface: 16001\n## Title: |cff8ccf4dPeon|r\n## Notes-deDE: Kern\n## Version: 0.11.0\n\nCore.lua\n');
  w('addons/Peon/Core.lua', 'Peon = {}\nPeon.API       = 11   -- Kommentar\n');
  w('addons/Peon_Broker/Peon_Broker.toc', `## Interface: 16001\n## Title: |cff8ccf4dPeon|r Broker\n## Notes: Auction\n## Notes-deDE: Auktionshaus-Helfer\n## Version: ${brokerVersion}\n## Dependencies: Peon\n\nBroker.lua\nMedia\\trend.tga\n`);
  w('addons/Peon_Broker/Broker.lua', '-- Broker\n');
  w('addons/Peon_Broker/Media/trend.tga', 'TGA\0\x01\x02');
  w('addons/Peon_Bridge/Peon_Bridge.toc', `## Interface: 16001\n## Title: |cff8ccf4dPeon|r Bridge\n## Version: 0.4.0\n## Dependencies: Peon\n\nData.lua\nBridge.lua\n${bridgeExtra}`);
  w('addons/Peon_Bridge/Bridge.lua', '-- Bridge\n');
  w('addons/Peon_Bridge/Data.lua', 'PeonBridgeData = {}\n');   // vom Manager, nie ausliefern
  w('docs/changelog/Peon.md', '# Peon\n\n## 0.11.0\n\n- Kern neu\n\n## 0.10.0\n\n- alt\n');
  w('docs/changelog/Peon_Broker.md', '# Broker\n\n## 0.33.0\n\n- Bridge\n\n## 0.32.0\n\n- Absatz\n\n## 0.31.0\n\n- Bereich\n');
  w('docs/changelog/Peon_Bridge.md', '# Bridge\n\n## 0.4.0\n\n- Kanaele\n');
  const config = {
    fmt: 1, discord: null, managerMinVersion: '0.6.0',
    addons: { Peon: { api: 'core' }, Peon_Broker: { api: 8 }, Peon_Bridge: { api: 5, managerOnly: true, exclude: ['Data.lua'] } },
    managerModules: [{ key: 'broker-client', title: 'Peon Broker Client', needs: ['Peon_Broker', 'Peon_Bridge'] }],
  };
  // Dateien wie git ls-files (alles, was im Ordner liegt)
  const listFiles = (name) => {
    const base = path.join(repo, 'addons', name), out = [];
    const walk = (d) => { for (const e of fs.readdirSync(d, { withFileTypes: true })) { const p = path.join(d, e.name); if (e.isDirectory()) walk(p); else out.push(path.relative(base, p).split(path.sep).join('/')); } };
    walk(base);
    return out;
  };
  return { repo, config, listFiles };
}

function run(f, extra = {}) {
  return R.build({ repo: f.repo, config: f.config, listFiles: f.listFiles, out: tmp('out'), tag: 'v2026.11.04', ...extra });
}

test('Zip: hin und zurueck, Ordner, leere Datei, Umlaute', () => {
  const zip = R.makeZip([{ name: 'A/' }, { name: 'A/x.lua', data: Buffer.from('print(1)\n'.repeat(50)) }, { name: 'A/leer.txt', data: Buffer.alloc(0) }, { name: 'A/Größe.txt', data: Buffer.from('ä') }]);
  const e = R.readZip(zip);
  assert.deepEqual(e.map((x) => x.name), ['A/', 'A/x.lua', 'A/leer.txt', 'A/Größe.txt']);
  assert.equal(e[1].data.toString(), 'print(1)\n'.repeat(50));
  assert.equal(e[2].data.length, 0);
  assert.equal(e[3].data.toString(), 'ä');
});

test('Bauen: Zips, Manifest, Data.lua nie dabei', () => {
  const f = fakeRepo();
  const { out, manifest: m } = run(f);
  assert.equal(m.release, 'v2026.11.04');
  assert.equal(m.date, '2026-11-04');
  assert.equal(m.prerelease, false);
  assert.deepEqual(m.manager, { version: '0.6.0', minVersion: '0.6.0' });
  assert.deepEqual(m.addons.map((a) => a.name), ['Peon', 'Peon_Bridge', 'Peon_Broker']);
  const peon = m.addons[0], bridge = m.addons[1], broker = m.addons[2];
  assert.equal(peon.title, 'Peon');
  assert.equal(peon.api, 11);
  assert.deepEqual(peon.deps, []);
  assert.equal(broker.title, 'Broker');
  assert.equal(broker.desc, 'Auktionshaus-Helfer');
  assert.deepEqual(broker.deps, ['Peon']);
  assert.equal(broker.api, 8);
  assert.equal(broker.interface, 16001);
  assert.equal(broker.file, 'Peon_Broker-0.33.0.zip');
  assert.equal(broker.managerOnly, false);
  assert.equal(bridge.managerOnly, true);
  for (const a of m.addons) {
    const buf = fs.readFileSync(path.join(out, a.file));
    assert.equal(buf.length, a.size);
    assert.equal(crypto.createHash('sha256').update(buf).digest('hex'), a.sha256);
  }
  const names = R.readZip(fs.readFileSync(path.join(out, broker.file))).map((e) => e.name);
  assert.deepEqual(names, ['Peon_Broker/', 'Peon_Broker/Broker.lua', 'Peon_Broker/Media/', 'Peon_Broker/Media/trend.tga', 'Peon_Broker/Peon_Broker.toc']);
  const bn = R.readZip(fs.readFileSync(path.join(out, bridge.file))).map((e) => e.name);
  assert.ok(!bn.some((n) => /Data\.lua$/.test(n)), 'Data.lua darf nicht ausgeliefert werden');
  assert.ok(bn.includes('Peon_Bridge/Bridge.lua'));
  assert.deepEqual(m.managerModules[0].needs, ['Peon_Broker', 'Peon_Bridge']);
  const notes = fs.readFileSync(path.join(out, 'manifest.json'), 'utf8');
  assert.ok(JSON.parse(notes).addons.length === 3);
  assert.match(fs.readFileSync(path.join(out, 'notes.md'), 'utf8'), /\| Peon_Bridge \| 0\.4\.0 \| nur mit dem Peon Manager \|/);
});

test('Gleiches Addon, gleiches Zip (Pruefsumme bleibt)', () => {
  const f = fakeRepo();
  const a = run(f).manifest, b = run(f).manifest;
  assert.deepEqual(a.addons.map((x) => x.sha256), b.addons.map((x) => x.sha256));
});

test('Was ist neu: ohne frueheres Release nur die aktuelle Version, sonst alles seitdem', () => {
  const f = fakeRepo();
  const first = run(f).manifest;
  const broker = first.addons.find((a) => a.name === 'Peon_Broker');
  assert.equal(broker.notes, '### 0.33.0\n\n- Bridge');
  assert.equal(broker.changed, true);
  const prev = { addons: [{ name: 'Peon_Broker', version: '0.31.0' }, { name: 'Peon', version: '0.11.0' }] };
  const second = run(f, { prev }).manifest;
  const b2 = second.addons.find((a) => a.name === 'Peon_Broker');
  assert.equal(b2.notes, '### 0.33.0\n\n- Bridge\n\n### 0.32.0\n\n- Absatz');
  const p2 = second.addons.find((a) => a.name === 'Peon');
  assert.equal(p2.changed, false);
  assert.equal(p2.notes, '');
  assert.match(R.releaseNotes(second), /\| Peon \| 0\.11\.0 \| unverändert \|/);
});

test('Vorabversion: Tag mit -test', () => {
  const m = run(fakeRepo(), { test: true }).manifest;
  assert.equal(m.release, 'v2026.11.04-test');
  assert.equal(m.prerelease, true);
  assert.throws(() => run(fakeRepo(), { tag: '2026-11-04' }), /Tag passt nicht/);
  assert.equal(run(fakeRepo(), { tag: 'v2026.11.04.2' }).manifest.release, 'v2026.11.04.2');
});

test('Fehler: Version ohne Changelog, Datei aus der TOC fehlt, Addon nicht in release.json', () => {
  assert.throws(() => run(fakeRepo({ brokerVersion: '0.34.0' })), /Peon_Broker 0\.34\.0: kein Abschnitt/);
  assert.throws(() => run(fakeRepo({ bridgeExtra: 'Fehlt.lua\n' })), /Datei aus der TOC fehlt im Repo: Fehlt\.lua/);
  const f = fakeRepo();
  delete f.config.addons.Peon_Broker;
  assert.throws(() => run(f), /Peon_Broker: fehlt in scripts\/release\.json/);
});

test('Versionen vergleichen', () => {
  assert.ok(R.cmpVersion('0.10.0', '0.9.9') > 0);
  assert.ok(R.cmpVersion('1.5.1', '1.5.1') === 0);
  assert.ok(R.cmpVersion('0.2.0', '0.10.0') < 0);
});

test('Echtes Repo: alle Addons, Bridge nur fuer den Manager, ohne Data.lua', () => {
  const { out, manifest: m } = R.build({ out: tmp('echt'), tag: 'v2026.11.04', dirty: true });
  const names = m.addons.map((a) => a.name);
  for (const n of ['Peon', 'Peon_Broker', 'Peon_Bridge', 'Peon_Ledger', 'Peon_Tooltip']) assert.ok(names.includes(n), n);
  assert.ok(!names.includes('Peon_Feedback'));
  const bridge = m.addons.find((a) => a.name === 'Peon_Bridge');
  assert.equal(bridge.managerOnly, true);
  assert.ok(!R.readZip(fs.readFileSync(path.join(out, bridge.file))).some((e) => /Data\.lua$/.test(e.name)));
  assert.ok(m.addons.every((a) => a.notes.startsWith(`### ${a.version}`)), 'jede Version hat einen Changelog-Abschnitt');
  assert.equal(m.addons.find((a) => a.name === 'Peon').api, 11);
});
