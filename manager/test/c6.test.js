'use strict';
// Tests fuer C6: Absatz im Client und Chancen (Rechenmodell Kapitel 9): node --test test/
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { execFileSync } = require('node:child_process');
const { Service } = require('../src/core/service');
const { toLua, parseLua } = require('../src/core/lua');
const broker = require('../src/core/broker');
const game = require('../src/core/game');
const sales = require('../src/core/sales');

function tmp() { return fs.mkdtempSync(path.join(os.tmpdir(), 'peon-')); }
const M = 'Classic Beta PvE / Alliance';
function at(day, hour) { return broker.dayTime(day) - 12 * 3600 + hour * 3600; }
const DAY = 20748;

function world() {
  const wow = tmp();
  const sv = path.join(wow, 'WTF', 'Account', '1#1', 'SavedVariables');
  fs.mkdirSync(sv, { recursive: true });
  const ad = path.join(wow, 'Interface', 'AddOns', 'Peon_Bridge');
  fs.mkdirSync(ad, { recursive: true });
  fs.writeFileSync(path.join(ad, 'Peon_Bridge.toc'), 'x');
  fs.writeFileSync(path.join(sv, 'Peon_Broker.lua'), 'PeonBrokerDB = ' + toLua({
    markets: { [M]: { items: {
      2589: { d: `${DAY - 3}:1000:1000:100:1;${DAY - 2}:1000:1000:100:1;${DAY - 1}:1000:1000:100:1`, nm: 'Leinenstoff', ql: 1 },
      4306: { d: `${DAY - 3}:900:900:10:1;${DAY - 2}:900:900:10:1;${DAY - 1}:900:900:10:1`, nm: 'Seidenstoff', ql: 1 },
    } } },
    commodity: { 4306: true, 2770: true },
  }));
  const queue = [];
  const svc = new Service({ enable: ['broker-client'], dbDir: tmp(), now: () => at(DAY, 23) });
  svc.saveSettings({ wowDir: wow });
  let k = 1;
  const push = (e) => { queue.push({ id: `${e.t}-${k++}`, market: M, ...e }); fs.writeFileSync(path.join(sv, 'Peon_Bridge.lua'), 'PeonBridgeDB = ' + toLua({ queue, fmt: 1 })); };
  return { svc, wow, push, ad };
}

const NAMES = { 2589: 'Leinenstoff|1|10|1', 4306: 'Seidenstoff|1|500|', 6611: 'Klinge|2|1200|0' };

test('Namen mit Haendlerpreis und Warenart (Peon_Client 0.3.0), alte Form', () => {
  assert.deepEqual(game.parseName('Leinenstoff|1|10|1'), { name: 'Leinenstoff', quality: 1, vendor: 10, commodity: 1 });
  assert.deepEqual(game.parseName('Kupfererz|1'), { name: 'Kupfererz', quality: 1, vendor: null, commodity: null });
  assert.deepEqual(game.parseName('X||'), { name: 'X', quality: null, vendor: null, commodity: null });
});

test('Absatz aus zwei Scans: von unten gekauft, oben abgebrochen, Einzelgegenstand, Data.lua', () => {
  const { svc, push, ad } = world();
  const t0 = at(DAY, 10);
  push({ kind: 'scan', t: t0, names: NAMES, rows: [
    '2589;;;20;10000;;;4;;3', '2589;;;20;12000;;;4;;1', '2589;;;20;30000;;;4;;1',
    '6611;;Klinge des Wolfs;1;50000;;;4;;1', '4306;;;5;1500;;;4;;1'].join('\n') });
  push({ kind: 'scan', t: t0 + 3600, rows: [
    '2589;;;20;10000;;;4;;1', '2589;;;20;12000;;;4;;1', '4306;;;5;1500;;;4;;1'].join('\n') });
  svc.broker.importGame();
  const it = svc.broker.db.prepare("SELECT vendor, commodity FROM items WHERE key = '2589'").get();
  assert.deepEqual({ ...it }, { vendor: 10, commodity: 1 });
  assert.equal(svc.broker.db.prepare("SELECT commodity FROM items WHERE key = '4306'").get().commodity, 1, 'Warenart von Broker');
  assert.equal(svc.broker.db.prepare("SELECT vendor FROM items WHERE key = '6611:Klinge des Wolfs'").get().vendor, 1200, 'Variante bekommt den Haendlerpreis');
  const st = sales.marketStats(svc.broker.db, svc.broker.marketId(M), svc.now());
  const lein = st.get('2589');
  // zwei der drei Angebote zu 500 weg (unter dem stehenden Anker 500): verkauft 40; 1500 weg ueber dem Anker: abgebrochen 20
  assert.equal(lein.sold, 40); assert.equal(lein.cancelled, 20); assert.equal(lein.expired, 0);
  assert.equal(Math.round(lein.perDay), 960); assert.equal(lein.level, 2); assert.equal(lein.minutes, 60);
  const kl = st.get('6611:Klinge des Wolfs');
  assert.ok(Math.abs(kl.sold - 0.9) < 1e-9 && Math.abs(kl.cancelled - 0.1) < 1e-9, 'Einzelgegenstand: 10 % Abbrueche');
  assert.equal(st.get('4306').sold, 0, 'unveraendert: beobachtet, nichts verkauft');
  // Data.lua: sales getrennt von items
  const data = parseLua(fs.readFileSync(path.join(ad, 'Data.lua'))).PeonBridgeData;
  assert.equal(data.markets[M].sales[2589], '9600:100:60');
  assert.ok(data.markets[M].items[2589], 'Langzeit-Teil weiter da');
  // Scan dazwischen: altes Paar ersetzt, Summen neu
  push({ kind: 'scan', t: t0 + 1800, rows: ['2589;;;20;10000;;;4;;2', '2589;;;20;12000;;;4;;1', '2589;;;20;30000;;;4;;1', '4306;;;5;1500;;;4;;1'].join('\n') });
  svc.broker.importGame();
  const pairs = svc.broker.db.prepare("SELECT COUNT(*) AS n FROM sales_pair WHERE src = 'scan'").get().n;
  assert.equal(pairs, 2);
  const l2 = sales.marketStats(svc.broker.db, svc.broker.marketId(M), svc.now()).get('2589');
  assert.equal(l2.sold, 40); assert.equal(l2.cancelled, 20);
  // nach 2 Tagen zu Tageswerten zusammengefasst: gleiche Summen, Einzelvergleiche weg
  svc.now = () => at(DAY + 3, 12);
  svc.broker.importGame();
  assert.equal(svc.broker.db.prepare('SELECT COUNT(*) AS n FROM sales_cmp').get().n, 0);
  const l3 = sales.marketStats(svc.broker.db, svc.broker.marketId(M), svc.now()).get('2589');
  assert.equal(l3.sold, 40); assert.equal(l3.cancelled, 20); assert.equal(l3.cmp, 2); assert.equal(l3.minutes, 60);
  svc.close();
});

