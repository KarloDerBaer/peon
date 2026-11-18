'use strict';
// Sicherung der Spieldaten (ab 0.48.0): was gesichert wird, Anlaesse, Aufraeumen, Wiederherstellen, Schutz
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { GameBackup, KEEP } = require('../src/core/gamebackup');

function world() {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'peon-spiel-'));
  const wowDir = path.join(root, 'wow');
  const acc = path.join(wowDir, 'WTF', 'Account', 'KONTO');
  const w = (rel, text) => { const f = path.join(acc, ...rel.split('/')); fs.mkdirSync(path.dirname(f), { recursive: true }); fs.writeFileSync(f, text); return f; };
  w('SavedVariables/Peon.lua', 'PeonDB = { a = 1 }\n');
  w('SavedVariables/Peon_Ledger.lua', 'PeonLedgerDB = { buch = "' + 'x'.repeat(5000) + '" }\n');
  w('SavedVariables/Blizzard_Fremd.lua', 'Fremd = 1\n');
  w('SavedVariables/Peon_Ledger.lua.bak', 'alt\n');
  w('Server/Charakter/SavedVariables/Peon_Fishing.lua', 'PeonFishingCharDB = { mode = "fishing" }\n');
  w('Server/Charakter/SavedVariables/Anderes.lua', 'x\n');
  const logs = [];
  let now = 1_800_000_000;
  const host = { settings: { wowDir }, dbDir: path.join(root, 'daten'), now: () => now, log: (ok, text) => logs.push({ ok, text }) };
  return { root, acc, w, host, logs, gb: new GameBackup(host), tick: (s) => { now += s; } };
}

test('Spielsicherung: nur Peon-Dateien aus Konto und Charakter, gepackt, mit Liste', () => {
  const { gb, acc, logs } = world();
  const src = gb.sources().map((s) => s.rel).sort();
  assert.deepEqual(src, ['KONTO/SavedVariables/Peon.lua', 'KONTO/SavedVariables/Peon_Ledger.lua', 'KONTO/Server/Charakter/SavedVariables/Peon_Fishing.lua']);
  const r = gb.create('manuell');
  assert.equal(r.files, 3);
  assert.ok(r.bytes > 0 && r.bytes < fs.statSync(path.join(acc, 'SavedVariables', 'Peon_Ledger.lua')).size, 'gepackt kleiner als das Original');
  const list = gb.list();
  assert.equal(list.length, 1);
  assert.equal(list[0].kind, 'manuell');
  assert.equal(list[0].files, 3);
  assert.ok(fs.existsSync(path.join(gb.dir, r.id, 'KONTO', 'SavedVariables', 'Peon.lua.gz')));
  assert.ok(logs.some((l) => l.ok && /3 Dateien/.test(l.text)));
  assert.throws(() => gb.create('quatsch'), /Unbekannter Anlass/);
});

test('Spielsicherung: ohne WoW-Ordner oder ohne Peon-Dateien nichts', () => {
  const { gb, host } = world();
  host.settings.wowDir = '';
  assert.deepEqual(gb.sources(), []);
  assert.equal(gb.create('manuell'), null);
  host.settings.wowDir = path.join(host.dbDir, 'gibtsnicht');
  assert.equal(gb.create('manuell'), null);
  assert.deepEqual(gb.list(), []);
});

test('Spielsicherung: vor Updates hoechstens alle 10 Minuten, taeglich einmal, je Anlass nur die neuesten', () => {
  const { gb, tick } = world();
  assert.ok(gb.beforeUpdate());
  tick(60);
  assert.equal(gb.beforeUpdate(), null, 'kurz danach keine zweite');
  tick(10 * 60);
  assert.ok(gb.beforeUpdate());
  assert.ok(gb.dailyIfDue());
  tick(3600);
  assert.equal(gb.dailyIfDue(), null, 'heute schon');
  tick(20 * 3600);
  assert.ok(gb.dailyIfDue());
  for (let i = 0; i < KEEP.update + 3; i++) { tick(11 * 60); gb.beforeUpdate(); }
  const kinds = gb.list().reduce((m, b) => { m[b.kind] = (m[b.kind] || 0) + 1; return m; }, {});
  assert.equal(kinds.update, KEEP.update, 'nur die neuesten vor Updates');
  assert.equal(kinds.taeglich, 2, 'taegliche bleiben davon unberuehrt');
  const ups = gb.list().filter((b) => b.kind === 'update');
  assert.ok(ups[0].t > ups[ups.length - 1].t, 'neueste zuerst');
});

