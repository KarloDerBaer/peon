'use strict';
// Tests fuer den Baustein Blizzard-API (Forever) und den Beobachter: nachgebaute Antworten nach dem geprueften Aufbau, kein Netz
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const zlib = require('node:zlib');
const { probe, BlizzardClient, BlizzardAccess } = require('../src/core/blizzard');
const { BlizzardWatch, compareOffers, addCensus, mostCommon } = require('../src/core/blizzard-watch');

const KEY = { clientId: 'meine-id-1234', clientSecret: 'GEHEIM-secret', region: 'eu' };
const TOKEN = 'TOKEN-abc';
const STAMP = 'Thu, 05 Nov 2026 07:47:00 GMT';
const STAMP2 = 'Thu, 05 Nov 2026 08:47:00 GMT';
const OFFER = { id: 7, item: { id: 2770 }, bid: 100, buyout: 200, quantity: 1, time_left: 'LONG' };
const MASS = { id: 8, item: { id: 2589 }, unit_price: 50, quantity: 20, time_left: 'SHORT' };

// routes: Pfad -> [Code, Antwort, Last-Modified]. Alles andere ist 404.
function fakeApi(routes, { token = [200, { access_token: TOKEN, expires_in: 3600 }] } = {}) {
  const calls = [];
  const res = ([status, body, stamp]) => ({ status, ok: status >= 200 && status < 300, headers: { get: (n) => (n.toLowerCase() === 'last-modified' ? stamp || null : null) },
    json: async () => body, text: async () => JSON.stringify(body) });
  const fetchImpl = async (url, opt) => {
    calls.push({ url: String(url), opt });
    const u = new URL(url);
    if (u.pathname === '/token') return res(token);
    assert.equal(opt.headers.Authorization, `Bearer ${TOKEN}`);
    return res(routes[u.pathname] || [404, { detail: 'Not Found' }]);
  };
  return { fetchImpl, calls };
}
const OPT = { now: () => 1000, apiBase: 'https://test.invalid', oauthBase: 'https://test.invalid' };
const run = (routes, o) => { const f = fakeApi(routes, o); return probe(KEY, { ...OPT, fetchImpl: f.fetchImpl }).then((r) => ({ r, calls: f.calls })); };

const RULES = { '/data/wow/ruleset/index': [200, { rulesets: [{ id: 1, name: 'PvP' }, { id: 2, name: 'Normal' }] }] };
const HOUSES = { '/data/wow/ruleset/1/auctions/index': [200, { auctions: [{ id: 112, name: 'Leer' }, { id: 113, name: 'Horde' }] }] };
const EMPTY_112 = { '/data/wow/ruleset/1/auctions/112': [200, { id: 112, name: 'Leer', commodities: { href: 'x' } }], '/data/wow/ruleset/1/auctions/112/commodities': [200, { auctions: [] }] };
const FULL_113 = { '/data/wow/ruleset/1/auctions/113': [200, { auctions: [OFFER, OFFER, OFFER, OFFER] }, STAMP], '/data/wow/ruleset/1/auctions/113/commodities': [200, { auctions: [MASS] }, STAMP] };

test('Pruefabruf folgt dem Weg ueber Regelsatz und Haus, ueberspringt leere Haeuser', async () => {
  const { r, calls } = await run({ ...RULES, ...HOUSES, ...EMPTY_112, ...FULL_113 });
  assert.equal(r.result, 'auctions');
  assert.equal(r.sample.house, 113);
  assert.equal(r.sample.count, 4);
  assert.equal(r.sample.offers.length, 3);
  assert.equal(r.sample.lastModified, STAMP);
  assert.deepEqual(r.sample.fields, Object.keys(OFFER));
  assert.equal(r.sample.commodities.count, 1);
  assert.deepEqual(r.rulesets.map((x) => x.id), [1, 2]);
  assert.deepEqual(r.houses.map((x) => x.id), [112, 113]);
  assert.equal(r.steps.find((s) => s.name === 'Regelsätze').note, '2 Regelsätze');
  assert.ok(calls.some((c) => new URL(c.url).searchParams.get('namespace') === 'dynamic-forever-eu'));
  assert.ok(!calls.some((c) => /connected-realm|realm\/index/.test(c.url)), 'keine Realm-Wege mehr');
});

