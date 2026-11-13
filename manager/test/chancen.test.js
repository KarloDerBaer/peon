'use strict';
// Tests fuer Chancen und Prognosen (ab Manager 0.35.0, docs/konzepte/manager/Peon_Manager_Chancen.md): node --test test/
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { openDb } = require('../src/core/db');
const proof = require('../src/core/proof');
const sales = require('../src/core/sales');
const spec = require('../src/core/spec');
const forecast = require('../src/core/forecast');
const book = require('../src/core/chancebook');
const { levelOf } = require('../src/core/chance-client');

const tmp = () => fs.mkdtempSync(path.join(os.tmpdir(), 'peon-ch-'));
const NOW = 1794000000;
const DAY = Math.floor(NOW / 86400);

test('D1 und D2: Verkaeufe mit Preisstufe und Standzeit, F56 belegter Preis, F58 Haltbarkeit', () => {
  const db = openDb(tmp());
  const t0 = NOW - 10 * 3600;
  // erster Stand nach dem Einbau: Standzeit dieser Angebote unbekannt
  proof.noteSeen(db, 1, [{ id: 1 }, { id: 2 }], t0);
  const start = proof.startOf(db, 1);
  proof.noteSeen(db, 1, [{ id: 3 }, { id: 4 }], t0 + 3600);
  assert.equal(start, t0);
  // Angebot 3 stand eine Stunde, bevor es verkauft wurde; Angebot 1 seit dem ersten Stand
  proof.record(db, 1, '2589', DAY, [{ p: 1000, q: 1, id: 3 }, { p: 1000, q: 2, id: 1 }, { p: 500, q: 1, id: 4 }], t0 + 3600, t0 + 3 * 3600, start);
  proof.record(db, 1, '2589', DAY, [{ p: 980, q: 2, id: 0 }], t0 + 3 * 3600, t0 + 4 * 3600, start);
  const pr = proof.soldPrices(db, 1, DAY).get('2589');
  assert.ok(pr && pr.n === 6 && Math.abs(pr.median - 1000) <= 20, 'Median der Verkaeufe in Stufen zu 2 %');
  assert.equal(db.prepare('SELECT SUM(qty) AS q FROM sale_life').get().q, 2, 'nur Angebote mit bekannter Standzeit');
  const h = proof.durability(db, 1, '2589', 1000, DAY);
  assert.ok(h && h.hours === 1 && h.n === 1, 'nur Verkaeufe unter 80 % des belegten Preises zaehlen');
  assert.equal(proof.durabilityAll(db, 1, new Map([['2589', 1000]]), DAY).get('2589').hours, 1);
  proof.prune(db, NOW + 40 * 86400, DAY + 40);
  assert.equal(db.prepare('SELECT COUNT(*) AS n FROM sale_px').get().n, 0, 'nach 30 Tagen weg');
  db.close();
});

test('Vergleich liefert jeden Verkauf mit Angebotsnummer', () => {
  const A = [{ id: 7, q: 1, p: 100, lo: 7200, hi: 43200 }, { id: 8, q: 5, p: 120, lo: 7200, hi: 43200 }];
  const B = [{ id: 8, q: 2, p: 120, lo: 0, hi: 0 }];
  const r = sales.compare(A, B, 0, 3600, { withIds: true, cancelPct: 0 });
  assert.deepEqual(r.soldList.map((x) => [x.id, x.q, x.p]).sort(), [[7, 1, 100], [8, 3, 120]]);
});

// Kontext wie chance-client.chanceCtx, nur was spec braucht
function ctx(over = {}) {
  const items = new Map([['2589', { name: 'Leinenstoff', quality: 1, item_id: 2589, vendor: 10 }]]);
  return {
    now: NOW, today: DAY, t: NOW - 600, age: 600, rows: [],
    offers: new Map([['2589', [{ p: 50000, q: 1 }, { p: 52000, q: 1 }, { p: 95000, q: 2 }, { p: 120000, q: 1 }]]]),
    stats: new Map([['2589', { perDay: 4, level: 3 }]]),
    bands: new Map([['2589', { lang: 100000, schw: 0.1 }]]), shifts: new Map(),
    proof: new Map([['2589', { median: 100000, n: 12 }]]), dur: new Map(), rules: spec.rulesOf(null),
    broker: { hours: 2, minGain: 5000, minQty: 500, minLevels: 4, minSales: 270, targetPct: 0.2 }, forecasts: new Map(),
    over: () => ({}), vendor: (k) => (items.get(k) || {}).vendor || null, isCommodity: () => false,
    info: (k) => items.get(k) || { item_id: Number(k) }, hold: () => ({ hours: 5, n: 3 }),
    ...over,
  };
}