test('Spielsicherung: Wiederherstellen nur bei geschlossenem WoW, vorher wird der jetzige Stand gesichert', () => {
  const { gb, acc, tick } = world();
  const first = gb.create('manuell');
  fs.writeFileSync(path.join(acc, 'SavedVariables', 'Peon.lua'), 'PeonDB = { kaputt = true }\n');
  fs.rmSync(path.join(acc, 'Server', 'Charakter', 'SavedVariables', 'Peon_Fishing.lua'));
  tick(5);
  const nein = gb.restore(first.id, true);
  assert.equal(nein.ok, false);
  assert.match(nein.error, /WoW läuft/);
  assert.match(fs.readFileSync(path.join(acc, 'SavedVariables', 'Peon.lua'), 'utf8'), /kaputt/, 'bei laufendem WoW nichts angefasst');
  const r = gb.restore(first.id, false);
  assert.equal(r.ok, true);
  assert.equal(r.files, 3);
  assert.equal(fs.readFileSync(path.join(acc, 'SavedVariables', 'Peon.lua'), 'utf8'), 'PeonDB = { a = 1 }\n');
  assert.match(fs.readFileSync(path.join(acc, 'Server', 'Charakter', 'SavedVariables', 'Peon_Fishing.lua'), 'utf8'), /fishing/, 'fehlende Datei wieder da');
  assert.equal(fs.readFileSync(path.join(acc, 'SavedVariables', 'Blizzard_Fremd.lua'), 'utf8'), 'Fremd = 1\n', 'fremde Dateien unberuehrt');
  const before = gb.list().find((b) => b.id === r.before);
  assert.equal(before.kind, 'vor-wiederherstellen');
  assert.equal(before.files, 2, 'der kaputte Stand ist gesichert');
  assert.equal(gb.restore('../../etwas', false).ok, false);
  assert.equal(gb.restore('2026-01-01_000000_manuell', false).ok, false);
});

test('Spielsicherung: Pfade in info.json koennen nicht aus dem WoW-Ordner heraus schreiben', () => {
  const { gb, root, acc } = world();
  const r = gb.create('manuell');
  const infoFile = path.join(gb.dir, r.id, 'info.json');
  const info = JSON.parse(fs.readFileSync(infoFile, 'utf8'));
  info.files.push('../../../boese/SavedVariables/Peon.lua', 'KONTO/SavedVariables/nicht-peon.lua', 'KONTO/Ordner/Peon.lua');
  fs.writeFileSync(infoFile, JSON.stringify(info));
  const res = gb.restore(r.id, false);
  assert.equal(res.ok, true);
  assert.equal(res.files, 3);
  assert.ok(!fs.existsSync(path.join(root, 'boese')));
  assert.ok(!fs.existsSync(path.join(acc, 'Ordner')));
});

test('Spielsicherung: Loeschen nur echter Sicherungen', () => {
  const { gb } = world();
  const r = gb.create('manuell');
  assert.equal(gb.remove('../daten'), false);
  assert.equal(gb.remove(r.id), true);
  assert.deepEqual(gb.list(), []);
  assert.equal(gb.remove(r.id), false);
});

test('Spielsicherung: der Service sichert vor dem Installieren von Addons', () => {
  const src = fs.readFileSync(path.join(__dirname, '..', 'src', 'core', 'addons.js'), 'utf8');
  const i = src.indexOf('async install(names)');
  const j = src.indexOf('for (const n of this.plan(names))', i);
  assert.ok(i > 0 && j > i && src.slice(i, j).includes('gameBackup.beforeUpdate()'), 'Sicherung vor der Schleife der Installation');
  const svc = fs.readFileSync(path.join(__dirname, '..', 'src', 'core', 'service.js'), 'utf8');
  assert.match(svc, /this\.gameBackup = new GameBackup\(/);
});
