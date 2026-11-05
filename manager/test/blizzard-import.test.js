'use strict';
// Tests fuer den Einleser der Blizzard-API: nachgebautes Blizzard nach dem geprueften Aufbau, kein Netz
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { Service } = require('../src/core/service');
const { BlizzardClient } = require('../src/core/blizzard');
const imp = require('../src/core/blizzard-import');
const sales = require('../src/core/sales');
const game = require('../src/core/game');

const T0 = 1793865600;   // volle Zeit fuer die Staende
const stamp = (t) => new Date(t * 1000).toUTCString();
const tmp = () => fs.mkdtempSync(path.join(os.tmpdir(), 'peon-api-'));

// Nachgebautes Blizzard: world.houses[id] = { single, mass }, Stand umschaltbar
function fakeBlizzard() {
  const world = { t: T0, houses: {}, items: { 2589: { name: 'Leinenstoff', quality: { type: 'COMMON' }, sell_price: 13 }, 6611: { name: 'Klinge', quality: { type: 'UNCOMMON' }, sell_price: 500 } }, classic: {}, calls: [], broken: false };
  const res = (status, body = {}) => ({ status, ok: status === 200, headers: { get: (n) => (n.toLowerCase() === 'last-modified' ? stamp(world.t) : null) }, json: async () => body, text: async () => JSON.stringify(body) });
  const fetchImpl = async (url, opt) => {
    const u = new URL(url);
    const p = u.pathname;
    if (p !== '/token') world.calls.push(p);
    if (p === '/token') return res(200, { access_token: 'T', expires_in: 3600 });
    if (world.broken) return res(503);
    if (p === '/data/wow/ruleset/index') return res(200, { rulesets: [{ id: 1 }, { id: 2 }] });
    if (p === '/data/wow/ruleset/1/auctions/index') return res(200, { auctions: [{ id: 110, name: 'Auktionshaus der Allianz' }, { id: 111, name: 'Auktionshaus der Allianz' }, { id: 112, name: 'Auktionshaus der Allianz' }, { id: 114, name: 'Auktionshaus der Horde' }, { id: 117, name: 'Auktionshaus der Schwarzmeerräuber' }] });
    let m = /^\/data\/wow\/item\/(\d+)$/.exec(p);
    if (m) {
      const list = u.searchParams.get('namespace').startsWith('static-classic1x') ? world.classic : world.items;
      return list[m[1]] ? res(200, { id: Number(m[1]), ...list[m[1]] }) : res(404);
    }
    m = /^\/data\/wow\/ruleset\/1\/auctions\/(\d+)(\/commodities)?$/.exec(p);
    if (m) {
      const h = world.houses[m[1]];
      if (m[2]) {
        if (opt.headers['If-Modified-Since'] === stamp(world.t)) return res(304);
        return res(200, { auctions: h ? h.mass : [] });
      }
      return res(200, h ? { auctions: h.single } : { id: Number(m[1]) });
    }
    return res(404);
  };
  return { world, fetchImpl };
}

const SINGLE = [
  { id: 11, item: { id: 6611, bonus_lists: [12726] }, buyout: 5000, quantity: 1, time_left: 'VERY_LONG' },
  { id: 12, item: { id: 6611, bonus_lists: [12720] }, buyout: 7000, quantity: 1, time_left: 'LONG' },
  { id: 13, item: { id: 6611, context: 11 }, bid: 100, quantity: 1, time_left: 'SHORT' },
];
const MASS = [
  { id: 21, item: { id: 2589 }, quantity: 20, unit_price: 50, time_left: 'LONG' },
  { id: 22, item: { id: 2589 }, quantity: 5, unit_price: 60, time_left: 'VERY_LONG' },
];

function setup({ wow } = {}) {
  const { world, fetchImpl } = fakeBlizzard();
  let now = T0 + 600;
  const dir = wow || tmp();
  const svc = new Service({ enable: ['broker-client'], dbDir: tmp(), now: () => now, fetchImpl });
  svc.saveSettings({ wowDir: dir });
  const client = new BlizzardClient({ clientId: 'a', clientSecret: 'b', region: 'eu' }, { fetchImpl, now: () => now, apiBase: 'https://x.invalid', oauthBase: 'https://x.invalid' });
  return { svc, world, client, step: (s) => { now += s; }, getNow: () => now, api: svc.broker.api, db: svc.broker.db };
}