test('Nur Massenware reicht als Treffer', async () => {
  const { r } = await run({ ...RULES, ...HOUSES, ...EMPTY_112, '/data/wow/ruleset/1/auctions/113/commodities': [200, { auctions: [MASS] }, STAMP] });
  assert.equal(r.result, 'auctions');
  assert.equal(r.sample.count, 1);
  assert.deepEqual(r.sample.fields, Object.keys(MASS));
});

test('Listen werden auch unter anderem Namen gefunden', async () => {
  const { r } = await run({ '/data/wow/ruleset/index': [200, { ruleset_list: [{ id: 1, name: 'PvP' }] }], '/data/wow/ruleset/1/auctions/index': [200, { houses: [{ id: 113 }] }],
    '/data/wow/ruleset/1/auctions/113': FULL_113['/data/wow/ruleset/1/auctions/113'] });
  assert.equal(r.result, 'auctions');
});

test('Haeuser ohne Angebote, ohne Antwort, Bereich unbekannt', async () => {
  assert.equal((await run({ ...RULES, ...HOUSES, ...EMPTY_112, '/data/wow/ruleset/1/auctions/113': [200, { id: 113 }] })).r.result, 'empty');
  assert.equal((await run({ ...RULES, ...HOUSES })).r.result, 'no-listings', 'wie Classic Era: Haeuser ja, Angebote 404');
  assert.equal((await run({ ...RULES })).r.result, 'no-auctions');
  assert.equal((await run({})).r.result, 'no-namespace');
  assert.equal((await run({ '/data/wow/ruleset/index': [503, {}] })).r.result, 'network');
  assert.equal((await run({ ...RULES, ...HOUSES, '/data/wow/ruleset/1/auctions/112': [500, {}], '/data/wow/ruleset/1/auctions/112/commodities': [500, {}], '/data/wow/ruleset/1/auctions/113': [500, {}], '/data/wow/ruleset/1/auctions/113/commodities': [500, {}] })).r.result, 'network');
});

test('Zugang falsch, Blizzard nicht erreichbar, unbekannte Region', async () => {
  assert.equal((await run({}, { token: [401, {}] })).r.result, 'bad-key');
  assert.equal((await run({}, { token: [200, {}] })).r.result, 'bad-key');
  assert.equal((await run({}, { token: [503, {}] })).r.result, 'network');
  const r = await probe(KEY, { fetchImpl: async () => { throw new Error('offline'); } });
  assert.equal(r.result, 'network');
  await assert.rejects(probe({ ...KEY, region: 'kr' }), /Unbekannte Region/);
});

test('Anmeldung nutzt den Zugang, Bericht enthaelt weder Zugang noch Token', async () => {
  const { r, calls } = await run({ ...RULES, ...HOUSES, ...EMPTY_112, ...FULL_113 });
  const login = calls[0];
  assert.equal(login.opt.method, 'POST');
  assert.equal(login.opt.headers.Authorization, `Basic ${Buffer.from(`${KEY.clientId}:${KEY.clientSecret}`).toString('base64')}`);
  assert.ok(calls.every((c) => !c.url.includes(KEY.clientSecret) && !c.url.includes(TOKEN)), 'nichts Geheimes in Adressen');
  const text = JSON.stringify(r);
  for (const s of [KEY.clientId, KEY.clientSecret, TOKEN]) assert.ok(!text.includes(s), s);
});

test('Abfrage: Bereich, Region, Anmeldung bleibt gueltig und wird bei Bedarf erneuert', async () => {
  const f = fakeApi({ '/x': [200, { a: 1 }, STAMP] });
  let t = 1000;
  const c = new BlizzardClient(KEY, { ...OPT, now: () => t, fetchImpl: f.fetchImpl });
  const r = await c.get('/x');
  assert.equal(r.status, 200);
  assert.equal(r.lastModified, STAMP);
  assert.equal(r.bytes, JSON.stringify({ a: 1 }).length);
  await c.get('/x', { kind: 'static', region: 'us', since: STAMP });
  const last = f.calls[f.calls.length - 1];
  assert.equal(new URL(last.url).searchParams.get('namespace'), 'static-forever-us');
  assert.equal(last.opt.headers['If-Modified-Since'], STAMP);
  assert.equal(f.calls.filter((x) => x.url.endsWith('/token')).length, 1, 'nur eine Anmeldung');
  t += 4000;
  await c.get('/x');
  assert.equal(f.calls.filter((x) => x.url.endsWith('/token')).length, 2, 'abgelaufen: neu anmelden');
});

