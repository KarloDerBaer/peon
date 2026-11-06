'use strict';
// Tests fuer Marktnamen, Zwischenspeicher, Favoriten, Einkaufsliste und genaue Werte (Manager 0.17.0): node --test test/
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { execFileSync } = require('node:child_process');
const { Service } = require('../src/core/service');
const { marketLabel, sameMarket } = require('../src/core/markets');
const shopping = require('../src/core/shopping');
const { parseLua, toLua } = require('../src/core/lua');
const { parseTip } = require('../src/core/game');
const { marketId } = require('../src/core/db');

process.removeAllListeners('warning');
function tmp() { return fs.mkdtempSync(path.join(os.tmpdir(), 'peon-v-')); }
const NOW = 1794000000;
const M = 'CAMWOW EU4 Realm 3 PvE / Alliance';

function setup() {
  const dir = tmp();
  const wow = tmp();
  const sv = path.join(wow, 'WTF', 'Account', 'KONTO', 'SavedVariables');
  fs.mkdirSync(sv, { recursive: true });
  const ad = path.join(wow, 'Interface', 'AddOns', 'Peon_Bridge');
  fs.mkdirSync(ad, { recursive: true });
  fs.writeFileSync(path.join(ad, 'Peon_Bridge.toc'), 'x');
  const clock = { t: NOW };
  const svc = new Service({ enable: ['broker-client'], dbDir: dir, version: '0.17.0', now: () => clock.t });
  svc.saveSettings({ wowDir: wow });
  return { svc, dir, wow, sv, ad, clock, db: svc.broker.db, b: svc.broker };
}

function stand(db, id, t, rows, market = M) {
  const mid = marketId(db, market, {});
  const lines = [];
  db.prepare("INSERT INTO snapshots(id, market_id, source, art, t, offers, items, rows) VALUES (?, ?, 'scan', 'api', ?, 10, 2, ?)").run(id, mid, t, require('node:zlib').deflateSync(Buffer.from(Object.entries(rows).map(([k, r]) => `${parseInt(k, 10)};;;${r.qty ?? 5};${(r.min) * (r.qty ?? 5)};;;4;;1`).join('\n'))));
  for (const [key, r] of Object.entries(rows)) {
    db.prepare('INSERT OR IGNORE INTO items(key, item_id, name, quality) VALUES (?, ?, ?, 1)').run(key, parseInt(key, 10) || 1, `Name ${key}`);
    db.prepare("INSERT INTO item_snap(snapshot_id, market_id, item_key, t, source, min, median, p25, p75, qty, auctions) VALUES (?, ?, ?, ?, 'scan', ?, ?, ?, ?, ?, ?)")
      .run(id, mid, key, t, r.min, r.median ?? r.min, r.min, r.min, r.qty ?? 5, r.qty ?? 5);
  }
  return mid;
}

test('Marktnamen: nur Regelsatz und Fraktion', () => {
  assert.equal(marketLabel(M), 'PvE Allianz');
  assert.equal(marketLabel('CAMWOW EU4 Realm 3 PvE / Neutral'), 'PvE Neutral');
  assert.equal(marketLabel('CAMWOW EU1 Realm 1 PvP / Horde'), 'PvP Horde');
  assert.equal(marketLabel('Blizzard EU Haus 117 / Neutral'), 'PvE Neutral');
  assert.equal(marketLabel('Blizzard EU Haus 113 / Horde'), 'PvP Horde');
  assert.equal(marketLabel('Classic Beta PvE / Alliance'), 'PvE Allianz');
  assert.equal(marketLabel('irgendwas'), 'irgendwas');
});

test('Anderer interner Name desselben Markts ergibt keinen zweiten Markt', () => {
  const { svc, db, b, wow, ad } = setup();
  const a = marketId(db, M, { region: 3 });
  assert.equal(marketId(db, 'CAMWOW EU4 Realm 1 PvE / Alliance', { region: 3 }), a);
  assert.equal(marketId(db, 'CAMWOW EU4 Realm 1 PvE / Alliance', {}), a, 'beim zweiten Mal ueber den Verweis');
  assert.notEqual(marketId(db, 'CAMWOW EU4 Realm 3 PvE / Horde', { region: 3 }), a, 'andere Fraktion');
  assert.notEqual(marketId(db, 'CAMWOW EU4 Realm 3 PvP / Alliance', { region: 3 }), a, 'anderer Regelsatz');
  assert.notEqual(marketId(db, 'CAMWOW US1 Realm 3 PvE / Alliance', { region: 1 }), a, 'andere Region');
  assert.notEqual(marketId(db, 'Blizzard EU Haus 111 / Alliance', {}), a, 'Haus ohne Zuordnung bleibt getrennt');
  assert.equal(sameMarket(M, 3, 'CAMWOW EU2 Realm 9 PvE / Alliance', 3), true);
  // Das Spiel findet seine Werte auch unter dem anderen Namen
  stand(db, 'a', NOW - 60, { 100: { min: 500 } });
  b.importGame();
  const data = parseLua(fs.readFileSync(path.join(ad, 'Data.lua'))).PeonBridgeData;
  assert.equal(data.aliases['CAMWOW EU4 Realm 1 PvE / Alliance'], M);
  assert.ok(wow);
  svc.close();
});

