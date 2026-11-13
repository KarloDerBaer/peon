'use strict';
// Manager 0.33.0, Angleichung A5 (docs/konzepte/manager/Peon_Manager_Angleichung.md 4.2):
// Seite Einkaufen mit Vorrat je Konto (wie im Spiel nur Taschen und Bank), Fehlt, Zustand je Liste und Zeile.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { Service } = require('../src/core/service');
const { toLua } = require('../src/core/lua');
const { marketId } = require('../src/core/db');

process.removeAllListeners('warning');
const NOW = 1794000000;
const M = 'CAMWOW EU4 Realm 3 PvE / Alliance';
function tmp() { return fs.mkdtempSync(path.join(os.tmpdir(), 'peon-e-')); }

function setup() {
  const dir = tmp(), wow = tmp();
  const ad = path.join(wow, 'Interface', 'AddOns', 'Peon_Bridge');
  fs.mkdirSync(ad, { recursive: true });
  fs.writeFileSync(path.join(ad, 'Peon_Bridge.toc'), 'x');
  const clock = { t: NOW };
  const svc = new Service({ enable: ['broker-client'], dbDir: dir, version: '0.33.0', now: () => clock.t });
  svc.saveSettings({ wowDir: wow });
  const b = svc.broker;
  let ft = 0;
  const sv = (folder) => { const p = path.join(wow, 'WTF', 'Account', folder, 'SavedVariables'); fs.mkdirSync(p, { recursive: true }); return p; };
  const account = (folder, acct, ledger) => {
    if (ledger) fs.writeFileSync(path.join(sv(folder), 'Peon_Ledger.lua'), `PeonLedgerDB = ${toLua(ledger)}`);
    const f = path.join(sv(folder), 'Peon_Broker.lua');
    fs.writeFileSync(f, `PeonBrokerDB = ${toLua({ markets: {}, acct })}`);
    ft = Math.max(ft + 1, clock.t);
    fs.utimesSync(f, ft, ft);
    b.importGame();
  };
  const mid = marketId(b.db, M, {});
  b.db.prepare("INSERT INTO snapshots(id, market_id, source, art, t, offers, items, rows) VALUES ('s1', ?, 'scan', 'api', ?, 1, 1, ?)").run(mid, NOW - 60, require('node:zlib').deflateSync(Buffer.from('100;;;5;5000;;;4;;1')));
  b.db.prepare("INSERT OR IGNORE INTO items(key, item_id, name, quality) VALUES ('100', 100, 'Kupfererz', 1)").run();
  b.db.prepare("INSERT INTO item_snap(snapshot_id, market_id, item_key, t, source, min, median, p25, p75, qty, auctions) VALUES ('s1', ?, '100', ?, 'scan', 1000, 1000, 1000, 1000, 5, 5)").run(mid, NOW - 60);
  return { svc, b, account, clock };
}

const ledger = (bags, bank, mail) => ({ realms: { R: { chars: { Anton: { places: { bags: { items: { 100: bags } }, bank: { items: { 100: bank } }, mail: { items: { 100: mail } } } } } } } });

test('Vorrat und Fehlt je Konto, wie im Spiel nur Taschen und Bank', () => {
  const { svc, b, account } = setup();
  account('KONTOA', 'kA_1', ledger(3, 4, 50));
  account('KONTOB', 'kB_2', ledger(20, 0, 0));
  b.selectAccount('kA_1');
  const id = b.newShopList('Erze');
  b.addShopItem(id, '100');
  b.setShopItem(id, '100', { wish: 10 });
  let r = b.shopView(M).lists[0].items[0];
  assert.deepEqual([r.stock, r.need, r.cheapest], [7, 3, 1000], 'nur Konto A, ohne Post');
  b.setShopItem(id, '100', { wish: 5 });
  r = b.shopView(M).lists[0].items[0];
  assert.equal(r.need, 0, 'genug');
  // Konto B: eigener Vorrat, eigene Listen
  b.selectAccount('kB_2');
  assert.equal(b.shopView(M).lists.length, 0);
  const idB = b.newShopList('B');
  b.addShopItem(idB, '100');
  b.setShopItem(idB, '100', { wish: 25 });
  r = b.shopView(M).lists[0].items[0];
  assert.deepEqual([r.stock, r.need], [20, 5]);
  svc.close();
});

test('Ohne Ledger im Konto: kein Vorrat, Fehlt ist die ganze Menge', () => {
  const { svc, b, account } = setup();
  account('KONTOA', 'kA_1', null);
  const id = b.newShopList('Erze');
  b.addShopItem(id, '100');
  b.setShopItem(id, '100', { wish: 4 });
  const v = b.shopView(M);
  assert.equal(v.hasLedger, false);
  assert.deepEqual([v.lists[0].items[0].stock, v.lists[0].items[0].need], [null, 4]);
  svc.close();
});

test('Zustand: Liste und Zeile warten auf das Laden im Spiel', () => {
  const { svc, b, account, clock } = setup();
  account('KONTOA', 'kA_1', null);
  const id = b.newShopList('Erze');
  b.meta('gameLoadAt', b.now() + 1);
  clock.t += 60;   // spaeter als das Laden im Spiel
  assert.equal(b.shopView(M).lists[0].wait, false);
  b.updateShopList(id, { pct: 25 });
  assert.equal(b.shopView(M).lists[0].wait, true, 'Rabatt geaendert');
  b.addShopItem(id, '100');
  const l = b.shopView(M).lists[0];
  assert.equal(l.items[0].wait, true);
  assert.equal(l.items[0].rule, 750, 'Wert der Liste 25 % unter 1000');
  svc.close();
});
