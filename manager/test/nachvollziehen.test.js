'use strict';
// Manager 0.31.0, Angleichung A3 (docs/konzepte/manager/Peon_Manager_Angleichung.md 3.3 bis 3.6):
// Protokoll des Abgleichs, Zustand je Zeile, beide geaendert, Geloeschtes wiederherstellen.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { Service } = require('../src/core/service');
const { parseLua, toLua } = require('../src/core/lua');

process.removeAllListeners('warning');
const NOW = 1794000000;
const M = 'CAMWOW EU4 Realm 3 PvE / Alliance';
function tmp() { return fs.mkdtempSync(path.join(os.tmpdir(), 'peon-n-')); }

function setup() {
  const dir = tmp(), wow = tmp();
  const ad = path.join(wow, 'Interface', 'AddOns', 'Peon_Bridge');
  fs.mkdirSync(ad, { recursive: true });
  fs.writeFileSync(path.join(ad, 'Peon_Bridge.toc'), 'x');
  const sv = path.join(wow, 'WTF', 'Account', 'KONTOA', 'SavedVariables');
  fs.mkdirSync(sv, { recursive: true });
  const clock = { t: NOW };
  const svc = new Service({ enable: ['broker-client'], dbDir: dir, version: '0.31.0', now: () => clock.t });
  svc.saveSettings({ wowDir: wow });
  const b = svc.broker;
  // Peon_Broker.lua des Kontos schreiben und einlesen
  let ft = 0;   // Zeit der Datei: jedes Speichern spaeter als das vorige, sonst gilt die Datei als unveraendert
  const game = (db) => {
    const f = path.join(sv, 'Peon_Broker.lua');
    fs.writeFileSync(f, `PeonBrokerDB = ${toLua({ markets: {}, acct: 'kA_1', ...db })}`);
    ft = Math.max(ft + 1, clock.t);
    fs.utimesSync(f, ft, ft);
    b.importGame();
  };
  const data = () => parseLua(fs.readFileSync(path.join(ad, 'Data.lua'))).PeonBridgeData;
  game({});
  return { svc, b, clock, game, data };
}

test('Eingabe im Manager: Protokoll, wartet bis zum Laden, Bestaetigung aus dem Spiel', () => {
  const { svc, b, clock, game } = setup();
  clock.t = NOW + 10;
  const id = b.newShopList('Erze');
  b.addShopItem(id, '2770');
  b.setShopItem(id, '2770', { wish: 20 });
  const log = b.syncLog({ area: 'shop' });
  assert.deepEqual(log.map((e) => [e.origin, e.kind, e.field]).reverse(), [['manager', 'neu', '+'], ['manager', 'neu', '+'], ['manager', 'geändert', 'wish']]);
  assert.equal(log[0].new, 20);
  assert.equal(b.sync().inputs, 3);
  let view = b.shopView(M);
  assert.equal(view.lists[0].wait, true);
  assert.equal(view.lists[0].items[0].wait, true);
  // Das Spiel laedt neu: nichts wartet mehr
  b.meta('gameLoadAt', NOW + 20);
  assert.equal(b.sync().inputs, 0);
  view = b.shopView(M);
  assert.equal(view.lists[0].items[0].wait, false);
  // Beim naechsten Speichern bestaetigt das Spiel die Werte: nichts mehr offen, kein neuer Eintrag im Protokoll
  const l = b.shopDoc().lists[0];
  clock.t = NOW + 30;
  game({ lists: [{ ...l, items: { 2770: { ...l.items['2770'] } } }] });
  assert.deepEqual(b.pendOf('kA_1'), {});
  assert.equal(b.syncLog({ area: 'shop', origin: 'spiel' }).length, 0);
  svc.close();
});