test('Liste kommt aus dem Zwischenspeicher, neue Daten rechnen neu, auch nach dem Neustart', () => {
  const { svc, db, b, dir } = setup();
  stand(db, 'a', NOW - 200, { 100: { min: 500 }, 200: { min: 900 } });
  const first = b.itemList(M);
  assert.deepEqual(first.items.map((x) => x.key).sort(), ['100', '200']);
  assert.equal(b.itemList(M), first, 'zweites Mal dieselbe Liste');
  assert.equal(b.bands(1), b.bands(1));
  stand(db, 'b', NOW - 100, { 100: { min: 700 } });
  const second = b.itemList(M);
  assert.notEqual(second, first);
  assert.equal(second.items.find((x) => x.key === '100').min, 700);
  assert.equal(db.prepare('SELECT COUNT(*) AS n FROM list_cache').get().n, 1);
  // Nach einem Neustart ohne neue Rechnung: Der Wert kommt aus der Datenbank
  db.prepare("UPDATE item_snap SET min = 1 WHERE item_key = '100'").run();
  svc.close();
  const again = new Service({ enable: ['broker-client'], dbDir: dir, version: '0.17.0', now: () => NOW });
  assert.equal(again.broker.itemList(M).items.find((x) => x.key === '100').min, 700);
  again.close();
});

test('Gegenstand: Werte eines einzelnen Gegenstands wie die der ganzen Liste, andere Maerkte dabei', () => {
  const { svc, db, b } = setup();
  for (let d = 5; d >= 0; d--) stand(db, `t${d}`, NOW - d * 86400 - 60, { 100: { min: 1000 + d * 10 }, 200: { min: 5000 } });
  stand(db, 'n', NOW - 30, { 100: { min: 800, qty: 2 } }, 'CAMWOW EU4 Realm 3 PvE / Neutral');
  const d = b.itemDetail(M, '100', '30d');
  const whole = b.bands(1).items.get('100');
  assert.deepEqual(d.longterm, whole);
  assert.equal(d.others.length, 1);
  assert.deepEqual([d.others[0].label, d.others[0].min, d.others[0].qty], ['PvE Neutral', 800, 2]);
  assert.equal(b.itemDetail(M, '200', '30d').others.length, 0);
  svc.close();
});

test('Favoriten gelten marktuebergreifend', () => {
  const { svc, b } = setup();
  assert.deepEqual(b.favorites(), []);
  assert.deepEqual(b.setFavorite('100', true), ['100']);
  b.setFavorite('3192:Kurzes Bastardschwert des Gorillas', true);
  b.setFavorite('100', true);
  assert.equal(b.favorites().length, 2);
  assert.deepEqual(b.setFavorite('100', false), ['3192:Kurzes Bastardschwert des Gorillas']);
  svc.close();
});

