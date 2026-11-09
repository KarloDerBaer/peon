'use strict';
// Zwischenspeicher der Momentaufnahmen (Manager 0.23.0): gleiche Ergebnisse wie die Abfragen ueber alle Zeilen
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { openDb, tx } = require('../src/core/db');
const game = require('../src/core/game');
const broker = require('../src/core/broker');
const history = require('../src/core/history');
const longterm = require('../src/core/longterm');
const retention = require('../src/core/retention');
const { SnapIndex } = require('../src/core/snapindex');

const M = 'Classic Beta PvE / Alliance';
const NOW = 1792700225 + 20 * 86400;
const TODAY = broker.dayOf(NOW);
const at = (day, hour) => broker.dayTime(day) - 12 * 3600 + hour * 3600;

// Zufall mit festem Startwert, damit der Test immer dasselbe prueft
function rnd(seed) { let s = seed; return () => { s = (s * 1103515245 + 12345) % 2147483648; return s / 2147483648; }; }

function scanRows(r) {
  const lines = [];
  for (const item of [2770, 2589, 2592, 4306, 6611]) {
    if (r() < 0.15) continue;   // mal fehlt ein Gegenstand
    for (let i = 0; i < 1 + Math.floor(r() * 4); i++) lines.push(`${item};;;${1 + Math.floor(r() * 20)};${Math.floor(100 + r() * 900)};;;3;;1`);
  }
  return lines.join('\n');
}

function setup() {
  const db = openDb(fs.mkdtempSync(path.join(os.tmpdir(), 'peon-')));
  const r = rnd(7);
  let n = 0;
  const add = (t, kind = 'scan') => {
    n++;
    const e = kind === 'scan'
      ? { id: `s${n}`, kind, market: M, t, rows: scanRows(r) }
      : { id: `l${n}`, kind, market: M, t, key: '2770', rows: r() < 0.3 ? '' : `2770;;;5;;${Math.floor(100 + r() * 50)};;1;${n};1` };
    tx(db, () => game.importEntry(db, e, null));
  };
  // 16 Tage, je Tag einige Scans und Live-Abfragen
  for (let d = TODAY - 15; d <= TODAY; d++) for (let h = 1; h < 24; h += 5) { add(at(d, h)); if (h % 2) add(at(d, h) + 60, 'live'); }
  // Broker-Verlauf fuer einen Gegenstand, den es sonst nicht gibt, und fuer einen mit eigenen Werten
  const mid = db.prepare('SELECT id FROM markets WHERE key = ?').get(M).id;
  const ins = db.prepare("INSERT INTO hist(market_id, item_key, source, period, num, t, min, median, qty, n) VALUES (?, ?, 'broker', 'day', ?, ?, ?, ?, ?, 1)");
  for (let d = TODAY - 10; d <= TODAY; d++) { ins.run(mid, '9999', d, broker.dayTime(d), 50, 60 + d % 3, 4); ins.run(mid, '2770', d, broker.dayTime(d), 50, 300, 4); }
  return { db, mid, add };
}

// Zahlen auf 9 Stellen runden: die Reihenfolge beim Addieren darf sich unterscheiden
function norm(x) {
  if (x instanceof Map) return [...x].map(([k, v]) => [k, norm(v)]).sort((a, b) => String(a[0]).localeCompare(String(b[0])));
  if (Array.isArray(x)) return x.map(norm);
  if (x && typeof x === 'object') return Object.fromEntries(Object.entries(x).sort().map(([k, v]) => [k, norm(v)]));
  if (typeof x === 'number') return Math.round(x * 1e6) / 1e6;
  return x;
}

function same(db, mid, idx, label) {
  assert.deepEqual(norm(idx.dayValues(mid, NOW, longterm.DAYS)), norm(longterm.dayValues(db, mid, TODAY)), `${label}: Tageswerte fuer den Bereich`);
  const a = history.itemList(db, M, NOW, idx.listParts(mid, NOW));
  const b = history.itemList(db, M, NOW);
  const byKey = (l) => l.items.sort((x, y) => String(x.key).localeCompare(String(y.key))).map((it) => ({ ...it, min: it.min, median: it.median }));
  assert.deepEqual(norm(byKey(a)), norm(byKey(b)), `${label}: Gegenstandsliste`);
  assert.equal(a.lastScan, b.lastScan);
}

test('Zwischenspeicher: gleiche Werte wie die Abfragen, neue Staende ohne neues Lesen', () => {
  const { db, mid, add } = setup();
  const idx = new SnapIndex(db);
  same(db, mid, idx, 'Anfang');
  assert.equal(idx.builds, 1);
  add(NOW - 600);
  add(NOW - 300, 'live');
  same(db, mid, idx, 'nach neuen Staenden');
  assert.equal(idx.builds, 1, 'neue Staende werden dazugenommen, nicht alles neu gelesen');
});

test('Zwischenspeicher: nach dem Verdichten zu Stundenwerten wieder gleich', () => {
  const { db, mid, add } = setup();
  const idx = new SnapIndex(db);
  same(db, mid, idx, 'vorher');
  // Alles aelter als 5 Tage zu Stundenwerten (das Programm haelt mindestens 14 Tage, hier direkt verdichtet)
  for (const _ of retention.pruneSteps(db, { keepDays: 5, hourDays: 60, now: NOW })) { /* alle Schritte */ }
  assert.ok(db.prepare('SELECT COUNT(*) AS n FROM item_hour').get().n > 0, 'es gibt Stundenwerte');
  same(db, mid, idx, 'nach dem Verdichten');
  assert.equal(idx.builds, 2, 'geaenderte Zeilenzahl: einmal neu gelesen');
  add(NOW - 100);
  same(db, mid, idx, 'Stundenwerte und neuer Stand');
});

test('Zwischenspeicher: neuer Tag verschiebt das Fenster', () => {
  const { db, mid } = setup();
  const idx = new SnapIndex(db);
  idx.dayValues(mid, NOW, longterm.DAYS);
  const later = NOW + 86400;
  assert.deepEqual(norm(idx.dayValues(mid, later, longterm.DAYS)), norm(longterm.dayValues(db, mid, TODAY + 1)));
  assert.equal(idx.builds, 2);
});
