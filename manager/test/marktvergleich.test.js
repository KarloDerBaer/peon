'use strict';
// Tests fuer den Marktvergleich mit dem neutralen Haus (ab Manager 0.50.0, compare.js, compare-client.js): node --test test/
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { sidOf } = require('./snap-helper');
const { openDb } = require('../src/core/db');
const cmp = require('../src/core/compare');
const { SnapIndex } = require('../src/core/snapindex');
const { methods } = require('../src/core/compare-client');

const tmp = () => fs.mkdtempSync(path.join(os.tmpdir(), 'peon-mv-'));
const NOW = 1794000000;
const DAY = Math.floor(NOW / 86400);
const HOME = 'Test PvE / Alliance', NEUTRAL = 'Test PvE / Neutral';

function setup() {
  const db = openDb(path.join(tmp(), 'b.db'));
  db.prepare('INSERT INTO markets(id, key) VALUES (1, ?), (2, ?)').run(HOME, NEUTRAL);
  return db;
}

// je Tag 4 Staende (alle 6 Std.) in einem Markt, prices[key] = Preis oder function(tag) -> Preis
function fill(db, mid, days, prices, qty = 20) {
  const ins = db.prepare("INSERT INTO item_snap(sid, market_id, item_key, t, source, min, median, p25, qty, auctions) VALUES (?, ?, ?, ?, 'scan', ?, ?, ?, ?, 5)");
  for (let d = days; d >= 1; d--) {
    for (let h = 0; h < 4; h++) {
      const t = NOW - d * 86400 + h * 6 * 3600 + 3600;
      const sid = sidOf(db, `m${mid}d${d}h${h}`, mid, t);
      for (const [key, p] of Object.entries(prices)) {
        const v = typeof p === 'function' ? p(d) : p;
        if (v) ins.run(sid, mid, key, t, v, v * 1.1, v, typeof qty === 'function' ? qty(key) : qty);
      }
    }
  }
}

// Absatz je Tag: sold Stueck zum Preis px
function sales(db, mid, days, key, sold, px, expired = 0) {
  const ins = db.prepare('INSERT INTO sales_day(market_id, item_key, day, secs, cmp, sold, expired, cancelled, listed, value, max_sold) VALUES (?, ?, ?, 86400, 24, ?, ?, 0, 0, ?, ?)');
  for (let d = 1; d <= days; d++) ins.run(mid, key, DAY - d + 1, sold, expired, sold * px, px);
}

test('Regeln: Vorgaben 10 % Anteil und 1 Tag, Grenzen und Auswahl', () => {
  const r = cmp.rules({});
  assert.equal(r.share, 0.1);
  assert.equal(r.hold, 1);
  assert.equal(r.cutN, 0.15);
  assert.equal(cmp.rules({ days: 5 }).days, 7, 'nur 3, 7 oder 14');
  assert.equal(cmp.rules({ days: 14 }).days, 14);
  assert.equal(cmp.rules({ share: 5 }).share, 1, 'geklemmt');
});

test('Chance nach Neutral: Preise, Netto nach 15 %, Absatz, Menge, Ampel', () => {
  const db = setup();
  fill(db, 1, 7, { 100: 1000, 200: 1000 });   // Fraktion: 10s
  fill(db, 2, 7, { 100: 3000, 200: 1050 });   // Neutral: 30s, Gegenstand 200 kaum anders
  sales(db, 2, 7, '100', 20, 2500);           // in Neutral 20 am Tag zu 25s
  sales(db, 2, 7, '200', 20, 1050);
  sales(db, 1, 7, '100', 5, 1000);
  const res = cmp.computePair(db, 1, 2, { now: NOW });
  const c = res.chances.find((x) => x.key === '100');
  assert.ok(c, 'Chance gefunden');
  assert.equal(c.dir, 'n');
  assert.equal(c.buy, 1000);
  assert.equal(c.sell, 2500, 'echter Verkaufspreis unter dem guenstigsten Angebot');
  assert.equal(c.net, Math.round(2500 * 0.85 - 1000));
  assert.equal(c.perDay, 20);
  assert.equal(c.qty, 2, '20 am Tag x 10 % x 1 Tag');
  assert.equal(c.cons, 1);
  assert.equal(c.light, 'green', 'Vorrat 20 / 20 = 1 Tag');
  assert.match(c.say, /^Fraktion kauft für 10s, Neutral verkauft im Mittel für 25s, 20 am Tag\. Unterschied an \d von \d Tagen/);
  assert.equal(c.cons14, 1);
  assert.equal(c.even, 1, 'an jedem Tag verkauft');
  assert.ok(c.pick, 'unter den besten 10');
  assert.ok(!res.chances.find((x) => x.key === '200'), 'zu kleine Spanne');
  const row = res.items.find((x) => x.key === '200');
  assert.ok(row && row.light === 'red');
  assert.equal(res.cutSure, false);
});