test('Einkaufsliste: neuere Aenderung gewinnt, Loeschmarken halten, keine Wiederkehr', () => {
  const d = shopping.empty();
  const l = shopping.newList(d, 'Erze', 100);
  assert.equal(l.pct, 10);
  shopping.addItem(d, l.id, '2770', { name: 'Kupfererz', quality: 1 }, 100);
  shopping.setItem(d, l.id, '2770', { wish: 20, max: 500 }, 110);
  assert.deepEqual([d.lists[0].items[2770].wish, d.lists[0].items[2770].max], [20, 500]);

  // Spiel aendert spaeter die Menge: gewinnt
  let inc = { lists: [{ id: l.id, name: 'Erze', pct: 10, u: 100, items: { 2770: { wish: 30, u: 200 } } }] };
  assert.equal(shopping.merge(d, inc), true);
  assert.equal(d.lists[0].items[2770].wish, 30);
  // Dasselbe nochmal: nichts Neues
  assert.equal(shopping.merge(d, inc), false);
  // Aelterer Stand aendert nichts
  assert.equal(shopping.merge(d, { lists: [{ id: l.id, name: 'Alt', pct: 50, u: 50, items: { 2770: { wish: 1, u: 150 } } }] }), false);
  assert.equal(d.lists[0].name, 'Erze');

  // Im Manager geloescht: Der alte Stand aus dem Spiel bringt es nicht zurueck
  shopping.removeItem(d, l.id, '2770', 300);
  assert.equal(shopping.merge(d, inc), false);
  assert.equal(d.lists[0].items[2770], undefined);
  // Danach neu im Spiel hinzugefuegt: kommt wieder
  assert.equal(shopping.merge(d, { lists: [{ id: l.id, u: 100, items: { 2770: { u: 400 } } }] }), true);
  assert.ok(d.lists[0].items[2770]);
  assert.equal(d.gone.items[`${l.id}|2770`], undefined);

  // Im Spiel geloescht
  assert.equal(shopping.merge(d, { gone: { items: { [`${l.id}|2770`]: 500 } } }), true);
  assert.equal(d.lists[0].items[2770], undefined);

  // Liste geloescht, alter Stand kommt nicht wieder, Marken verfallen
  shopping.deleteList(d, l.id, 600);
  assert.equal(d.lists.length, 0);
  assert.equal(shopping.merge(d, { lists: [{ id: l.id, name: 'Erze', u: 100, items: {} }] }), false);
  assert.equal(shopping.purge(d, 600 + shopping.GONE_DAYS * 86400 + 1000), true);
  assert.deepEqual(d.gone, { lists: {}, items: {} });
  assert.equal(shopping.money(12345), '1g 23s 45c');
});

// Gleiche Regeln wie Brokers Shop.lua
const REPO = path.join(__dirname, '..', '..');
const LUA = path.join(REPO, 'tools', process.platform === 'win32' ? 'lua5.1.exe' : 'lua5.1-linux');

test('Einkaufsliste: gleiches Ergebnis wie Broker (Shop.lua, 1500 Zufallsfaelle)', { skip: !fs.existsSync(LUA) }, () => {
  let seed = 17;
  const rnd = (n) => { seed = (seed * 16807) % 2147483647; return seed % n; };
  const IDS = ['g1_1', 'm2_2', 'g3_3'], KEYS = ['2770', '2589', '15000:Name des Wolfs'];
  const side = () => {
    const lists = [];
    for (const id of IDS) {
      if (rnd(3) === 0) continue;
      const items = {};
      for (const k of KEYS) if (rnd(2)) { const it = { u: 100 + rnd(6) }; if (rnd(2)) it.wish = 1 + rnd(9); if (rnd(3) === 0) it.max = 100 * (1 + rnd(9)); items[k] = it; }
      lists.push({ id, name: `L${rnd(4)}`, pct: rnd(4) * 10, u: 100 + rnd(6), items });
    }
    const gone = { lists: {}, items: {} };
    for (const id of IDS) {
      if (rnd(4) === 0) gone.lists[id] = 100 + rnd(6);
      for (const k of KEYS) if (rnd(4) === 0) gone.items[`${id}|${k}`] = 100 + rnd(6);
    }
    return { lists, gone };
  };
  const cases = Array.from({ length: 1500 }, () => ({ a: side(), b: side() }));
  const file = path.join(tmp(), 'cases.lua');
  fs.writeFileSync(file, `CASES = ${toLua(cases)}\n`);
  const out = execFileSync(LUA, [path.join(__dirname, 'lua', 'shop_compare.lua'), path.join(REPO, 'addons', 'Peon_Broker'), file]).toString().trim().split(/\r?\n/);
  const v = (x) => (x == null ? '-' : String(x));
  const sorted = (o) => Object.keys(o).sort((x, y) => (x < y ? -1 : x > y ? 1 : 0));
  let bad = 0;
  cases.forEach((c, i) => {
    const d = shopping.clean(JSON.parse(JSON.stringify(c.a)));
    shopping.merge(d, c.b);
    const parts = [...d.lists].sort((x, y) => (x.id < y.id ? -1 : 1)).map((l) => `${l.id}=${l.name},${v(l.pct)},${v(l.u)}[${sorted(l.items).map((k) => `${k}:${v(l.items[k].wish)}:${v(l.items[k].max)}:${v(l.items[k].u)}`).join(' ')}]`);
    const g = [...sorted(d.gone.lists).map((k) => `L${k}=${v(d.gone.lists[k])}`), ...sorted(d.gone.items).map((k) => `I${k}=${v(d.gone.items[k])}`)];
    const js = `${parts.join(';')}#${g.join(';')}`;
    if (js !== out[i]) { if (bad < 3) console.log('ABWEICHUNG', i, '\nJS ', js, '\nLua', out[i], '\n', JSON.stringify(c)); bad++; }
  });
  assert.equal(bad, 0);
});

