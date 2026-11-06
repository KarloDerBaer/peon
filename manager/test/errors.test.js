'use strict';
// Tests fuer den Fehlerspeicher (errors.js): Einlesen aus Kern und BugGrabber, Namen ersetzen, Leeren ueber Data.lua, Senden, Worker
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { Service } = require('../src/core/service');
const { sanitize, privateNames } = require('../src/core/errors');
const { parseLua, toLua } = require('../src/core/lua');

process.removeAllListeners('warning');
const tmp = () => fs.mkdtempSync(path.join(os.tmpdir(), 'peon-err-'));

function setup({ bridge = true, fetchImpl, enable } = {}) {
  const wow = tmp();
  const sv = path.join(wow, 'WTF', 'Account', 'MEINKONTO', 'SavedVariables');
  fs.mkdirSync(sv, { recursive: true });
  fs.mkdirSync(path.join(wow, 'WTF', 'Account', 'MEINKONTO', '93', 'Mira-Dorn'), { recursive: true });
  if (bridge) {
    const d = path.join(wow, 'Interface', 'AddOns', 'Peon_Bridge');
    fs.mkdirSync(d, { recursive: true });
    fs.writeFileSync(path.join(d, 'Peon_Bridge.toc'), 'x');
  }
  const svc = new Service({ dbDir: tmp(), version: '1.2.3', now: () => 5000, fetchImpl, enable });
  svc.saveSettings({ wowDir: wow });
  const stamps = { n: 0 };
  // Spiel schreibt die Datei: Zeit vorstellen, damit der Einleser die Aenderung sieht
  const write = (name, text) => {
    const f = path.join(sv, name);
    fs.writeFileSync(f, text);
    stamps.n += 10;
    const t = new Date(Date.now() + stamps.n * 1000);
    fs.utimesSync(f, t, t);
  };
  const core = (errors) => write('Peon.lua', 'PeonDB = ' + toLua({ errors }));
  const data = () => parseLua(fs.readFileSync(path.join(wow, 'Interface', 'AddOns', 'Peon_Bridge', 'Data.lua'))).PeonBridgeData;
  return { svc, wow, write, core, data };
}

const err = (over = {}) => ({ addon: 'Peon_Tooltip', where: 'Border', msg: 'Style.lua:104: kaputt', version: '0.7.4', build: '60000', first: 1000, last: 1000, n: 2, ...over });

test('Namen und Pfade werden ersetzt', () => {
  const names = ['Mira-Dorn', 'MEINKONTO'];
  const s = sanitize('C:\\Users\\Jemand\\x.lua Mira Dorn Player-6937-003A7824 meinkonto Interface/AddOns/Peon/Core.lua', names);
  assert.equal(s, '<Pfad> <Name> <Spieler> <Name> Interface/AddOns/Peon/Core.lua');
  assert.equal(sanitize('Miradorn', ['Mira']), 'Miradorn', 'nur ganze Woerter');
});

test('privateNames findet Konten und Charaktere', () => {
  const { wow } = setup();
  assert.deepEqual(privateNames(wow).sort(), ['MEINKONTO', 'Mira-Dorn']);
});

test('Kern-Fehler werden eingelesen, zusammengefasst und ohne Namen gespeichert', () => {
  const { svc, core } = setup();
  core([err({ msg: 'Items.lua:5: Fehler bei Mira Dorn' })]);
  assert.equal(svc.errors.scan(), true);
  assert.equal(svc.errors.scan(), false, 'unveraenderte Datei wird nicht neu gelesen');
  core([err({ msg: 'Items.lua:5: Fehler bei Mira Dorn', last: 2000, n: 5 })]);
  svc.errors.scan();
  const rows = svc.errors.rows();
  assert.equal(rows.length, 1);
  assert.equal(rows[0].msg, 'Items.lua:5: Fehler bei <Name>');
  assert.equal(rows[0].last, 2000);
  assert.equal(rows[0].n, 5);
  assert.equal(svc.overview().errorCount, 1);
  svc.close();
});