test('Gemessener Anteil gilt, Richtung nach Fraktion, ohne Absatz keine Chance', () => {
  const db = setup();
  fill(db, 1, 7, { 300: 5000, 400: 5000 });
  fill(db, 2, 7, { 300: 1000, 400: 1000 });
  sales(db, 1, 7, '300', 10, 4800);
  const res = cmp.computePair(db, 1, 2, { now: NOW, cutN: 0.1 });
  assert.equal(res.cutN, 0.1);
  assert.equal(res.cutSure, true);
  const c = res.chances.find((x) => x.key === '300');
  assert.equal(c.dir, 'h');
  assert.equal(c.net, Math.round(4800 * 0.95 - 1000));
  assert.ok(!res.chances.find((x) => x.key === '400'), 'ohne Absatz im Ziel keine Chance');
  assert.ok(res.items.find((x) => x.key === '400').why === undefined);
});

test('Bestaendigkeit und voller Zielmarkt', () => {
  const db = setup();
  // an 4 von 7 Tagen guenstig in Fraktion, sonst teurer
  fill(db, 1, 7, { 500: (d) => (d <= 4 ? 1000 : 4000), 600: 1000 });
  fill(db, 2, 7, { 500: 3000, 600: 3000 }, (k) => (k === '600' ? 2000 : 10));
  sales(db, 2, 7, '500', 10, 3000);
  sales(db, 2, 7, '600', 10, 3000);
  const res = cmp.computePair(db, 1, 2, { now: NOW });
  const a = res.chances.find((x) => x.key === '500');
  assert.ok(a && a.light === 'yellow', 'haelt nur an 4 von 7 Tagen');
  assert.ok(!res.chances.find((x) => x.key === '600'), '2000 im Angebot bei 10 am Tag: 200 Tage Vorrat');
});

test('SnapIndex liefert dieselben Tageswerte (guenstigster Preis)', () => {
  const db = setup();
  fill(db, 1, 7, { 100: 1000 });
  fill(db, 2, 7, { 100: 3000 });
  sales(db, 2, 7, '100', 20, 2500);
  const snaps = new SnapIndex(db);
  const m = snaps.dayMins(1, NOW, 7).get('100');
  assert.ok(m && m.size >= 6);
  for (const x of m.values()) assert.equal(x.min, 1000, 'min, nicht Median (1100)');
  const res = cmp.computePair(db, 1, 2, { now: NOW, snaps });
  assert.equal(res.chances.find((x) => x.key === '100').buy, 1000);
});

