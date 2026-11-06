'use strict';
// Tests fuer Datensicherung, Preisaenderungen und Modul-Gruppen (Manager 0.16.0): node --test test/
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { DatabaseSync } = require('node:sqlite');
const { Service } = require('../src/core/service');
const backup = require('../src/core/backup');

process.removeAllListeners('warning');
function tmp() { return fs.mkdtempSync(path.join(os.tmpdir(), 'peon-u-')); }
const NOW = 1794000000;

function setup(dir = tmp()) {
  const svc = new Service({ enable: ['broker-client'], dbDir: dir, version: '0.16.0', now: () => NOW });
  return { svc, dir, db: svc.broker.db };
}

// Ein Stand mit Kennzahlen je Gegenstand: rows = { key: { min, median, qty } }
function stand(db, id, t, rows) {
  db.prepare("INSERT OR IGNORE INTO markets(id, key) VALUES (1, 'M / Alliance')").run();
  db.prepare("INSERT INTO snapshots(id, market_id, source, art, t, offers, items) VALUES (?, 1, 'scan', 'api', ?, 10, 2)").run(id, t);
  for (const [key, r] of Object.entries(rows)) {
    db.prepare('INSERT OR IGNORE INTO items(key, item_id, name, quality) VALUES (?, ?, ?, 1)').run(key, parseInt(key, 10) || 1, `Name ${key}`);
    db.prepare("INSERT INTO item_snap(snapshot_id, market_id, item_key, t, source, min, median, p25, p75, qty, auctions) VALUES (?, 1, ?, ?, 'scan', ?, ?, ?, ?, ?, ?)")
      .run(id, key, t, r.min, r.median ?? r.min, r.min, r.min, r.qty ?? 5, r.qty ?? 5);
  }
}

test('Module tragen die Ueberschrift ihrer Gruppe in der Seitenleiste', () => {
  const { svc } = setup();
  const m = svc.moduleList().find((x) => x.key === 'broker-client');
  assert.equal(m.navTitle, 'Broker');
  assert.ok(m.views.includes('shopping') && m.views.includes('favorites'));
  svc.close();
});

test('Preisaenderungen: gegen den ueblichen Preis, sobald es ihn gibt, sonst gegen den Stand davor', () => {
  const { svc, db } = setup();
  const b = svc.broker;
  const day = 86400;
  // Erst wenig Daten: Vergleich zweier Staende
  stand(db, 'a', NOW - 2 * day, { 100: { min: 1000, median: 1000 } });
  stand(db, 'b', NOW - day, { 100: { min: 2000, median: 2000 } });
  let mv = b.moves(1, { id: 'b', t: NOW - day });
  assert.equal(mv.mode, 'scan');
  assert.equal(mv.up[0].before, 1000);

  // Genug Gegenstaende ueber mehrere Tage: Der Ausreisser im letzten Stand zaehlt gegen den ueblichen Preis
  const many = (median) => Object.fromEntries(Array.from({ length: 25 }, (_, i) => [String(1000 + i), { min: median, median }]));
  for (let d = 12; d >= 2; d--) stand(db, `t${d}`, NOW - d * day, many(10000));
  stand(db, 'neu', NOW - 60, { ...many(10000), 1000: { min: 200000, median: 200000 }, 1001: { min: 5000, median: 5000 } });
  mv = b.moves(1, { id: 'neu', t: NOW - 60 });
  assert.equal(mv.mode, 'band');
  assert.equal(mv.up[0].key, '1000');
  assert.ok(Math.abs(mv.up[0].before - 10000) < 3000, 'Vergleich ist der uebliche Preis');
  assert.equal(mv.down[0].key, '1001');
  // Einmal je Stand gerechnet
  assert.equal(b.moves(1, { id: 'neu', t: NOW - 60 }), mv);
  svc.close();
});

