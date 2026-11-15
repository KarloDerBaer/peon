'use strict';
// Tests fuer Muster nach Tageszeit und Wochentag (ab Manager 0.38.0, Peon_Chancen_Reiter_Muster.md 5): node --test test/
const test = require('node:test');
const assert = require('node:assert/strict');
const { sidOf } = require('./snap-helper');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { openDb } = require('../src/core/db');
const pattern = require('../src/core/pattern');
const spec = require('../src/core/spec');

const tmp = () => fs.mkdtempSync(path.join(os.tmpdir(), 'peon-mu-'));
const NOW = 1794000000;
const OFF = -new Date(NOW * 1000).getTimezoneOffset() * 60;
const LDAY = Math.floor((NOW + OFF) / 86400);   // Ortstag von NOW

// Kennzahlen in item_snap: je Tag und Abschnitt ein Wert, fn(tag, abschnitt) -> Preis
function fill(db, key, days, fn, auctions = 8) {
  const ins = db.prepare("INSERT INTO item_snap(sid, market_id, item_key, t, source, min, median, qty, auctions) VALUES (?, 1, ?, ?, 'scan', ?, ?, ?, ?)");
  for (let d = days; d >= 1; d--) {
    for (let s = 0; s < 8; s++) {
      const t = (LDAY - d) * 86400 - OFF + s * 3 * 3600 + 3600;
      ins.run(sidOf(db, `s${d}-${s}`, 1, t), key, t, fn(d, s), fn(d, s), auctions, auctions);
    }
  }
}

test('Tageszeit: festes Muster, auch wenn der ganze Markt faellt', () => {
  const db = openDb(tmp());
  // 16 Tage, Preis faellt je Tag um 3 %, nachts 0 bis 3 Uhr 30 % billiger, 9 bis 12 Uhr 10 % teurer
  fill(db, '2589', 16, (d, s) => Math.round(100000 * Math.pow(0.97, 16 - d) * (s === 0 ? 0.7 : s === 3 ? 1.1 : 1)));
  const p = pattern.marketPatterns(db, 1, NOW).get('2589');
  assert.ok(p && p.kind === 'tod' && p.lo === 0 && p.hi === 3, JSON.stringify(p));
  assert.ok(p.hits === p.n && p.n >= 14 && p.spread > 0.3);
  db.close();
});

test('Tageszeit: nur der Abwaertstrend ist kein Muster', () => {
  const db = openDb(tmp());
  // Preis faellt gleichmaessig ueber den Tag: ohne Bereinigung waere der spaete Abend immer am guenstigsten
  fill(db, '2589', 16, (d, s) => Math.round(100000 * Math.pow(0.97, (16 - d) + s / 8)));
  assert.equal(pattern.marketPatterns(db, 1, NOW).size, 0);
  db.close();
});

test('Tageszeit: zu wenige Tage, zu wenige Angebote, zu wenig Abstand', () => {
  const db = openDb(tmp());
  fill(db, 'a', 10, (d, s) => (s === 0 ? 70000 : 100000));
  fill(db, 'b', 16, (d, s) => (s === 0 ? 70000 : 100000), 2);
  fill(db, 'c', 16, (d, s) => (s === 0 ? 95000 : 100000));
  assert.equal(pattern.marketPatterns(db, 1, NOW).size, 0);
  db.close();
});

test('Wochentag: Samstag guenstig ueber 4 Wochen', () => {
  const db = openDb(tmp());
  const wd = (d) => ((LDAY - d) + 3) % 7;   // Montag = 0
  fill(db, '2589', 28, (d) => (wd(d) === 5 ? 70000 : 100000));
  const p = pattern.marketPatterns(db, 1, NOW).get('2589');
  assert.ok(p && p.kind === 'wd' && p.lo === 5, JSON.stringify(p));
  assert.equal(pattern.windowText('wd', p.lo), 'Samstag');
  assert.equal(pattern.windowCode('wd', p.lo), '32/-1');
  assert.equal(pattern.windowCode('tod', 3), '127/3');
  db.close();
});

