'use strict';
// Tests fuer bessere Vorschlaege (Manager 0.21.0, KarloDerBaer 08.11.2026, Beispiel Magicusmantel):
// Kuerzung nach unten (F37a), neues Preisniveau (F54), Abstand zu den anderen Angeboten (F50a), Trefferquote (F55)
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const longterm = require('../src/core/longterm');
const chances = require('../src/core/chances');
const { parseRows } = require('../src/core/stats');
const { openDb } = require('../src/core/db');
const { dayOf } = require('../src/core/broker');

const G = 10000;
const NOW = 1794000000;

test('F37a: Preissturz bei wenigen gleichen Tagen wird nicht mehr abgeschnitten', () => {
  // Magicusmantel: 4g, 4g, heute 1g 50s. Bisher Kuerzung auf 3g 40s (5 % Schwankung), LANG etwa 3g 75s
  const r = longterm.compute(new Map([[100, { value: 4 * G }], [101, { value: 4 * G }], [102, { value: 1.5 * G }]]), 102);
  const w = [0.5 ** (2 / 3), 0.5 ** (1 / 3), 1];
  const want = (4 * G * w[0] + 4 * G * w[1] + 1.5 * G) / (w[0] + w[1] + w[2]);
  assert.ok(Math.abs(r.lang - want) < 1e-6, 'heutiger Tag zaehlt voll');
  assert.ok(r.lang < 3 * G);
  // Ausreisser nach oben weiter gekuerzt, nach unten erst unter 25 % der Mitte
  const up = longterm.compute(new Map([[1, { value: 100 }], [2, { value: 100 }], [3, { value: 100 }], [4, { value: 100000 }]]), 4);
  assert.ok(up.lang <= 115);
  const down = longterm.compute(new Map([[1, { value: 1000 }], [2, { value: 1000 }], [3, { value: 1000 }], [4, { value: 1 }]]), 4);
  const wd = [0.5, 0.5 ** (2 / 3), 0.5 ** (1 / 3), 1];
  assert.ok(Math.abs(down.lang - (1000 * (wd[0] + wd[1] + wd[2]) + 250) / (wd[0] + wd[1] + wd[2] + wd[3])) < 1e-6, 'unten bei 25 % der Mitte gekuerzt');
});

test('F50a: Wiederverkauf hoechstens zum Median der Angebote', () => {
  const bands = new Map([['12998', { lang: 4 * G, schw: 0.05 }]]);
  // alle Angebote gleich tief (Magicusmantel 07.11.): kein Wiederverkauf
  const flat = parseRows(['12998;;;1;12000;;;4;;6', '12998;;;1;12400;;;4;;4', '12998;;;1;13000;;;4;;2'].join('\n'));
  assert.equal(chances.scanOpp(flat, bands, new Map()).filter((x) => x.kind === 'r').length, 0);
  // eines tief, die anderen im Bereich: Wiederverkauf zur Untergrenze
  const deal = parseRows(['12998;;;1;12000;;;4;;1', '12998;;;1;39000;;;4;;5'].join('\n'));
  const r = chances.scanOpp(deal, bands, new Map()).find((x) => x.kind === 'r');
  assert.ok(r && r.qty === 1 && r.ref === 4 * G * 0.95);
  // neues Preisniveau nach unten: kein Wiederverkauf
  const sh = new Map([['12998', { dir: 'down', level: 12000 }]]);
  assert.equal(chances.scanOpp(deal, bands, new Map(), sh).filter((x) => x.kind === 'r').length, 0);
});

function db() {
  return openDb(fs.mkdtempSync(path.join(os.tmpdir(), 'peon-')));
}
function snap(d, key, t, min, median) {
  d.prepare("INSERT INTO item_snap(snapshot_id, market_id, item_key, t, source, min, median, qty, auctions) VALUES (?, 1, ?, ?, 'scan', ?, ?, 5, 5)")
    .run(`s${t}-${key}`, key, t, min, median);
}

test('F54: neues Preisniveau, alle Staende der letzten 12 Std. unter dem Bereich (ab 0.22.0)', () => {
  const d = db();
  const bands = new Map([['a', { lang: 4 * G, schw: 0.05 }], ['b', { lang: 4 * G, schw: 0.05 }], ['c', { lang: 4 * G, schw: 0.05 }]]);
  for (const h of [11, 8, 4, 2]) snap(d, 'a', NOW - h * 3600, 12000, 12400);
  // b: einer im Bereich, c: nur 4 Std. lang beobachtet
  for (const h of [11, 8, 5]) snap(d, 'b', NOW - h * 3600, 12000, 12400);
  snap(d, 'b', NOW - 3600, 39000, 40000);
  for (const h of [5, 3, 1]) snap(d, 'c', NOW - h * 3600, 12000, 12400);
  // aelter als 12 Std. zaehlt nicht (Robuster Stein: vor 23 Std. noch im Bereich)
  snap(d, 'a', NOW - 23 * 3600, 40000, 40000);
  const s = longterm.shifts(d, 1, NOW, bands);
  assert.deepEqual([...s.keys()], ['a']);
  assert.equal(s.get('a').dir, 'down');
  assert.equal(s.get('a').level, 12400);
  assert.equal(s.get('a').n, 4);
  assert.equal(longterm.shifts(d, 1, NOW, bands, 'a').size, 1);
  assert.equal(longterm.shifts(d, 1, NOW, bands, 'b').size, 0);
  d.close();
});