test('Einkaufsliste im Manager: Hoechstpreis, Treffer, Meldung einmal, Weg ins Spiel und zurueck', () => {
  const { svc, db, b, sv, ad, clock } = setup();
  for (let d = 5; d >= 1; d--) stand(db, `t${d}`, NOW - d * 86400, { 100: { min: 1000 }, 200: { min: 2000 } });
  stand(db, 'jetzt', NOW - 60, { 100: { min: 1000 }, 200: { min: 2000 } });
  const id = b.newShopList('Erze');
  assert.equal(b.shopLists('100')[0].on, false);
  b.addShopItem(id, '100');
  b.addShopItem(id, '200');
  assert.equal(b.shopLists('100')[0].on, true);

  let view = b.shopView(M);
  let r100 = view.lists[0].items.find((x) => x.key === '100');
  assert.equal(r100.name, 'Name 100');
  assert.equal(r100.limit, 900, '10 % unter dem Mittel');
  assert.equal(r100.hits, 0);
  assert.deepEqual(b.shopCheck(), []);

  // Eigener Hoechstpreis geht vor
  b.setShopItem(id, '100', { max: 1200, wish: 3 });
  view = b.shopView(M);
  r100 = view.lists[0].items.find((x) => x.key === '100');
  assert.deepEqual([r100.limit, r100.rule, r100.wish, r100.hits], [1200, 900, 3, 5]);
  assert.equal(view.lists[0].items[0].key, '100', 'Treffer oben');
  const hits = b.shopCheck();
  assert.deepEqual(hits.map((x) => [x.key, x.min, x.limit, x.label]), [['100', 1000, 1200, 'PvE Allianz']]);
  assert.deepEqual(b.shopCheck(), [], 'nur einmal melden');
  assert.deepEqual(b.shopBuyable(M).map((x) => x.key), ['100']);

  // Weg ins Spiel: gleich in Data.lua, ohne dass neu gerechnet werden muss
  const data = () => parseLua(fs.readFileSync(path.join(ad, 'Data.lua'))).PeonBridgeData;
  assert.equal(data().shop.lists[0].id, id);
  assert.equal(data().shop.lists[0].items[100].max, 1200);
  assert.equal(data().channels.broker, true);

  // Stand fuer die Kopfleiste
  const s0 = b.sync();
  assert.ok(s0.inputs > 0);
  b.meta('gameLoadAt', clock.t + 10);
  assert.equal(b.sync().inputs, 0, 'nach dem Laden im Spiel nichts mehr offen');

  // Weg zurueck: Im Spiel geaendert und eine neue Liste, das Einlesen mischt es ein und schreibt es wieder
  clock.t += 100;
  fs.writeFileSync(path.join(sv, 'Peon_Broker.lua'), `PeonBrokerDB = ${toLua({
    markets: {},
    lists: [{ id, name: 'Erze', pct: 20, u: clock.t, items: { 100: { wish: 9, u: clock.t, name: 'Name 100' } } }, { id: 'g9_9', name: 'Vom Spiel', pct: 10, u: clock.t, items: {} }],
    listsGone: { items: { [`${id}|200`]: clock.t } },
  })}`);
  b.importGame();
  view = b.shopView(M);
  assert.deepEqual(view.lists.map((l) => l.name), ['Erze', 'Vom Spiel']);
  assert.equal(view.lists[0].pct, 20);
  assert.deepEqual(view.lists[0].items.map((x) => [x.key, x.wish]), [['100', 9]]);
  assert.equal(data().shop.lists.length, 2);
  assert.equal(data().shop.gone.items[`${id}|200`], clock.t);
  assert.equal(b.sync().inputs, 0, 'Was vom Spiel kam, wartet nicht');

  // Liste loeschen
  b.deleteShopList('g9_9');
  assert.equal(data().shop.lists.length, 1);
  assert.ok(b.sync().inputs > 0);
  svc.close();
});

