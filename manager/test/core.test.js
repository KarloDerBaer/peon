'use strict';
// Tests fuer den Rechenkern des Peon Manager (ohne Electron): node --test test/
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { parseLua, toLua } = require('../src/core/lua');
const { parseRow, parseRows, summarize, itemKey } = require('../src/core/stats');
const { parsePricetable, suggestMarket } = require('../src/core/ahledger');
const { Service, merge } = require('../src/core/service');
const game = require('../src/core/game');

function tmp() { return fs.mkdtempSync(path.join(os.tmpdir(), 'peon-')); }

// Nachgebauter WoW-Ordner mit Peon_Bridge.lua wie vom Spiel geschrieben
function fakeWow(content) {
  const wow = tmp();
  const sv = path.join(wow, 'WTF', 'Account', '123456789#2', 'SavedVariables');
  fs.mkdirSync(sv, { recursive: true });
  if (content !== undefined) fs.writeFileSync(path.join(sv, 'Peon_Bridge.lua'), content);
  const ad = path.join(wow, 'Interface', 'AddOns', 'Peon_Bridge');
  fs.mkdirSync(ad, { recursive: true });
  fs.writeFileSync(path.join(ad, 'Peon_Bridge.toc'), '## Interface: 16001\n');
  fs.writeFileSync(path.join(ad, 'Data.lua'), '-- Platzhalter\n');
  return { wow, sv, ad };
}

const SAMPLE = `
PeonBridgeDB = {
["debug"] = false,
["queue"] = {
{
["id"] = "1792700225-1",
["kind"] = "scan",
["market"] = "Classic Beta PvE / Alliance",
["realm"] = "Classic Beta PvE",
["faction"] = "Alliance",
["region"] = 110,
["t"] = 1792700225,
["char"] = "Mirel Dorna",
["total"] = 8,
["offers"] = 8,
["lines"] = 5,
["partial"] = false,
["names"] = {
[2770] = "Kupfererz|1",
[2589] = "Leinenstoff|1",
},
["rows"] = "2770;;;20;2400;;;3;;2\\n2770;;;5;600;;;2;;1\\n2589;;;1;0;;50;4;;1\\n6611;12731;Klinge des Wolfs;1;9000;;;3;;2\\n1288;;;1;99999999999;;;3;;1\\n2589;;;3;90;;60;1;;1",
}, -- [1]
{
["id"] = "1792700300-2",
["kind"] = "live",
["key"] = "2770",
["commodity"] = true,
["partial"] = false,
["market"] = "Classic Beta PvE / Alliance",
["t"] = 1792700300,
["rows"] = "2770;;;10;;118;;1;111;1\\n2770;;;30;;120;;4;3000000001;1",
}, -- [2]
},
["fmt"] = 1,
}
`;

test('Lua: Tabellen, Texte, Zahlen, Kommentare, Umlaute', () => {
  const g = parseLua('A = { ["x"] = 1, [2] = "zw\\"ei\\n", y = true, "a", -- [1]\n z = -1.5e3, n = nil }\nB = "Bär"\nC = { 1, 2, 3 }\nD = {}\nE = "\\195\\164"');
  assert.equal(g.A.x, 1);
  assert.equal(g.A[2], 'zw"ei\n');
  assert.equal(g.A.y, true);
  assert.equal(g.A[1], 'a');
  assert.equal(g.A.z, -1500);
  assert.equal('n' in g.A, false);
  assert.equal(g.B, 'Bär');
  assert.deepEqual(g.C, [1, 2, 3]);
  assert.deepEqual(g.D, {});
  assert.equal(g.E, 'ä');
  assert.equal(parseLua('X = 49999996000').X, 49999996000);
  assert.throws(() => parseLua('X = { "offen'), /Text ohne Ende/);
});

test('Lua: Rueckweg toLua -> parseLua', () => {
  const v = { fmt: 1, ack: { '1792700225-1': true }, markets: { 'Classic Beta PvE / Alliance': { t: 5, items: { 2770: 'a;b', '6611:Klinge des Bären': 'x' } } }, big: 49999996000 };
  const back = parseLua('PeonBridgeData = ' + toLua(v)).PeonBridgeData;
  assert.equal(back.ack['1792700225-1'], true);
  assert.equal(back.markets['Classic Beta PvE / Alliance'].items[2770], 'a;b');
  assert.equal(back.markets['Classic Beta PvE / Alliance'].items['6611:Klinge des Bären'], 'x');
  assert.equal(back.big, 49999996000);
  assert.equal(toLua(49999996000), '49999996000');
});