test('Chance Muster: Werte, Pruefliste, Gold, fallender Preis', () => {
  const p = { kind: 'tod', lo: 0, hi: 3, rel: { lo: 0.75, hi: 1.1 }, spread: 0.39, hits: 12, n: 14 };
  const flat = new Map();
  for (let a = 0; a <= 13; a++) flat.set(LDAY - a, { value: 100000 });
  const c = {
    now: NOW, today: LDAY, t: NOW, age: 0, offers: new Map([['2589', [{ p: 90000, q: 3 }]]]),
    stats: new Map([['2589', { perDay: 4 }]]), bands: new Map([['2589', { lang: 100000, schw: 0.1 }]]), days: new Map([['2589', flat]]),
    rules: spec.rulesOf(null), gold: null, over: () => ({}), info: () => ({ name: 'Leinenstoff', quality: 1, item_id: 2589 }), forecasts: new Map(),
  };
  const x = spec.evalPattern(c, '2589', p);
  assert.ok(x.ok, JSON.stringify(x.checks.filter((k) => !k.ok)));
  assert.equal(x.kind, 'm');
  assert.equal(x.limit, 75000);
  assert.equal(x.target, 110000);
  assert.equal(x.qty, 4, 'ein Tagesabsatz');
  assert.equal(x.gain, Math.floor(110000 * 0.95 * 4 - 300000));
  assert.ok(x.window && x.window.buy === '127/0' && x.window.sell === '127/3' && x.window.buyText === '0 bis 3 Uhr');
  assert.ok(x.say.startsWith('Am günstigsten 0 bis 3 Uhr, am teuersten 9 bis 12 Uhr, an 12 von 14 Tagen so.'), x.say);
  // Gold: 25 % von 20g = 5g, also keins zu 7g 50s
  assert.ok(!spec.evalPattern({ ...c, gold: 200000 }, '2589', p).ok);
  // Preis faellt: kein Vorschlag
  const fall = new Map([[LDAY - 2, { value: 100000 }], [LDAY - 1, { value: 100000 }], [LDAY, { value: 80000 }]]);
  assert.ok(!spec.evalPattern({ ...c, days: new Map([['2589', fall]]) }, '2589', p).ok);
  // Abstand zu klein
  assert.ok(!spec.evalPattern(c, '2589', { ...p, rel: { lo: 0.95, hi: 1.0 } }).ok);
});

test('Muster gehen mit Zeitfenstern an Broker, Haendler nicht', () => {
  const { install } = require('../src/core/chance-client');
  const db = openDb(tmp());
  const bc = { db, now: () => NOW, store: {}, meta(k, v) { if (v === undefined) return this.store[k] ?? null; this.store[k] = v; return v; } };
  install(bc);
  bc.chanceResult = () => ({ list: [{ key: '2589', kind: 'm', buy: 75000, target: 110000, until: NOW + 3600, gain: 118000, risk: 'low', qty: 4, say: 'x', window: { buy: '127/0', sell: '127/3' } }] });
  bc.chanceCtx = () => ({ t: NOW });
  const r = bc.chancesForBroker(1);
  assert.match(r.list['2589'], /^m:75000:110000:\d+:118000:0:4:127\/0:127\/3$/);
  db.close();
});

test('Schema 13: gespeicherte Haendler-Vorschlaege fallen weg', () => {
  const dir = tmp();
  let db = openDb(dir);
  db.prepare("INSERT INTO chance_log(market_id, item_key, kind, day, t, shown, data) VALUES (1, '4306', 'v', 1, 1, 1, '{}')").run();
  db.prepare("INSERT INTO chance_log(market_id, item_key, kind, day, t, shown, data) VALUES (1, '2589', 's', 1, 1, 1, '{}')").run();
  db.prepare("DELETE FROM meta WHERE key = 'vendorKindGone'").run();
  db.close();
  db = openDb(dir);
  assert.deepEqual(db.prepare('SELECT kind FROM chance_log').all().map((x) => x.kind), ['s']);
  db.close();
});
