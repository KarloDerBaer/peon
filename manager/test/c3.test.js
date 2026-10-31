'use strict';
// Tests fuer Broker-Verlauf und C3 (Gegenstaende, Gegenstand, Aufbewahrung): node --test test/
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { Service } = require('../src/core/service');
const { toLua } = require('../src/core/lua');
const broker = require('../src/core/broker');
const retention = require('../src/core/retention');

function tmp() { return fs.mkdtempSync(path.join(os.tmpdir(), 'peon-')); }
function fakeWow() {
  const wow = tmp();
  const sv = path.join(wow, 'WTF', 'Account', '123456789#2', 'SavedVariables');
  fs.mkdirSync(sv, { recursive: true });
  const ad = path.join(wow, 'Interface', 'AddOns', 'Peon_Bridge');
  fs.mkdirSync(ad, { recursive: true });
  fs.writeFileSync(path.join(ad, 'Peon_Bridge.toc'), '## Interface: 16001\n');
  return { wow, sv };
}
const M = 'Classic Beta PvE / Alliance';

// lokale Zeit eines Tages (Broker-Tag) zu einer Uhrzeit
function at(day, hour) { return broker.dayTime(day) - 12 * 3600 + hour * 3600; }

test('Broker-Tag wie im Spiel und zurueck', () => {
  const t = 1792700225;   // 22.10.2026
  const d = broker.dayOf(t);
  assert.equal(d, 20748);
  assert.equal(broker.dayOf(broker.dayTime(d)), d);
  assert.deepEqual(broker.keyInfo('2770'), { key: '2770', item: 2770, variant: null });
  assert.deepEqual(broker.keyInfo('6611:Klinge des Bären'), { key: '6611:Klinge des Bären', item: 6611, variant: 'Klinge des Bären' });
  assert.deepEqual(broker.keyInfo('15000:1047'), { key: '15000:1047', item: 15000, variant: null });
  assert.equal(broker.keyInfo('x'), null);
});

test('Broker-Verlauf einlesen, ersetzen, Namen', () => {
  const { wow, sv } = fakeWow();
  const day = 20748;
  const write = (d) => fs.writeFileSync(path.join(sv, 'Peon_Broker.lua'), 'PeonBrokerDB = ' + toLua({ markets: { [M]: { items: d } }, debug: false }));
  write({
    2770: { d: `${day - 2}:240:320:200:2;${day - 1}:130:170:90:1`, w: `${Math.floor((day - 40) / 7)}:100:150:80:5`, nm: 'Kupfererz', ql: 1 },
    '6611:Klinge des Wolfs': { d: `${day - 1}:9000:9000:1:1`, ql: 2 },
    999: { q: 0 },   // ohne Verlauf
  });
  const svc = new Service({ dbDir: tmp(), now: () => at(day, 20) });
  svc.saveSettings({ wowDir: wow });
  const r = svc.importBroker();
  assert.equal(r.length, 1);
  assert.deepEqual(r[0].markets, [{ key: M, items: 2, rows: 4 }]);
  const h = svc.db.prepare("SELECT * FROM hist WHERE item_key = '2770' AND period = 'day' ORDER BY num").all();
  assert.equal(h.length, 2);
  assert.equal(h[0].min, 120); assert.equal(h[0].median, 160); assert.equal(h[0].qty, 100); assert.equal(h[0].n, 2);
  assert.equal(broker.dayOf(h[0].t), day - 2);
  const w = svc.db.prepare("SELECT * FROM hist WHERE period = 'week'").get();
  assert.equal(w.median, 150); assert.equal(w.n, 5);
  const it = svc.db.prepare("SELECT * FROM items WHERE key = '6611:Klinge des Wolfs'").get();
  assert.equal(it.name, 'Klinge des Wolfs'); assert.equal(it.quality, 2); assert.equal(it.variant, 'Klinge des Wolfs');
  // unveraenderte Datei wird nicht nochmal gelesen
  assert.equal(svc.importBroker().length, 0);
  // neue Datei ersetzt die Werte (Broker hat verdichtet)
  write({ 2770: { d: `${day}:110:140:50:1`, nm: 'Kupfererz', ql: 1 } });
  const t2 = new Date(Date.now() + 5000); fs.utimesSync(path.join(sv, 'Peon_Broker.lua'), t2, t2);
  svc.importBroker();
  assert.equal(svc.db.prepare("SELECT COUNT(*) AS n FROM hist").get().n, 1);
  // kaputte Datei: Fehler im Protokoll, nichts geloescht
  fs.writeFileSync(path.join(sv, 'Peon_Broker.lua'), 'PeonBrokerDB = { ["markets"] = ');
  const t3 = new Date(Date.now() + 9000); fs.utimesSync(path.join(sv, 'Peon_Broker.lua'), t3, t3);
  const r3 = svc.importBroker();
  assert.ok(r3[0].error);
  assert.equal(svc.db.prepare("SELECT COUNT(*) AS n FROM hist").get().n, 1);
  svc.close();
});

