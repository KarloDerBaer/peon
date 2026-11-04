'use strict';
// Tests fuer die Manager-Module (Peon_GitHub_Design.md 5.2): ein/aus, eigene Datenbank, Umzug, Kanaele in Data.lua
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { DatabaseSync } = require('node:sqlite');
const { Service } = require('../src/core/service');
const modules = require('../src/core/modules');
const { openDb } = require('../src/core/db');
const { parseLua } = require('../src/core/lua');

process.removeAllListeners('warning');
const tmp = () => fs.mkdtempSync(path.join(os.tmpdir(), 'peon-mod-'));

// WoW-Ordner mit Peon_Bridge und Peon_Broker, auf Wunsch ohne Bridge
function fakeWow({ bridge = true } = {}) {
  const wow = tmp();
  fs.mkdirSync(path.join(wow, 'WTF', 'Account', 'KONTO', 'SavedVariables'), { recursive: true });
  const add = (n) => { const d = path.join(wow, 'Interface', 'AddOns', n); fs.mkdirSync(d, { recursive: true }); fs.writeFileSync(path.join(d, n + '.toc'), '## Interface: 16001\n'); };
  add('Peon_Broker');
  if (bridge) add('Peon_Bridge');
  return wow;
}
const dataLua = (wow) => parseLua(fs.readFileSync(path.join(wow, 'Interface', 'AddOns', 'Peon_Bridge', 'Data.lua'))).PeonBridgeData;
const tables = (file) => { const db = new DatabaseSync(file); try { return db.prepare("SELECT name FROM sqlite_master WHERE type = 'table'").all().map((r) => r.name); } finally { db.close(); } };

test('Liste der Module: Broker Client mit Addons, Kanal und Ansichten', () => {
  const m = modules.find('broker-client');
  assert.equal(m.title, 'Peon Broker Client');
  assert.deepEqual(m.needs, ['Peon_Broker', 'Peon_Bridge']);
  assert.deepEqual(m.channels, ['broker']);
  assert.deepEqual(m.views, ['overview', 'items', 'chances', 'sources']);
  assert.deepEqual(modules.channels({ modules: { 'broker-client': { enabled: true } } }), { broker: true });
  assert.deepEqual(modules.channels({ modules: { 'broker-client': { enabled: false } } }), {});
  assert.deepEqual(modules.views({}), []);
  // gleiche Angaben wie im Manifest der Releases
  const rel = JSON.parse(fs.readFileSync(path.join(__dirname, '..', '..', 'scripts', 'release.json'), 'utf8'));
  const r = rel.managerModules.find((x) => x.key === 'broker-client');
  assert.equal(r.title, m.title); assert.equal(r.desc, m.desc); assert.deepEqual(r.needs, m.needs); assert.deepEqual(r.channels, m.channels);
});

test('Neu installiert: Broker Client aus, keine eigene Datenbank, Data.lua ohne Kanaele', () => {
  const dir = tmp(), wow = fakeWow();
  const svc = new Service({ dbDir: dir });
  assert.equal(svc.broker, null);
  assert.equal(svc.isActive('broker-client'), false);
  svc.saveSettings({ wowDir: wow });
  assert.ok(fs.existsSync(path.join(dir, 'peon.db')));
  assert.ok(!fs.existsSync(path.join(dir, 'broker-client.db')), 'Datenbank des Moduls erst beim Installieren');
  const tm = tables(path.join(dir, 'peon.db'));
  assert.ok(tm.includes('meta') && tm.includes('log') && !tm.includes('snapshots') && !tm.includes('markets'), 'peon.db nur Zustand und Protokoll: ' + tm.join(', '));
  const ov = svc.overview();
  assert.deepEqual(ov.views, []);
  assert.deepEqual(ov.markets, []);
  assert.equal(ov.modules[0].enabled, false);
  assert.deepEqual(ov.modules[0].addons, [{ name: 'Peon_Broker', present: true }, { name: 'Peon_Bridge', present: true }]);
  svc.syncBridge();
  const d = dataLua(wow);
  assert.equal(d.fmt, 2);
  assert.deepEqual(d.channels, {});
  assert.deepEqual(d.markets, {});
  const t = fs.statSync(path.join(wow, 'Interface', 'AddOns', 'Peon_Bridge', 'Data.lua')).mtimeMs;
  assert.equal(svc.syncBridge(), null, 'schon geschrieben: nicht nochmal');
  assert.equal(fs.statSync(path.join(wow, 'Interface', 'AddOns', 'Peon_Bridge', 'Data.lua')).mtimeMs, t);
  svc.close();
});