test('F55: Trefferquote der Wiederverkaufs-Vorschlaege', () => {
  const d = db();
  const opp = (key, t, buy, ref) => d.prepare("INSERT INTO opp_snap(snapshot_id, market_id, item_key, t, kind, qty, profit, cost, ref) VALUES (?, 1, ?, ?, 'r', 2, 1, ?, ?)")
    .run(`o${t}-${key}`, key, t, buy * 2, ref);
  const t0 = NOW - 5 * 86400;
  // a: zwei Treffer am selben Tag zaehlen einmal, Median steigt bis zum Ziel
  opp('a', t0, 1000, 2000); opp('a', t0 + 60, 1000, 2000);
  snap(d, 'a', t0 + 86400, 900, 2100);
  // b: Median steigt nur ueber Kaufpreis plus Gebuehr
  opp('b', t0, 1000, 2000);
  snap(d, 'b', t0 + 86400, 900, 1200);
  // c: Median bleibt tief
  opp('c', t0, 1000, 2000);
  snap(d, 'c', t0 + 86400, 900, 1000);
  // e: danach kein Stand, nicht bewertbar; f: juenger als 3 Tage, noch offen
  opp('e', t0, 1000, 2000);
  opp('f', NOW - 86400, 1000, 2000);
  snap(d, 'f', NOW - 3600, 2000, 3000);
  // a: Stand nach den 3 Tagen zaehlt nicht
  snap(d, 'c', t0 + 4 * 86400, 3000, 3000);
  const r = chances.hitRate(d, 1, NOW);
  assert.deepEqual({ n: r.n, hit: r.hit, even: r.even, miss: r.miss, hold: r.hold }, { n: 3, hit: 1, even: 1, miss: 1, hold: 3 });
  assert.ok(dayOf(t0) === dayOf(t0 + 60));
  d.close();
});

test('0.21.1: neue Regeln verwerfen alte Wiederverkaufs-Treffer, letzter Scan wird neu ausgewertet', () => {
  const d = db();
  const opp = (id, t, kind) => d.prepare('INSERT INTO opp_snap(snapshot_id, market_id, item_key, t, kind, qty, profit, cost, ref) VALUES (?, 1, ?, ?, ?, 1, 1, 1, 2)').run(id, 'a', t, kind);
  const scan = (id, t) => d.prepare('INSERT INTO opp_scan(snapshot_id, market_id, t, vendor_n) VALUES (?, 1, ?, 0)').run(id, t);
  opp('alt', NOW - 7200, 'r'); opp('alt', NOW - 7200, 'v'); scan('alt', NOW - 7200);
  opp('neu', NOW - 60, 'r'); opp('neu', NOW - 60, 'v'); scan('neu', NOW - 60);
  assert.equal(chances.resetRules(d, null), true);
  assert.deepEqual(d.prepare('SELECT snapshot_id, kind FROM opp_snap').all().map((x) => x.snapshot_id + x.kind), ['altv']);
  assert.deepEqual(d.prepare('SELECT snapshot_id FROM opp_scan').all().map((x) => x.snapshot_id), ['alt']);
  assert.equal(chances.resetRules(d, chances.RULES), false);
  d.close();
});

test('Satz auf der Gegenstandsseite: kein Schnaeppchen, wenn alle Angebote gleich tief liegen', async () => {
  const { verdict } = await import('../src/renderer/util.js');
  const lt = { lang: 4 * G, schw: 0.05 };
  const base = { longterm: lt, sales: { perDay: 11 } };
  // Magicusmantel 07.11.: Min 1g 20s, Median 1g 24s, 12 Stueck
  const v1 = verdict({ ...base, current: { qty: 12, min: 12000, median: 12400 } });
  assert.equal(v1.tone, '');
  assert.match(v1.text, /70 % unter dem üblichen Preis, die anderen Angebote aber auch/);
  // eines tief, die anderen hoch: Schnaeppchen
  const v2 = verdict({ ...base, current: { qty: 12, min: 12000, median: 39000 } });
  assert.equal(v2.tone, 'good');
  // neues Preisniveau: Vergleich mit den letzten 24 Std.
  const v3 = verdict({ ...base, shift: { dir: 'down', level: 12400 }, current: { qty: 12, min: 12000, median: 12400 } });
  assert.match(v3.text, /^Der Preis ist gefallen: .*\. Das günstigste Angebot (entspricht|liegt \d+ % unter) dem Preis der letzten 12 Std\./);
  assert.equal(v3.tone, '');
});