test('Zeilen und Kennzahlen wie Broker', () => {
  const r = parseRow('6611;12731;Klinge des Wolfs;1;9000;;;3;;2');
  assert.deepEqual([r.item, r.bonus, r.name, r.qty, r.buyout, r.unit, r.bid, r.tl, r.id, r.n], [6611, '12731', 'Klinge des Wolfs', 1, 9000, null, null, 3, null, 2]);
  assert.equal(itemKey(r), '6611:Klinge des Wolfs');
  // Kupfererz wie im Rechenmodell: 10 x 120, 40 x 150, 50 x 160, 20 x 500 -> Min 120, Median 160, Menge 120
  const rows = parseRows('2770;;;10;1200;;;3;;1\n2770;;;40;6000;;;3;;1\n2770;;;50;8000;;;3;;1\n2770;;;20;10000;;;3;;1');
  const s = summarize(rows).get('2770');
  assert.equal(s.min, 120); assert.equal(s.median, 160); assert.equal(s.qty, 120); assert.equal(s.auctions, 4);
  assert.equal(s.p25, 150); assert.equal(s.p75, 160);
  // gerade Menge: Mittel der beiden mittleren Stueck
  const s2 = summarize(parseRows('1;;;1;100;;;3;;1\n1;;;1;300;;;3;;1')).get('1');
  assert.equal(s2.median, 200);
  // Zaehler n: 2 gleiche Angebote zu je 20 Stueck
  const s3 = summarize(parseRows('2770;;;20;2400;;;3;;2\n2770;;;5;600;;;2;;1')).get('2770');
  assert.equal(s3.qty, 45); assert.equal(s3.auctions, 3); assert.equal(s3.min, 120);
  // reines Gebot zaehlt nicht, Stueckpreis aus Live-Abfrage
  const s4 = summarize(parseRows('2589;;;1;0;;50;4;;1')).get('2589');
  assert.equal(s4.qty, 0); assert.equal(s4.min, null);
  const s5 = summarize(parseRows('2770;;;10;;118;;1;111;1')).get('2770');
  assert.equal(s5.min, 118);
});

test('AHledger: Preistabelle lesen, Vorschlag fuer den Markt', () => {
  const pt = parsePricetable('AHL1|forever/normal/alliance/us|1792691095|3\n35:1900:1900:1:3193:2400:500:10100:12\n117:5:5:54:18:10:1:90:85\n200:15000:15000:1:15000:15000:15000:15000:\n');
  assert.equal(pt.market, 'forever.normal.alliance.us');
  assert.equal(pt.t, 1792691095);
  assert.equal(pt.rows.length, 3);
  assert.deepEqual(pt.rows[1], { id: 117, median: 5, min: 5, qty: 54, med7: 18, med30: 10, low30: 1, high30: 90, perDay: 8.5 });
  assert.equal(pt.rows[2].perDay, null);
  assert.throws(() => parsePricetable('kaputt'), /Kopfzeile/);
  assert.equal(suggestMarket('Classic Beta PvE / Alliance', 110), 'forever.normal.alliance.us');
  assert.equal(suggestMarket('Classic PvP / Horde', 3), 'forever.pvp.horde.eu');
  assert.equal(suggestMarket('Unsinn', 1), null);
});

test('Einstellungen: Standardwerte ergaenzen, falsche Typen ersetzen', () => {
  const m = merge({ a: 1, b: { c: 2, d: 3 }, e: {} }, { a: 'x', b: { c: 5 }, f: 9 });
  assert.deepEqual(m, { a: 1, b: { c: 5, d: 3 }, e: {}, f: 9 });
});