test('Ohne Peon_Bridge: nichts schreiben, kein Fehler', () => {
  const wow = fakeWow({ bridge: false });
  const svc = new Service({ dbDir: tmp() });
  svc.saveSettings({ wowDir: wow });
  assert.equal(svc.syncBridge(true), null);
  assert.equal(svc.overview().modules[0].addons[1].present, false);
  assert.ok(!svc.overview().log.some((l) => !l.ok));
  svc.close();
});

test('Umzug von Manager 0.6.0: peon.db mit Broker-Daten wird broker-client.db, Modul bleibt aktiv', () => {
  const dir = tmp();
  // alter Stand: alles in peon.db, settings.json ohne modules
  const old = openDb(dir);
  old.prepare("INSERT INTO markets(key, created) VALUES ('Realm / Horde', 1)").run();
  old.prepare("INSERT INTO meta(key, value) VALUES ('ack', '{\"ids\":[]}')").run();
  old.close();
  fs.renameSync(path.join(dir, 'broker-client.db'), path.join(dir, 'peon.db'));
  for (const ext of ['-wal', '-shm']) if (fs.existsSync(path.join(dir, 'broker-client.db' + ext))) fs.renameSync(path.join(dir, 'broker-client.db' + ext), path.join(dir, 'peon.db' + ext));
  fs.writeFileSync(path.join(dir, 'settings.json'), JSON.stringify({ wowDir: 'X:\\WoW', keepDays: 45 }));

  const svc = new Service({ dbDir: dir });
  assert.equal(svc.isActive('broker-client'), true, 'wer schon Daten hatte, nutzt den Broker Client weiter');
  assert.ok(svc.broker);
  assert.equal(svc.broker.db.prepare('SELECT key FROM markets').get().key, 'Realm / Horde', 'Daten sind mit umgezogen');
  assert.ok(!tables(path.join(dir, 'peon.db')).includes('snapshots'), 'neue peon.db nur fuer den Manager');
  assert.equal(svc.settings.keepDays, 45, 'Einstellungen bleiben');
  assert.equal(JSON.parse(fs.readFileSync(path.join(dir, 'settings.json'), 'utf8')).modules['broker-client'].enabled, true);
  assert.ok(svc.overview().log.some((l) => /umgezogen/.test(l.text)));
  svc.close();
  // zweiter Start: nichts mehr umziehen
  const svc2 = new Service({ dbDir: dir });
  assert.ok(svc2.broker && svc2.broker.db.prepare('SELECT COUNT(*) AS n FROM markets').get().n === 1);
  assert.equal(svc2.overview().log.filter((l) => /umgezogen/.test(l.text)).length, 1);
  svc2.close();
});

test('Alte Einstellungen ohne Datenbank: Broker Client an', () => {
  const dir = tmp();
  fs.writeFileSync(path.join(dir, 'settings.json'), JSON.stringify({ wowDir: 'X:\\WoW' }));
  const svc = new Service({ dbDir: dir });
  assert.equal(svc.isActive('broker-client'), true);
  svc.close();
});

