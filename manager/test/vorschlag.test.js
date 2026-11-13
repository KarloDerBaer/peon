'use strict';
// Tests fuer bessere Vorschlaege (Manager 0.21.0, KarloDerBaer 08.11.2026, Beispiel Magicusmantel):
// Kuerzung nach unten (F37a), neues Preisniveau (F54), Abstand zu den anderen Angeboten (F50a), Trefferquote (F55)
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const longterm = require('../src/core/longterm');
const { openDb } = require('../src/core/db');

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