// Datenbank mit Broker-Verlauf und eigenen Scans an mehreren Tagen
function setup() {
  const { wow, sv } = fakeWow();
  const day = 20748;
  fs.writeFileSync(path.join(sv, 'Peon_Broker.lua'), 'PeonBrokerDB = ' + toLua({ markets: { [M]: { items: {
    2770: { d: `${day - 9}:100:100:100:1;${day - 3}:100:100:100:1;${day - 1}:400:440:200:2`, nm: 'Kupfererz', ql: 1 },
    2589: { d: `${day - 3}:20:22:10:1`, nm: 'Leinenstoff', ql: 1 },
  } } } }));
  const queue = [];
  let k = 1;
  const scan = (t, rows) => queue.push({ id: `${t}-${k++}`, kind: 'scan', market: M, t, rows: rows.join('\n'), names: { 2770: 'Kupfererz|1', 2589: 'Leinenstoff|1', 15: 'Seltenes|3' } });
  // Tag-1: eigener Scan (gilt statt Broker), heute zwei Scans morgens und abends
  scan(at(day - 1, 9), ['2770;;;10;2000;;;3;;1', '2770;;;10;2400;;;3;;1']);
  scan(at(day, 8), ['2770;;;10;1500;;;3;;1', '2770;;;5;1000;;;2;;2', '2589;;;20;400;;;4;;1', '15;;;1;900000;;;4;;1']);
  scan(at(day, 20), ['2770;;;10;1800;;;3;;1', '2770;;;30;6000;;;3;;1', '15;;;1;1000000;;;4;;1']);
  queue.push({ id: `${at(day, 21)}-${k++}`, kind: 'live', market: M, t: at(day, 21), key: '2770', commodity: true, rows: '2770;;;5;;190;;1;123;1' });
  fs.writeFileSync(path.join(sv, 'Peon_Bridge.lua'), 'PeonBridgeDB = ' + toLua({ queue, fmt: 1 }));
  const svc = new Service({ dbDir: tmp(), now: () => at(day, 22) });
  svc.saveSettings({ wowDir: wow });
  svc.importGame();
  return { svc, day };
}

test('Gegenstandsliste: letzter Stand, weg, Mittel 7 Tage, Trend, Quellen', () => {
  const { svc } = setup();
  const l = svc.itemList(M);
  assert.equal(l.items.length, 3);
  const cu = l.items.find((x) => x.key === '2770');
  assert.equal(cu.name, 'Kupfererz'); assert.equal(cu.inLast, true);
  assert.equal(cu.min, 180); assert.equal(cu.qty, 40); assert.equal(cu.auctions, 2);
  assert.equal(cu.median, 200);
  // Tagesmediane: Tag-3 Broker 100, Tag-1 eigener Scan 220 (statt Broker 220), heute Mittel der Scans
  assert.ok(cu.avg7 > 100 && cu.avg7 < 220);
  assert.deepEqual(cu.sources, { scan: 3, live: 1, broker: 3 });
  const le = l.items.find((x) => x.key === '2589');
  assert.equal(le.inLast, false, 'im letzten Scan nicht dabei');
  assert.equal(le.qty, 0);
  assert.equal(le.min, 20, 'letzter gesehener Wert');
  const s = l.items.find((x) => x.key === '15');
  assert.equal(s.quality, 3); assert.equal(s.min, 1000000);
  svc.close();
});

test('Gegenstand: Verlauf, Vorrang eigener Tage, aktueller Stand, Muster, Preisstufen', () => {
  const { svc, day } = setup();
  const d = svc.itemDetail(M, '2770', 'all');
  assert.equal(d.name, 'Kupfererz');
  assert.equal(d.own.length, 4);
  assert.equal(d.counts.scan, 3); assert.equal(d.counts.live, 1);
  const bdays = d.broker.map((x) => broker.dayOf(x.t));
  assert.deepEqual(bdays, [day - 9, day - 3], 'Broker-Tag mit eigenem Scan entfaellt');
  assert.equal(d.current.source, 'live'); assert.equal(d.current.min, 190);
  assert.ok(d.median7 > 0 && d.days7 === 3);
  assert.equal(d.low14, 100);
  assert.ok(d.pattern && d.pattern.scans === 3);
  const mon = d.pattern.cells.flat().filter(Boolean);
  assert.equal(mon.length, 3);
  assert.equal(d.levels.t, at(day, 20));
  assert.deepEqual(d.levels.list, [{ price: 180, qty: 10, auctions: 1, cum: 10 }, { price: 200, qty: 30, auctions: 1, cum: 40 }]);
  // Zeitraum 1 Tag: nur heute
  const d1 = svc.itemDetail(M, '2770', '1d');
  assert.equal(d1.own.length, 3);
  assert.equal(d1.broker.length, 0);
  // unbekannt
  assert.equal(svc.itemDetail('X / Horde', '1', 'all'), null);
  const none = svc.itemDetail(M, '424242', 'all');
  assert.equal(none.own.length, 0); assert.equal(none.levels, null);
  svc.close();
});

