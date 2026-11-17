'use strict';
// Tests fuer die Stabilitaet der Preise (ab Manager 0.45.0, stability.js): node --test test/
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { sidOf } = require('./snap-helper');
const { openDb } = require('../src/core/db');
const st = require('../src/core/stability');
const { classOf } = require('../src/core/item-info');

const tmp = () => fs.mkdtempSync(path.join(os.tmpdir(), 'peon-st-'));
const NOW = 1794000000;

// Ein Stand je Stunde ueber `hours` Stunden bis NOW (art api), fn(h) -> { min, p25, auctions } je Gegenstand
function fillHours(db, hours, items) {
  const ins = db.prepare("INSERT INTO item_snap(sid, market_id, item_key, t, source, min, median, p25, qty, auctions) VALUES (?, 1, ?, ?, 'scan', ?, ?, ?, 10, ?)");
  for (let h = hours; h >= 1; h--) {
    const t = NOW - h * 3600;
    const sid = sidOf(db, `a${h}`, 1, t);
    for (const [key, fn] of Object.entries(items)) {
      const v = fn(h);
      if (v) ins.run(sid, key, t, v.min, v.min, v.p25 ?? v.min, v.auctions ?? 30);
    }
  }
}

function addItem(db, key, { commodity = null, cls = null, sub = null, name = null } = {}) {
  db.prepare('INSERT INTO items(key, item_id, name, commodity, cls, sub, cls_name, sub_name, updated) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0)')
    .run(key, Number(key), name || `Ding ${key}`, commodity, cls, sub, cls === 7 ? 'Handwerkswaren' : cls != null ? `Klasse ${cls}` : null, sub != null ? `Unter ${sub}` : null);
}

test('Index und Stufe: Grenzen liegen bei 80, 60, 40 und 20', () => {
  const L = st.HOUR_LIMITS;
  assert.equal(st.indexOf(0, L), 100);
  assert.equal(st.indexOf(0.01, L), 80);
  assert.equal(st.indexOf(0.03, L), 60);
  assert.equal(st.indexOf(0.06, L), 40);
  assert.equal(st.indexOf(0.10, L), 20);
  assert.equal(st.indexOf(0.20, L), 0);
  assert.equal(st.indexOf(1, L), 0);
  assert.equal(Math.round(st.indexOf(0.02, L)), 70);
  assert.equal(st.indexOf(null, L), null);
  assert.deepEqual([100, 80, 79.9, 60, 40, 20, 19, 0].map(st.levelOf), [0, 0, 1, 1, 2, 3, 4, 4]);
  // Tage: Mindestschwankung 5 % ist noch sehr stabil
  assert.ok(st.indexOf(0.05, st.DAY_LIMITS) > 80);
  assert.equal(st.indexOf(0.40, st.DAY_LIMITS), 20);
});

test('Gesamt: es zaehlt der schlechtere Teil', () => {
  const r = st.rate(0.004, { schw: 0.5 });
  assert.ok(r.ih > 80 && r.id < 20);
  assert.equal(r.idx, r.id);
  assert.equal(r.lv, 4);
  assert.equal(st.rate(0.02, null).idx, st.rate(0.02, null).ih);
  assert.equal(st.rate(null, { schw: 0.05 }).lv, 0);
});

test('Stunden: Bewegung ohne die groessten 5 %, Luecken zaehlen nicht', () => {
  const ts = [], ps = [];
  for (let i = 0; i < 100; i++) { ts.push(i * 3600); ps.push(i % 2 ? 102 : 100); }
  const h = st.hourPart(ts, ps);
  assert.ok(Math.abs(h - 0.02) < 0.001, String(h));
  // ein einzelner Ausreisser aendert fast nichts
  ps[50] = 1000;
  assert.ok(st.hourPart(ts, ps) < 0.025);
  // grosse Luecken: keine Paare, zu wenig Bewegungen
  assert.equal(st.hourPart(ts.map((t) => t * 3), ps), null);
});

test('Tage: Schwankung wie F36, Richtung vom ersten zum letzten Tag', () => {
  const days = new Map();
  [100, 100, 101, 99, 100, 50].forEach((v, i) => days.set(20000 + i, [v, v, v]));
  const d = st.dayPart(days);
  assert.equal(d.days, 6);
  assert.equal(d.schw, 0.05);   // Median-Abweichung klein, Mindestwert
  assert.equal(d.dir, -0.5);
  assert.equal(d.span, 5);
  // Tage mit weniger als 3 Preisen zaehlen nicht, unter 5 Tagen kein Ergebnis
  days.set(20003, [99]);
  days.delete(20004);
  assert.equal(st.dayPart(days), null);
});

