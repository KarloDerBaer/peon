'use strict';
// Manager 0.30.0, Broker 0.89.0, Angleichung A2 (docs/konzepte/manager/Peon_Manager_Angleichung.md 3.2 bis 3.4):
// Abgleich je Wert fuer Einkaufslisten und Beobachtung, Grenzen der Beobachtung, Loeschmarken ein Jahr.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { execFileSync } = require('node:child_process');
const shopping = require('../src/core/shopping');
const watching = require('../src/core/watching');
const { Service } = require('../src/core/service');
const { parseLua, toLua } = require('../src/core/lua');

process.removeAllListeners('warning');
const REPO = path.join(__dirname, '..', '..');
const LUA = path.join(REPO, 'tools', process.platform === 'win32' ? 'lua5.1.exe' : 'lua5.1-linux');
const NOW = 1794000000;
function tmp() { return fs.mkdtempSync(path.join(os.tmpdir(), 'peon-w-')); }

test('Einkaufsliste: verschiedene Werte an beiden Stellen geaendert, beide bleiben', () => {
  const d = shopping.empty();
  const l = shopping.newList(d, 'Erze', 100);
  shopping.addItem(d, l.id, '2770', {}, 100);
  shopping.setItem(d, l.id, '2770', { wish: 20, max: 500 }, 110);
  // Manager aendert die Menge, das Spiel unabhaengig davon den Hoechstpreis
  shopping.setItem(d, l.id, '2770', { wish: 40 }, 200);
  const fromGame = { lists: [{ id: l.id, name: 'Erze', pct: 10, u: 150, t: { name: 100, pct: 100 }, items: { 2770: { wish: 20, max: 900, u: 210, t: { wish: 110, max: 210 } } } }] };
  assert.equal(shopping.merge(d, fromGame), true);
  const it = d.lists[0].items[2770];
  assert.deepEqual([it.wish, it.max], [40, 900], 'Menge aus dem Manager, Hoechstpreis aus dem Spiel');
  assert.deepEqual([it.t.wish, it.t.max, it.u], [200, 210, 210]);
  // Derselbe Wert an beiden Stellen: der neuere gewinnt
  shopping.setItem(d, l.id, '2770', { max: 700 }, 300);
  const head = { id: l.id, name: 'Erze', pct: 10, u: 150, t: { name: 100, pct: 100 } };
  assert.equal(shopping.merge(d, { lists: [{ ...head, items: { 2770: { wish: 40, max: 800, u: 290, t: { wish: 200, max: 290 } } } }] }), false);
  assert.equal(d.lists[0].items[2770].max, 700);
  // Geleerter Wert ist auch eine Aenderung
  assert.equal(shopping.merge(d, { lists: [{ ...head, items: { 2770: { wish: 40, u: 400, t: { wish: 200, max: 400 } } } }] }), true);
  assert.equal(d.lists[0].items[2770].max, undefined);
  assert.equal(d.lists[0].items[2770].wish, 40, 'Menge ohne neuere Zeit bleibt');
  // Name und Rabatt einer Liste getrennt
  shopping.updateList(d, l.id, { name: 'Erze neu' }, 500);
  shopping.merge(d, { lists: [{ id: l.id, name: 'Alt', pct: 30, u: 510, t: { name: 100, pct: 510 }, items: {} }] });
  assert.deepEqual([d.lists[0].name, d.lists[0].pct], ['Erze neu', 30]);
});

test('Einkaufsliste: Daten ohne Zeiten je Wert verhalten sich wie bisher, u steigt nicht falsch mit', () => {
  const d = shopping.clean({ lists: [{ id: 'g1_1', name: 'A', pct: 10, u: 100, items: { 2770: { wish: 5, max: 70, u: 100 } } }] });
  // Neuere Menge mit eigener Zeit, Hoechstpreis aelter als 100
  shopping.merge(d, { lists: [{ id: 'g1_1', u: 100, items: { 2770: { wish: 9, max: 1, u: 200, t: { wish: 200, max: 50 } } } }] });
  const it = d.lists[0].items[2770];
  assert.deepEqual([it.wish, it.max, it.t.max, it.u], [9, 70, 100, 200], 'der alte Hoechstpreis behaelt seine Zeit 100, nicht 200');
  // Spaeter ein Hoechstpreis von 150: neuer als 100, gilt
  shopping.merge(d, { lists: [{ id: 'g1_1', u: 100, items: { 2770: { max: 3, u: 150, t: { max: 150 } } } }] });
  assert.equal(d.lists[0].items[2770].max, 3);
  // Anzeige wird ergaenzt, nicht ersetzt
  shopping.merge(d, { lists: [{ id: 'g1_1', u: 100, items: { 2770: { u: 1, name: 'Kupfererz', q: 1 } } }] });
  assert.equal(d.lists[0].items[2770].name, 'Kupfererz');
  shopping.merge(d, { lists: [{ id: 'g1_1', u: 100, items: { 2770: { u: 1, name: 'Anders' } } }] });
  assert.equal(d.lists[0].items[2770].name, 'Kupfererz');
});