test('Abfrage: Antwort 401 meldet einmal neu an und fragt erneut', async () => {
  let first = true;
  const inner = fakeApi({ '/x': [200, { a: 1 }] });
  const fetchImpl = async (url, opt) => {
    if (!String(url).endsWith('/token') && first) { first = false; return { status: 401, ok: false, headers: { get: () => null } }; }
    return inner.fetchImpl(url, opt);
  };
  const r = await new BlizzardClient(KEY, { ...OPT, fetchImpl }).get('/x');
  assert.equal(r.status, 200);
  assert.deepEqual(r.json, { a: 1 });
});

test('Vergleich zweier Staende ueber die Angebotsnummer', () => {
  const a = { id: 1, item: { id: 5 }, buyout: 100, quantity: 1, time_left: 'LONG' };
  const b = { id: 2, item: { id: 5 }, buyout: 100, quantity: 1, time_left: 'SHORT' };
  const c = compareOffers([a, b], [{ ...a, time_left: 'MEDIUM', bid: 7 }, { id: 3, item: { id: 5 }, buyout: 9, quantity: 1, time_left: 'LONG' }]);
  assert.deepEqual({ before: c.before, after: c.after, kept: c.kept, added: c.added, gone: c.gone }, { before: 2, after: 2, kept: 1, added: 1, gone: 1 });
  assert.deepEqual(c.changed, { bid: 1 });
  assert.deepEqual(c.timeLeft, { 'LONG > MEDIUM': 1 });
  assert.equal(c.otherItem, 0);
});

test('Felder und Werte zaehlen, Beispiele begrenzt, haeufigster Stand', () => {
  const offers = Array.from({ length: 8 }, (_, i) => ({ id: i, item: { id: 6611, bonus_lists: [12731, i] }, quantity: i ? 1 : 3, time_left: 'LONG' }));
  const c = addCensus({}, offers);
  assert.equal(c.offers, 8);
  assert.equal(c.itemFields.bonus_lists, 8);
  assert.equal(c.itemExamples.bonus_lists.length, 5);
  assert.equal(c.timeLeft.LONG, 8);
  assert.equal(c.quantityNot1, 1);
  assert.equal(mostCommon(['a', 'b', 'b']), 'b');
});

// Nachgebautes Blizzard fuer den Beobachter: Stand umschaltbar, antwortet auf If-Modified-Since mit 304
function fakeHouses() {
  const world = { stamp: STAMP, offers: [OFFER], broken: false, calls: [] };
  const res = (status, body = {}, stamp = world.stamp) => ({ status, ok: status === 200, headers: { get: (n) => (n.toLowerCase() === 'last-modified' ? stamp : null) }, json: async () => body, text: async () => JSON.stringify(body) });
  const fetchImpl = async (url, opt) => {
    const u = new URL(url);
    world.calls.push(u.pathname);
    if (u.pathname === '/token') return res(200, { access_token: TOKEN, expires_in: 3600 });
    if (u.pathname === '/data/wow/ruleset/index') return res(200, { rulesets: [{ id: 1, name: 'PvP', status: 'UP' }] });
    if (u.pathname === '/data/wow/ruleset/1/auctions/index') return res(200, { auctions: [{ id: 112 }, { id: 113 }] });
    if (u.pathname === '/data/wow/region/index') return res(200, { regions: [{ href: 'r' }] });
    if (u.pathname.startsWith('/data/wow/item/') || u.pathname.startsWith('/data/wow/media/')) return res(200, { id: 2589, name: 'Leinenstoff', sell_price: 13 });
    if (u.pathname.endsWith('/112')) return res(200, { id: 112 });
    if (u.pathname.endsWith('/112/commodities')) return res(200, { auctions: [] });
    if (u.pathname.endsWith('/113/commodities')) {
      const own = world.massStamp || world.stamp;
      if (!world.no304 && opt.headers['If-Modified-Since'] === own) return res(304, {}, own);
      return res(200, { auctions: [MASS] }, own);
    }
    if (u.pathname.endsWith('/113')) {
      if (world.broken) return res(503);
      return res(200, { auctions: world.offers });
    }
    return res(404);
  };
  return { world, fetchImpl };
}