test('Markt: Massenware mit p25, Einzel mit min, Kategorien und Gruppen', () => {
  const db = openDb(tmp());
  db.prepare("INSERT INTO markets(id, key) VALUES (1, 'Test / Alliance')").run();
  addItem(db, '2589', { commodity: 1, cls: 7, sub: 5 });   // ruhig, nur das guenstigste Angebot springt
  addItem(db, '2592', { commodity: 1, cls: 7, sub: 5 });   // unruhig
  addItem(db, '9999', { commodity: 0, cls: 4, sub: 1 });   // Einzel, ruhig
  addItem(db, '8888', { commodity: 0, cls: 4, sub: 1 });   // Einzel, wenig Angebote
  addItem(db, '7777', { cls: 0, sub: 0 });                 // Warenart unbekannt, stapelbar
  addItem(db, '6666', { commodity: 1, cls: 7, sub: 5 });   // Massenware, wenig Angebote
  db.prepare('UPDATE items SET stack = 1 WHERE key = ?').run('7777');
  fillHours(db, 7 * 24 - 1, {
    2589: (h) => ({ min: h % 2 ? 50 : 100, p25: 100 }),
    2592: (h) => ({ min: 100, p25: h % 2 ? 110 : 100 }),
    9999: (h) => ({ min: h % 2 ? 1000 : 1005, auctions: 25 }),
    8888: (h) => ({ min: 500, auctions: 4 }),
    7777: (h) => ({ min: 20, p25: 30 }),
    6666: (h) => ({ min: 20, p25: h % 2 ? 20 : 40, auctions: 5 }),
  });
  const out = {};
  for (const _ of st.marketSteps(db, 1, NOW, out)) { /* Schritte */ }
  const v = out.value;
  const it = (k) => st.unpack(v.items[k]);
  assert.equal(v.apiStands, 7 * 24 - 1);
  assert.ok(it('2589').h < 0.001, 'Massenware mit p25 ruhig');
  assert.equal(it('2589').g, 0);
  assert.ok(it('2592').h > 0.09, 'Massenware unruhig');
  assert.ok(it('2592').g >= 3);
  assert.ok(it('9999').h < 0.01 && it('9999').f === 0);
  assert.equal(it('8888').f, 1, 'wenig Angebote');
  assert.equal(it('6666').f, 1, 'auch Massenware mit wenig Angeboten zaehlt nicht');
  assert.equal(it('7777').m, 1, 'stapelbar gilt als Massenware');
  assert.ok(it('2589').days >= 5 && it('2589').d === 0.05);
  // Gruppen ohne Gegenstaende mit wenig Angeboten
  assert.equal(v.groups.all.n, 4);
  assert.equal(v.groups.mass.n, 3);
  assert.equal(v.groups.craft.n, 2);
  assert.equal(v.groups.single.n, 1);
  assert.equal(v.groups.all.per.reduce((a, b) => a + b, 0), 4);
  const c7 = v.cats.find((c) => c.key === 'c7');
  assert.equal(c7.name, 'Handwerkswaren');
  assert.equal(c7.n, 2);
  const c7s = v.cats.find((c) => c.key === 'c7/s5');
  assert.equal(c7s.parent, 'c7');
  assert.ok(v.cats.indexOf(c7s) === v.cats.indexOf(c7) + 1, 'Unterklasse direkt unter der Klasse');
  // Verlauf
  const hist = st.addHistory(st.addHistory([], { ...v, t: NOW - 3600 }), v);
  assert.equal(hist.length, 2);
  assert.equal(hist[1].craft.n, 2);
  assert.equal(st.addHistory([{ t: NOW - 40 * 86400 }], v).length, 1, 'alte Eintraege fallen weg');
  db.close();
});

test('Markt ohne API-Staende: nur die Tage, aeltere Tage aus 3-Stunden-Werten', () => {
  const db = openDb(tmp());
  db.prepare("INSERT INTO markets(id, key) VALUES (1, 'Test / Alliance')").run();
  addItem(db, '2589', { commodity: 1 });
  const ins = db.prepare("INSERT INTO item_hour(market_id, hour, item_key, source, t, min, median, p25, qty, auctions, n) VALUES (1, ?, '2589', 'scan', ?, 100, 100, ?, 10, 10, 1)");
  for (let d = 12; d >= 1; d--) for (let s = 0; s < 4; s++) {
    const t = NOW - d * 86400 + s * 3 * 3600;
    ins.run(Math.floor(t / 3600), t, d % 2 ? 100 : 160);
  }
  const out = {};
  for (const _ of st.marketSteps(db, 1, NOW, out)) { /* Schritte */ }
  const x = st.unpack(out.value.items['2589']);
  assert.equal(x.h, null);
  assert.ok(x.days >= 10);
  assert.ok(x.d > 0.25, String(x.d));
  assert.ok(x.g >= 2);
  db.close();
});