test('Spekulation schnell: belegter Preis, Zielpreis unter dem naechsten Angebot, Verkaufsdauer, Gewinn, Satz', () => {
  const x = spec.evalFast(ctx(), '2589');
  assert.ok(x.ok, 'Vorschlag');
  assert.equal(x.limit, 70000, 'Kaufen bis 30 % unter 10g');
  assert.equal(x.qty, 2);
  assert.equal(x.target, 94999, 'hoechstens knapp unter dem naechsten fremden Angebot');
  assert.equal(x.days, (0 + 2) / 4, 'keine Stueck dazwischen, 2 eigene bei 4 am Tag');
  assert.equal(x.gain, Math.floor(94999 * 0.95 * 2 - 102000));
  assert.ok(x.say.startsWith('Liegt 50 % unter dem, wofür er zuletzt verkauft wurde.'), x.say);
  assert.equal(x.risk, 'low');
  // zu wenige Belege: Warum nicht?
  const y = spec.evalFast(ctx({ proof: new Map([['2589', { median: 100000, n: 2 }]]) }), '2589');
  assert.ok(!y.ok && y.say === 'Kein Vorschlag, weil: Noch kein belegter Verkaufspreis.', y.say);
  // Uebersteuerung: Zielpreis selbst festgelegt
  const z = spec.evalFast(ctx({ over: () => ({ target: 80000 }) }), '2589');
  assert.ok(z.ok && z.target === 80000 && z.limit === 56000 && z.checks.find((k) => k.id === 'gap').user, 'von dir geaendert');
  const n = spec.evalFast(ctx({ over: () => ({ never: true }) }), '2589');
  assert.ok(!n.ok && n.checks.some((k) => k.id === 'never'));
});

test('Haendler: nur live erreichbar bei kurzer Haltbarkeit', () => {
  const c = ctx({ offers: new Map([['2589', [{ p: 5, q: 20 }]]]), hold: () => ({ hours: 0, n: 4 }), rules: spec.rulesOf({ v: { minGain: 50 } }) });
  const v = spec.evalVendor(c, '2589');
  assert.ok(v.ok && v.gain === 100 && v.liveOnly);
  const all = spec.marketChances(c);
  assert.ok(all.live.some((x) => x.key === '2589') && !all.list.some((x) => x.kind === 'v'), 'geht als Kandidat an den Radar');
});

test('Regler: Grenzen, Standard, Probe mit Rueckmeldungen', () => {
  const r = spec.rulesOf({ s: { gap: 5, nProof: 0 }, f: { signals: { glut: false }, minSure: 'mid' } });
  assert.equal(r.s.gap, 0.8, 'auf den Regler geklemmt');
  assert.equal(r.s.nProof, 1);
  assert.equal(r.f.signals.glut, false);
  const db = openDb(tmp());
  const x = spec.evalFast(ctx(), '2589');
  const near = spec.evalFast(ctx({ offers: new Map([['2589', [{ p: 82000, q: 1 }, { p: 120000, q: 1 }]]]) }), '2589');
  book.log(db, 1, NOW - 86400, [x], []);
  book.log(db, 1, NOW - 2 * 86400, [], [near]);   // ein anderer Tag, je Gegenstand und Tag zaehlt ein Eintrag
  db.prepare("INSERT INTO chance_rate(t, origin, item_key, up, reason) VALUES (?, 'manager', '2589', 0, 'Scherzpreis')").run(NOW - 86400);
  const p = book.probe(db, 1, NOW, 's', spec.rulesOf(null), spec.rulesOf({ s: { gap: 0.15 } }));
  assert.equal(p.before.n, 1);
  assert.equal(p.after.n, 2, 'der Beinahe-Vorschlag kaeme dazu');
  assert.deepEqual(p.ratingsAdded, {}, 'Bewertung gilt dem Gegenstand, der schon vorher drin war');
  const q = book.probe(db, 1, NOW, 's', spec.rulesOf(null), spec.rulesOf({ s: { gap: 0.6 } }));
  assert.equal(q.after.n, 0);
  assert.deepEqual(q.ratingsRemoved, { Scherzpreis: 1 }, 'davon hattest du einen als Scherzpreis markiert');
  db.close();
});

test('Nachpruefung: Ziel erreicht, Kaufpreis wieder drin, nicht', () => {
  const db = openDb(tmp());
  const x = spec.evalFast(ctx(), '2589');
  book.log(db, 1, NOW - 5 * 86400, [x], []);
  db.prepare("INSERT INTO item_snap(snapshot_id, market_id, item_key, t, source, min, median, qty) VALUES ('s1', 1, '2589', ?, 'scan', 90000, 96000, 3)").run(NOW - 4 * 86400);
  book.check(db, 1, NOW);
  assert.equal(db.prepare('SELECT outcome FROM chance_log').get().outcome, 'hit');
  const rates = book.rates(db, 1, NOW);
  assert.ok(rates.s.n === 1 && rates.s.rate === 1);
  db.close();
});

