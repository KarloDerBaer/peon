'use strict';
// Manager 0.32.0, Angleichung A4 (docs/konzepte/manager/Peon_Manager_Angleichung.md 4.1 und 4.3):
// Seite Beobachten mit Preis, Kaufen bis, Zielpreis und Rat, Glocken je Grenze, Meldung einmal je Ueberschreiten.
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
function tmp() { return fs.mkdtempSync(path.join(os.tmpdir(), 'peon-b-')); }

function setup() {
  const dir = tmp(), wow = tmp();
  const ad = path.join(wow, 'Interface', 'AddOns', 'Peon_Bridge');
  fs.mkdirSync(ad, { recursive: true });
  fs.writeFileSync(path.join(ad, 'Peon_Bridge.toc'), 'x');
  const clock = { t: NOW };
  const svc = new Service({ enable: ['broker-client'], dbDir: dir, version: '0.32.0', now: () => clock.t });
  svc.saveSettings({ wowDir: wow });
  const b = svc.broker;
  let ft = 0;
  const brokerFile = (folder, db) => {
    const sv = path.join(wow, 'WTF', 'Account', folder, 'SavedVariables');
    fs.mkdirSync(sv, { recursive: true });
    const f = path.join(sv, 'Peon_Broker.lua');
    fs.writeFileSync(f, `PeonBrokerDB = ${toLua({ markets: {}, ...db })}`);
    ft = Math.max(ft + 1, clock.t);
    fs.utimesSync(f, ft, ft);
    b.importGame();
  };
  return { svc, b, clock, brokerFile, db: b.db };
}

// Ein Stand mit Preisen je Gegenstand (min je Stueck)
function stand(db, id, t, rows) {
  const mid = marketId(db, M, {});
  db.prepare("INSERT INTO snapshots(id, market_id, source, art, t, offers, items, rows) VALUES (?, ?, 'scan', 'api', ?, 10, 2, ?)").run(id, mid, t, require('node:zlib').deflateSync(Buffer.from(Object.entries(rows).map(([k, r]) => `${parseInt(k, 10)};;;5;${r * 5};;;4;;1`).join('\n'))));
  for (const [key, r] of Object.entries(rows)) {
    db.prepare('INSERT OR IGNORE INTO items(key, item_id, name, quality) VALUES (?, ?, ?, 1)').run(key, parseInt(key, 10), `Name ${key}`);
    db.prepare("INSERT INTO item_snap(snapshot_id, market_id, item_key, t, source, min, median, p25, p75, qty, auctions) VALUES (?, ?, ?, ?, 'scan', ?, ?, ?, ?, 5, 5)")
      .run(id, mid, key, t, r, r, r, r);
  }
}

test('Ansicht: Preis, Kaufen bis als Betrag und in %, Zielpreis, Rat wie im Spiel', () => {
  const { svc, b, db, brokerFile } = setup();
  for (let d = 5; d >= 1; d--) stand(db, `t${d}`, NOW - d * 86400, { 100: 1000, 200: 2000, 300: 3000 });
  stand(db, 'jetzt', NOW - 60, { 100: 1000, 200: 2000, 300: 3000 });
  brokerFile('KONTOA', { acct: 'kA_1', watch: {
    100: { u: NOW - 100, lim: 1000 },            // Preis 1000 auf der Grenze: KAUFEN
    200: { u: NOW - 100, pct: 10, up: 1500 },     // Grenze 10 % unter 2000 = 1800, Preis 2000 ueber dem Ziel 1500: VERKAUFEN
    300: { u: NOW - 100, lim: 100 },              // nichts
    999: { u: NOW - 100, name: 'Ohne Daten', up: 50 },
  } });
  const v = b.watchView(M);
  const row = (k) => v.rows.find((r) => r.key === k);
  assert.deepEqual([row('100').price, row('100').buyLimit, row('100').advice], [1000, 1000, 'buy']);
  assert.deepEqual([row('200').buy, row('200').buyLimit, row('200').up, row('200').advice], [{ pct: 10 }, 1800, 1500, 'sell']);
  assert.equal(row('300').advice, null);
  assert.deepEqual([row('999').price, row('999').name, row('999').advice], [null, 'Ohne Daten', null]);
  assert.deepEqual(v.rows.map((r) => r.key).slice(0, 2), ['100', '200'], 'Rat zuerst');
  assert.deepEqual(row('100').bells, { buy: false, up: false }, 'Glocken beginnen aus');
  assert.ok(row('100').band, 'ueblicher Bereich dabei');
  svc.close();
});