test('Zeitplan: eine Stunde warten, dann alle 5 Minuten, nach Fehlern auch', () => {
  assert.equal(imp.dueAt(undefined), 0);
  assert.equal(imp.dueAt({ checked: T0 + 600, t: T0 }), T0 + 3600 + 120);
  assert.equal(imp.dueAt({ checked: T0 + 3720, t: T0 }), T0 + 3720 + 300, 'Stand noch nicht da');
  assert.equal(imp.dueAt({ checked: T0 + 600, t: T0, error: { status: 503 } }), T0 + 900);
  assert.equal(imp.dueAt({ checked: T0 + 600 }), T0 + 900);
});

test('Regelsatz und Region aus dem Realm-Namen, Haus dazu', () => {
  assert.equal(imp.rulesetOf('CAMWOW EU4 Realm 3 PvE'), 2);
  assert.equal(imp.rulesetOf('CAMWOW EU4 Realm 1 PvP'), 1);
  assert.equal(imp.rulesetOf('CAMWOW EU4 Realm 2 RP'), 3);
  assert.equal(imp.rulesetOf('CAMWOW EU4 Realm 5 RP PvP'), 15);
  assert.equal(imp.regionOfRealm('CAMWOW EU4 Realm 3 PvE'), 'eu');
  assert.equal(imp.regionOfRealm('CAMWOW NA1 Realm 3 PvE'), 'us');
  assert.equal(imp.regionOfRealm('Etwas anderes', 3), 'eu');
  assert.equal(imp.regionOfRealm('Etwas anderes'), null);
  assert.deepEqual(imp.houseForRuleset(2, 'Alliance'), { house: 111, sure: true });
  assert.deepEqual(imp.houseForRuleset(2, 'Horde'), { house: 114, sure: true });
  assert.deepEqual(imp.houseForRuleset(1, 'Alliance'), { house: 110, sure: false });
  assert.equal(imp.houseForRuleset(3, 'Alliance'), null, 'Rollenspiel geht nur ueber den Scan');
});

test('Scan-Vergleich zaehlt jedes Angebot nur einmal, reine Gebote nicht', () => {
  const rows = [{ item: 1, qty: 1, buyout: 100, n: 2 }, { item: 2, qty: 4, buyout: 800, n: 1 }, { item: 3, qty: 1, buyout: 0, n: 5 }];
  const offers = [{ item: { id: 1 }, quantity: 1, buyout: 100 }, { item: { id: 2 }, quantity: 4, unit_price: 200 }, { item: { id: 9 }, quantity: 1 }];
  assert.equal(imp.matchScan(rows, offers), 2 / 3);
  assert.equal(imp.matchScan([], offers), 0);
});

test('Zeilen im Format der Scans, Namen von Gegenstaenden mit Zusatz', () => {
  assert.equal(imp.variantName('Aus dem Scan', 1, '12726', 'Klinge'), 'Aus dem Scan');
  assert.equal(imp.variantName(null, 1, '12726', 'Klinge'), 'Klinge des Wolfs');
  assert.equal(imp.variantName(null, 1, '99999', 'Klinge'), 'Klinge #99999');
  assert.equal(imp.variantName(null, 7, '12726', null), '7 #12726');
  const lines = imp.toRows(SINGLE, MASS, () => 'Klinge des Wolfs');
  assert.equal(lines[0], '6611;12726;Klinge des Wolfs;1;5000;;;4;11;1');
  assert.equal(lines[2], '6611;;;1;;;100;1;13;1');
  assert.equal(lines[3], '2589;;;20;1000;50;;3;21;1');
});

