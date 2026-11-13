'use strict';
// Manager 0.29.0, Angleichung A1 (docs/konzepte/manager/Peon_Manager_Angleichung.md 3.1 und 6):
// Einkaufslisten und Beobachtung je WoW-Konto, Kennung aus Broker, Umstellung des frueheren gemischten Stands.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { Service } = require('../src/core/service');
const { parseLua, toLua } = require('../src/core/lua');

process.removeAllListeners('warning');
const NOW = 1794000000;

function tmp() { return fs.mkdtempSync(path.join(os.tmpdir(), 'peon-k-')); }

function setup() {
  const dir = tmp();
  const wow = tmp();
  const ad = path.join(wow, 'Interface', 'AddOns', 'Peon_Bridge');
  fs.mkdirSync(ad, { recursive: true });
  fs.writeFileSync(path.join(ad, 'Peon_Bridge.toc'), 'x');
  const clock = { t: NOW };
  const svc = new Service({ enable: ['broker-client'], dbDir: dir, version: '0.29.0', now: () => clock.t });
  svc.saveSettings({ wowDir: wow });
  const sv = (folder) => { const p = path.join(wow, 'WTF', 'Account', folder, 'SavedVariables'); fs.mkdirSync(p, { recursive: true }); return p; };
  // Peon_Broker.lua eines Kontoordners schreiben, mt = Zeit der Datei in Sekunden
  const brokerFile = (folder, db, mt) => {
    const f = path.join(sv(folder), 'Peon_Broker.lua');
    fs.writeFileSync(f, `PeonBrokerDB = ${toLua({ markets: {}, ...db })}`);
    fs.utimesSync(f, mt, mt);
  };
  const data = () => parseLua(fs.readFileSync(path.join(ad, 'Data.lua'))).PeonBridgeData;
  return { svc, b: svc.broker, clock, sv, brokerFile, data };
}

const list = (id, name, u, items = {}) => ({ id, name, pct: 10, u, items });

test('Vor dem ersten Konto: gemischter Stand wie bisher, Data.lua ohne Listen', () => {
  const { svc, b, brokerFile, data } = setup();
  brokerFile('ALT', { lists: [list('g1_1', 'Aus altem Broker', NOW - 100)] }, NOW - 50);
  b.importGame();
  assert.deepEqual(b.shopDoc().lists.map((l) => l.name), ['Aus altem Broker'], 'Broker ohne Kennung gleicht ab, solange es kein Konto gibt');
  assert.equal(b.acctSel(), null);
  b.setFavorite('2770', true);
  assert.deepEqual(b.favorites(), ['2770']);
  assert.equal(data().accts, undefined, 'ohne Konto nichts fuer das Spiel');
  assert.deepEqual(b.accounts().list, []);
  assert.deepEqual(b.accounts().waiting, ['ALT']);
  svc.close();
});

test('Umstellung: der gemischte Stand geht an das zuletzt gespielte Konto, andere Konten bleiben fuer sich', () => {
  const { svc, b, brokerFile, data, clock } = setup();
  // frueherer Stand im Manager
  const legacyList = b.newShopList('Erze');
  b.addShopItem(legacyList, '2770');
  b.setFavorite('2589', true);
  // zwei Konten melden sich mit Kennung, A zuletzt gespielt
  brokerFile('KONTOA', { acct: 'kA_1', lists: [list('gA_1', 'Liste A', NOW - 10)], watch: { 1000: { u: NOW - 10 } } }, NOW - 5);
  brokerFile('KONTOB', { acct: 'kB_2', lists: [list('gB_1', 'Liste B', NOW - 20)], watch: { 2000: { u: NOW - 20 } } }, NOW - 300);
  clock.t = NOW + 10;
  b.importGame();

  assert.equal(b.acctSel(), 'kA_1', 'gewaehlt ist das zuletzt gespielte Konto');
  assert.deepEqual(b.shopDoc('kA_1').lists.map((l) => l.name).sort(), ['Erze', 'Liste A'], 'A: frueherer Stand und eigene Liste');
  assert.deepEqual(b.shopDoc('kB_2').lists.map((l) => l.name), ['Liste B'], 'B: nur die eigene Liste');
  assert.deepEqual(b.favorites('kA_1').sort(), ['1000', '2589']);
  assert.deepEqual(b.favorites('kB_2'), ['2000']);
  assert.equal(b.accounts().migrated.acct, 'kA_1');

  // Data.lua je Konto
  const d = data();
  assert.deepEqual(Object.keys(d.accts).sort(), ['kA_1', 'kB_2']);
  assert.deepEqual(d.accts.kB_2.shop.lists.map((l) => l.name), ['Liste B']);
  assert.equal(d.accts.kB_2.watch.items['1000'], undefined, 'nichts von A bei B');
  assert.equal(d.shop, undefined);

  // Ein spaeteres neues Konto bekommt den frueheren Stand nicht noch einmal
  brokerFile('KONTOC', { acct: 'kC_3', lists: [] }, NOW + 20);
  clock.t = NOW + 30;
  b.importGame();
  assert.deepEqual(b.shopDoc('kC_3').lists, []);
  svc.close();
});