function watcher() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'peon-watch-'));
  const { world, fetchImpl } = fakeHouses();
  const logs = [];
  let t = 2000;
  const w = () => new BlizzardWatch({ client: new BlizzardClient(KEY, { ...OPT, now: () => t, fetchImpl }), dir, now: () => t, log: (ok, text) => logs.push(text) });
  return { dir, world, make: w, logs, step: (s) => { t += s; } };
}

test('Beobachter: erster Lauf holt alle Haeuser, legt sie gepackt ab, dann nur noch kleine Rueckfrage', async () => {
  const { dir, world, make, logs, step } = watcher();
  const w = make();
  assert.equal(await w.tick(), 'new');
  const r = JSON.parse(fs.readFileSync(path.join(dir, 'bericht.json'), 'utf8'));
  assert.equal(r.stands.length, 1);
  assert.equal(r.stands[0].offers, 2);
  assert.equal(r.stands[0].complete, true);
  assert.equal(r.stands[0].sameStamp, true);
  assert.equal(r.lastModified, STAMP);
  assert.equal(r.census.einzeln.offers, 1);
  assert.equal(r.census.masse.timeLeft.SHORT, 1);
  assert.equal(r.once.item.json.name, 'Leinenstoff');
  assert.equal(r.once.regions.us.rulesets, 1);
  assert.equal(r.once.regions.tw.status, 200);
  const stored = JSON.parse(zlib.gunzipSync(fs.readFileSync(path.join(dir, r.lastDir, 'h113-einzeln.json.gz'))));
  assert.equal(stored.auctions[0].id, OFFER.id);
  assert.equal(logs.length, 1);

  world.calls.length = 0;
  step(600);
  assert.equal(await w.tick(), 'same');
  assert.deepEqual(world.calls.filter((p) => p !== '/token'), [`/data/wow/ruleset/1/auctions/${w.report.refHouse}${w.report.refKind === 'masse' ? '/commodities' : ''}`], 'nur eine Abfrage');
  assert.equal(w.report.conditional[304], 1);
  assert.equal(w.report.stands.length, 1);
});

test('Beobachter: neuer Stand vergleicht die Nummern, Abstand steht in der Kurzfassung, alte Staende gehen', async () => {
  const { dir, world, make, step } = watcher();
  const w = make();
  await w.tick();
  world.stamp = STAMP2;
  world.offers = [{ ...OFFER, time_left: 'MEDIUM' }, { ...OFFER, id: 99 }];
  step(3600);
  assert.equal(await w.tick(), 'new');
  assert.deepEqual({ kept: w.report.compare.einzeln.kept, added: w.report.compare.einzeln.added, gone: w.report.compare.einzeln.gone }, { kept: 1, added: 1, gone: 0 });
  assert.equal(w.report.compare.einzeln.timeLeft['LONG > MEDIUM'], 1);
  const s = w.summary();
  assert.equal(s.stands, 2);
  assert.deepEqual(s.gaps, [60]);
  for (let i = 3; i < 8; i++) {
    world.stamp = `Thu, 05 Nov 2026 ${String(7 + i).padStart(2, '0')}:47:00 GMT`;
    step(3600);
    await w.tick();
  }
  assert.equal(fs.readdirSync(dir).filter((n) => n.startsWith('stand-')).length, 4, 'nur die letzten Staende');
});