test('Loeschmarken halten ein Jahr', () => {
  const d = shopping.empty();
  d.gone.items['g1_1|2770'] = NOW;
  assert.equal(shopping.purge(d, NOW + 300 * 86400), false);
  assert.equal(shopping.purge(d, NOW + 366 * 86400), true);
  const w = watching.clean({ items: {}, gone: { 2770: NOW } });
  assert.equal(watching.purge(w, NOW + 300 * 86400), false);
  assert.equal(watching.purge(w, NOW + 366 * 86400), true);
});

test('Beobachtung: Kaufen bis und Zielpreis je Wert, Zahl von frueher gilt nur als Anwesenheit', () => {
  const d = watching.clean({ items: { 2770: 100 }, gone: {} });
  assert.deepEqual(d.items['2770'], { u: 100, t: { buy: 0, up: 0 } }, 'ab 0.34.0: Werte unbekannt, Zeit 0');
  watching.setBuy(d, '2770', 'abs', 1500, 200);
  // Spiel setzt den Zielpreis, kennt das neue Kaufen bis noch nicht
  assert.equal(watching.merge(d, { items: { 2770: { u: 210, pct: 20, up: 4000, t: { buy: 150, up: 210 } } } }), true);
  const w = d.items['2770'];
  assert.deepEqual([w.lim, w.pct, w.up, w.t.buy, w.t.up], [1500, undefined, 4000, 200, 210]);
  // Kaufen bis wechselt im Spiel auf %, neuer: der Betrag faellt weg
  watching.merge(d, { items: { 2770: { u: 300, pct: 10, t: { buy: 300, up: 210 }, up: 4000 } } });
  assert.deepEqual([d.items['2770'].lim, d.items['2770'].pct], [undefined, 10]);
  // Ein alter Manager oder Broker schickt nur eine Zahl: Grenzen bleiben
  assert.equal(watching.merge(d, { items: { 2770: 999 } }), true);
  assert.deepEqual([d.items['2770'].u, d.items['2770'].pct, d.items['2770'].up], [999, 10, 4000]);
  // Zielpreis leeren
  watching.setUp(d, '2770', null, 1000);
  assert.equal(d.items['2770'].up, undefined);
  assert.equal(d.items['2770'].t.up, 1000);
  // Fuer Data.lua ohne Merker
  const g = watching.forGame(d);
  assert.equal(g.items['2770'].m, undefined);
  assert.equal(g.items['2770'].pct, 10);
});