test('Aenderung aus dem Spiel steht im Protokoll mit alt und neu', () => {
  const { svc, b, clock, game } = setup();
  game({ lists: [{ id: 'g1_1', name: 'Erze', pct: 10, u: NOW, items: { 2770: { wish: 5, u: NOW } } }] });
  clock.t = NOW + 100;
  game({ lists: [{ id: 'g1_1', name: 'Erze', pct: 20, u: NOW + 90, t: { name: NOW, pct: NOW + 90 }, items: { 2770: { wish: 40, u: NOW + 90, t: { wish: NOW + 90 } } } }] });
  const log = b.syncLog({ origin: 'spiel' });
  const wish = log.find((e) => e.field === 'wish');
  assert.deepEqual([wish.old, wish.new, wish.listName, wish.key], [5, 40, 'Erze', '2770']);
  const pct = log.find((e) => e.field === 'pct');
  assert.deepEqual([pct.old, pct.new], [10, 20]);
  svc.close();
});

test('Derselbe Wert an beiden Stellen: Eintrag "beide geaendert", es gilt der neuere', () => {
  const { svc, b, clock, game } = setup();
  game({ lists: [{ id: 'g1_1', name: 'Erze', pct: 10, u: NOW, items: { 2770: { max: 1000, u: NOW } } }] });
  // Manager setzt den Hoechstpreis, das Spiel spaeter auch (es kannte die Aenderung noch nicht)
  clock.t = NOW + 100;
  b.setShopItem('g1_1', '2770', { max: 1200 });
  clock.t = NOW + 200;
  game({ lists: [{ id: 'g1_1', name: 'Erze', pct: 10, u: NOW, items: { 2770: { max: 1500, u: NOW + 150, t: { max: NOW + 150, wish: NOW } } } }] });
  let both = b.syncLog({ origin: 'beide' });
  assert.equal(both.length, 1);
  assert.deepEqual([both[0].old, both[0].new, both[0].extra.wins, both[0].name || both[0].key], [1200, 1500, 'spiel', '2770']);
  assert.equal(b.shopDoc().lists[0].items['2770'].max, 1500);
  assert.equal(b.syncLog({ origin: 'spiel' }).filter((e) => e.field === 'max').length, 0, 'keine zweite Zeile fuer denselben Wert');
  assert.deepEqual(b.pendOf('kA_1'), {}, 'erledigt');

  // Umgekehrt: das Spiel aendert frueher als der Manager, dessen Wert gilt
  clock.t = NOW + 300;
  game({ lists: [{ id: 'g1_1', name: 'Erze', pct: 10, u: NOW, items: { 2770: { max: 1500, u: NOW + 150, t: { max: NOW + 150, wish: NOW } } } }] });
  clock.t = NOW + 400;
  b.setShopItem('g1_1', '2770', { max: 900 });
  clock.t = NOW + 500;
  game({ lists: [{ id: 'g1_1', name: 'Erze', pct: 10, u: NOW, items: { 2770: { max: 2000, u: NOW + 350, t: { max: NOW + 350, wish: NOW } } } }] });
  both = b.syncLog({ origin: 'beide' });
  assert.equal(both.length, 2);
  assert.deepEqual([both[0].old, both[0].new, both[0].extra.wins], [900, 2000, 'manager']);
  assert.equal(b.shopDoc().lists[0].items['2770'].max, 900);
  assert.equal(Object.keys(b.pendOf('kA_1')).length, 1, 'wartet weiter, bis das Spiel den Wert des Managers hat');
  // erneutes Einlesen meldet denselben Fall nicht noch einmal
  clock.t = NOW + 600;
  game({ lists: [{ id: 'g1_1', name: 'Erze', pct: 10, u: NOW, items: { 2770: { max: 2000, u: NOW + 350, t: { max: NOW + 350, wish: NOW } } } }] });
  assert.equal(b.syncLog({ origin: 'beide' }).length, 2);
  svc.close();
});