test('Glocken: Meldung einmal je Ueberschreiten, wieder erst nach der anderen Seite, ohne Daten bleibt der Zustand', () => {
  const { svc, b, db, clock, brokerFile } = setup();
  stand(db, 's1', NOW - 60, { 100: 1000 });
  brokerFile('KONTOA', { acct: 'kA_1', watch: { 100: { u: NOW - 100, lim: 1200, up: 5000 } } });
  assert.deepEqual(b.watchCheck(), [], 'ohne Glocke keine Meldung');
  b.setWatchBell('100', 'buy', true);
  const hits = b.watchCheck();
  assert.deepEqual(hits.map((h) => [h.key, h.which, h.price, h.limit, h.label]), [['100', 'buy', 1000, 1200, 'PvE Allianz']]);
  assert.deepEqual(b.watchCheck(), [], 'nur einmal');
  // Preis steigt ueber die Grenze, dann wieder darunter: neue Meldung
  clock.t = NOW + 100; stand(db, 's2', NOW + 50, { 100: 1300 });
  assert.deepEqual(b.watchCheck(), []);
  clock.t = NOW + 200; stand(db, 's3', NOW + 150, { 100: 1100 });
  assert.equal(b.watchCheck().length, 1);
  // Gegenstand fehlt im Stand: keine neue Meldung, wenn er wiederkommt
  clock.t = NOW + 300; stand(db, 's4', NOW + 250, { 555: 1 });
  assert.deepEqual(b.watchCheck(), []);
  clock.t = NOW + 400; stand(db, 's5', NOW + 350, { 100: 1100 });
  assert.deepEqual(b.watchCheck(), [], 'Zustand blieb ueber die Luecke');
  // Zielpreis mit Glocke
  b.setWatchUp('100', 1000);
  b.setWatchBell('100', 'up', true);
  const up = b.watchCheck();
  assert.deepEqual(up.map((h) => [h.which, h.price, h.limit]), [['up', 1100, 1000]]);
  assert.deepEqual(b.watchView(M).rows[0].bells, { buy: true, up: true });
  // Entfernen loescht die Glocken, neu beobachtet beginnt ohne
  b.setFavorite('100', false);
  b.setFavorite('100', true);
  assert.deepEqual(b.watchView(M).rows[0].bells, { buy: false, up: false });
  svc.close();
});

test('Glocken und Ansicht je Konto, die Meldung nennt das Konto', () => {
  const { svc, b, db, brokerFile } = setup();
  stand(db, 's1', NOW - 60, { 100: 1000 });
  brokerFile('KONTOA', { acct: 'kA_1', watch: { 100: { u: NOW - 100, lim: 1200 } } });
  brokerFile('KONTOB', { acct: 'kB_2', watch: { 100: { u: NOW - 100, lim: 900 } } });
  b.nameAccount('kA_1', 'Haupt');
  b.selectAccount('kA_1');
  b.setWatchBell('100', 'buy', true);
  b.selectAccount('kB_2');
  assert.deepEqual(b.watchView(M).rows[0].bells, { buy: false, up: false }, 'B hat eigene Glocken');
  assert.equal(b.watchView(M).rows[0].buyLimit, 900);
  const hits = b.watchCheck();
  assert.deepEqual(hits.map((h) => [h.acct, h.acctName]), [['kA_1', 'Haupt']]);
  svc.close();
});

test('Eingaben auf der Seite: Kaufen bis wechseln, leeren, Zielpreis, Zustand wartet', () => {
  const { svc, b, db, brokerFile } = setup();
  stand(db, 's1', NOW - 60, { 100: 1000 });
  brokerFile('KONTOA', { acct: 'kA_1', watch: { 100: { u: NOW - 100 } } });
  b.setWatchBuy('100', 'abs', 1500);
  let r = b.watchView(M).rows[0];
  assert.deepEqual([r.buy, r.buyLimit, r.advice, r.wait], [{ lim: 1500 }, 1500, 'buy', true]);
  b.setWatchBuy('100', null, null);
  r = b.watchView(M).rows[0];
  assert.deepEqual([r.buy, r.buyLimit, r.advice], [null, null, null]);
  b.setWatchUp('100', 800);
  r = b.watchView(M).rows[0];
  assert.deepEqual([r.up, r.advice], [800, 'sell']);
  b.meta('gameLoadAt', b.now() + 10);
  assert.equal(b.watchView(M).rows[0].wait, false, 'nach dem Laden im Spiel');
  svc.close();
});