test('Einlesen aus dem Spiel, Bestaetigung, kein doppeltes Einlesen', () => {
  const { wow, ad } = fakeWow(SAMPLE);
  const dbDir = tmp();
  let now = 1792700400;
  const svc = new Service({ enable: ['broker-client'], dbDir, version: '0.1.0', now: () => now });
  svc.saveSettings({ wowDir: wow });
  const r = svc.broker.importGame();
  assert.equal(r.imported, 2); assert.equal(r.known, 0); assert.deepEqual(r.failed, []);
  assert.equal(r.ack.count, 2);
  const data = parseLua(fs.readFileSync(path.join(ad, 'Data.lua'))).PeonBridgeData;
  assert.equal(data.ack['1792700225-1'], true);
  assert.equal(data.ack['1792700300-2'], true);
  assert.equal(data.manager, '0.1.0');
  assert.equal(data.client, undefined);
  assert.equal(data.fmt, 2);
  assert.deepEqual(data.channels, { broker: true });   // Format 2: Kanal broker freigeschaltet (Peon_GitHub_Design.md 4.3)
  assert.equal(data.t, now);
  assert.ok(!fs.existsSync(path.join(ad, 'Data.lua.neu')));

  const db = svc.broker.db;
  const snap = db.prepare("SELECT * FROM snapshots WHERE id = '1792700225-1'").get();
  assert.equal(snap.source, 'scan'); assert.equal(snap.art, 'moment'); assert.equal(snap.region, 110);
  assert.equal(snap.char, 'Mirel Dorna'); assert.equal(snap.offers, 8); assert.equal(snap.items, 4);
  assert.equal(game.snapshotRows(db, '1792700225-1').length, 6);
  const cu = db.prepare("SELECT * FROM item_snap WHERE snapshot_id = '1792700225-1' AND item_key = '2770'").get();
  assert.equal(cu.min, 120); assert.equal(cu.qty, 45); assert.equal(cu.auctions, 3);
  const big = db.prepare("SELECT * FROM item_snap WHERE item_key = '1288'").get();
  assert.equal(big.min, 99999999999);
  const live = db.prepare("SELECT * FROM item_snap WHERE snapshot_id = '1792700300-2'").get();
  assert.equal(live.source, 'live'); assert.equal(live.min, 118); assert.equal(live.qty, 40);
  const items = db.prepare('SELECT key, name, quality FROM items ORDER BY key').all();
  assert.deepEqual({ ...items.find((x) => x.key === '2770') }, { key: '2770', name: 'Kupfererz', quality: 1 });
  assert.deepEqual({ ...items.find((x) => x.key === '6611:Klinge des Wolfs') }, { key: '6611:Klinge des Wolfs', name: 'Klinge des Wolfs', quality: null });
  // Markt bekommt einen AHledger-Vorschlag (noch nicht bestaetigt)
  assert.deepEqual(svc.settings.marketMap['Classic Beta PvE / Alliance'], { ext: 'forever.normal.alliance.us', confirmed: false });

  // nochmal einlesen: nichts neu, Data.lua bleibt gleich
  const t1 = fs.statSync(path.join(ad, 'Data.lua')).mtimeMs;
  now += 60;
  const r2 = svc.broker.importGame();
  assert.equal(r2.imported, 0); assert.equal(r2.known, 2); assert.equal(r2.ack, null);
  assert.equal(fs.statSync(path.join(ad, 'Data.lua')).mtimeMs, t1);

  // Spiel hat die bestaetigten geloescht und eine neue abgelegt
  const sv = path.join(wow, 'WTF', 'Account', '123456789#2', 'SavedVariables', 'Peon_Bridge.lua');
  fs.writeFileSync(sv, 'PeonBridgeDB = { ["queue"] = { { ["id"] = "1792701200-3", ["kind"] = "scan", ["market"] = "Classic Beta PvE / Alliance", ["t"] = 1792701200, ["rows"] = "2770;;;10;1300;;;3;;1" } } }');
  const r3 = svc.broker.importGame();
  assert.equal(r3.imported, 1);
  const d3 = parseLua(fs.readFileSync(path.join(ad, 'Data.lua'))).PeonBridgeData;
  assert.deepEqual(Object.keys(d3.ack), ['1792701200-3']);

  // Uebersicht
  const ov = svc.overview();
  assert.equal(ov.markets.length, 1);
  const m = ov.markets[0];
  assert.equal(m.scans, 2); assert.equal(m.lives, 1); assert.equal(m.lastScan.id, '1792701200-3');
  assert.equal(m.history.length, 2);
  assert.equal(m.moves.base, 1792700225);
  assert.ok(ov.wowOk);
  assert.equal(ov.back.count, 1);
  svc.close();
});

test('Fehler: kaputte Datei, fehlender Markt, kein Peon_Bridge', () => {
  const { wow, ad } = fakeWow('PeonBridgeDB = { ["queue"] = { { ["id"] = "x-1", ["kind"] = "scan", ["t"] = 5, ["rows"] = "" }, { ["id"] = "x-2", ["kind"] = "scan", ["market"] = "M / Horde", ["t"] = 6, ["rows"] = "1;;;1;5;;;3;;1" } } }');
  const svc = new Service({ enable: ['broker-client'], dbDir: tmp() });
  svc.saveSettings({ wowDir: wow });
  const r = svc.broker.importGame();
  assert.equal(r.imported, 1);
  assert.equal(r.failed.length, 1);
  assert.match(r.failed[0].error, /Markt oder Zeit fehlt/);
  const data = parseLua(fs.readFileSync(path.join(ad, 'Data.lua'))).PeonBridgeData;
  assert.deepEqual(Object.keys(data.ack), ['x-2']);   // nur was sicher in der Datenbank ist
  assert.equal(svc.overview().log[0].ok, 0);

  const w2 = fakeWow('PeonBridgeDB = { ["queue"] = { "nicht zu Ende ');
  svc.saveSettings({ wowDir: w2.wow });
  const r2 = svc.broker.importGame();
  assert.equal(r2.imported, 0); assert.equal(r2.failed.length, 1);

  const empty = tmp();
  svc.saveSettings({ wowDir: empty });
  const r3 = svc.broker.importGame();
  assert.equal(r3.error, 'Keine Peon_Bridge.lua gefunden');
  assert.equal(svc.overview().wowOk, false);
  svc.close();
});