test('Liste fuer Broker: Auswahl der besten, je Gegenstand eine Richtung, Angeheftete, Grenzen', () => {
  const res = { t: NOW, cutN: 0.15, cutSure: false, rules: cmp.rules({ top: 1 }), chances: [
    { key: '1', dir: 'n', buy: 100, sell: 300, net: 155, perDay: 12.34, qty: 2, supply: 1.5, cons: 0.857, score: 900, light: 'green', say: 'A', pick: true },
    { key: '1', dir: 'h', buy: 300, sell: 100, net: 5, perDay: 1, qty: 1, supply: null, cons: 1, score: 10, light: 'yellow', say: 'B', pick: false },
    { key: '2', dir: 'n', buy: 100, sell: 300, net: 155, perDay: 1, qty: 1, supply: null, cons: 0.5, score: 5, light: 'yellow', say: 'C', pick: false },
    { key: '3', dir: 'n', buy: 100, sell: 300, net: 155, perDay: 1, qty: 1, supply: 2, cons: 0.5, score: 4, light: 'yellow', say: 'D', pick: false },
  ] };
  const b = cmp.forBroker(res, new Set(['3']));
  assert.equal(b.list['1'], 'n:100:300:155:123:2:15:86:900:g');
  assert.equal(b.say['1'], 'A');
  assert.equal(b.list['2'], undefined, 'nicht ausgewaehlt');
  assert.equal(b.list['3'], 'n:100:300:155:10:1:20:50:4:y', 'angeheftet');
  assert.equal(b.cutN, 1500);
  assert.equal(b.minPct, 20);
  assert.equal(b.minNet, 1000);
});

test('Auswahl: die besten N, Langzeit senkt einen schrumpfenden Unterschied', () => {
  const db = setup();
  const keys = {};
  for (let i = 0; i < 12; i++) keys[String(1000 + i)] = 1000;
  // 1100: frueher grosser Unterschied, jetzt kleiner (schrumpfend); 1101: gleichbleibend
  keys['1100'] = 1000; keys['1101'] = 1000;
  fill(db, 1, 14, keys);
  const nPrices = {};
  for (let i = 0; i < 12; i++) nPrices[String(1000 + i)] = 2000 + i * 100;
  nPrices['1100'] = (d) => (d > 7 ? 6000 : 2500);
  nPrices['1101'] = 2500;
  fill(db, 2, 14, nPrices);
  for (const k of Object.keys(nPrices)) if (k !== '1100') sales(db, 2, 14, k, 10, nPrices[k]);
  // 1100: aeltere Tage zu 60s verkauft, juengere zu 25s
  const ins = db.prepare('INSERT INTO sales_day(market_id, item_key, day, secs, cmp, sold, expired, cancelled, listed, value, max_sold) VALUES (2, ?, ?, 86400, 24, 10, 0, 0, 0, ?, ?)');
  for (let d = 1; d <= 14; d++) { const px = d > 7 ? 6000 : 2500; ins.run('1100', DAY - d + 1, 10 * px, px); }
  const res = cmp.computePair(db, 1, 2, { now: NOW, rules: { top: 5 } });
  assert.equal(res.chances.filter((c) => c.pick).length, 5);
  assert.equal(res.sum.picked, 5);
  const a = res.chances.find((c) => c.key === '1100'), b = res.chances.find((c) => c.key === '1101');
  assert.ok(a.trend < 1 && b.trend === 1, `Trend ${a.trend} / ${b.trend}`);
  assert.ok(a.score < b.score, 'schrumpfend zaehlt weniger');
  assert.equal(Object.keys(cmp.forBroker(res).list).length, 5);
});