test('BugGrabber: nur Eintraege mit Peon, ohne locals', () => {
  const { svc, write } = setup();
  write('!BugGrabber.lua', 'BugGrabberDB = ' + toLua({ errors: [
    { message: "[ADDON_ACTION_BLOCKED] AddOn 'Peon_Broker' hat etwas versucht", time: 1500, counter: 2, stack: 'x', locals: 'GEHEIM' },
    { message: "[ADDON_ACTION_BLOCKED] AddOn 'Questie' hat etwas versucht", time: 1500, counter: 1, stack: 'y', locals: 'z' },
    { message: 'Interface/AddOns/Blizzard_X/a.lua:1: kaputt', time: 1600, counter: 1, stack: '[Interface/AddOns/Peon_Bags/Bags.lua]:9: in function', locals: '' },
  ] }));
  svc.errors.scan();
  const rows = svc.errors.rows();
  assert.deepEqual(rows.map((r) => r.addon).sort(), ['Peon_Bags', 'Peon_Broker']);
  assert.ok(!JSON.stringify(rows).includes('GEHEIM'));
  svc.close();
});

test('Leeren: Marke in Data.lua, alte Eintraege kommen nicht zurueck, neuere bleiben', () => {
  const { svc, core, data } = setup();
  core([err()]);
  svc.errors.scan();
  assert.equal(svc.errors.clear(), 1);
  assert.equal(svc.errors.count(), 0);
  assert.equal(data().errorsClearBefore, 1000);
  core([err(), err({ where: 'Icons', first: 1500, last: 1500 })]);
  svc.errors.scan();
  assert.deepEqual(svc.errors.rows().map((r) => r.place), ['Icons']);
  svc.close();
});

test('Leeren mit aktivem Broker Client schreibt Data.lua mit Marke und Kanal', () => {
  const { svc, core, data } = setup({ enable: ['broker-client'] });
  core([err()]);
  svc.errors.scan();
  svc.errors.clear();
  assert.equal(data().errorsClearBefore, 1000);
  assert.equal(data().channels.broker, true);
  svc.close();
});

test('Leeren ohne Bridge: im Manager leer, kein Absturz', () => {
  const { svc, core } = setup({ bridge: false });
  core([err()]);
  svc.errors.scan();
  assert.equal(svc.errors.clear(), 1);
  svc.errors.seen.clear();
  svc.errors.scan();
  assert.equal(svc.errors.count(), 0);
  svc.close();
});

test('Export als Text nennt Addon, Bereich, Anzahl und Fehlertext', () => {
  const { svc, core } = setup();
  assert.equal(svc.errors.exportText(), '');
  core([err()]);
  svc.errors.scan();
  const t = svc.errors.exportText();
  assert.match(t, /Manager 1\.2\.3/);
  assert.match(t, /Peon_Tooltip 0\.7\.4, Border, 2x/);
  assert.match(t, /Style\.lua:104: kaputt/);
  svc.close();
});

test('Senden: leert erst nach Bestaetigung', async () => {
  const calls = [];
  let reply = { ok: false, status: 500 };
  const { svc, core } = setup({ fetchImpl: async (url, o) => { calls.push({ url, body: JSON.parse(o.body) }); return reply; } });
  core([err()]);
  svc.errors.scan();
  await assert.rejects(svc.errors.send(), /noch nicht eingerichtet/);
  assert.equal(calls.length, 0);
  process.env.PEON_MANAGER_REPORT_URL = 'https://test.invalid/bericht';
  try {
    await assert.rejects(svc.errors.send(), /500/);
    assert.equal(svc.errors.count(), 1, 'Fehlschlag behaelt die Fehler');
    reply = { ok: false, status: 429 };
    await assert.rejects(svc.errors.send(), /zu viele/);
    assert.equal(svc.errors.count(), 1);
    reply = { ok: true, status: 200 };
    const r = await svc.errors.send();
    assert.equal(r.sent, 1);
    assert.equal(svc.errors.count(), 0);
    const b = calls[calls.length - 1].body;
    assert.equal(b.fmt, 1);
    assert.equal(b.manager, '1.2.3');
    assert.equal(b.errors[0].where, 'Border');
    assert.ok(!JSON.stringify(b).includes('MEINKONTO'));
  } finally { delete process.env.PEON_MANAGER_REPORT_URL; svc.close(); }
});

test('Bericht bleibt unter der Grenze des Workers', () => {
  const { svc, core } = setup();
  const many = [];
  for (let i = 0; i < 100; i++) many.push(err({ where: `Teil${i}`, msg: 'x'.repeat(1000), last: 1000 + i }));
  core(many);
  svc.errors.scan();
  const r = svc.errors.report();
  assert.ok(Buffer.byteLength(JSON.stringify(r)) < 64 * 1024);
  assert.ok(r.omitted > 0);
  assert.equal(r.errors.length + r.omitted, 100);
  assert.equal(r.errors[0].where, 'Teil99', 'neueste zuerst');
  svc.close();
});