test('AHledger abrufen: speichern, ETag, gleicher Stand, Fehler', async () => {
  const { wow } = fakeWow(SAMPLE);
  const calls = [];
  let reply = { status: 200, etag: '"v1"', body: 'AHL1|forever/normal/alliance/us|1792691095|2\n35:1900:1900:1:3193:2400:500:10100:12\n117:5:5:54:18:10:1:90:85\n' };
  const fetchImpl = async (url, opts) => {
    calls.push({ url, headers: opts.headers });
    if (reply.status === 'fail') throw new Error('Netz weg');
    if (reply.status === 304) return { status: 304, ok: false, headers: new Map() };
    return { status: reply.status, ok: reply.status === 200, headers: new Map([['etag', reply.etag]]), text: async () => reply.body };
  };
  const svc = new Service({ enable: ['broker-client'], dbDir: tmp(), fetchImpl });
  svc.saveSettings({ wowDir: wow });
  svc.broker.importGame();
  let r = await svc.broker.fetchAhledger();
  assert.equal(r[0].market, 'forever.normal.alliance.us'); assert.equal(r[0].status, 200); assert.equal(r[0].rows, 2);
  assert.match(calls[0].url, /\/v1\/pricetable\/forever\.normal\.alliance\.us$/);
  assert.equal(calls[0].headers['If-None-Match'], undefined);
  const row = svc.broker.db.prepare('SELECT * FROM ext_ahledger WHERE item_id = 117').get();
  assert.equal(row.per_day, 8.5); assert.equal(row.med7, 18);
  reply = { status: 304 };
  r = await svc.broker.fetchAhledger();
  assert.equal(r[0].status, 304);
  assert.equal(calls[1].headers['If-None-Match'], '"v1"');
  assert.equal(svc.broker.db.prepare('SELECT COUNT(*) AS n FROM ext_ahledger').get().n, 2);
  reply = { status: 200, etag: '"v2"', body: 'AHL1|forever/normal/alliance/us|1792691095|2\n35:1:1:1:1:1:1:1:1\n' };
  r = await svc.broker.fetchAhledger();
  assert.equal(r[0].status, 304, 'gleicher Stand ohne Aenderung wird nicht doppelt gespeichert');
  reply = { status: 'fail' };
  r = await svc.broker.fetchAhledger();
  assert.match(r[0].error, /Netz weg/);
  const ov = svc.overview();
  assert.equal(ov.ahledger.markets[0].tData, 1792691095);
  assert.equal(ov.ahledger.markets[0].ok, false);
  svc.saveSettings({ ahledger: { enabled: false, intervalMin: 30 } });
  assert.deepEqual(await svc.broker.fetchAhledger(), []);
  svc.close();
});

test('Echte Datei aus dem Spiel (22.10.2026)', () => {
  const real = path.join(__dirname, 'fixtures', 'Peon_Bridge_echt.lua');
  if (!fs.existsSync(real)) return;
  const { wow } = fakeWow(fs.readFileSync(real));
  const svc = new Service({ enable: ['broker-client'], dbDir: tmp() });
  svc.saveSettings({ wowDir: wow });
  const t0 = Date.now();
  const r = svc.broker.importGame();
  const ms = Date.now() - t0;
  assert.equal(r.imported, 1); assert.deepEqual(r.failed, []);
  const snap = svc.broker.db.prepare('SELECT * FROM snapshots').get();
  assert.equal(snap.offers, 20220); assert.equal(snap.lines, 9388); assert.equal(snap.region, 110);
  assert.equal(snap.char, 'Mirel Dorna');
  const n = svc.broker.db.prepare('SELECT COUNT(*) AS n, SUM(auctions) AS a FROM item_snap').get();
  assert.equal(n.a, 20220, 'alle Angebote gezaehlt');
  const axe = svc.broker.db.prepare("SELECT * FROM items WHERE key = '3201:Barbarische Kriegsaxt des Bären'").get();
  assert.ok(axe, 'Variante mit Umlaut im Schluessel');
  const named = svc.broker.db.prepare('SELECT COUNT(*) AS n FROM items WHERE name IS NOT NULL').get().n;
  assert.equal(named, n.n, 'jeder Gegenstand hat einen Namen');
  console.log(`  echte Datei: ${n.n} Gegenstaende, ${ms} ms, Datenbank ${(svc.overview().dbSize / 1024).toFixed(0)} KB`);
  svc.close();
});