test('Paare, Regeln, Ausblenden und Ansicht im Broker Client', () => {
  const db = setup();
  db.prepare('INSERT INTO markets(id, key) VALUES (3, ?)').run('Anders PvP / Horde');
  fill(db, 1, 7, { 100: 1000 });
  fill(db, 2, 7, { 100: 3000 });
  sales(db, 2, 7, '100', 20, 2500);
  db.prepare("INSERT INTO items(key, item_id, name, quality, commodity, updated) VALUES ('100', 100, 'Testerz', 1, 1, 0)").run();
  const meta = new Map();
  const cache = new Map();
  const c = Object.assign(Object.create(methods), {
    db, snaps: null, now: () => NOW, lastLua: { [HOME]: {} },
    meta(k, v) { if (v === undefined) return meta.has(k) ? meta.get(k) : null; meta.set(k, v); return v; },
    calcPut(mid, name, dsig, rsig, value) { cache.set(`${mid}|${name}`, { dsig, rsig, t: NOW, value: JSON.parse(JSON.stringify(value)) }); },
    calcGet(mid, name) { return cache.get(`${mid}|${name}`) || null; },
  });
  const pairs = c.comparePairs();
  assert.equal(pairs.length, 1);
  assert.equal(pairs[0].home.key, HOME);
  assert.equal(c.comparePairOf(NEUTRAL).home.key, HOME);
  assert.equal(c.compareRunAll(), 1);
  const v = c.compareView(HOME);
  assert.equal(v.chances[0].name, 'Testerz');
  assert.equal(v.chances[0].commodity, 1);
  assert.equal(v.stale, false);
  assert.ok(c.compareForBroker(1).list['100']);
  c.hideCompare('100', true);
  assert.equal(c.compareForBroker(1).list['100'], undefined, 'ausgeblendet geht nicht an Broker');
  c.hideCompare('100', false);
  c.pinCompare('100', true);
  assert.ok(c.lastLua[HOME].cmp.list['100'], 'Anheften schreibt gleich in die Werte fuer Data.lua');
  c.setCompareRules({ share: 0.5 });
  assert.equal(c.compareView(HOME).stale, true, 'neue Regeln: alte Rechnung');
  // gemessener Anteil aus Broker
  assert.equal(c.cutFromGame([{ mt: 1, cut: { Neutral: { r: 0.12, n: 3 } } }]), true);
  assert.equal(c.compareCut(), 0.12);
  assert.equal(c.compareItem(HOME, '100').chances.length, 1);
});

// ---------- ab 0.51.0: Beobachten mit Schnellkauf und Markttausch (watching.js) ----------
const watching = require('../src/core/watching');

test('Beobachten: Listen wie in Broker, Schnellkauf und Haken mit eigener Zeit', () => {
  const d = watching.empty();
  assert.equal(watching.setList(d, '5', 'trade', true, NOW), true);
  const w = d.items['5'];
  assert.ok(watching.inTrade(w) && !watching.inBuyout(w) && !watching.inQuick(w), 'nur Markttausch');
  assert.ok(w.t.lists > 0);
  assert.equal(watching.setQuick(d, '5', { qlim: 1234, qgold: 0 }, NOW + 1), true);
  assert.equal(w.qlim, 1234);
  assert.ok(w.t.q > 0);
  assert.equal(watching.setQuick(d, '5', { qlim: 1234, qgold: 0 }, NOW + 2), false, 'unveraendert');
  watching.setList(d, '5', 'quick', true, NOW + 3);
  assert.ok(watching.inQuick(w) && watching.inTrade(w));
  watching.setList(d, '5', 'trade', false, NOW + 4);
  assert.ok(d.items['5'] && !watching.inTrade(w));
  assert.equal(watching.setList(d, '5', 'quick', false, NOW + 5), 'removed', 'keine Liste mehr: Beobachtung endet');
  assert.ok(!d.items['5'] && d.gone['5']);
});

test('Beobachten: neuere Werte des Schnellkaufs aus dem Spiel gewinnen, aeltere nicht', () => {
  const d = watching.empty();
  watching.setList(d, '7', 'quick', true, NOW);
  watching.setQuick(d, '7', { qlim: 100 }, NOW + 1);
  const t = d.items['7'].t.q;
  watching.merge(d, { items: { 7: { u: t - 5, qlim: 50, t: { q: t - 5 } } } });
  assert.equal(d.items['7'].qlim, 100, 'aelter: bleibt');
  watching.merge(d, { items: { 7: { u: t + 5, qlim: 70, qon: true, t: { q: t + 5, lists: 0 } } } });
  assert.equal(d.items['7'].qlim, 70, 'neuer: uebernommen');
  const g = watching.forGame(d).items['7'];
  assert.equal(g.qlim, 70);
  assert.equal(g.qon, true);
});