test('Abruf: Stand wird wie ein Scan eingelesen, Namen und Warenart kommen mit', async () => {
  const { svc, world, client, api, db } = setup();
  world.houses[111] = { single: SINGLE, mass: MASS };
  api.setHouse('eu', 111, true, 'Allianz');
  const r = await api.tick(client);
  assert.deepEqual({ imported: r.imported, errors: r.errors }, { imported: 1, errors: 0 });
  const s = db.prepare("SELECT * FROM snapshots WHERE id = ?").get(`api-eu-111-${T0}`);
  assert.equal(s.source, 'scan');
  assert.equal(s.art, 'api');
  assert.equal(s.t, T0);
  assert.equal(s.offers, 5);
  const m = db.prepare('SELECT key FROM markets').all();
  assert.deepEqual(m.map((x) => x.key), ['Blizzard EU Haus 111 / Alliance']);
  const cloth = db.prepare("SELECT * FROM item_snap WHERE snapshot_id = ? AND item_key = '2589'").get(s.id);
  assert.deepEqual({ min: cloth.min, qty: cloth.qty, auctions: cloth.auctions }, { min: 50, qty: 25, auctions: 2 });
  const item = db.prepare("SELECT * FROM items WHERE key = '2589'").get();
  assert.deepEqual({ name: item.name, quality: item.quality, vendor: item.vendor, commodity: item.commodity }, { name: 'Leinenstoff', quality: 1, vendor: 13, commodity: 1 });
  const wolf = db.prepare("SELECT * FROM items WHERE key = '6611:Klinge des Wolfs'").get();
  assert.equal(wolf.variant, 'Klinge des Wolfs');
  assert.equal(wolf.vendor, 500);
  assert.equal(db.prepare("SELECT commodity FROM items WHERE key = '6611'").get().commodity, 0);
  const ov = svc.overview();
  assert.equal(ov.markets[0].scans, 0);
  assert.equal(ov.markets[0].stands, 1);
  assert.equal(ov.markets[0].lastScan.art, 'api');
  assert.deepEqual({ selected: ov.api.selected, stands: ov.api.stands, last: ov.api.last }, { selected: 1, stands: 1, last: T0 });
  svc.close();
});

test('Spieldaten: abgelehnte Abfragen werden wiederholt, ohne Grundnamen wird der Stand nicht eingelesen', async () => {
  const { svc, world, client, api, db, step } = setup();
  api.wait = async () => {};
  world.houses[111] = { single: SINGLE, mass: MASS };
  api.setHouse('eu', 111, true, 'Allianz');
  const realGet = client.get.bind(client);
  let refuse = 2;   // zwei Mal abgelehnt: die dritte Runde kommt durch
  client.get = async (p, o) => {
    if (p === '/data/wow/item/6611' && refuse > 0) { refuse -= 1; return { status: 429, json: null, bytes: 0, lastModified: null }; }
    return realGet(p, o);
  };
  assert.equal((await api.tick(client)).imported, 1);
  assert.ok(db.prepare("SELECT 1 FROM items WHERE key = '6611:Klinge des Wolfs'").get(), 'voller Name');
  assert.ok(!db.prepare("SELECT 1 FROM items WHERE key LIKE '%#%'").get(), 'kein Ersatzname');
  svc.close();

  const b = setup();
  b.api.wait = async () => {};
  b.world.houses[111] = { single: SINGLE, mass: MASS };
  b.api.setHouse('eu', 111, true, 'Allianz');
  const get2 = b.client.get.bind(b.client);
  let blocked = true;
  b.client.get = async (p, o) => (p === '/data/wow/item/6611' && blocked ? { status: 429, json: null, bytes: 0, lastModified: null } : get2(p, o));
  const r = await b.api.tick(b.client);
  assert.deepEqual({ imported: r.imported, errors: r.errors }, { imported: 0, errors: 1 });
  assert.equal(b.db.prepare("SELECT COUNT(*) AS n FROM snapshots WHERE art = 'api'").get().n, 0);
  blocked = false;
  b.step(300);
  assert.equal((await b.api.tick(b.client)).imported, 1, 'beim naechsten Versuch');
  assert.ok(b.db.prepare("SELECT 1 FROM items WHERE key = '6611:Klinge des Wolfs'").get());
  b.svc.close();
  void step;
});

test('Spieldaten: kennt Forever den Gegenstand nicht, helfen die Classic-Daten', async () => {
  const { svc, world, client, api, db } = setup();
  api.wait = async () => {};
  delete world.items[6611];
  world.classic[6611] = { name: 'Klinge', quality: { type: 'UNCOMMON' }, sell_price: 500 };
  world.houses[111] = { single: SINGLE, mass: MASS };
  api.setHouse('eu', 111, true, 'Allianz');
  assert.equal((await api.tick(client)).imported, 1);
  assert.ok(db.prepare("SELECT 1 FROM items WHERE key = '6611:Klinge des Wolfs'").get());
  svc.close();
});