test('Auswahl: Stern und Einkaufslisten wirken nur im gewaehlten Konto', () => {
  const { svc, b, brokerFile, data } = setup();
  brokerFile('KONTOA', { acct: 'kA_1' }, NOW - 5);
  brokerFile('KONTOB', { acct: 'kB_2' }, NOW - 50);
  b.importGame();
  assert.equal(b.selectAccount('gibtsnicht'), false);
  assert.equal(b.selectAccount('kB_2'), true);
  assert.equal(b.acctSel(), 'kB_2');
  b.setFavorite('2770', true);
  const id = b.newShopList('Nur B');
  assert.deepEqual(b.favorites(), ['2770']);
  assert.deepEqual(b.favorites('kA_1'), []);
  assert.deepEqual(b.shopLists('2770').map((l) => l.id), [id]);
  assert.equal(b.shopDoc('kA_1').lists.length, 0);
  assert.equal(data().accts.kB_2.shop.lists[0].name, 'Nur B');
  assert.equal(data().accts.kA_1, undefined, 'A hat nichts');
  svc.close();
});

test('Abgleich je Konto: Aenderungen aus dem Spiel landen nur beim eigenen Konto', () => {
  const { svc, b, brokerFile, clock } = setup();
  brokerFile('KONTOA', { acct: 'kA_1', lists: [list('gA_1', 'Liste A', NOW - 10)] }, NOW - 5);
  brokerFile('KONTOB', { acct: 'kB_2', lists: [list('gB_1', 'Liste B', NOW - 20)] }, NOW - 50);
  b.importGame();
  // B aendert im Spiel und beobachtet etwas
  clock.t = NOW + 100;
  brokerFile('KONTOB', { acct: 'kB_2', lists: [list('gB_1', 'Liste B neu', NOW + 90)], watch: { 3000: { u: NOW + 90 } } }, NOW + 95);
  b.importGame();
  assert.deepEqual(b.shopDoc('kB_2').lists.map((l) => l.name), ['Liste B neu']);
  assert.deepEqual(b.shopDoc('kA_1').lists.map((l) => l.name), ['Liste A']);
  assert.deepEqual(b.favorites('kB_2'), ['3000']);
  assert.deepEqual(b.favorites('kA_1'), []);
  // Ein Ordner mit altem Broker (ohne Kennung) gleicht jetzt nichts mehr ab
  brokerFile('ALT', { lists: [list('gX_1', 'Ohne Kennung', NOW + 100)] }, NOW + 100);
  clock.t = NOW + 200;
  b.importGame();
  assert.ok(!b.shopDoc('kA_1').lists.some((l) => l.name === 'Ohne Kennung'));
  assert.ok(!b.shopDoc('kB_2').lists.some((l) => l.name === 'Ohne Kennung'));
  assert.deepEqual(b.accounts().waiting, ['ALT']);
  svc.close();
});

test('Dieselbe Kennung in zwei Ordnern: Hinweis, abgeglichen wird nur der zuletzt gespeicherte', () => {
  const { svc, b, brokerFile, clock } = setup();
  brokerFile('KONTOA', { acct: 'kA_1', lists: [list('gA_1', 'Original', NOW - 10)] }, NOW - 100);
  b.importGame();
  // Kopie des Ordners, zuletzt gespeichert
  brokerFile('KOPIE', { acct: 'kA_1', lists: [list('gA_1', 'Kopie', NOW + 5)] }, NOW + 5);
  clock.t = NOW + 10;
  b.importGame();
  const a = b.accounts().list.find((x) => x.id === 'kA_1');
  assert.equal(a.dup, true);
  assert.equal(a.folder, 'KOPIE');
  assert.deepEqual(a.folders, ['KOPIE', 'KONTOA']);
  assert.equal(b.shopDoc('kA_1').lists[0].name, 'Kopie');
  // Der aeltere Ordner aendert spaeter etwas, wird aber nicht neuer gespeichert als die Kopie: kein Abgleich
  brokerFile('KONTOA', { acct: 'kA_1', lists: [list('gA_1', 'Alt geaendert', NOW + 20)] }, NOW + 1);
  clock.t = NOW + 30;
  b.importGame();
  assert.equal(b.shopDoc('kA_1').lists[0].name, 'Kopie');
  svc.close();
});

test('Konten fuer die Datenlage: eigener Name, Charaktere aus Ledger, Zahlen', () => {
  const { svc, b, brokerFile, sv } = setup();
  brokerFile('KONTOA', { acct: 'kA_1', lists: [list('gA_1', 'Liste A', NOW - 10)], watch: { 1000: { u: NOW - 10 } } }, NOW - 5);
  fs.writeFileSync(path.join(sv('KONTOA'), 'Peon_Ledger.lua'), `PeonLedgerDB = ${toLua({ realms: { R: { chars: { Zora: {}, Anton: {} } } } })}`);
  b.importGame();
  assert.equal(b.nameAccount('kA_1', '  Hauptkonto  '), true);
  const a = b.accounts().list[0];
  assert.equal(a.name, 'Hauptkonto');
  assert.equal(a.folder, 'KONTOA');
  assert.deepEqual(a.chars, ['Anton', 'Zora']);
  assert.equal(a.lists, 1);
  assert.equal(a.watch, 1);
  assert.equal(a.selected, true);
  assert.equal(b.nameAccount('kA_1', ''), true);
  assert.equal(b.accounts().list[0].name, null, 'leer = wieder ohne Namen');
  svc.close();
});
