'use strict';
// Tests fuer den Reiter Aufkauf im Radar (Manager 0.26.0, Neuaufbau H5, gleiche Regel wie Broker Buyout.lua): node --test test/
const test = require('node:test');
const assert = require('node:assert/strict');
const chances = require('../src/core/chances');

// Zeilen wie aus einer Momentaufnahme: item, qty (Stueck je Angebot), n (gleiche Angebote), unit (Preis je Stueck)
function rows(list) { return list.map(([item, unit, qty, n]) => ({ item, name: null, qty, n: n || 1, unit })); }
const LEVELS = rows([[2770, 1000, 50], [2770, 1100, 30], [2770, 1500, 100]]);
const COMM = (k) => k === '2770';
const SALES = new Map([['2770', { perDay: 50 * 24, level: 3 }]]);
const BANDS = new Map([['2770', { lang: 1400, schw: 0.1 }]]);

test('Aufkauf: beste Stelle, Ziel naechste Stufe, Gewinn nach 5 % Gebuehr', () => {
  const list = chances.buyout(LEVELS, { commodity: COMM, sales: SALES, bands: BANDS });
  assert.equal(list.length, 1);
  const x = list[0];
  assert.equal(x.qty, 80);
  assert.equal(x.cost, 83000);
  assert.equal(x.limit, 1100);
  assert.equal(x.target, 1500);
  assert.equal(x.gain, 31000);
  assert.ok(Math.abs(x.hours - 1.6) < 1e-9);
  assert.equal(x.risk, 'mid', 'Verkaufsdauer nahe an der Grenze');
  assert.equal(x.why.length, 1);
});

test('Aufkauf: Bedingungen schliessen aus', () => {
  assert.equal(chances.buyout(LEVELS, { commodity: () => false, sales: SALES, bands: BANDS }).length, 0, 'nur Massenware');
  assert.equal(chances.buyout(LEVELS, { commodity: COMM, sales: new Map(), bands: BANDS }).length, 0, 'ohne Absatz nichts');
  const slow = new Map([['2770', { perDay: 30 * 24, level: 3 }]]);
  assert.equal(chances.buyout(LEVELS, { commodity: COMM, sales: slow, bands: BANDS }).length, 0, 'verkauft sich nicht in 2 Std.');
  assert.equal(chances.buyout(LEVELS, { commodity: COMM, sales: slow, bands: BANDS, maxHours: 3 }).length, 1, 'Grenze einstellbar');
  const down = new Map([['2770', { dir: 'down' }]]);
  assert.equal(chances.buyout(LEVELS, { commodity: COMM, sales: SALES, bands: BANDS, shifts: down }).length, 0, 'Preis faellt: kein Aufkauf');
  assert.equal(chances.buyout(LEVELS, { commodity: COMM, sales: SALES, bands: BANDS, minGain: 40000 }).length, 0, 'unter dem Mindestgewinn');
  assert.equal(chances.buyout(rows([[2770, 1000, 50]]), { commodity: COMM, sales: SALES, bands: BANDS }).length, 0, 'eine Stufe reicht nicht');
});

test('Aufkauf: Risiko rot bei altem Stand, sortiert nach Gewinn mit Rot unten', () => {
  const old = chances.buyout(LEVELS, { commodity: COMM, sales: SALES, bands: BANDS, age: 8000 });
  assert.equal(old[0].risk, 'high');
  const two = rows([[2770, 1000, 50], [2770, 1100, 30], [2770, 1500, 100], [2589, 100, 100], [2589, 200, 100]]);
  const sales = new Map([...SALES, ['2589', { perDay: 2400, level: 3 }]]);
  const comm = (k) => k === '2770' || k === '2589';
  const list = chances.buyout(two, { commodity: comm, sales, bands: new Map([...BANDS, ['2589', { lang: 200, schw: 0.1 }]]) });
  assert.deepEqual(list.map((x) => x.key), ['2770', '2589'], 'hoeherer Gewinn zuerst');
  assert.ok(list[1].gain === Math.floor(100 * 200 * 0.95 - 100 * 100));
});