test('Prognosen: Knappheit, Sicherheit aus Signalen, neue Signale zaehlen nicht, schlechte schalten sich aus', () => {
  const qty = new Map(), sd = new Map();
  for (let i = 0; i < 14; i++) { qty.set(DAY - 13 + i, i < 8 ? 100 : 100 - (i - 7) * 14); sd.set(DAY - 13 + i, { sold: 10, listed: 10, expired: 0, secs: 86400 }); }
  const r = forecast.reachDays(qty, sd, DAY, 14, 10);
  const s = forecast.scarce(r, sd, DAY, { lang: 1000, schw: 0.2 }, 900);
  assert.ok(s && s.dir === 1 && s.expect > 0.3, 'Reichweite faellt, Absatz bleibt');
  const rates = new Map([['scarce', { n: 30, rate: 0.6 }], ['level', { n: 30, rate: 0.5 }], ['glut', { n: 25, rate: 0.2 }], ['fest', { n: 3, rate: 1 }]]);
  const a = forecast.combine([s], new Map([['scarce', { n: 5, rate: null }]]));
  assert.ok(a.sure === 'low' && a.signals[0].isNew, 'neu: niedrig');
  const b = forecast.combine([s, { id: 'level', dir: 1, days: 14, expect: 0.2 }], rates);
  assert.ok(b.sure === 'mid' && b.days === 14, 'zwei bewaehrte: mittel, Stufenbereich hoechstens mittel');
  assert.equal(forecast.combine([s, { id: 'glut', dir: -1, days: 7, expect: 0.2 }], new Map()), null, 'gegenlaeufig: heben sich auf');
  const c = forecast.combine([{ id: 'glut', dir: -1, days: 7, expect: 0.2 }], rates);
  assert.equal(c, null, 'unter 40 %: aus');
  assert.ok(forecast.combine([{ id: 'glut', dir: -1, days: 7, expect: 0.2 }], rates, { glut: 'force' }), 'von Hand wieder an');
  assert.equal(forecast.combine([s], rates, { scarce: false }), null, 'Schalter aus');
});

test('Stufenbereich: weniger eingestellt, verkauft kaum weniger', () => {
  const sd = new Map();
  for (const k of ['10', '11']) {
    const m = new Map();
    for (let i = 0; i < 14; i++) m.set(DAY - 13 + i, { sold: 5, listed: i < 7 ? 20 : 10, expired: 2, secs: 86400 });
    sd.set(k, m);
  }
  const levels = new Map([[10, { req: 25, equip: 1 }], [11, { req: 28, equip: 1 }]]);
  const idx = forecast.levelIndex(sd, levels, new Map(), new Map(), DAY);
  const x = idx.get('2:1');
  assert.ok(x && x.from === 21 && x.to === 30 && x.signal && Math.round(x.listedChange * 100) === -50 && x.soldChange === 0);
});

test('Prognose nachpruefen und Trefferquote je Signal', () => {
  const db = openDb(tmp());
  forecast.logForecasts(db, 1, new Map([['2589', { key: '2589', dir: 1, days: 3, sure: 'low', expect: 0.2, price: 1000, signals: [{ id: 'scarce' }] }]]), NOW - 5 * 86400);
  db.prepare("INSERT INTO item_hour(market_id, item_key, source, hour, t, median, n) VALUES (1, '2589', 'scan', 1, ?, 1150, 1)").run(NOW - 2 * 86400);
  forecast.checkForecasts(db, 1, NOW);
  assert.equal(db.prepare('SELECT outcome FROM forecast_log').get().outcome, 'hit', '15 % gestiegen, erwartet 20 %: mindestens die Haelfte');
  const r = forecast.signalRates(db, 1, NOW).get('scarce');
  assert.ok(r.n === 1 && r.rate === 1);
  db.close();
});

test('Stufe aus der Blizzard-API (D3)', () => {
  assert.deepEqual(levelOf({ level: 33, preview_item: { requirements: { level: { value: 28 } }, inventory_type: { type: 'CHEST' } } }), { req: 28, ilvl: 33, equip: 1 });
  assert.deepEqual(levelOf({ level: 5, preview_item: { inventory_type: { type: 'NON_EQUIP' } } }), { req: 0, ilvl: 5, equip: 0 });
});

test('Einschaetzungen aus Broker: einmal je Eintrag, Art aus dem Radar', () => {
  const db = openDb(tmp());
  const list = [{ key: 2589, name: 'Leinenstoff', t: NOW, rate: 'bad', note: 'Scherz', radar: { kind: 'spec', mk: 's' }, say: 'Satz' }, { key: 2590, t: NOW, rate: 'good', kind: 'v' }];
  assert.equal(book.importBroker(db, list), 2);
  assert.equal(book.importBroker(db, list), 0, 'kein zweites Mal');
  const r = book.ratings(db);
  assert.ok(r.find((x) => x.item_key === '2589' && x.kind === 's' && x.up === 0 && x.say === 'Satz'));
  assert.ok(r.find((x) => x.item_key === '2590' && x.kind === 'v' && x.up === 1));
  const text = book.exportText(db, spec.rulesOf(null), {}, NOW);
  assert.ok(text.includes('Leinenstoff') && !/Account|WTF/.test(text), 'Datei ohne Konto- und Charakternamen');
  db.close();
});
