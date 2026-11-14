'use strict';
// Tests fuer den Umzug des Datenordners (ab Manager 0.36.0, src/core/datadir.js): node --test test/
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const datadir = require('../src/core/datadir');

const tmp = () => fs.mkdtempSync(path.join(os.tmpdir(), 'peon-dd-'));

function fill(dir) {
  fs.mkdirSync(path.join(dir, 'backup'), { recursive: true });
  fs.mkdirSync(path.join(dir, 'tmp'), { recursive: true });
  fs.writeFileSync(path.join(dir, 'peon.db'), 'a'.repeat(100));
  fs.writeFileSync(path.join(dir, 'broker-client.db-wal'), 'b'.repeat(50));
  fs.writeFileSync(path.join(dir, 'backup', 'alt.db'), 'c'.repeat(10));
  fs.writeFileSync(path.join(dir, 'tmp', 'zwischen'), 'd'.repeat(1000));
}

test('Pruefen: leerer Ordner direkt, voller Ordner mit Unterordner, nicht in sich selbst', () => {
  const root = tmp();
  const from = path.join(root, 'Daten');
  fill(from);
  const empty = path.join(root, 'leer');
  fs.mkdirSync(empty);
  const a = datadir.check(from, empty);
  assert.equal(a.error, null);
  assert.equal(a.to, empty);
  assert.equal(a.bytes, 160, 'ohne tmp');
  const full = path.join(root, 'voll');
  fs.mkdirSync(full);
  fs.writeFileSync(path.join(full, 'x.txt'), 'x');
  assert.equal(datadir.check(from, full).to, path.join(full, datadir.SUBDIR));
  assert.ok(datadir.check(from, from).error, 'derselbe Ordner');
  assert.ok(datadir.check(from, path.join(from, 'neu')).error, 'im alten Ordner');
});

test('Umzug: kopiert alles ausser tmp, Zeiger erst danach, alter Ordner bleibt', async () => {
  const root = tmp();
  const base = path.join(root, 'Peon Manager');
  const from = path.join(base, 'Daten');
  fill(from);
  const to = path.join(root, 'D', 'PeonManager');
  assert.equal(datadir.resolve(base, from), from, 'ohne Zeiger der Standard');
  datadir.request(base, from, to);
  assert.equal(datadir.resolve(base, from), from, 'vorgemerkt, noch nicht umgezogen');
  const r = await datadir.applyPending(base, from, { now: 1 });
  assert.ok(r.ok, r.error);
  assert.equal(datadir.resolve(base, from), to);
  assert.equal(fs.readFileSync(path.join(to, 'backup', 'alt.db'), 'utf8'), 'c'.repeat(10));
  assert.ok(!fs.existsSync(path.join(to, 'tmp')), 'tmp zieht nicht mit');
  assert.ok(fs.existsSync(path.join(from, 'peon.db')), 'alter Ordner bleibt');
  assert.equal(datadir.pointer(base).from, from);
  assert.equal(await datadir.applyPending(base, from), null, 'nur einmal');
  // zurueck in den Standard: Zeiger weg, Ziel muss leer sein
  fs.renameSync(from, `${from}-alt`);
  datadir.request(base, to, from);
  assert.ok((await datadir.applyPending(base, from)).ok);
  assert.equal(datadir.pointer(base), null);
  assert.equal(datadir.resolve(base, from), from);
});

test('Umzug scheitert: Zeiger bleibt, halbe Kopie wird weggeraeumt', async () => {
  const root = tmp();
  const base = path.join(root, 'Peon Manager');
  const from = path.join(base, 'Daten');
  fill(from);
  const to = path.join(root, 'neu');
  datadir.request(base, from, to);
  fs.writeFileSync(path.join(base, datadir.PENDING), JSON.stringify({ from: path.join(root, 'gibtsnicht'), to }));
  const r = await datadir.applyPending(base, from);
  assert.ok(!r.ok && r.error);
  assert.equal(datadir.resolve(base, from), from);
  assert.ok(!fs.existsSync(to));
  assert.throws(() => datadir.request(base, from, from), /schon der Datenordner/);
});