test('classOf: Klasse, Unterklasse und Stapelbarkeit aus der Blizzard-API', () => {
  assert.deepEqual(classOf({ item_class: { id: 7, name: 'Handwerkswaren' }, item_subclass: { id: 5, name: 'Stoff' }, is_stackable: true }),
    { cls: 7, sub: 5, clsName: 'Handwerkswaren', subName: 'Stoff', stack: 1 });
  assert.equal(classOf({ name: 'x' }), null);
  assert.equal(classOf(null), null);
  assert.equal(classOf({ item_class: { id: 2 }, is_stackable: false }).stack, 0);
});

test('Pack und Unpack', () => {
  const x = { h: 0.0123456, d: 0.05, i: 70, g: 1, ih: 70, id: 88, dir: -0.123456, days: 9, span: 8, a: 12.5, m: 1, f: 0, c: 7, s: 5 };
  const y = st.unpack(st.pack(x));
  assert.equal(y.h, 0.0123);
  assert.equal(y.dir, -0.1235);
  assert.equal(y.c, 7);
  assert.equal(st.unpack(undefined), null);
});

test('Manager: Rechnung im Hintergrund, Seite, Gegenstand, Liste und Lese-Prozess', async () => {
  const { Service } = require('../src/core/service');
  const { BrokerClient } = require('../src/core/broker-client');
  const { toLua } = require('../src/core/lua');
  const wow = tmp();
  const sv = path.join(wow, 'WTF', 'Account', '1#1', 'SavedVariables');
  fs.mkdirSync(sv, { recursive: true });
  fs.mkdirSync(path.join(wow, 'Interface', 'AddOns', 'Peon_Bridge'), { recursive: true });
  fs.writeFileSync(path.join(wow, 'Interface', 'AddOns', 'Peon_Bridge', 'Peon_Bridge.toc'), 'x');
  const M = 'Test / Alliance';
  const svc = new Service({ enable: ['broker-client'], dbDir: tmp(), now: () => NOW });
  svc.saveSettings({ wowDir: wow });
  fs.writeFileSync(path.join(sv, 'Peon_Bridge.lua'), 'PeonBridgeDB = ' + toLua({ fmt: 1, queue: [
    { id: 'x1', market: M, kind: 'scan', t: NOW - 7200, names: { 2589: 'Leinenstoff|1|10|1', 2592: 'Wollstoff|1|30|1' }, rows: '2589;;;20;2000;;;4;;3\n2592;;;20;4000;;;4;;3' }] }));
  svc.broker.importGame();
  const db = svc.broker.db;
  const mid = db.prepare('SELECT id FROM markets WHERE key = ?').get(M).id;
  assert.equal(mid, 1);
  db.prepare("UPDATE items SET cls = 7, sub = 5, cls_name = 'Handwerkswaren', sub_name = 'Stoff' WHERE key IN ('2589', '2592')").run();
  fillHours(db, 7 * 24 - 3, {
    2589: (h) => ({ min: 100, p25: 100 }),
    2592: (h) => ({ min: 200, p25: h % 2 ? 230 : 200 }),
  });
  const r = await svc.broker.stabilityInBackground();
  assert.ok(r.stability >= 2, JSON.stringify(r));
  // gleicher Stand: keine neue Rechnung
  assert.equal((await svc.broker.stabilityInBackground()).stability, undefined);
  const v = svc.broker.stabilityView(M);
  assert.equal(v.groups.craft.n, 2);
  const lein = v.items.find((x) => x.key === '2589');
  assert.equal(lein.name, 'Leinenstoff');
  assert.equal(lein.g, 0);
  assert.equal(v.hist.length, 1);
  const d = svc.broker.itemDetail(M, '2592', '7d');
  assert.ok(d.stability && d.stability.g >= 3, JSON.stringify(d.stability));
  assert.equal(d.stability.cat.name, 'Handwerkswaren');
  assert.equal(d.stability.sub.name, 'Stoff');
  const list = svc.broker.itemList(M);
  assert.equal(list.items.find((x) => x.key === '2589').stab.g, 0);
  // Lese-Prozess liest dasselbe aus calc_cache
  const rd = new BrokerClient(Object.assign(Object.create(svc), { readOnly: true }));
  try {
    assert.deepEqual(JSON.parse(JSON.stringify(rd.stabilityView(M))), JSON.parse(JSON.stringify(v)));
    assert.equal(await rd.stabilityInBackground(), null, 'der Lese-Prozess rechnet nicht');
  } finally { rd.close(); }
  assert.deepEqual(svc.broker.stabilityView('Gibt es nicht'), null);
  svc.close();
});