test('Beobachter: eine Sekunde Unterschied zwischen den Haeusern loest keinen neuen Abruf aus', async () => {
  for (const no304 of [false, true]) {
    const { world, make, step } = watcher();
    world.massStamp = 'Thu, 05 Nov 2026 07:47:01 GMT';
    world.no304 = no304;
    const w = make();
    assert.equal(await w.tick(), 'new');
    assert.equal(w.report.lastModified, STAMP, 'die meisten Haeuser bestimmen den Stand');
    assert.equal(w.report.refStamp, world.massStamp);
    assert.equal(w.report.stands[0].sameStamp, false);
    step(600);
    assert.equal(await w.tick(), 'same', no304 ? 'ohne 304 ueber die Zeit erkannt' : 'mit 304');
    assert.equal(w.report.stands.length, 1);
  }
});

test('Beobachter: fehlt eine Antwort, zaehlt der Stand nicht und wird neu geholt', async () => {
  const { dir, world, make, step } = watcher();
  const w = make();
  world.broken = true;
  assert.equal(await w.tick(), 'error');
  assert.equal(w.report.lastModified, null);
  assert.equal(w.report.lastError.where, 'Stand unvollständig');
  assert.equal(fs.readdirSync(dir).filter((n) => n.startsWith('stand-')).length, 0);
  world.broken = false;
  step(600);
  assert.equal(await w.tick(), 'new');
  assert.equal(w.report.lastError, null);
  assert.equal(w.summary().stands, 1);
});

test('Beobachter: Bericht uebersteht einen Neustart, enthaelt nichts Geheimes', async () => {
  const { dir, world, make, step } = watcher();
  await make().tick();
  world.calls.length = 0;
  const again = make();
  step(600);
  assert.equal(await again.tick(), 'same');
  assert.equal(again.report.checks, 2);
  const text = fs.readFileSync(path.join(dir, 'bericht.json'), 'utf8');
  for (const s of [KEY.clientId, KEY.clientSecret, TOKEN]) assert.ok(!text.includes(s), s);
});

function access(over = {}) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'peon-blz-'));
  // Nachbau der Windows-Verschluesselung: Klartext ist in der Datei nicht lesbar
  const encrypt = (s) => Buffer.from(s, 'utf8').map((b) => b ^ 0x5a);
  const decrypt = (b) => Buffer.from(b).map((x) => x ^ 0x5a).toString('utf8');
  return { dir, a: new BlizzardAccess({ keyFile: path.join(dir, 'k.dat'), reportFile: path.join(dir, 'r.json'), encrypt, decrypt, ...over }) };
}

test('Zugang: nur verschluesselt gespeichert, Zustand ohne Secret, entfernen', () => {
  const { dir, a } = access();
  assert.equal(a.state().saved, false);
  assert.throws(() => a.save({ clientId: 'x' }), /eintragen/);
  assert.throws(() => a.save({ ...KEY, region: 'kr' }), /Region/);
  const st = a.save({ ...KEY, clientSecret: `  ${KEY.clientSecret} ` });
  assert.deepEqual({ saved: st.saved, region: st.region, idEnd: st.idEnd }, { saved: true, region: 'eu', idEnd: '1234' });
  assert.ok(!JSON.stringify(st).includes(KEY.clientSecret), 'Zustand fuer die Oberflaeche ohne Secret');
  assert.ok(!JSON.stringify(st).includes(KEY.clientId));
  const raw = fs.readFileSync(path.join(dir, 'k.dat')).toString('latin1');
  assert.ok(!raw.includes(KEY.clientSecret) && !raw.includes(KEY.clientId), 'Datei ohne Klartext');
  assert.equal(a.load().clientSecret, KEY.clientSecret);
  a.saveReport({ result: 'no-listings' });
  assert.equal(a.clear().saved, false);
  assert.ok(!fs.existsSync(path.join(dir, 'k.dat')));
  assert.equal(a.state().report.result, 'no-listings', 'Bericht bleibt');
});

test('Zugang: ohne Verschluesselung wird nichts gespeichert, fremde Datei gilt als nicht vorhanden', () => {
  const { dir, a } = access({ available: () => false });
  assert.throws(() => a.save(KEY), /nicht verschlüsseln/);
  assert.equal(fs.readdirSync(dir).length, 0);
  const b = access({ decrypt: () => { throw new Error('anderer Rechner'); } });
  fs.writeFileSync(b.a.keyFile, 'irgendwas');
  const st = b.a.state();
  assert.equal(st.saved, false);
  assert.equal(st.unreadable, true);
});