// ---------- Worker ----------
const worker = () => import('../../worker/peon-fehler/worker.mjs');
const ENV = { GITHUB_REPO: 'KarloDerBaer/peon-fehler', GITHUB_TOKEN: 'test' };
const post = (body, ip = '1.2.3.4') => new Request('https://w.invalid/bericht', { method: 'POST', body: typeof body === 'string' ? body : JSON.stringify(body), headers: { 'CF-Connecting-IP': ip } });
const good = () => ({ fmt: 1, manager: '1.2.3', omitted: 0, errors: [{ source: 'peon', addon: 'Peon_Tooltip', version: '0.7.4', build: '1', where: 'Border', msg: 'kaputt', stack: '', first: 1, last: 2, n: 3 }] });
function fakeCache() {
  const m = new Map();
  return { match: async (k) => (m.has(k.url) ? new Response(m.get(k.url)) : undefined), put: async (k, r) => { m.set(k.url, await r.text()); } };
}

test('Worker: legt ein Issue an und gibt die Nummer zurueck', async () => {
  const { handle } = await worker();
  const seen = [];
  const fetchImpl = async (url, o) => { seen.push({ url, o }); return new Response(JSON.stringify({ number: 7 }), { status: 201 }); };
  const res = await handle(post(good()), ENV, { fetchImpl, cache: fakeCache() });
  assert.equal(res.status, 200);
  assert.deepEqual(await res.json(), { ok: true, number: 7 });
  assert.equal(seen[0].url, 'https://api.github.com/repos/KarloDerBaer/peon-fehler/issues');
  assert.equal(seen[0].o.headers.Authorization, 'Bearer test');
  const issue = JSON.parse(seen[0].o.body);
  assert.equal(issue.title, 'Peon_Tooltip 0.7.4: Border');
  assert.match(issue.body, /kaputt/);
});

test('Worker: lehnt Falsches ab, ohne GitHub zu fragen', async () => {
  const { handle } = await worker();
  let calls = 0;
  const opt = { fetchImpl: async () => { calls++; return new Response('{}'); }, cache: fakeCache() };
  assert.equal((await handle(new Request('https://w.invalid/bericht'), ENV, opt)).status, 404);
  assert.equal((await handle(new Request('https://w.invalid/anders', { method: 'POST', body: '{}' }), ENV, opt)).status, 404);
  assert.equal((await handle(post('kein json'), ENV, opt)).status, 400);
  assert.equal((await handle(post({ fmt: 2, errors: [] }), ENV, opt)).status, 400);
  assert.equal((await handle(post({ ...good(), errors: [{ addon: 'Fremd', msg: 'x' }] }), ENV, opt)).status, 400);
  assert.equal((await handle(post('x'.repeat(70000)), ENV, opt)).status, 413);
  assert.equal(calls, 0);
});

test('Worker: bremst zu viele Berichte und meldet Fehler von GitHub', async () => {
  const { handle } = await worker();
  const opt = { fetchImpl: async () => new Response(JSON.stringify({ number: 1 })), cache: fakeCache() };
  for (let i = 0; i < 5; i++) assert.equal((await handle(post(good()), ENV, opt)).status, 200);
  assert.equal((await handle(post(good()), ENV, opt)).status, 429);
  assert.equal((await handle(post(good(), '9.9.9.9'), ENV, opt)).status, 200, 'andere Adresse geht noch');
  const down = { fetchImpl: async () => new Response('', { status: 500 }), cache: fakeCache() };
  assert.equal((await handle(post(good()), ENV, down)).status, 502);
});

test('Worker: Fehlertext kann den Codeblock nicht verlassen', async () => {
  const { buildIssue, cleanReport } = await worker();
  const r = good();
  r.errors[0].msg = '```\n@jemand <b>x</b>';
  r.errors[0].where = 'Bor`der @jemand';
  const issue = buildIssue(cleanReport(r));
  assert.equal(issue.body.match(/```/g).length, 2);
  assert.ok(!issue.title.includes('@'));
  assert.ok(!issue.title.includes('`'));
});