test('Spieldaten: unbekannter Gegenstand (404) bekommt den Ersatznamen', async () => {
  const { svc, world, client, api, db } = setup();
  api.wait = async () => {};
  world.items = {};
  world.houses[111] = { single: SINGLE, mass: MASS };
  api.setHouse('eu', 111, true, 'Allianz');
  assert.equal((await api.tick(client)).imported, 1);
  assert.ok(db.prepare("SELECT 1 FROM items WHERE key = '6611:6611 #12726'").get());
  svc.close();
});

test('Zeitplan im Lauf: keine Abfrage vor der vollen Stunde, danach nur eine Rueckfrage', async () => {
  const { svc, world, client, api, step, db } = setup();
  world.houses[111] = { single: SINGLE, mass: MASS };
  api.setHouse('eu', 111, true, 'Allianz');
  await api.tick(client);
  world.calls.length = 0;
  step(1800);
  assert.equal((await api.tick(client)).checked, 0);
  assert.equal(world.calls.length, 0, 'nichts gefragt');
  step(1500);    // jetzt eine Stunde und 2 Minuten nach dem Stand, Blizzard hat noch nichts Neues
  assert.equal((await api.tick(client)).imported, 0);
  assert.deepEqual(world.calls, ['/data/wow/ruleset/1/auctions/111/commodities'], 'nur eine Rueckfrage');
  world.calls.length = 0;
  step(60);
  assert.equal((await api.tick(client)).checked, 0, 'fragt erst nach 5 Minuten wieder');
  step(300);
  world.t = T0 + 3600;
  assert.equal((await api.tick(client)).imported, 1);
  assert.equal(db.prepare("SELECT COUNT(*) AS n FROM snapshots WHERE art = 'api'").get().n, 2);
  svc.close();
});

test('Absatz: API-Staende ueber die Nummern, Teilkauf erkannt, Scan-Paar im selben Zeitraum zaehlt nicht', async () => {
  const { svc, world, client, api, step, db, getNow } = setup();
  world.houses[111] = { single: SINGLE, mass: MASS };
  api.setHouse('eu', 111, true, 'Allianz');
  await api.tick(client);
  world.t = T0 + 3600;
  // 21 teilweise gekauft (5 Stueck), 11 weg trotz langer Restzeit
  world.houses[111] = { single: SINGLE.slice(1), mass: [{ ...MASS[0], quantity: 15 }, MASS[1]] };
  step(3600);
  await api.tick(client);
  const mid = db.prepare('SELECT id FROM markets').get().id;
  // Zwei eigene Scans im selben Zeitraum: gleiche Menge, wuerden ohne Nummern anders zaehlen
  for (const [id, t] of [['scan-a', T0 + 300], ['scan-b', T0 + 2000]]) {
    game.importEntry(db, { id, kind: 'scan', market: 'Blizzard EU Haus 111 / Alliance', t, rows: '2589;;;99;4950;;;3;;1', offers: 1 }, null);
  }
  const r = sales.updateMarket(db, mid, getNow());
  assert.equal(r.added, 1, 'nur das API-Paar');
  const pairs = db.prepare('SELECT src FROM sales_pair').all().map((x) => x.src);
  assert.deepEqual(pairs, ['api']);
  const st = sales.marketStats(db, mid, getNow());
  assert.equal(st.get('2589').sold, 5, 'Teilkauf');
  assert.ok(st.get('6611:Klinge des Wolfs').sold > 0, 'verschwunden trotz VERY_LONG');
  svc.close();
});

test('Absatz: eigene Scans zaehlen weiter, wo es keine API-Staende gibt', async () => {
  const { svc, db, getNow } = setup();
  for (const [id, t, q] of [['s1', T0, 10], ['s2', T0 + 3600, 5]]) {
    game.importEntry(db, { id, kind: 'scan', market: 'M / Alliance', t, rows: `2589;;;${q};${q * 50};;;3;;1`, offers: 1 }, null);
  }
  const mid = db.prepare('SELECT id FROM markets').get().id;
  assert.equal(sales.updateMarket(db, mid, getNow()).added, 1);
  assert.deepEqual(db.prepare('SELECT src FROM sales_pair').all().map((x) => x.src), ['scan']);
  svc.close();
});