// ---------- ab 0.52.0: Einstellgebuehr, Luecke im Ziel, Verlauf, Erfolgskontrolle ----------
test('Einstellgebuehr: verloren nur fuer abgelaufene Angebote', () => {
  assert.equal(cmp.depositLoss(100, 1), 0, 'alles verkauft');
  assert.equal(cmp.depositLoss(100, 0.5), 20, '5 % von 1s = 5c, mal 4 = 20c, je Verkauf ein Ablauf');
  assert.equal(cmp.depositLoss(100, 0.01), 80, 'Absatzquote hoechstens bis 20 % gerechnet');
  assert.equal(cmp.depositLoss(null, 0.5), 0);
  const db = setup();
  fill(db, 1, 7, { 100: 1000 });
  fill(db, 2, 7, { 100: 3000 });
  sales(db, 2, 7, '100', 20, 3000, 20);   // Absatzquote 50 %
  const res = cmp.computePair(db, 1, 2, { now: NOW, vendor: new Map([['100', 1000]]) });
  const c = res.chances.find((x) => x.key === '100');
  assert.equal(c.depLoss, 200, '5 % von 10s = 50c x 4 = 2s je Ablauf');
  assert.equal(c.net, Math.round(3000 * 0.85 - 1000 - 200));
});

test('Luecke: im Ziel kein Angebot, aber Verkaeufe', () => {
  const db = setup();
  fill(db, 1, 7, { 300: 1000 });
  // Neutral hat keine Preise fuer 300, verkauft aber an 5 Tagen zu 30s
  const ins = db.prepare('INSERT INTO sales_day(market_id, item_key, day, secs, cmp, sold, expired, cancelled, listed, value, max_sold) VALUES (2, ?, ?, 86400, 24, 4, 0, 0, 0, ?, ?)');
  for (let d = 1; d <= 5; d++) ins.run('300', DAY - d + 1, 4 * 3000, 3000);
  fill(db, 2, 7, { 999: 50 });   // damit der Markt Staende hat
  const res = cmp.computePair(db, 1, 2, { now: NOW });
  const c = res.chances.find((x) => x.key === '300');
  assert.ok(c && c.gap && c.dir === 'n', 'Chance in die Luecke');
  assert.equal(c.sell, 3000);
  assert.match(c.say, /Im Ziel gerade kein Angebot/);
});

test('Verlauf beider Haeuser und Erfolgskontrolle der Auswahl', () => {
  const db = setup();
  fill(db, 1, 10, { 100: 1000 });
  fill(db, 2, 10, { 100: 3000 });
  sales(db, 2, 10, '100', 20, 2500);
  const s = cmp.itemSeries(db, 1, 2, '100', NOW, 14);
  assert.equal(s.days.length, 14);
  assert.ok(s.home.filter((v) => v === 1000).length >= 9 && s.neutralSold.filter((v) => v === 2500).length >= 9);
  const meta = new Map();
  const c = Object.assign(Object.create(methods), {
    db, snaps: null, now: () => NOW, readOnly: false, settings: { wowDir: '' },
    meta(k, v) { if (v === undefined) return meta.has(k) ? meta.get(k) : null; meta.set(k, v); return v; },
  });
  // Vorschlag von vor 5 Tagen, erwartet 11s 25c
  meta.set('compareLog', [{ m: 1, n: 2, key: '100', dir: 'n', day: DAY - 5, t: NOW - 5 * 86400, buy: 1000, sell: 2500, net: 1125, cut: 0.15, minNet: 1000 }]);
  const v = c.compareSuccess(HOME);
  assert.equal(v.checked, 1);
  assert.equal(v.held, 1, `gehalten: ${JSON.stringify(v.rows[0])}`);
  assert.equal(v.rows[0].real, Math.round(2500 * 0.85 - 1000));
  // Auswahl merken: je Tag nur einmal
  const res = { t: NOW, cutN: 0.15, cutH: 0.05, rules: cmp.rules({}), chances: [{ key: '100', dir: 'n', buy: 1, sell: 2, net: 1, pick: true }, { key: '7', dir: 'h', pick: false }] };
  assert.equal(c.compareLogPicks({ home: { id: 1 }, neutral: { id: 2 } }, res), 1);
  assert.equal(c.compareLogPicks({ home: { id: 1 }, neutral: { id: 2 } }, res), 0);
});

// ---------- ab 0.53.0: Pakete ----------
const packages = require('../src/core/packages');