test('Live-Abfragen mit Nummern nur ausserhalb von Scan-Paaren', () => {
  const { svc, push } = world();
  const t0 = at(DAY, 2);
  push({ kind: 'live', t: t0, key: '2770', commodity: true, rows: '2770;;;10;;100;;3;77;1\n2770;;;5;;120;;3;78;1' });
  push({ kind: 'live', t: t0 + 600, key: '2770', commodity: true, rows: '2770;;;6;;100;;3;77;1\n2770;;;5;;120;;3;78;1' });
  svc.broker.importGame();
  let s = sales.marketStats(svc.broker.db, svc.broker.marketId(M), svc.now()).get('2770');
  assert.equal(s.sold, 4); assert.equal(s.minutes, 10);
  // Scans, die diese Zeit abdecken: der Live-Vergleich kommt nicht dazu (kein doppeltes Zaehlen)
  push({ kind: 'scan', t: t0 - 300, rows: '2770;;;10;1000;;;3;;1' });
  push({ kind: 'scan', t: t0 + 900, rows: '2770;;;10;1000;;;3;;1' });
  svc.broker.importGame();
  const live = svc.broker.db.prepare("SELECT COUNT(*) AS n FROM sales_pair WHERE src = 'live'").get().n;
  assert.equal(live, 1, 'bereits gezaehlter Live-Vergleich bleibt, neue nur ohne Scan-Paar');
  svc.close();
});

