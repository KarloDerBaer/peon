'use strict';
// Tests fuer das Modul Peon Broker Client im Arbeitsprozess (Manager 0.23.0): broker-remote.js und broker-worker.js
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { parseLua } = require('../src/core/lua');
const { Service } = require('../src/core/service');
const { BrokerRemote, workerFile } = require('../src/core/broker-remote');

function tmp() { return fs.mkdtempSync(path.join(os.tmpdir(), 'peon-')); }

function fakeWow(content) {
  const wow = tmp();
  const sv = path.join(wow, 'WTF', 'Account', '123456789#2', 'SavedVariables');
  fs.mkdirSync(sv, { recursive: true });
  fs.writeFileSync(path.join(sv, 'Peon_Bridge.lua'), content);
  const ad = path.join(wow, 'Interface', 'AddOns', 'Peon_Bridge');
  fs.mkdirSync(ad, { recursive: true });
  fs.writeFileSync(path.join(ad, 'Peon_Bridge.toc'), '## Interface: 16001\n');
  fs.writeFileSync(path.join(ad, 'Data.lua'), '-- Platzhalter\n');
  return { wow, ad };
}

const T = Math.floor(Date.now() / 1000) - 3600;
const SAMPLE = `
PeonBridgeDB = {
["queue"] = {
{
["id"] = "${T}-1", ["kind"] = "scan", ["market"] = "Classic Beta PvE / Alliance", ["realm"] = "Classic Beta PvE", ["faction"] = "Alliance",
["t"] = ${T}, ["total"] = 3, ["offers"] = 3, ["lines"] = 2, ["partial"] = false,
["names"] = { [2770] = "Kupfererz|1", [2589] = "Leinenstoff|1" },
["rows"] = "2770;;;20;2400;;;3;;2\\n2589;;;3;90;;60;1;;1",
},
},
["fmt"] = 1,
}
`;

function setup() {
  const { wow, ad } = fakeWow(SAMPLE);
  const dbDir = tmp();
  const errors = [];
  const svc = new Service({ enable: ['broker-client'], dbDir, version: '0.23.0', brokerFactory: (h) => new BrokerRemote(h, { onError: (e) => errors.push(e) }) });
  svc.saveSettings({ wowDir: wow });
  return { svc, wow, ad, dbDir, errors };
}

test('Arbeitsprozess: Pfad im fertigen Programm zeigt auf den entpackten Ordner', () => {
  assert.match(workerFile(), /broker-worker\.js$/);
  const packed = path.join('C:', 'Programme', 'resources', 'app.asar', 'src', 'core', 'broker-worker.js');
  assert.equal(packed.replace(/app\.asar([\\/])/, 'app.asar.unpacked$1'), path.join('C:', 'Programme', 'resources', 'app.asar.unpacked', 'src', 'core', 'broker-worker.js'));
});

test('Arbeitsprozess: Einlesen, Data.lua, Ansichten und Uebersicht', async () => {
  const { svc, ad, errors } = setup();
  try {
    const r = svc.broker.importGame();
    assert.ok(r instanceof Promise, 'Aufrufe liefern Promises');
    const sum = await r;
    assert.equal(sum.imported, 1);
    const data = parseLua(fs.readFileSync(path.join(ad, 'Data.lua'))).PeonBridgeData;
    assert.equal(data.ack[`${T}-1`], true);
    assert.equal(data.manager, '0.23.0');
    const list = await svc.broker.itemList('Classic Beta PvE / Alliance');
    assert.deepEqual(list.items.map((x) => x.key).sort(), ['2589', '2770']);
    const ov = await svc.overviewAsync();
    assert.equal(ov.markets.length, 1);
    assert.equal(ov.pruning, false);
    assert.ok(ov.log.some((l) => /1 neue Momentaufnahme/.test(l.text)));
    assert.equal(await svc.broker.get('api.busy'), false, 'Felder lesen, auch verschachtelt');
    assert.deepEqual(await svc.broker.setFavorite('2770', true), ['2770']);
    assert.equal((await svc.broker.importGame()).imported, 0, 'nichts doppelt');
    assert.deepEqual(errors, []);
  } finally { await svc.broker.close(); svc.close(); }
});

test('Arbeitsprozess: gespeicherte Einstellungen kommen im Manager an, Fehler kommen zurueck', async () => {
  const { svc } = setup();
  try {
    await svc.broker.api.setHouse('eu', 111, true, 'Allianz');
    assert.equal(svc.settings.blizzard.houses['eu-111'].how, 'manual');
    assert.match(JSON.parse(fs.readFileSync(svc.settingsFile, 'utf8')).blizzard.houses['eu-111'].market, /Haus 111/);
    await assert.rejects(svc.broker.gibtEsNicht(), /Unbekannter Aufruf: gibtEsNicht/);
    await assert.rejects(svc.broker.itemDetail(), /./, 'Fehler im Arbeitsprozess werden zum abgelehnten Promise');
    // Einstellungen aus dem Manager gelten beim naechsten Aufruf auch dort
    svc.saveSettings({ keepDays: 77 });
    assert.equal(await svc.broker.get('settings.keepDays'), 77);
  } finally { await svc.broker.close(); svc.close(); }
});

test('Arbeitsprozess: Sicherung der offenen Datenbank, Aufrufe nach dem Beenden', async () => {
  const { svc } = setup();
  await svc.broker.importGame();
  const target = tmp();
  const r = await svc.createBackup(target);
  assert.deepEqual(r.files.sort(), ['broker-client.db', 'peon.db']);
  const { DatabaseSync } = require('node:sqlite');
  const copy = new DatabaseSync(path.join(r.dir, 'broker-client.db'));
  assert.equal(copy.prepare('SELECT COUNT(*) AS n FROM snapshots').get().n, 1);
  copy.close();
  await svc.broker.close();
  await assert.rejects(svc.broker.favorites(), /beendet/);
  svc.close();
});

test('Arbeitsprozess: Hauptteil bleibt frei, waehrend gerechnet wird', async () => {
  const { svc } = setup();
  try {
    // Der Arbeitsprozess haengt absichtlich 600 ms, der Hauptteil zaehlt weiter
    let ticks = 0;
    const timer = setInterval(() => { ticks++; }, 20);
    const busy = svc.broker.call('$get', 'api.busy').then(() => svc.broker.call('host.now'));
    const block = svc.broker.call('db.exec', "WITH RECURSIVE c(x) AS (SELECT 1 UNION ALL SELECT x + 1 FROM c WHERE x < 3000000) SELECT SUM(x) FROM c");
    await Promise.all([busy, block.catch(() => null)]);
    clearInterval(timer);
    assert.ok(ticks >= 3, `Hauptteil lief weiter (${ticks} Takte)`);
  } finally { await svc.broker.close(); svc.close(); }
});