test('Beobachtung: gleiches Ergebnis wie Broker (Watch.lua, 3000 Zufallsfaelle)', { skip: !fs.existsSync(LUA) }, () => {
  let seed = 23;
  const rnd = (n) => { seed = (seed * 16807) % 2147483647; return seed % n; };
  const KEYS = ['2770', '2589', '15000:Name des Wolfs'];
  const side = (asNumbers) => {
    const items = {}, gone = {};
    for (const k of KEYS) {
      if (rnd(2)) {
        const u = 100 + rnd(6);
        if (asNumbers && rnd(4) === 0) { items[k] = u; continue; }
        const w = { u };
        const kind = rnd(3);
        if (kind === 1) w.lim = 100 * (1 + rnd(9)); else if (kind === 2) w.pct = 10 * rnd(4);
        if (rnd(2)) w.up = 1000 * (1 + rnd(5));
        if (rnd(3) === 0) w.name = `N${rnd(3)}`;
        if (rnd(3)) { w.t = {}; if (rnd(3)) w.t.buy = u - rnd(4); if (rnd(3)) w.t.up = u - rnd(4); }
        items[k] = w;
      }
      if (rnd(4) === 0) gone[k] = 100 + rnd(6);
    }
    return { items, gone };
  };
  const cases = Array.from({ length: 3000 }, () => ({ a: side(false), b: side(true) }));
  const file = path.join(tmp(), 'cases.lua');
  fs.writeFileSync(file, `CASES = ${toLua(cases)}\n`);
  const out = execFileSync(LUA, [path.join(__dirname, 'lua', 'watch_compare.lua'), path.join(REPO, 'addons', 'Peon_Broker'), file]).toString().trim().split(/\r?\n/);
  const v = (x) => (x == null ? '-' : String(x));
  const sorted = (o) => Object.keys(o).sort((x, y) => (x < y ? -1 : x > y ? 1 : 0));
  let bad = 0;
  cases.forEach((c, i) => {
    const d = watching.clean(JSON.parse(JSON.stringify(c.a)));
    watching.merge(d, c.b);
    const parts = sorted(d.items).map((k) => { const w = d.items[k]; const t = w.t || {}; return `${k}:${v(w.u)}:${v(w.lim)}:${v(w.pct)}:${v(w.up)}:${v(t.buy)}:${v(t.up)}:${v(w.name)}`; });
    const g = sorted(d.gone).map((k) => `${k}=${v(d.gone[k])}`);
    const js = `${parts.join(';')}#${g.join(';')}`;
    if (js !== out[i]) { if (bad < 3) console.log('ABWEICHUNG', i, '\nJS ', js, '\nLua', out[i], '\n', JSON.stringify(c)); bad++; }
  });
  assert.equal(bad, 0);
});

test('Weg ins Spiel und zurueck: Grenzen der Beobachtung je Konto in Data.lua und aus Peon_Broker.lua', () => {
  const dir = tmp(), wow = tmp();
  const ad = path.join(wow, 'Interface', 'AddOns', 'Peon_Bridge');
  fs.mkdirSync(ad, { recursive: true });
  fs.writeFileSync(path.join(ad, 'Peon_Bridge.toc'), 'x');
  const sv = path.join(wow, 'WTF', 'Account', 'KONTOA', 'SavedVariables');
  fs.mkdirSync(sv, { recursive: true });
  const clock = { t: NOW };
  const svc = new Service({ enable: ['broker-client'], dbDir: dir, version: '0.30.0', now: () => clock.t });
  svc.saveSettings({ wowDir: wow });
  const b = svc.broker;
  const write = (db, mt) => { const f = path.join(sv, 'Peon_Broker.lua'); fs.writeFileSync(f, `PeonBrokerDB = ${toLua({ markets: {}, acct: 'kA_1', ...db })}`); fs.utimesSync(f, mt, mt); };
  write({ watch: { 2770: { u: NOW - 50, name: 'Kupfererz', lim: 1200, up: 5000, hit: true, t: { buy: NOW - 60, up: NOW - 50 } } } }, NOW - 40);
  b.importGame();
  let w = b.watchDoc().items['2770'];
  assert.deepEqual([w.lim, w.up, w.name, w.hit], [1200, 5000, 'Kupfererz', undefined], 'Grenzen kommen an, Merker des Alarms nicht');
  // im Manager Kaufen bis auf 15 %
  clock.t = NOW + 10;
  assert.equal(b.setWatchBuy('2770', 'pct', 15), true);
  const data = parseLua(fs.readFileSync(path.join(ad, 'Data.lua'))).PeonBridgeData;
  const g = data.accts.kA_1.watch.items[2770] || data.accts.kA_1.watch.items['2770'];
  assert.deepEqual([g.pct, g.lim, g.up, g.t.buy], [15, undefined, 5000, NOW + 10]);
  // im Spiel inzwischen der Zielpreis geaendert (vor dem Laden der Aenderung aus dem Manager)
  write({ watch: { 2770: { u: NOW + 20, lim: 1200, up: 6000, t: { buy: NOW - 60, up: NOW + 20 } } } }, NOW + 25);
  clock.t = NOW + 30;
  b.importGame();
  w = b.watchDoc().items['2770'];
  assert.deepEqual([w.pct, w.lim, w.up], [15, undefined, 6000], 'beide Aenderungen bleiben');
  svc.close();
});