test('Im Spiel geloescht: unter Geloescht, Wiederherstellen bringt es zurueck und ins Spiel', () => {
  const { svc, b, clock, game, data } = setup();
  game({ lists: [{ id: 'g1_1', name: 'Erze', pct: 10, u: NOW, items: { 2770: { wish: 5, max: 700, u: NOW }, 2589: { u: NOW } } }] });
  clock.t = NOW + 100;
  game({ lists: [{ id: 'g1_1', name: 'Erze', pct: 10, u: NOW, items: { 2589: { u: NOW } } }], listsGone: { items: { 'g1_1|2770': NOW + 90 } } });
  let trash = b.syncTrash({ area: 'shop' });
  assert.equal(trash.length, 1);
  assert.deepEqual([trash[0].what, trash[0].key, trash[0].origin], ['item', '2770', 'spiel']);
  clock.t = NOW + 200;
  assert.deepEqual(b.restoreTrash(trash[0].id), { ok: true });
  const it = b.shopDoc().lists[0].items['2770'];
  assert.deepEqual([it.wish, it.max, it.u > NOW + 90], [5, 700, true]);
  assert.equal(b.shopDoc().gone.items['g1_1|2770'], undefined);
  assert.equal(data().accts.kA_1.shop.lists[0].items[2770].wish, 5, 'gleich in Data.lua');
  assert.equal(b.syncTrash({ area: 'shop' }).length, 0);
  assert.equal(b.syncLog({ origin: 'manager' })[0].kind, 'wiederhergestellt');
  assert.equal(b.restoreTrash(trash[0].id).ok, false, 'nur einmal');

  // Ganze Liste im Manager geloescht: Gegenstand allein geht nicht, die Liste schon
  clock.t = NOW + 300;
  b.removeShopItem('g1_1', '2589');
  b.deleteShopList('g1_1');
  trash = b.syncTrash({ area: 'shop' });
  assert.deepEqual(trash.map((e) => e.what).sort(), ['item', 'list']);
  const item = trash.find((e) => e.what === 'item');
  const list = trash.find((e) => e.what === 'list');
  assert.equal(list.n, 1);
  assert.equal(b.restoreTrash(item.id).ok, false);
  assert.match(b.restoreTrash(item.id).error, /Liste/);
  assert.equal(b.restoreTrash(list.id).ok, true);
  assert.equal(b.restoreTrash(item.id).ok, true);
  assert.deepEqual(Object.keys(b.shopDoc().lists[0].items).sort(), ['2589', '2770']);
  svc.close();
});

test('Beobachtung: Grenzen im Protokoll, Stern weg und wiederhergestellt mit Grenzen', () => {
  const { svc, b, clock, game } = setup();
  game({ watch: { 2770: { u: NOW, name: 'Kupfererz', lim: 1200, up: 5000 } } });
  clock.t = NOW + 100;
  b.setWatchBuy('2770', 'pct', 20);
  const e = b.syncLog({ area: 'watch', origin: 'manager' })[0];
  assert.deepEqual([e.field, e.old, e.new, e.name], ['buy', { lim: 1200 }, { pct: 20 }, 'Kupfererz']);
  clock.t = NOW + 200;
  b.setFavorite('2770', false);
  const trash = b.syncTrash({ area: 'watch' });
  assert.equal(trash.length, 1);
  clock.t = NOW + 300;
  assert.equal(b.restoreTrash(trash[0].id).ok, true);
  const w = b.watchDoc().items['2770'];
  assert.deepEqual([w.pct, w.up, w.name], [20, 5000, 'Kupfererz']);
  assert.ok(b.favorites().includes('2770'));
  svc.close();
});

test('Protokoll 90 Tage, Geloeschtes 30 Tage', () => {
  const { svc, b, clock } = setup();
  b.setFavorite('2770', true);
  b.setFavorite('2770', false);
  assert.ok(b.syncLog().length >= 2);
  assert.equal(b.syncTrash().length, 1);
  clock.t = NOW + 31 * 86400;
  assert.equal(b.syncTrash().length, 0, 'nach 30 Tagen nicht mehr angeboten');
  b.prune();
  assert.equal(b.db.prepare('SELECT COUNT(*) AS n FROM sync_trash').get().n, 0);
  assert.ok(b.syncLog().length >= 2);
  clock.t = NOW + 91 * 86400;
  b.prune();
  assert.equal(b.syncLog().length, 0);
  svc.close();
});