test('F50b: kein Wiederverkauf, wenn unter dem Ziel mehr als ein Tagesabsatz liegt (Robuster Stein)', () => {
  const bands = new Map([['7912', { lang: 900, schw: 0.05 }]]);
  // ein Angebot tief, die anderen im Bereich
  const rows = parseRows(['7912;;;20;6000;;;4;;10', '7912;;;20;18000;;;4;;10'].join('\n'));
  const deal = (s) => chances.scanOpp(rows, bands, new Map(), null, new Map([['7912', s]])).find((x) => x.kind === 'r');
  // 200 Stueck unter dem Ziel, verkauft werden 210 am Tag: Chance
  assert.ok(deal({ perDay: 210, level: 3 }));
  // nur 50 am Tag: man muesste den Markt leer kaufen
  assert.equal(deal({ perDay: 50, level: 3 }), undefined);
  // Absatz noch unsicher (Stufe 1) oder unbekannt: nicht geprueft
  assert.ok(deal({ perDay: 50, level: 1 }));
  assert.ok(chances.scanOpp(rows, bands, new Map()).find((x) => x.kind === 'r'));
});

test('F50c: kein Wiederverkauf bei Schwankung ueber 40 % (Umhang des Huegelwaechters)', () => {
  const rows = parseRows(['3719;;;1;1700;;;4;;1', '3719;;;1;9000;;;4;;5'].join('\n'));
  const r = (schw) => chances.scanOpp(rows, new Map([['3719', { lang: 5300, schw }]]), new Map()).filter((x) => x.kind === 'r').length;
  assert.equal(r(0.3), 1);
  assert.equal(r(0.8), 0);
});

test('Chancen-Tabelle nur aus dem letzten Scan, Zeitraum zaehlt nur die Haeufigkeit (0.22.0)', () => {
  const d = db();
  const opp = (id, t, key, qty, cost) => d.prepare("INSERT INTO opp_snap(snapshot_id, market_id, item_key, t, kind, qty, profit, cost, ref) VALUES (?, 1, ?, ?, 'r', ?, ?, ?, 2000)")
    .run(id, key, t, qty, qty * 500, cost);
  const scan = (id, t) => d.prepare('INSERT INTO opp_scan(snapshot_id, market_id, t, vendor_n) VALUES (?, 1, ?, 0)').run(id, t);
  scan('s1', NOW - 7200); scan('s2', NOW - 60);
  opp('s1', NOW - 7200, 'alt', 10, 10000);   // nur frueher eine Chance: nicht in der Liste
  opp('s1', NOW - 7200, 'a', 4, 8000);       // frueher teurer
  opp('s2', NOW - 60, 'a', 2, 2000);
  const r = chances.summarizeOpp(d, 1, 'r', 7, NOW, new Map(), 's2');
  assert.deepEqual(r.list.map((x) => x.key), ['a']);
  const a = r.list[0];
  assert.equal(a.buy, 1000, 'Preis aus dem letzten Scan, nicht das Mittel');
  assert.equal(a.qty, 2);
  assert.equal(a.hits, 2);
  assert.equal(a.share, 1);
  assert.deepEqual(a.now, { qty: 2, profit: 1000, price: 1000 });
  d.close();
});

test('Satz auf der Gegenstandsseite: Marktpreis bei viel Ware unter dem Bereich, unsicherer Bereich', async () => {
  const { verdict } = await import('../src/renderer/util.js');
  // Robuster Stein: 1.680 Stueck unter dem Bereich, 210 am Tag verkauft
  const v1 = verdict({ longterm: { lang: 928, schw: 0.1 }, sales: { perDay: 210, level: 3 }, depth: { below: 1680 },
    current: { qty: 1680, min: 298, median: 320 } });
  assert.equal(v1.tone, '');
  assert.match(v1.text, /^Das ist der Marktpreis: Unter dem üblichen Bereich liegen 1\.680 Stück, so viel wie in 8 Tagen verkauft wird\./);
  // wenig darunter: weiter Schnaeppchen
  const v2 = verdict({ longterm: { lang: 928, schw: 0.1 }, sales: { perDay: 210, level: 3 }, depth: { below: 20 },
    current: { qty: 200, min: 298, median: 900 } });
  assert.equal(v2.tone, 'good');
  // Umhang: Bereich 10s bis 95s
  const v3 = verdict({ longterm: { lang: 5300, schw: 0.8 }, sales: { perDay: 187, level: 3 }, current: { qty: 47, min: 1700, median: 1700 } });
  assert.equal(v3.tone, '');
  assert.match(v3.text, /^Der Preis schwankt stark/);
});