test('Fehler: Stand bleibt aus, Meldung einmal, naechster Versuch nach 5 Minuten', async () => {
  const { svc, world, client, api, step, db } = setup();
  world.houses[111] = { single: SINGLE, mass: MASS };
  api.setHouse('eu', 111, true, 'Allianz');
  await api.tick(client);
  world.t = T0 + 3600;
  world.broken = true;
  step(3400);
  const r = await api.tick(client);
  assert.equal(r.errors, 1);
  assert.equal(api.summary().error.status, 503);
  step(300);
  await api.tick(client);
  assert.equal(db.prepare("SELECT COUNT(*) AS n FROM log WHERE kind = 'blizzard' AND ok = 0").get().n, 1, 'nur einmal im Protokoll');
  world.broken = false;
  step(300);
  assert.equal((await api.tick(client)).imported, 1);
  assert.equal(api.summary().error, null);
  svc.close();
});

test('Vorschlag: Platzhalter bekommt den echten Namen, Daten bleiben erhalten', async () => {
  const wow = tmp();
  const sv = path.join(wow, 'WTF', 'Account', 'KONTO', 'SavedVariables');
  const { svc, world, client, api, db } = setup({ wow });
  world.houses[111] = { single: SINGLE, mass: MASS };
  api.setHouse('eu', 111, true, 'Allianz');
  await api.tick(client);
  assert.equal(db.prepare('SELECT key FROM markets').get().key, 'Blizzard EU Haus 111 / Alliance');
  fs.mkdirSync(sv, { recursive: true });
  fs.writeFileSync(path.join(sv, 'Peon_Ledger.lua'), 'PeonLedgerDB = { ["realms"] = { ["CAMWOW EU4 Realm 3 PvE"] = { ["chars"] = { ["Mirel Dorna"] = { ["faction"] = "Alliance" } } } } }');
  await api.suggest(client);
  assert.deepEqual(db.prepare('SELECT key, faction FROM markets').all().map((x) => [x.key, x.faction]), [['CAMWOW EU4 Realm 3 PvE / Alliance', 'Alliance']]);
  assert.equal(db.prepare("SELECT COUNT(*) AS n FROM snapshots WHERE art = 'api'").get().n, 1);
  svc.close();
});

test('Vorschlag ueber den Scan: das richtige Haus, Daten landen im Markt des Scans', async () => {
  const { svc, world, client, api, db } = setup();
  world.houses[110] = { single: [{ id: 1, item: { id: 2589 }, buyout: 1, quantity: 1, time_left: 'LONG' }], mass: [] };
  world.houses[111] = { single: SINGLE, mass: MASS };
  api.setHouse('eu', 111, true, 'Allianz');
  await api.tick(client);
  game.importEntry(db, { id: 's', kind: 'scan', market: 'CAMWOW EU4 Realm 9 PvP / Alliance', realm: 'CAMWOW EU4 Realm 9 PvP', faction: 'Alliance', region: 3, t: T0, rows: '2589;;;20;1000;;;3;;1\n2589;;;5;300;;;4;;1\n6611;12726;Klinge des Wolfs;1;5000;;;4;;1', offers: 3 }, null);
  // Der Name sagt PvP (Gruppe 1), der Scan sagt Haus 111: der Scan gewinnt
  const r = await api.suggest(client);
  assert.deepEqual(r.map((x) => [x.house, x.how]), [[111, 'scan']]);
  assert.equal(r[0].score, 1);
  assert.equal(svc.settings.blizzard.houses['eu-111'].market, 'CAMWOW EU4 Realm 9 PvP / Alliance');
  assert.equal(db.prepare('SELECT COUNT(*) AS n FROM variant_names').get().n, 1, 'aus dem Scan gelernt');
  svc.close();
});