test('Aufbewahrung: Verdichten zu Stunden- und Tageswerten, Schaetzung', () => {
  const { svc, day } = setup();
  const db = svc.db;
  const before = db.prepare('SELECT COUNT(*) AS n FROM item_snap').get().n;
  // 0 = unbegrenzt: nichts passiert
  svc.saveSettings({ keepDays: 0 });
  assert.deepEqual(svc.prune(), { snaps: 0, hours: 0, blobs: 0, pairs: 0 });
  // nur 1 Tag fein: der Scan von Tag-1 wird zu Stundenwerten
  svc.saveSettings({ keepDays: 1 });
  const r = svc.prune();
  assert.equal(r.blobs, 1);
  assert.equal(r.snaps, 1);
  assert.equal(db.prepare('SELECT COUNT(*) AS n FROM item_snap').get().n, before - 1);
  const h = db.prepare("SELECT * FROM item_hour WHERE item_key = '2770'").get();
  assert.equal(h.n, 1); assert.equal(h.median, 220);
  // Verlauf zeigt den Stundenwert, Broker-Tag bleibt ausgeblendet
  const d = svc.itemDetail(M, '2770', 'all');
  assert.equal(d.hours.length, 1);
  assert.deepEqual(d.broker.map((x) => broker.dayOf(x.t)), [day - 9, day - 3]);
  // Stundenwerte aelter als hourDays werden Tageswerte
  retention.prune(db, { keepDays: 1, hourDays: 0.5, now: at(day, 22) });
  assert.equal(db.prepare('SELECT COUNT(*) AS n FROM item_hour').get().n, 0);
  assert.equal(db.prepare("SELECT n FROM item_day WHERE item_key = '2770'").get().n, 1);
  // Zusammenfuehren: zweimal in dieselbe Stunde -> gewichtetes Mittel
  db.prepare("INSERT INTO item_snap(snapshot_id, market_id, item_key, t, source, min, median, qty, auctions) VALUES ('x', 1, 'z', ?, 'scan', 10, 10, 1, 1)").run(at(day - 5, 10));
  db.prepare("INSERT INTO item_snap(snapshot_id, market_id, item_key, t, source, min, median, qty, auctions) VALUES ('y', 1, 'z', ?, 'scan', 40, 40, 1, 1)").run(at(day - 5, 10) + 60);
  retention.prune(db, { keepDays: 1, hourDays: 0, now: at(day, 22) });
  db.prepare("INSERT INTO item_snap(snapshot_id, market_id, item_key, t, source, min, median, qty, auctions) VALUES ('w', 1, 'z', ?, 'scan', 100, 100, 1, 1)").run(at(day - 5, 10) + 120);
  retention.prune(db, { keepDays: 1, hourDays: 0, now: at(day, 22) });
  const z = db.prepare("SELECT * FROM item_hour WHERE item_key = 'z'").get();
  assert.equal(z.n, 3); assert.equal(z.median, 50);
  // Schaetzung
  const e30 = svc.retention(30), e90 = svc.retention(90);
  assert.ok(e30.measured);
  assert.ok(e30.perScan > 0 && e30.scansPerDay >= 1);
  assert.ok(e90.fine > e30.fine && e90.total > e30.total);
  assert.equal(svc.retention(0).fine, 0);
  svc.close();
});

test('Echte Daten: Broker-Verlauf und Scan vom 22.10.2026', () => {
  const fb = path.join(__dirname, 'fixtures', 'Peon_Broker_echt.lua');
  const fc = path.join(__dirname, 'fixtures', 'Peon_Bridge_echt.lua');
  if (!fs.existsSync(fb) || !fs.existsSync(fc)) return;
  const { wow, sv } = fakeWow();
  fs.copyFileSync(fb, path.join(sv, 'Peon_Broker.lua'));
  fs.copyFileSync(fc, path.join(sv, 'Peon_Bridge.lua'));
  const svc = new Service({ dbDir: tmp(), now: () => 1792700225 + 3600 });
  svc.saveSettings({ wowDir: wow });
  const t0 = Date.now();
  const r = svc.importGame();
  const ms = Date.now() - t0;
  assert.equal(r.imported, 1);
  assert.equal(r.broker.length, 1);
  const bm = r.broker[0].markets.find((m) => m.key === M);
  assert.ok(bm.items > 2000);
  const t1 = Date.now();
  const l = svc.itemList(M);
  const msList = Date.now() - t1;
  assert.ok(l.items.length >= 2773);
  const cu = l.items.find((x) => x.key === '2770');
  assert.equal(cu.name, 'Kupfererz');
  const t2 = Date.now();
  const d = svc.itemDetail(M, '2770', 'all');
  const msItem = Date.now() - t2;
  // Broker-Tage 30.09. bis 03.10. bleiben, der 22.10. kommt aus dem eigenen Scan
  assert.deepEqual(d.broker.map((x) => x.num), [20726, 20727, 20728, 20729]);
  assert.equal(d.own.length, 1);
  assert.ok(d.levels.list.length > 0);
  const named = l.items.filter((x) => x.name).length;
  console.log(`  echt: ${l.items.length} Gegenstaende (${named} mit Namen), Einlesen ${ms} ms, Liste ${msList} ms, Gegenstand ${msItem} ms`);
  svc.close();
});

