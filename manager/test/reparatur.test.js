'use strict';
// Manager 0.34.0: Fehler aus dem ersten Test der Vorabversion v2026.11.13-test (Beobachten).
//   Grenzen aus dem Spiel kamen bei alten Eintraegen nie an, ein leerer Wert ohne Aenderung bekam eine neue Zeit,
//   "wartet auf /reload" blieb stehen, die erste Eingabe nach dem Start rechnete alle Maerkte neu.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { Service } = require('../src/core/service');
const { parseLua, toLua } = require('../src/core/lua');
const watching = require('../src/core/watching');

process.removeAllListeners('warning');
const NOW = 1794000000;
function tmp() { return fs.mkdtempSync(path.join(os.tmpdir(), 'peon-r-')); }

function setup() {
  const dir = tmp(), wow = tmp();
  const ad = path.join(wow, 'Interface', 'AddOns', 'Peon_Bridge');
  fs.mkdirSync(ad, { recursive: true });
  fs.writeFileSync(path.join(ad, 'Peon_Bridge.toc'), 'x');
  const sv = path.join(wow, 'WTF', 'Account', 'KONTOA', 'SavedVariables');
  fs.mkdirSync(sv, { recursive: true });
  const clock = { t: NOW };
  const svc = new Service({ enable: ['broker-client'], dbDir: dir, version: '0.34.0', now: () => clock.t });
  svc.saveSettings({ wowDir: wow });
  let ft = 0;
  const write = (name, text) => { const f = path.join(sv, name); fs.writeFileSync(f, text); ft = Math.max(ft + 1, clock.t); fs.utimesSync(f, ft, ft); return ft; };
  const game = (db) => { write('Peon_Broker.lua', `PeonBrokerDB = ${toLua({ markets: {}, acct: 'kA_1', ...db })}`); svc.broker.importGame(); };
  const data = () => parseLua(fs.readFileSync(path.join(ad, 'Data.lua'))).PeonBridgeData;
  return { svc, b: svc.broker, clock, game, write, data };
}

// Spielstand wie bei KarloDerBaer: drei beobachtete Gegenstaende mit Grenzen, ohne Zeiten je Wert (vor Broker 0.89)
const GAME = {
  2452: { u: NOW - 9000, lim: 300, up: 340, name: 'Flitzdistel' },
  3818: { u: NOW - 3000, lim: 300, up: 500, name: 'Blassblatt' },
};

test('Alte Beobachtung ohne Grenzen (Tabelle favorites, gleiche Zeit wie im Spiel): die Grenzen kommen an', () => {
  const { svc, b, game } = setup();
  // Stand vor 0.29.0: nur "beobachtet" mit derselben Zeit wie im Spiel
  for (const [k, w] of Object.entries(GAME)) b.db.prepare('INSERT INTO favorites(item_key, added) VALUES (?, ?)').run(k, w.u);
  game({ watch: GAME });
  const d = b.watchDoc();
  assert.deepEqual([d.items['2452'].lim, d.items['2452'].up], [300, 340]);
  assert.deepEqual([d.items['3818'].lim, d.items['3818'].up], [300, 500]);
  svc.close();
});