test('Vorschlag ohne Scan: Charaktere aus Peon_Ledger, Regelsatz bestimmt das Haus, Region muss passen', async () => {
  const wow = tmp();
  const sv = path.join(wow, 'WTF', 'Account', 'KONTO', 'SavedVariables');
  fs.mkdirSync(sv, { recursive: true });
  fs.writeFileSync(path.join(sv, 'Peon_Ledger.lua'), `PeonLedgerDB = { ["realms"] = {
    ["CAMWOW EU4 Realm 3 PvE"] = { ["chars"] = { ["Mirel Dorna"] = { ["faction"] = "Alliance" }, ["Borin Ost"] = { ["faction"] = "Horde" } } },
    ["CAMWOW EU4 Realm 2 RP"] = { ["chars"] = { ["Venla Ostra"] = { ["faction"] = "Alliance" } } },
    ["CAMWOW US1 Realm 3 PvE"] = { ["chars"] = { ["Weit Weg"] = { ["faction"] = "Alliance" } } } } }`);
  const { svc, client, api } = setup({ wow });
  const r = await api.suggest(client);
  const byMarket = Object.fromEntries(r.map((x) => [x.market, x]));
  assert.equal(byMarket['CAMWOW EU4 Realm 3 PvE / Alliance'].house, 111);
  assert.equal(byMarket['CAMWOW EU4 Realm 3 PvE / Alliance'].how, 'ruleset');
  assert.equal(byMarket['CAMWOW EU4 Realm 3 PvE / Horde'].house, 114);
  assert.equal(byMarket['CAMWOW EU4 Realm 2 RP / Alliance'].house, null, 'Rollenspiel ist noch unklar');
  assert.equal(byMarket['CAMWOW US1 Realm 3 PvE / Alliance'], undefined, 'andere Region');
  assert.deepEqual(Object.keys(svc.settings.blizzard.houses).sort(), ['eu-111', 'eu-114']);
  svc.close();
});

test('Haus von Hand gewaehlt: bekannter Markt desselben Regelsatzes, neutrales Haus eigener Markt, abwaehlen', async () => {
  const { svc, api, db, client } = setup();
  game.importEntry(db, { id: 's', kind: 'scan', market: 'CAMWOW EU4 Realm 3 PvE / Alliance', realm: 'CAMWOW EU4 Realm 3 PvE', faction: 'Alliance', region: 3, t: T0, rows: '2589;;;20;1000;;;3;;1', offers: 1 }, null);
  api.setHouse('eu', 111, true, 'Allianz');
  api.setHouse('eu', 117, true, 'Neutral');
  assert.equal(svc.settings.blizzard.houses['eu-111'].market, 'CAMWOW EU4 Realm 3 PvE / Alliance');
  assert.equal(svc.settings.blizzard.houses['eu-117'].market, 'CAMWOW EU4 Realm 3 PvE / Neutral');
  const v = await api.view(client);
  assert.equal(v.houses.find((h) => h.id === 111).selected, true);
  assert.equal(v.houses.find((h) => h.id === 111).sure, true);
  assert.equal(v.houses.find((h) => h.id === 110).ruleset, 'PvP');
  assert.equal(v.houses.find((h) => h.id === 112).empty, true);
  assert.equal(v.houses.find((h) => h.id === 117).factionLabel, 'Neutral');
  api.setHouse('eu', 117, false);
  assert.equal(svc.settings.blizzard.houses['eu-117'], undefined);
  svc.close();
});

test('Andere Region im Zugang: Auswahl der alten Region wird nicht abgerufen', async () => {
  const { svc, world, api, client, getNow } = setup();
  world.houses[111] = { single: SINGLE, mass: MASS };
  api.setHouse('us', 111, true, 'Allianz');
  const r = await api.tick(client);
  assert.equal(r.checked, 0);
  assert.equal(getNow() > 0, true);
  svc.close();
});

test('AHledger ist weg: alte Einstellungen und Tabellen verschwinden', () => {
  const dir = tmp();
  fs.writeFileSync(path.join(dir, 'settings.json'), JSON.stringify({ ahledger: { enabled: true, intervalMin: 30 }, marketMap: { x: { ext: 'y' } }, modules: { 'broker-client': { enabled: true } } }));
  const { DatabaseSync } = require('node:sqlite');
  const old = new DatabaseSync(path.join(dir, 'broker-client.db'));
  old.exec('CREATE TABLE ext_fetch (id INTEGER); CREATE TABLE ext_ahledger (id INTEGER);');
  old.close();
  const svc = new Service({ dbDir: dir });
  assert.equal(svc.settings.ahledger, undefined);
  assert.equal(svc.settings.marketMap, undefined);
  svc.saveSettings({ theme: 'dark' });
  const saved = JSON.parse(fs.readFileSync(path.join(dir, 'settings.json'), 'utf8'));
  assert.equal(saved.ahledger, undefined);
  const tables = svc.broker.db.prepare("SELECT name FROM sqlite_master WHERE name LIKE 'ext_%'").all();
  assert.deepEqual(tables, []);
  svc.close();
});
