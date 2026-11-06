'use strict';
// Tests fuer scripts/junctions.ps1 (nur Windows): laeuft auf einem erfundenen Repo und AddOns-Ordner im Temp-Ordner.
const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const SCRIPT = path.join(__dirname, '..', 'junctions.ps1');
const skip = process.platform !== 'win32' ? 'nur unter Windows' : false;

function setup(t) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'peon junctions '));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const repo = path.join(root, 'repo');
  const addons = path.join(root, 'AddOns');
  const archiv = path.join(root, 'archiv');
  for (const [name, version] of [['Peon', '0.13.0'], ['Peon_Bridge', '0.5.0']]) {
    const dir = path.join(repo, 'addons', name);
    fs.mkdirSync(path.join(dir, 'Sub'), { recursive: true });
    fs.writeFileSync(path.join(dir, `${name}.toc`), `## Title: ${name}\n## Version: ${version}\n`);
    fs.writeFileSync(path.join(dir, 'Sub', 'code.lua'), `-- ${name} ä\n`);
  }
  fs.mkdirSync(addons);
  const run = (...args) => {
    const r = spawnSync('powershell', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', SCRIPT, ...args,
      '-AddOns', addons, '-Archiv', archiv, '-Repo', repo, '-OhneWowPruefung'], { encoding: 'utf8' });
    return { code: r.status, out: r.stdout + r.stderr };
  };
  const isLink = (name) => fs.lstatSync(path.join(addons, name)).isSymbolicLink();
  const inRepo = (name, rel) => path.join(repo, 'addons', name, rel);
  const inGame = (name, rel) => path.join(addons, name, rel);
  return { repo, addons, archiv, run, isLink, inRepo, inGame };
}

test('Entwicklung legt Junctions an, Manager macht echte Ordner daraus, das Repo bleibt', { skip }, (t) => {
  const w = setup(t);
  assert.equal(w.run('entwicklung').code, 0);
  assert.ok(w.isLink('Peon') && w.isLink('Peon_Bridge'));

  fs.writeFileSync(w.inRepo('Peon_Bridge', 'Data.lua'), 'PeonBridgeData = { fmt = 2 }\n');
  const r = w.run('manager');
  assert.equal(r.code, 0, r.out);
  assert.ok(!w.isLink('Peon') && !w.isLink('Peon_Bridge'));
  assert.equal(fs.readFileSync(w.inGame('Peon', 'Sub/code.lua'), 'utf8'), '-- Peon ä\n');
  assert.equal(fs.readFileSync(w.inGame('Peon_Bridge', 'Data.lua'), 'utf8'), 'PeonBridgeData = { fmt = 2 }\n', 'Werte des Managers bleiben');
  assert.ok(fs.existsSync(w.inRepo('Peon', 'Sub/code.lua')), 'das Repo ist unberuehrt');
  assert.deepEqual(fs.readdirSync(w.addons).sort(), ['Peon', 'Peon_Bridge'], 'kein Zwischenordner bleibt liegen');
});

test('Einzelne Module umschalten, die anderen bleiben', { skip }, (t) => {
  const w = setup(t);
  w.run('entwicklung');
  assert.equal(w.run('manager', 'Peon_Bridge').code, 0);
  assert.ok(w.isLink('Peon'), 'nicht genannt');
  assert.ok(!w.isLink('Peon_Bridge'));
});

test('Falscher Modulname oder falsche Aktion: nichts wird geaendert', { skip }, (t) => {
  const w = setup(t);
  w.run('entwicklung');
  assert.equal(w.run('manager', 'Peon_Gibtsnicht').code, 1);
  assert.equal(w.run('umschalten').code, 1);
  assert.ok(w.isLink('Peon') && w.isLink('Peon_Bridge'));
});

test('Zurueck zur Entwicklung: Ordner mit anderer Version wandert ins Archiv, Data.lua kommt mit', { skip }, (t) => {
  const w = setup(t);
  w.run('entwicklung');
  w.run('manager');
  // Der Manager hat aktualisiert und Data.lua neu geschrieben
  fs.writeFileSync(w.inGame('Peon', 'Peon.toc'), '## Title: Peon\n## Version: 0.12.0\n');
  fs.writeFileSync(w.inGame('Peon_Bridge', 'Data.lua'), 'PeonBridgeData = { fmt = 3 }\n');
  assert.match(w.run('status').out, /Version 0\.12\.0 \(Repo 0\.13\.0\)/);

  const r = w.run('entwicklung');
  assert.equal(r.code, 0, r.out);
  assert.ok(w.isLink('Peon') && w.isLink('Peon_Bridge'));
  assert.match(fs.readFileSync(path.join(w.archiv, 'Peon', 'Peon.toc'), 'utf8'), /0\.12\.0/, 'nichts geht verloren');
  assert.match(fs.readFileSync(w.inRepo('Peon', 'Peon.toc'), 'utf8'), /0\.13\.0/, 'Repo unveraendert');
  assert.equal(fs.readFileSync(w.inRepo('Peon_Bridge', 'Data.lua'), 'utf8'), 'PeonBridgeData = { fmt = 3 }\n');

  // Mehrmals am selben Tag: freier Name im Archiv
  w.run('manager');
  assert.equal(w.run('entwicklung').code, 0);
  assert.ok(fs.existsSync(path.join(w.archiv, 'Peon-2')));
});

test('Anlegen bleibt streng: abweichende Ordner werden nicht ersetzt', { skip }, (t) => {
  const w = setup(t);
  w.run('entwicklung');
  w.run('manager');
  fs.writeFileSync(w.inGame('Peon', 'Peon.toc'), '## Version: 0.12.0\n');
  assert.equal(w.run('anlegen').code, 1);
  assert.ok(!w.isLink('Peon'), 'abweichend, bleibt');
  assert.ok(w.isLink('Peon_Bridge'), 'gleich, wird ersetzt');
});