test('Sicherung: anlegen, einspielen, bisheriger Stand bleibt, Zugang nicht dabei', async () => {
  const { svc, dir, db } = setup();
  stand(db, 'a', NOW - 100, { 100: { min: 5000 } });
  svc.saveSettings({ wowDir: dir, keepDays: 21 });
  fs.writeFileSync(path.join(dir, 'blizzard.bin'), 'geheim');
  const target = tmp();
  const r = await svc.createBackup(target);
  assert.deepEqual(r.files, ['peon.db', 'broker-client.db']);
  assert.ok(r.bytes > 0);
  assert.ok(!fs.existsSync(path.join(r.dir, 'blizzard.bin')));
  assert.ok(fs.existsSync(path.join(r.dir, 'settings.json')));
  const info = backup.inspect(r.dir);
  assert.equal(info.version, '0.16.0');
  // zweite Sicherung in derselben Minute: eigener Ordner
  assert.notEqual((await svc.createBackup(target)).dir, r.dir);

  // Danach aendert sich etwas, dann einspielen beim naechsten Start
  stand(db, 'b', NOW - 50, { 100: { min: 1 } });
  svc.saveSettings({ keepDays: 7 });
  backup.request(dir, r.dir);
  svc.close();

  const second = setup(dir);
  assert.equal(second.svc.restored.ok, true);
  assert.equal(second.svc.settings.keepDays, 21);
  assert.equal(second.db.prepare('SELECT COUNT(*) AS n FROM snapshots').get().n, 1, 'Stand der Sicherung');
  const old = second.svc.restored.old;
  assert.ok(fs.existsSync(path.join(old, 'broker-client.db')), 'bisheriger Stand bleibt liegen');
  assert.equal(JSON.parse(fs.readFileSync(path.join(old, 'settings.json'), 'utf8')).keepDays, 7);
  assert.equal(fs.readFileSync(path.join(dir, 'blizzard.bin'), 'utf8'), 'geheim', 'Zugang bleibt');
  assert.ok(!fs.existsSync(path.join(dir, 'restore.json')));
  second.svc.close();
  // Naechster Start: nichts mehr zu tun
  const third = setup(dir);
  assert.equal(third.svc.restored, null);
  third.svc.close();
});

test('Sicherung: fremder Ordner und kaputte Sicherung werden abgelehnt, nichts wird angefasst', async () => {
  assert.throws(() => backup.inspect(tmp()), /keine Sicherung/);
  const { svc, dir, db } = setup();
  stand(db, 'a', NOW - 100, { 100: { min: 5000 } });
  const r = await svc.createBackup(tmp());
  fs.rmSync(path.join(r.dir, 'broker-client.db'));
  assert.throws(() => backup.inspect(r.dir), /unvollständig/);
  assert.throws(() => backup.request(dir, r.dir), /unvollständig/);
  assert.ok(!fs.existsSync(path.join(dir, 'restore.json')));
  // Verschwindet die Sicherung vor dem Neustart: Der Start geht normal weiter, die Daten bleiben
  fs.writeFileSync(path.join(dir, 'restore.json'), JSON.stringify({ from: path.join(dir, 'gibtsnicht') }));
  svc.close();
  const again = setup(dir);
  assert.equal(again.svc.restored.ok, false);
  assert.equal(again.db.prepare('SELECT COUNT(*) AS n FROM snapshots').get().n, 1);
  assert.ok(!fs.existsSync(path.join(dir, 'restore.json')), 'kein neuer Versuch bei jedem Start');
  again.svc.close();
});

test('Sicherung: Geschlossene Datenbank eines ausgeschalteten Moduls kommt mit', async () => {
  const { svc, db } = setup();
  stand(db, 'a', NOW - 100, { 100: { min: 5000 } });
  svc.setModule('broker-client', false);
  const r = await svc.createBackup(tmp());
  assert.deepEqual(r.files, ['peon.db', 'broker-client.db']);
  const check = new DatabaseSync(path.join(r.dir, 'broker-client.db'), { readOnly: true });
  assert.equal(check.prepare('SELECT COUNT(*) AS n FROM snapshots').get().n, 1);
  check.close();
  svc.close();
});
