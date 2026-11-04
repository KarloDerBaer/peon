'use strict';
// Tests fuer den Pruefabruf der Blizzard-API (Forever): nachgebaute Antworten, kein Netz
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { probe, BlizzardAccess } = require('../src/core/blizzard');

const KEY = { clientId: 'meine-id-1234', clientSecret: 'GEHEIM-secret', region: 'eu' };
const TOKEN = 'TOKEN-abc';
const OFFER = { id: 7, item: { id: 2770 }, bid: 100, buyout: 200, quantity: 5, time_left: 'LONG' };

// routes: Pfad -> [Code, Antwort]. Alles andere ist 404.
function fakeApi(routes, { token = [200, { access_token: TOKEN }] } = {}) {
  const calls = [];
  const res = ([status, body]) => ({ status, ok: status >= 200 && status < 300, json: async () => body });
  const fetchImpl = async (url, opt) => {
    calls.push({ url: String(url), opt });
    const u = new URL(url);
    if (u.pathname === '/token') return res(token);
    assert.equal(opt.headers.Authorization, `Bearer ${TOKEN}`);
    assert.equal(u.searchParams.get('namespace'), 'dynamic-forever-eu');
    return res(routes[u.pathname] || [404, { detail: 'Not Found' }]);
  };
  return { fetchImpl, calls };
}
const run = (routes, o) => { const f = fakeApi(routes, o); return probe(KEY, { fetchImpl: f.fetchImpl, now: () => 1000, apiBase: 'https://test.invalid', oauthBase: 'https://test.invalid' }).then((r) => ({ r, calls: f.calls })); };

const REALMS = { '/data/wow/realm/index': [200, { realms: [{ id: 11 }, { id: 12 }] }] };
const GROUPS = { '/data/wow/connected-realm/index': [200, { connected_realms: [{ href: 'https://x/data/wow/connected-realm/500?namespace=y' }] }] };
const HOUSES = { '/data/wow/connected-realm/500/auctions/index': [200, { auctions: [{ id: 2, name: 'Allianz' }, { id: 6, name: 'Horde' }] }] };

test('Auktionsdaten je Auktionshaus: gefunden, mit Beispiel und Feldern', async () => {
  const { r } = await run({ ...REALMS, ...GROUPS, ...HOUSES, '/data/wow/connected-realm/500/auctions/2': [200, { auctions: [OFFER, OFFER, OFFER, OFFER] }] });
  assert.equal(r.result, 'auctions');
  assert.equal(r.sample.house, 2);
  assert.equal(r.sample.count, 4);
  assert.equal(r.sample.offers.length, 3);
  assert.deepEqual(r.sample.fields, Object.keys(OFFER));
  assert.equal(r.steps.find((s) => s.name === 'Realms').note, '2 Realms');
});

test('Aufbau wie Retail: alle Angebote ohne Auktionshaus', async () => {
  const { r } = await run({ ...REALMS, ...GROUPS, '/data/wow/connected-realm/500/auctions': [200, { auctions: [OFFER] }] });
  assert.equal(r.result, 'auctions');
  assert.equal(r.sample.house, null);
});

test('Wie Classic Era: Auktionshaeuser ja, Angebote 404', async () => {
  const { r } = await run({ ...REALMS, ...GROUPS, ...HOUSES });
  assert.equal(r.result, 'no-listings');
  assert.equal(r.steps.find((s) => s.path === '/data/wow/connected-realm/500/auctions/6').status, 404);
});

test('Bereich vorhanden, aber nichts zu Auktionen, Realm-Gruppen fehlen: Realm-Nummern werden probiert', async () => {
  const { r, calls } = await run(REALMS);
  assert.equal(r.result, 'no-auctions');
  assert.ok(calls.some((c) => c.url.includes('/connected-realm/11/auctions/index')));
  assert.ok(calls.some((c) => c.url.includes('/auctions/commodities')));
});

test('Leere Listen sind kein Treffer', async () => {
  const { r } = await run({ ...REALMS, ...GROUPS, ...HOUSES, '/data/wow/connected-realm/500/auctions/2': [200, { auctions: [] }] });
  assert.equal(r.result, 'empty');
  assert.equal(r.sample, null);
});

test('Hoechstens drei Realm-Gruppen', async () => {
  const many = { '/data/wow/connected-realm/index': [200, { connected_realms: [1, 2, 3, 4, 5].map((n) => ({ href: `https://x/connected-realm/${n}` })) }] };
  const { calls } = await run(many);
  assert.equal(calls.filter((c) => /auctions\/index/.test(c.url)).length, 3);
});

test('Bereich unbekannt, Zugang falsch, Blizzard nicht erreichbar', async () => {
  assert.equal((await run({})).r.result, 'no-namespace');
  assert.equal((await run({}, { token: [401, {}] })).r.result, 'bad-key');
  assert.equal((await run({}, { token: [503, {}] })).r.result, 'network');
  const r = await probe(KEY, { fetchImpl: async () => { throw new Error('offline'); } });
  assert.equal(r.result, 'network');
  await assert.rejects(probe({ ...KEY, region: 'kr' }), /Unbekannte Region/);
});

test('Anmeldung nutzt den Zugang, Bericht enthaelt weder Zugang noch Token', async () => {
  const { r, calls } = await run({ ...REALMS, ...GROUPS, ...HOUSES, '/data/wow/connected-realm/500/auctions/2': [200, { auctions: [OFFER] }] });
  const login = calls[0];
  assert.equal(login.opt.method, 'POST');
  assert.equal(login.opt.headers.Authorization, `Basic ${Buffer.from(`${KEY.clientId}:${KEY.clientSecret}`).toString('base64')}`);
  assert.ok(calls.every((c) => !c.url.includes(KEY.clientSecret) && !c.url.includes(TOKEN)), 'nichts Geheimes in Adressen');
  const text = JSON.stringify(r);
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