test('Reparatur: schon gespeicherte leere Grenzen mit Zeit aus u bekommen die Werte aus dem Spiel, eine leere Aenderung ohne Eingabe faellt weg', () => {
  const { svc, b, game, data, clock } = setup();
  game({});
  // Stand wie in 0.33.0 nach dem Fehler: Zeiten je Wert aus u, keine Werte, bei Blassblatt eine neue leere Zeit fuer Kaufen bis
  b.saveWatch('kA_1', { items: {
    2452: { u: NOW - 9000, t: { buy: NOW - 9000, up: NOW - 9000 }, name: 'Flitzdistel' },
    3818: { u: NOW + 50, t: { buy: NOW + 50, up: NOW - 3000 }, name: 'Blassblatt' },
  }, gone: {} });
  b.savePend('kA_1', { 'w|3818|buy': { t: NOW + 50, base: NOW - 3000, v: null } });
  b.meta('fixWatchT', null);
  clock.t = NOW + 100;
  game({ watch: GAME });
  const d = b.watchDoc();
  assert.deepEqual([d.items['2452'].lim, d.items['2452'].up], [300, 340]);
  assert.deepEqual([d.items['3818'].lim, d.items['3818'].up], [300, 500], 'Kaufen bis aus dem Spiel bleibt');
  assert.equal(b.pendOf('kA_1')['w|3818|buy'], undefined);
  // Data.lua loescht im Spiel nichts: Kaufen bis steht mit dem Wert aus dem Spiel darin
  const g = data().accts.kA_1.watch.items;
  assert.equal((g[3818] || g['3818']).lim, 300);
  // nur einmal
  assert.equal(b.repairWatchTimes(), 0);
  svc.close();
});

test('Reparatur laesst bewusst geleerte Werte (Eintrag im Protokoll) in Ruhe', () => {
  const { svc, b, game } = setup();
  game({ watch: { 2452: { u: NOW - 9000, lim: 300, name: 'Flitzdistel' } } });
  b.setWatchBuy('2452', null, null);   // im Manager bewusst geleert
  const t = b.watchDoc().items['2452'].t.buy;
  b.meta('fixWatchT', null);
  assert.equal(b.repairWatchTimes(), 1, 'nur der nie gesetzte Zielpreis');
  assert.equal(b.watchDoc().items['2452'].t.buy, t, 'Kaufen bis bleibt geleert');
  assert.equal(b.watchDoc().items['2452'].t.up, 0);
  svc.close();
});

test('Unveraenderter Wert ist keine Aenderung', () => {
  const d = watching.clean({ items: { 1: { u: 100, lim: 500, t: { buy: 100, up: 100 } } }, gone: {} });
  assert.equal(watching.setBuy(d, '1', 'abs', 500, 200), false);
  assert.equal(watching.setUp(d, '1', null, 200), false);
  assert.equal(d.items['1'].u, 100);
  assert.equal(watching.setBuy(d, '1', 'pct', 10, 200), true);
  assert.equal(watching.setBuy(d, '1', 'pct', 10, 300), false);
});

test('Erste Eingabe nach dem Start rechnet die Maerkte nicht neu, Werte bleiben aus Data.lua', () => {
  const { svc, b, game, data } = setup();
  game({ watch: GAME });
  // Neustart des Manager-Teils: keine Werte im Speicher, Data.lua hat Maerkte
  const d0 = data();
  d0.markets = { 'R / Alliance': { t: 1, day: 1, items: { 5: 'x' }, sales: {} } };
  fs.writeFileSync(path.join(path.dirname(b.settings.wowDir), path.basename(b.settings.wowDir), 'Interface', 'AddOns', 'Peon_Bridge', 'Data.lua'), `PeonBridgeData = ${toLua(d0)}`);
  b.lastLua = null;
  let built = 0;
  const orig = b.buildMarkets.bind(b);
  b.buildMarkets = () => { built++; return orig(); };
  b.setWatchUp('2452', 9999);
  assert.equal(built, 0);
  assert.equal(data().markets['R / Alliance'].items[5], 'x');
  svc.close();
});

test('Speichert das Spiel seine Bridge-Datei, gilt es als geladen (wartet verschwindet)', () => {
  const { svc, b, game, write, clock } = setup();
  game({ watch: GAME });
  clock.t = NOW + 100;
  b.setWatchUp('2452', 9999);
  assert.ok(b.waiting().includes('w|2452|up'));
  clock.t = NOW + 200;
  write('Peon_Bridge.lua', 'PeonBridgeDB = { queue = {} }');
  b.importGame();
  assert.deepEqual(b.waiting(), []);
  svc.close();
});