test('C4: Langzeit-Teil wie Broker (Rechenmodell Kapitel 8, Beispiel Leinenstoff)', () => {
  const longterm = require('../src/core/longterm');
  // Leinenstoff 30.09./01.10./02.10.: 1s 10c / 99c / 79c (Rechenmodell 7.3)
  const r = longterm.compute(new Map([[20726, { value: 110, own: false }], [20727, { value: 99, own: false }], [20728, { value: 79, own: true }]]), 20728);
  assert.equal(r.mitte, 99);
  assert.ok(Math.abs(r.schw - 1.4826 * 11 / 99) < 1e-12);
  const w = [0.5 ** (2 / 3), 0.5 ** (1 / 3), 1];
  assert.ok(Math.abs(r.lang - (110 * w[0] + 99 * w[1] + 79 * w[2]) / (w[0] + w[1] + w[2])) < 1e-9);
  assert.equal(r.days, 3); assert.equal(r.src, 'eb');
  // Bereich wie im Rechenmodell: RW 89c -> 74c bis 1s 03c
  assert.equal(Math.floor(89 * (1 - r.schw)), 74); assert.equal(Math.floor(89 * (1 + r.schw)), 103);
  assert.equal(longterm.encode(r), `99:${Math.round(r.schw * 10000)}:${Math.round(r.lang)}:3:eb`);
  // weniger als 3 Tage: nichts; Schwankung mindestens 5 %; Ausreisser gekuerzt
  assert.equal(longterm.compute(new Map([[1, { value: 5 }], [2, { value: 5 }]]), 2), null);
  const flat = longterm.compute(new Map([[1, { value: 100 }], [2, { value: 100 }], [3, { value: 100 }], [4, { value: 100000 }]]), 4);
  assert.equal(flat.schw, 0.05);
  assert.equal(flat.mitte, 100);
  assert.ok(flat.lang <= 115, 'Ausreisser auf MITTE x (1 + 3 x SCHW) gekuerzt');
});

test('C4: Data.lua mit Langzeit-Teil, eigene Tage vor Broker, neu bei Aenderung', () => {
  const { parseLua } = require('../src/core/lua');
  const { svc, day } = setup();
  const ad = path.join(svc.settings.wowDir, 'Interface', 'AddOns', 'Peon_Bridge');
  const data = parseLua(fs.readFileSync(path.join(ad, 'Data.lua'))).PeonBridgeData;
  const mk = data.markets[M];
  assert.ok(mk && mk.day === day && mk.t > 0);
  // Kupfererz: Tag-9 Broker 100 (ausserhalb 14 Tage? nein, drin), Tag-3 Broker 100, Tag-1 eigener Scan 220 statt Broker, heute Mittel der zwei Scans
  const v = String(mk.items[2770]).split(':');
  assert.equal(v[3], '4'); assert.equal(v[4], 'eb');
  // Leinenstoff nur 2 Tage (Broker Tag-3, eigener Scan heute): nicht drin
  assert.equal(mk.items[2589], undefined);
  const detail = svc.itemDetail(M, '2770', 'all');
  assert.equal(detail.longterm.days, 4);
  // unveraendert: Data.lua bleibt; neuer Tag aendert die Werte
  const t1 = fs.statSync(path.join(ad, 'Data.lua')).mtimeMs;
  assert.equal(svc.importGame().ack, null);
  assert.equal(fs.statSync(path.join(ad, 'Data.lua')).mtimeMs, t1);
  svc.now = () => at(day + 1, 10);
  const r = svc.importGame();
  assert.ok(r.ack && r.ack.items >= 1, 'neuer Tag: Data.lua neu geschrieben');
  assert.equal(parseLua(fs.readFileSync(path.join(ad, 'Data.lua'))).PeonBridgeData.markets[M].day, day + 1);
  svc.close();
});