test('Chancen (ab 0.35.0): Haendler, Marktuebersicht, Kandidaten fuer Broker in Data.lua', () => {
  const { svc, push, ad } = world();
  const t0 = at(DAY, 10);
  // Wiederverkauf ist abgeloest (KarloDerBaer 13.11.2026), Fallend und Lohnend stehen in der Marktuebersicht
  push({ kind: 'scan', t: t0, names: NAMES, rows: [
    '2589;;;20;10000;;;4;;3', '2589;;;20;12000;;;4;;1', '2589;;;20;20000;;;4;;5', '4306;;;5;1500;;;4;;1'].join('\n') });
  push({ kind: 'scan', t: t0 + 3 * 3600, rows: [
    '2589;;;20;10000;;;4;;1', '2589;;;20;12000;;;4;;1', '2589;;;20;20000;;;4;;5', '4306;;;5;1500;;;4;;1'].join('\n') });
  svc.broker.importGame();
  const c = svc.broker.chanceView(M);
  assert.ok(c && c.t === t0 + 3 * 3600, 'Stand des letzten Scans');
  assert.equal(c.list.filter((x) => x.kind === 's').length, 0, 'ohne belegte Verkaeufe keine Spekulation');
  const v = c.list.find((x) => x.key === '4306' && x.kind === 'v');
  assert.ok(v && v.qty === 5 && v.gain === 1000 && v.buy === 499 && v.target === 500, 'Seidenstoff 300 statt Haendler 500');
  assert.ok(v.say.includes('unter dem Händlerpreis') && v.checks.every((k) => k.ok), 'Satz und Pruefliste');
  const why = svc.broker.chanceItem(M, '2589');
  const s = why.checks.find((x) => x.kind === 's');
  assert.ok(s && !s.ok && s.say.startsWith('Kein Vorschlag, weil:') && s.say.includes('belegter Verkaufspreis'), 'Warum nicht: noch kein belegter Verkaufspreis');
  const mk = svc.broker.marketOverview(M);
  assert.ok(mk.down.length === 1 && mk.down[0].key === '4306', 'Fallend in der Marktuebersicht');
  assert.equal(mk.worth.find((x) => x.key === '2589'), undefined, 'Lohnend: nur zu 500 verkauft, weit unter dem Bereich');
  // Data.lua: Kandidatenliste fuer Broker (9.1)
  const d = parseLua(fs.readFileSync(path.join(ad, 'Data.lua'))).PeonBridgeData;
  const ch = d.markets[M].chances;
  assert.ok(ch && ch.list && /^v:499:500:\d+:1000:[012]:5$/.test(ch.list['4306'] || ch.list[4306]), 'Haendler als Kandidat mit Menge');
  assert.ok((ch.say['4306'] || ch.say[4306]).includes('Händlerpreis'), 'Satz fuer den Fokus');
  // Uebersteuerung: nie vorschlagen
  svc.broker.setOverride('4306', { never: true });
  const c2 = svc.broker.chanceView(M);
  assert.equal(c2.list.find((x) => x.key === '4306'), undefined, 'nie vorschlagen');
  assert.ok(svc.broker.chanceItem(M, '4306').checks.find((x) => x.kind === 'v').checks.some((k) => k.id === 'never' && k.user), 'in der Pruefliste: von dir geaendert');
  svc.broker.setOverride('4306', {});
  assert.ok(svc.broker.chanceView(M).list.find((x) => x.key === '4306'), 'zurueckgenommen');
  // D5: Vorschlaege mit allen Werten gespeichert, Rueckmeldung zugeordnet
  const db = svc.broker.db;
  assert.ok(db.prepare("SELECT COUNT(*) AS n FROM chance_log WHERE kind = 'v' AND shown = 1").get().n >= 1);
  const id = svc.broker.rateChance({ market: M, key: '4306', name: 'Seidenstoff', kind: 'v', up: true, reason: 'gekauft', note: 'x'.repeat(1200) });
  const r = svc.broker.chanceRatings().list.find((x) => x.id === id);
  assert.ok(r && r.log_id && r.note.length === 1000 && r.reason === 'gekauft', 'Rueckmeldung mit Vorschlag, Text gekuerzt');
  svc.close();
});

// Lua und Brokers Code aus dem Repo (tools/, addons/)
const REPO = path.join(__dirname, '..', '..');
const LUA = path.join(REPO, 'tools', process.platform === 'win32' ? 'lua5.1.exe' : 'lua5.1-linux');

test('Vergleich gleich wie Broker (Sales.lua, 3000 Zufallsfaelle)', { skip: !fs.existsSync(LUA) }, () => {
  const out = execFileSync('node', [path.join(__dirname, 'lua', 'gen.js'), LUA, path.join(REPO, 'addons', 'Peon_Broker')]).toString();
  assert.match(out, / 0 Abweichungen/);
});

test('0.5.0: Bereich je Tag, Absatz je Tag, Liste mit Bereich und Warenart, Protokolldatei', () => {
  const { svc, push } = world();
  const t0 = at(DAY, 10);
  push({ kind: 'scan', t: t0, names: NAMES, rows: ['2589;;;20;10000;;;4;;3', '2589;;;20;12000;;;4;;1'].join('\n') });
  push({ kind: 'scan', t: t0 + 3600, rows: ['2589;;;20;10000;;;4;;1', '2589;;;20;12000;;;4;;1'].join('\n') });
  svc.broker.importGame();
  const d = svc.broker.itemDetail(M, '2589', '30d');
  // Broker-Tage DAY-3..DAY-1, dazu heute: Bereich ab DAY-1 (3 Tage), heute mit 4 Tagen
  assert.deepEqual(d.bands.map((b) => b.day), [DAY - 1, DAY]);
  assert.ok(d.bands.every((b) => b.low < b.lang && b.high > b.lang && b.t > 0));
  assert.equal(d.salesDays.length, 1);
  assert.equal(Math.round(d.salesDays[0].perDay), 960);
  const it = svc.broker.itemList(M).items.find((x) => x.key === '2589');
  assert.ok(it.band && it.band.low > 0 && it.commodity === 1);
  const logs = fs.readdirSync(svc.broker.db.logDir);
  assert.ok(logs.length === 1 && /^\d{4}-\d{2}-\d{2}\.log$/.test(logs[0]));
  assert.match(fs.readFileSync(path.join(svc.broker.db.logDir, logs[0]), 'utf8'), /ok {4} spiel: 2 neue Momentaufnahmen/);
  // alte Protokolle werden beim Verdichten geloescht
  fs.writeFileSync(path.join(svc.broker.db.logDir, '2020-01-01.log'), 'alt');
  svc.broker.prune();
  assert.ok(!fs.existsSync(path.join(svc.broker.db.logDir, '2020-01-01.log')));
  svc.close();
});