test('Data.lua passt nicht mehr zu den Kanaelen: der Manager repariert sie beim Einlesen', () => {
  const wow = fakeWow();
  const svc = new Service({ dbDir: tmp(), enable: ['broker-client'] });
  svc.saveSettings({ wowDir: wow });
  const file = path.join(wow, 'Interface', 'AddOns', 'Peon_Bridge', 'Data.lua');
  svc.broker.importGame();
  assert.deepEqual(dataLua(wow).channels, { broker: true });
  // gleicher Stand: wird nicht neu geschrieben
  const t = dataLua(wow).t;
  fs.writeFileSync(file, fs.readFileSync(file, 'utf8').replace(`["t"] = ${t}`, '["t"] = 7'));
  svc.broker.importGame();
  assert.equal(dataLua(wow).t, 7, 'passt: Datei bleibt, wie sie ist');
  // von aussen ueberschrieben: keine Kanaele
  fs.writeFileSync(file, 'PeonBridgeData = { ["fmt"] = 2, ["channels"] = {}, ["ack"] = {}, ["markets"] = {} }\n');
  svc.broker.importGame();
  assert.deepEqual(dataLua(wow).channels, { broker: true }, 'Kanal wieder frei');
  // leerer Platzhalter
  fs.writeFileSync(file, '-- Platzhalter\n');
  svc.broker.importGame();
  assert.deepEqual(dataLua(wow).channels, { broker: true }, 'Platzhalter ersetzt');
  // geloescht und kaputt
  fs.unlinkSync(file);
  svc.broker.importGame();
  assert.deepEqual(dataLua(wow).channels, { broker: true }, 'geloeschte Datei neu');
  fs.writeFileSync(file, 'PeonBridgeData = { kaputt');
  svc.broker.importGame();
  assert.deepEqual(dataLua(wow).channels, { broker: true }, 'kaputte Datei neu');
  svc.close();
});

test('Installieren, Entfernen, Daten loeschen, wieder installieren', () => {
  const dir = tmp(), wow = fakeWow();
  const svc = new Service({ dbDir: dir });
  svc.saveSettings({ wowDir: wow });

  let list = svc.setModule('broker-client', true);
  assert.equal(list[0].enabled, true);
  assert.ok(svc.broker && fs.existsSync(path.join(dir, 'broker-client.db')));
  assert.deepEqual(svc.overview().views, ['overview', 'items', 'chances', 'sources']);
  svc.broker.importGame();
  assert.deepEqual(dataLua(wow).channels, { broker: true }, 'Kanal broker frei');
  svc.broker.db.prepare("INSERT INTO markets(key, created) VALUES ('Realm / Allianz', 1)").run();

  list = svc.setModule('broker-client', false);
  assert.equal(svc.broker, null);
  assert.deepEqual(dataLua(wow).channels, {}, 'Bridge zeichnet nichts mehr auf');
  assert.ok(list[0].hasData && list[0].dataBytes > 0, 'Daten bleiben liegen');
  assert.deepEqual(svc.overview().views, []);

  assert.equal(svc.setModule('broker-client', false)[0].enabled, false, 'doppelt aus: nichts passiert');
  svc.setModule('broker-client', true);
  assert.throws(() => svc.clearModuleData('broker-client'), /Erst entfernen/);
  assert.equal(svc.broker.db.prepare('SELECT COUNT(*) AS n FROM markets').get().n, 1, 'wieder an: alte Daten da');
  svc.broker.importGame();
  assert.deepEqual(dataLua(wow).channels, { broker: true }, 'nach erneutem Installieren wieder frei');

  svc.setModule('broker-client', false);
  list = svc.clearModuleData('broker-client');
  assert.equal(list[0].hasData, false);
  assert.ok(!fs.existsSync(path.join(dir, 'broker-client.db')));
  svc.setModule('broker-client', true);
  assert.equal(svc.broker.db.prepare('SELECT COUNT(*) AS n FROM markets').get().n, 0, 'nach Loeschen leer');
  const texts = svc.overview().log.map((l) => l.text);
  assert.ok(texts.some((t) => /installiert/.test(t)) && texts.some((t) => /entfernt/.test(t)) && texts.some((t) => /gelöscht/.test(t)));
  assert.throws(() => svc.setModule('gibt-es-nicht', true), /Unbekanntes Modul/);
  svc.close();
});