test('Vorrat kommt aus Peon_Ledger: Taschen und Bank aller Charaktere', () => {
  const { svc, db, b, sv } = setup();
  assert.equal(b.ledgerStock(), null, 'ohne Ledger');
  stand(db, 'a', NOW - 60, { 100: { min: 1000 } });
  fs.writeFileSync(path.join(sv, 'Peon_Ledger.lua'), `PeonLedgerDB = ${toLua({ realms: { R: { chars: {
    A: { places: { bags: { items: { 100: 3 } }, bank: { items: { 100: 4 } }, mail: { items: { 100: 50 } } } },
    B: { places: { bags: { items: { 100: 2, 200: 1 } } } },
  } } } })}`);
  const id = b.newShopList('X');
  b.addShopItem(id, '100');
  const view = b.shopView(M);
  assert.equal(view.hasLedger, true);
  assert.equal(view.lists[0].items[0].stock, 9);
  svc.close();
});

test('Hinweis in der Kopfleiste: Laden im Spiel wird erkannt', () => {
  const { svc, b, sv, clock } = setup();
  const file = path.join(sv, 'Peon_Bridge.lua');
  fs.writeFileSync(file, 'PeonBridgeDB = {}');
  const stampFile = (t) => fs.utimesSync(file, new Date(t * 1000), new Date(t * 1000));
  stampFile(clock.t);
  assert.equal(b.noteGame(false), false, 'erste Beobachtung sagt nichts');
  const id = b.newShopList('X');
  let s = b.sync();
  assert.ok(s.inputs > 0);
  assert.equal(s.running, false);

  clock.t += 50;
  assert.equal(b.noteGame(true), true, 'WoW gestartet: Es hat Data.lua gelesen');
  s = b.sync();
  assert.equal(s.inputs, 0);
  assert.equal(s.running, true);

  clock.t += 50;
  b.addShopItem(id, '100');
  assert.ok(b.sync().inputs > 0, 'neue Eingabe wartet auf /reload');
  assert.equal(b.noteGame(true), false);
  assert.ok(b.sync().inputs > 0);

  clock.t += 50;
  stampFile(clock.t);
  assert.equal(b.noteGame(true), true, 'Datei gespeichert: neu geladen');
  assert.equal(b.sync().inputs, 0);
  svc.close();
});

test('Der Manager bestellt fehlende genaue Werte und nimmt sie entgegen', () => {
  const { svc, db, b, sv, ad, clock } = setup();
  const zlib = require('node:zlib');
  const mid = marketId(db, M, { region: 3 });
  db.prepare("INSERT INTO snapshots(id, market_id, source, art, t, offers, items, rows) VALUES ('a', ?, 'scan', 'api', ?, 4, 4, ?)").run(mid, NOW - 60, zlib.deflateSync(Buffer.from([
    '3192;12723;Kurzes Bastardschwert des Gorillas;1;500;;;4;1;1', '5000;;;1;500;;;4;2;1', '2589;;;20;500;;;4;3;1', '6000;;Alte Variante;1;500;;;4;4;1', '7000;1,2;Zwei Boni;1;500;;;4;5;1',
  ].join('\n'))));
  const ins = db.prepare('INSERT INTO items(key, item_id, name, quality) VALUES (?, ?, ?, ?)');
  ins.run('5000', 5000, 'Selten', 2); ins.run('2589', 2589, 'Leinenstoff', 1);
  let want = b.tipWants();
  assert.equal(want['3192:Kurzes Bastardschwert des Gorillas'], 'item:3192::::::::20:1488:::1:12723', 'Form wie im Spiel bestaetigt');
  assert.equal(want['7000:Zwei Boni'], 'item:7000::::::::20:1488:::2:1:2');
  assert.equal(want['5000'], 'item:5000');
  assert.equal(want['2589'], undefined, 'Stoff nur, wenn er gemerkt ist');
  assert.equal(want['6000:Alte Variante'], undefined, 'ohne Bonus kein Link');
  // Gemerktes kommt dazu und steht vorn, auch ohne Angebot
  b.setFavorite('2589', true);
  b.setFavorite('9999', true);
  want = b.tipWants();
  assert.equal(want['2589'], 'item:2589');
  assert.equal(want['9999'], 'item:9999');

  // Weg ins Spiel und zurueck
  b.importGame();
  const data = () => parseLua(fs.readFileSync(path.join(ad, 'Data.lua'))).PeonBridgeData;
  assert.equal(data().tipWant['3192:Kurzes Bastardschwert des Gorillas'], 'item:3192::::::::20:1488:::1:12723');
  fs.writeFileSync(path.join(sv, 'Peon_Bridge.lua'), `PeonBridgeDB = ${toLua({ fmt: 1, queue: [], tipBox: { '3192:Kurzes Bastardschwert des Gorillas': 'Zweihändig\tSchwert\t\n+1 Stärke\t\t\n+1 Intelligenz\t\t', 5000: '' } })}`);
  b.importGame();
  assert.equal(data().tipWant['3192:Kurzes Bastardschwert des Gorillas'], undefined, 'bekannt: nicht mehr bestellt');
  assert.equal(data().tipWant['5000'], undefined, 'Spiel kennt ihn nicht: Pause');
  assert.deepEqual(b.tipStats().known, 1);
  assert.ok(b.tipStats().open > 0);
  // Nach 7 Tagen wieder fragen, vorhandene Werte ueberschreibt ein leerer Text nicht
  clock.t += 8 * 86400;
  assert.equal(b.tipWants()['5000'], 'item:5000');
  require('../src/core/game').saveTips(db, { '3192:Kurzes Bastardschwert des Gorillas': '' }, clock.t);
  assert.equal(JSON.parse(db.prepare('SELECT lines FROM item_tip WHERE key = ?').get('3192:Kurzes Bastardschwert des Gorillas').lines)[1].l, '+1 Stärke');
  svc.close();
});