test('Pakete: Gewinn auch bei halbem Verkauf, Streuung, Budget', () => {
  const ru = cmp.rules({});
  assert.equal(ru.pkgSize, 8);
  assert.equal(ru.pkgGold, 0.1);
  assert.equal(ru.pkgSafe, 0.5);
  const ch = [];
  for (let i = 0; i < 20; i++) ch.push({ key: String(100 + i), dir: 'n', ok: true, buy: 1000, sell: 4000, perDay: 2, rate: 0.8, supply: 1 });
  ch.push({ key: '999', dir: 'n', ok: true, buy: 90000, sell: 400000, perDay: 2, rate: 0.9, supply: 1 });
  const info = (k) => ({ commodity: false, cls: Number(k) % 5, vendor: 100 });
  const pk = packages.build(ch, 'n', info, ru, 50000, new Set(), 0.15);
  assert.ok(pk.offers.length >= 4 && pk.offers.length <= 8, `Angebote ${pk.offers.length}`);
  assert.ok(!pk.offers.some((o) => o.key === '999'), 'zu teuer fuer Budget und Streuung');
  assert.ok(pk.stake <= 50000);
  assert.ok(pk.gainSafe > 0, 'Gewinn bei halbem Verkauf');
  const perCat = new Map();
  for (const o of pk.offers) perCat.set(o.cls, (perCat.get(o.cls) || 0) + 1);
  assert.ok([...perCat.values()].every((v) => v <= packages.PER_CAT), 'hoechstens 3 je Kategorie');
  const pk2 = packages.build(ch, 'n', info, ru, 50000, new Set(pk.offers.map((o) => `n|${o.key}`)), 0.15);
  assert.ok(!pk2.offers.some((o) => pk.offers.some((x) => x.key === o.key)), 'ausgeschlossene fehlen');
  const fb = packages.forBroker(pk, 0.15);
  const [key, qty, buy, minSell, sell] = fb.list[0].split(':');
  assert.ok(key);
  assert.equal(Number(qty), 1);
  assert.equal(Number(minSell), Math.ceil((Number(buy) + 20) / 0.85), 'Mindestpreis deckt Kauf und Einstellgebuehr');
  assert.equal(Number(sell), 4000);
});

test('Pakete: safeGain rechnet mit den schlechtesten Verkaeufen', () => {
  const offers = [{ revenue: 100, cost: 50, dep: 10 }, { revenue: 1000, cost: 50, dep: 10 }];
  assert.equal(packages.safeGain(offers, 0.5), 100 - 100 - 10, 'nur das schlechteste verkauft');
});

test('Pakete: Erfolgskontrolle mit Bewegungen aus Ledger', () => {
  const c = Object.create(methods);
  const e = { dir: 'n', t: NOW, offers: [{ key: '100', qty: 2, buy: 100 }, { key: '200', qty: 1, buy: 100 }] };
  const moves = [[
    { k: 'ahbuy', id: 100, h: 'f', t: NOW + 10, m: -200, n: 2 },
    { k: 'ahbuy', id: 200, h: 'f', t: NOW + 20, m: -100, n: 1 },
    { k: 'ahsold', id: 100, h: 'n', t: NOW + 100, m: 500, q: 2 },
    { k: 'ahsold', id: 200, h: 'f', t: NOW + 100, m: 999, q: 1 },
  ]];
  const r = c.pkgResult(e, moves);
  assert.equal(r.bought, 2);
  assert.equal(r.sold, 1, 'im falschen Haus verkauft zaehlt nicht');
  assert.equal(r.cost, 300);
  assert.equal(r.income, 500);
  assert.equal(r.profit, 200);
  const meta = new Map();
  const d = Object.assign(Object.create(methods), { meta(k, v) { if (v === undefined) return meta.has(k) ? meta.get(k) : null; meta.set(k, v); return v; } });
  const pk = { t: NOW, n: { offers: [{ key: '1', qty: 1, buy: 5 }], stake: 5, gain: 3, gainSafe: 1, safe: 0.5 }, h: { offers: [] } };
  assert.equal(d.pkgLogDay({ home: { id: 1 } }, pk), 1);
  assert.equal(d.pkgLogDay({ home: { id: 1 } }, pk), 0, 'je Tag und Richtung einmal');
});