test('Bestellung: hoechstens 1.000, Gemerktes und Zusaetze zuerst', () => {
  const { svc, db, b } = setup();
  const zlib = require('node:zlib');
  const mid = marketId(db, M, { region: 3 });
  const lines = ['8000;777;Teil des Wolfs;1;500;;;4;1;1'];
  const ins = db.prepare('INSERT INTO items(key, item_id, name, quality) VALUES (?, ?, ?, 2)');
  for (let i = 0; i < 1200; i++) { lines.push(`${10000 + i};;;1;500;;;4;${i + 2};1`); ins.run(String(10000 + i), 10000 + i, `Teil ${i}`); }
  db.prepare("INSERT INTO snapshots(id, market_id, source, art, t, offers, items, rows) VALUES ('a', ?, 'scan', 'api', ?, 1201, 1201, ?)").run(mid, NOW - 60, zlib.deflateSync(Buffer.from(lines.join('\n'))));
  b.setFavorite('9999', true);
  const want = b.tipWants();
  assert.equal(Object.keys(want).length, 1000);
  assert.equal(want['9999'], 'item:9999', 'Favorit ist dabei');
  assert.equal(want['8000:Teil des Wolfs'], 'item:8000::::::::20:1488:::1:777', 'Zusatz ist dabei');
  assert.equal(b.tipStats().open, 1202, 'zaehlt alles Offene');
  svc.close();
});

test('Genaue Werte aus dem Spiel ersetzen die Grundwerte', async () => {
  const { svc, b, sv } = setup();
  assert.deepEqual(parseTip('Zweihändig\tSchwert\t\n+5 Ausdauer\t\tg\n\t\t\nBenötigt Stufe 7\t\tm\nGegenstandsstufe 12\t\ty'), [
    { l: 'Zweihändig', r: 'Schwert' }, { l: '+5 Ausdauer', c: 'good' }, { l: 'Benötigt Stufe 7', c: 'muted' }, { l: 'Gegenstandsstufe 12', c: 'level' },
  ]);
  const key = '3192:Kurzes Bastardschwert des Gorillas';
  fs.writeFileSync(path.join(sv, 'Peon_Bridge.lua'), `PeonBridgeDB = ${toLua({ fmt: 1, queue: [{
    id: 's1', kind: 'scan', fmt: 1, market: M, t: NOW - 60, rows: `3192;12723;Kurzes Bastardschwert des Gorillas;1;500;;;4;;1`,
    tips: { [key]: 'Zweihändig\tSchwert\t\n+5 Ausdauer\t\tg\n+5 Intelligenz\t\tg' },
  }] })}`);
  b.importGame();
  const t = await b.itemTip(key, null);
  assert.equal(t.state, 'ok');
  assert.equal(t.tip.exact, true);
  assert.deepEqual(t.tip.lines[1], { l: '+5 Ausdauer', c: 'good' });
  // Ohne Werte aus dem Spiel bleibt es beim bisherigen Weg
  assert.equal((await b.itemTip('3192', null)).state, 'no-access');
  svc.close();
});
