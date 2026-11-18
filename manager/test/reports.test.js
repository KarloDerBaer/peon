'use strict';
// Tests fuer Rueckmeldungen und Fehler (reports.js) und den Worker: Einlesen, Uebergabe ans Spiel, Bearbeiten im Manager, Senden
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { Service } = require('../src/core/service');
const { sanitize, privateNames, MAX_ITEMS } = require('../src/core/reports');
const { parseLua, toLua } = require('../src/core/lua');

process.removeAllListeners('warning');
const tmp = () => fs.mkdtempSync(path.join(os.tmpdir(), 'peon-rep-'));

function setup({ bridge = true, fetchImpl, enable } = {}) {
  const wow = tmp();
  const sv = path.join(wow, 'WTF', 'Account', 'MEINKONTO', 'SavedVariables');
  fs.mkdirSync(sv, { recursive: true });
  fs.mkdirSync(path.join(wow, 'WTF', 'Account', 'MEINKONTO', '93', 'Mira-Dorn'), { recursive: true });
  const addon = (n, v) => {
    const d = path.join(wow, 'Interface', 'AddOns', n);
    fs.mkdirSync(d, { recursive: true });
    fs.writeFileSync(path.join(d, `${n}.toc`), `## Title: x\n## Version: ${v}\n`);
  };
  addon('Peon', '0.13.0');
  addon('Peon_Tooltip', '0.7.4');
  if (bridge) addon('Peon_Bridge', '0.5.0');
  const svc = new Service({ dbDir: tmp(), version: '1.2.3', now: () => 5000, fetchImpl, enable });
  svc.saveSettings({ wowDir: wow });
  let tick = 0;
  // Spiel schreibt die Datei: Zeit vorstellen, damit der Einleser die Aenderung sieht
  const write = (name, body) => {
    const f = path.join(sv, name);
    fs.writeFileSync(f, body);
    tick += 10;
    const t = new Date(Date.now() + tick * 1000);
    fs.utimesSync(f, t, t);
  };
  const core = (errors, extra = {}) => write('Peon.lua', `PeonDB = ${toLua({ errors, ...extra })}`);
  const game = (entries) => write('Peon_Feedback.lua', `PeonFeedbackDB = ${toLua({ entries })}`);
  const data = () => parseLua(fs.readFileSync(path.join(wow, 'Interface', 'AddOns', 'Peon_Bridge', 'Data.lua'))).PeonBridgeData;
  return { svc, wow, core, game, write, data, rep: svc.reports };
}

const err = (over = {}) => ({ addon: 'Peon_Tooltip', where: 'Border', msg: 'Style.lua:104: kaputt', version: '0.7.4', build: '60000', first: 1000, last: 1000, n: 2, ...over });
const entry = (over = {}) => ({ id: 1, t: 2000, module: 'Peon_Tooltip', kind: 'idea', area: 'Rahmenfarbe', prio: 'high', text: 'Bitte blauer', char: 'Mira Dorn', market: 'Reich / Alliance', zone: 'Dun Morogh', ver: '0.7.4', ...over });
const mine = (over = {}) => ({ module: 'Peon_Manager', kind: 'bug', area: 'Module', prio: 'mid', text: 'Knopf klemmt', ...over });

test('Namen und Pfade werden ersetzt', () => {
  const s = sanitize('C:\\Users\\Jemand\\x.lua Mira Dorn Player-6937-003A7824 meinkonto Interface/AddOns/Peon/Core.lua', ['Mira-Dorn', 'MEINKONTO']);
  assert.equal(s, '<Pfad> <Name> <Spieler> <Name> Interface/AddOns/Peon/Core.lua');
  assert.equal(sanitize('Miradorn', ['Mira']), 'Miradorn', 'nur ganze Woerter');
});

test('privateNames findet Konten und Charaktere', () => {
  const { wow, svc } = setup();
  assert.deepEqual(privateNames(wow).sort(), ['MEINKONTO', 'Mira-Dorn']);
  svc.close();
});

test('Fehler werden eingelesen, ohne Namen gespeichert, Marke steht in Data.lua', () => {
  const { svc, rep, core, data } = setup();
  core([err({ msg: 'Items.lua:5: Fehler bei Mira Dorn' })]);
  assert.equal(rep.scan(), true);
  assert.equal(rep.scan(), false, 'unveraenderte Datei wird nicht neu gelesen');
  const r = rep.errorRows();
  assert.equal(r.length, 1);
  assert.equal(r[0].msg, 'Items.lua:5: Fehler bei <Name>');
  assert.equal(data().errorsClearBefore, 1000);
  assert.equal(svc.overview().reportCount, 1);
  svc.close();
});

test('Anzahl: Zuwachs wird addiert, auch nach dem Loeschen im Spiel, Notiz bleibt', () => {
  const { svc, rep, core } = setup();
  core([err({ n: 2 })]);
  rep.scan();
  const key = rep.errorRows()[0].key;
  rep.setNote(key, 'beim Ueberfahren');
  core([err({ n: 5, last: 1100 })]);        // gleiche Sitzung, Zaehler laeuft weiter
  rep.scan();
  assert.equal(rep.errorRows()[0].n, 5);
  core([err({ n: 1, first: 2000, last: 2000 })]);   // Spiel hat geloescht, neuer Eintrag beginnt bei 1
  rep.scan();
  const r = rep.errorRows()[0];
  assert.equal(r.n, 6);
  assert.equal(r.note, 'beim Ueberfahren');
  svc.close();
});

test('Geloeschter Fehler bleibt weg, tritt er neu auf, kommt er zurueck', () => {
  const { svc, rep, core } = setup();
  core([err()]);
  rep.scan();
  rep.deleteError(rep.errorRows()[0].key);
  core([err()]);
  rep.scan();
  assert.equal(rep.errorRows().length, 0, 'gleicher Stand aus der Datei kommt nicht zurueck');
  core([err({ last: 3000, n: 3 })]);
  rep.scan();
  assert.equal(rep.errorRows().length, 1);
  svc.close();
});

test('BugGrabber: nur Eintraege mit Peon, ohne locals', () => {
  const { svc, rep, write } = setup();
  write('!BugGrabber.lua', `BugGrabberDB = ${toLua({ errors: [
    { message: "[ADDON_ACTION_BLOCKED] AddOn 'Peon_Broker' hat etwas versucht", time: 1500, counter: 2, stack: 'x', locals: 'GEHEIM' },
    { message: "[ADDON_ACTION_BLOCKED] AddOn 'Questie' hat etwas versucht", time: 1500, counter: 1, stack: 'y', locals: 'z' },
    { message: 'Interface/AddOns/Blizzard_X/a.lua:1: kaputt', time: 1600, counter: 1, stack: '[Interface/AddOns/Peon_Bags/Bags.lua]:9: in function', locals: '' },
  ] })}`);
  rep.scan();
  assert.deepEqual(rep.errorRows().map((r) => r.addon).sort(), ['Peon_Bags', 'Peon_Broker']);
  assert.ok(!JSON.stringify(rep.errorRows()).includes('GEHEIM'));
  svc.close();
});

test('Rueckmeldung aus dem Spiel: ohne Charakter, Marke in Data.lua, Aenderung im Spiel kommt an', () => {
  const { svc, rep, game, data } = setup();
  game([entry({ text: 'Mira Dorn findet das blau' })]);
  rep.scan();
  const r = rep.feedbackRows();
  assert.equal(r.length, 1);
  assert.equal(r[0].origin, 'game');
  assert.equal(r[0].text, '<Name> findet das blau');
  assert.ok(!JSON.stringify(r).includes('Mira'));
  assert.equal(data().feedbackClearBefore, 2000);
  game([entry({ text: 'jetzt anders', edited: 2500 })]);
  rep.scan();
  assert.equal(rep.feedbackRows().length, 1);
  assert.equal(rep.feedbackRows()[0].text, 'jetzt anders');
  svc.close();
});

test('Aenderung im Manager bleibt, der alte Stand aus dem Spiel ueberschreibt sie nicht', () => {
  const { svc, rep, game } = setup();
  game([entry()]);
  rep.scan();
  const { key } = rep.feedbackRows()[0];
  rep.updateFeedback(key, { ...mine(), module: 'Peon_Tooltip', text: 'im Manager geaendert' });
  game([entry()]);
  rep.scan();
  assert.equal(rep.feedbackRows()[0].text, 'im Manager geaendert');
  rep.deleteFeedback(key);
  game([entry()]);
  rep.scan();
  assert.equal(rep.feedbackRows().length, 0, 'im Manager Geloeschtes kommt nicht zurueck');
  svc.close();
});

test('Rueckmeldung im Manager: anlegen, pruefen, Version des Moduls, aendern, loeschen', () => {
  const { svc, rep } = setup();
  assert.throws(() => rep.addFeedback(mine({ text: '   ' })), /Beschreibung/);
  assert.throws(() => rep.addFeedback(mine({ module: 'Fremd' })), /Modul/);
  assert.throws(() => rep.addFeedback(mine({ kind: 'x' })), /Art/);
  const key = rep.addFeedback(mine());
  assert.equal(rep.feedbackRows()[0].ver, '1.2.3', 'Version des Managers');
  rep.updateFeedback(key, mine({ module: 'Peon_Tooltip', text: 'anders' }));
  assert.equal(rep.feedbackRows()[0].ver, '0.7.4', 'Version folgt dem Modul');
  assert.equal(rep.feedbackRows()[0].origin, 'manager');
  assert.throws(() => rep.updateFeedback('gibtsnicht', mine()), /nicht mehr/);
  rep.deleteFeedback(key);
  assert.equal(rep.count(), 0);
  svc.close();
});

test('Auswahl: Manager und Kern zuerst, Bereiche aus PeonDB, immer mit Sonstiges', () => {
  const { svc, rep, core } = setup();
  core([], { feedbackAreas: { Peon_Tooltip: ['Rahmenfarbe', 'Optionen'] } });
  const m = rep.state().modules;
  assert.deepEqual(m.map((x) => x.key), ['Peon_Manager', 'Peon', 'Peon_Bridge', 'Peon_Tooltip']);
  assert.deepEqual(m[3].areas, ['Rahmenfarbe', 'Optionen', 'Sonstiges']);
  assert.deepEqual(m[1].areas, ['Sonstiges'], 'ohne gemeldete Bereiche');
  assert.ok(m[0].areas.includes('Rückmeldungen'));
  svc.close();
});

test('Ohne Bridge kein Absturz, Hinweis im Zustand', () => {
  const { svc, rep, core } = setup({ bridge: false });
  core([err()]);
  const s = rep.state();
  assert.equal(s.errors.length, 1);
  assert.equal(s.bridge, false);
  svc.close();
});

test('Mit aktivem Broker Client: Marken und Kanal in Data.lua', () => {
  const { svc, rep, core, game, data } = setup({ enable: ['broker-client'] });
  core([err()]);
  game([entry()]);
  rep.scan();
  assert.equal(data().errorsClearBefore, 1000);
  assert.equal(data().feedbackClearBefore, 2000);
  assert.equal(data().channels.broker, true);
  svc.close();
});

test('Senden: aelteste zuerst, Notiz dabei, Namen ersetzt, nur Bestaetigtes wird geloescht', async () => {
  const calls = [];
  let reply = { ok: false, status: 500 };
  const { svc, rep, core } = setup({ fetchImpl: async (url, o) => { calls.push({ url, body: JSON.parse(o.body) }); return reply; } });
  core([err()]);
  rep.scan();
  rep.setNote(rep.errorRows()[0].key, 'passierte bei Mira Dorn');
  rep.addFeedback(mine({ text: 'von meinkonto geschrieben' }));
  process.env.PEON_MANAGER_REPORT_URL = '';
  try {
    assert.equal(rep.state().canSend, false);
    await assert.rejects(rep.send(), /nicht eingerichtet/);
    process.env.PEON_MANAGER_REPORT_URL = 'https://test.invalid/bericht';
    await assert.rejects(rep.send(), /500/);
    assert.equal(rep.count(), 2, 'Fehlschlag behaelt alles');
    reply = { ok: false, status: 429 };
    await assert.rejects(rep.send(), /später/);
    const b = calls[0].body;
    assert.equal(b.fmt, 2);
    assert.equal(b.manager, '1.2.3');
    assert.deepEqual(b.items.map((i) => i.type), ['error', 'feedback'], 'aeltester zuerst');
    assert.equal(b.items[0].note, 'passierte bei <Name>');
    assert.equal(b.items[1].text, 'von <Name> geschrieben');
    assert.ok(!JSON.stringify(b).includes('MEINKONTO'));
    assert.match(rep.preview().text, /Notiz: passierte bei <Name>/);

    reply = { ok: true, status: 200, json: async () => ({ ok: false, done: [0] }) };   // nur der erste kam an
    const r = await rep.send();
    assert.equal(r.sent, 1);
    assert.equal(r.failed, 1);
    assert.equal(rep.errorRows().length, 0);
    assert.equal(rep.feedbackRows().length, 1);
    reply = { ok: true, status: 200, json: async () => ({ ok: true, done: [0] }) };
    await rep.send();
    assert.equal(rep.count(), 0);
    await assert.rejects(rep.send(), /nichts zu senden/);
  } finally { delete process.env.PEON_MANAGER_REPORT_URL; svc.close(); }
});

test('Absender-Kennung (ab 0.49.0): zufaellig, bleibt gleich, geht mit, neu auf Wunsch', async () => {
  const calls = [];
  const { svc, rep } = setup({ fetchImpl: async (url, o) => { calls.push(JSON.parse(o.body)); return { ok: true, status: 200, json: async () => ({ done: [0] }) }; } });
  rep.addFeedback(mine());
  assert.equal(rep.state().preview.sender, null, 'vor dem ersten Senden noch keine Kennung');
  process.env.PEON_MANAGER_REPORT_URL = 'https://test.invalid/bericht';
  try {
    await rep.send();
    const id = calls[0].sender;
    assert.match(id, /^[0-9a-f]{8}$/);
    assert.equal(svc.settings.senderId, id, 'in den Einstellungen gemerkt');
    assert.equal(rep.state().preview.sender, id, 'Vorschau zeigt die Kennung');
    rep.addFeedback(mine({ text: 'zweite' }));
    await rep.send();
    assert.equal(calls[1].sender, id, 'gleiche Kennung beim naechsten Senden');
    const neu = rep.newSenderId();
    assert.match(neu, /^[0-9a-f]{8}$/);
    assert.notEqual(neu, id);
    rep.addFeedback(mine({ text: 'dritte' }));
    await rep.send();
    assert.equal(calls[2].sender, neu, 'neue Kennung geht mit');
    svc.saveSettings({ senderId: 'kaputt!' });
    assert.equal(rep.senderId(false), null, 'ungueltige Kennung gilt nicht');
  } finally { process.env.PEON_MANAGER_REPORT_URL = ''; }
  svc.close();
});

test('Senden: hoechstens 20 und unter der Grenze des Workers, der Rest bleibt', () => {
  const { svc, rep, core } = setup();
  const many = [];
  for (let i = 0; i < 30; i++) many.push(err({ where: `Teil${i}`, msg: 'x'.repeat(1000), last: 1000 + i }));
  core(many);
  rep.scan();
  let n = rep.nextItems();
  assert.equal(n.next.length, MAX_ITEMS);
  assert.equal(n.left, 10);
  assert.equal(n.next[0].item.where, 'Teil0', 'aelteste zuerst');
  for (const r of rep.errorRows()) rep.setNote(r.key, 'n'.repeat(2000));
  n = rep.nextItems();
  assert.ok(Buffer.byteLength(JSON.stringify(n.next.map((e) => e.item))) < 64 * 1024);
  assert.ok(n.next.length < MAX_ITEMS && n.next.length > 0);
  svc.close();
});

test('Alles loeschen', () => {
  const { svc, rep, core } = setup();
  core([err()]);
  rep.scan();
  rep.addFeedback(mine());
  assert.equal(rep.deleteAll(), 2);
  assert.equal(rep.count(), 0);
  svc.close();
});

// ---------- Worker ----------
const worker = () => import('../../worker/peon-fehler/worker.mjs');
const ENV = { GITHUB_REPO: 'KarloDerBaer/peon-fehler', GITHUB_TOKEN: 'test' };
const post = (body, ip = '1.2.3.4') => new Request('https://w.invalid/bericht', { method: 'POST', body: typeof body === 'string' ? body : JSON.stringify(body), headers: { 'CF-Connecting-IP': ip } });
const errItem = (over = {}) => ({ type: 'error', ref: 0, source: 'peon', addon: 'Peon_Tooltip', version: '0.7.4', build: '1', where: 'Border', msg: 'kaputt', stack: '', note: 'beim Kampf', first: 1, last: 2, n: 3, ...over });
const fbItem = (over = {}) => ({ type: 'feedback', ref: 1, module: 'Peon_Broker', kind: 'idea', prio: 'high', area: 'Radar', text: 'Bitte sortierbar machen', version: '0.33.1', zone: 'Sturmwind', market: 'Reich / Alliance', origin: 'game', t: 5, ...over });
const good = (items = [errItem(), fbItem()]) => ({ fmt: 2, manager: '1.2.3', items });
function fakeCache() {
  const m = new Map();
  return { match: async (k) => (m.has(k.url) ? new Response(m.get(k.url)) : undefined), put: async (k, r) => { m.set(k.url, await r.text()); } };
}

test('Worker: je Eintrag ein Issue mit Label, Nummern und Bestaetigung zurueck', async () => {
  const { handle } = await worker();
  const seen = [], searched = [];
  const fetchImpl = async (url, o) => {
    if (o.method === 'GET') { searched.push(url); return new Response(JSON.stringify({ items: [] })); }
    seen.push({ url, o, issue: JSON.parse(o.body) }); return new Response(JSON.stringify({ number: 6 + seen.length }), { status: 201 });
  };
  const res = await handle(post(good()), ENV, { fetchImpl, cache: fakeCache() });
  assert.equal(res.status, 200);
  assert.deepEqual(await res.json(), { ok: true, done: [0, 1], numbers: [7, 8] });
  assert.equal(searched.length, 1, 'nur der Fehler wird gesucht, die Rueckmeldung nicht');
  assert.match(decodeURIComponent(searched[0]), /^https:\/\/api\.github\.com\/search\/issues\?q=repo:KarloDerBaer\/peon-fehler is:issue is:open in:body "peon-key: [0-9a-f]{16}"/);
  assert.match(seen[0].issue.body, /\n\npeon-key: [0-9a-f]{16}$/);
  assert.equal(seen[0].url, 'https://api.github.com/repos/KarloDerBaer/peon-fehler/issues');
  assert.equal(seen[0].o.headers.Authorization, 'Bearer test');
  assert.equal(seen[0].issue.title, 'Peon_Tooltip 0.7.4: Border');
  assert.deepEqual(seen[0].issue.labels, ['fehler']);
  assert.match(seen[0].issue.body, /Notiz:\nbeim Kampf/);
  assert.equal(seen[1].issue.title, '[Neue Idee] Broker: Bitte sortierbar machen');
  assert.deepEqual(seen[1].issue.labels, ['idee']);
  assert.match(seen[1].issue.body, /Priorität Hoch/);
  assert.match(seen[1].issue.body, /Markt: Reich \/ Alliance/);
  assert.match(seen[0].issue.body, /^Peon Manager 1\.2\.3\n/, 'ohne Kennung kein Absender');
});

test('Worker: Absender-Kennung im Issue und im Kommentar, falsche Kennung weggelassen', async () => {
  const { handle, cleanReport, buildComment } = await worker();
  const seen = [];
  const fetchImpl = async (url, o) => { if (o.method === 'GET') return new Response(JSON.stringify({ items: [] })); seen.push(JSON.parse(o.body)); return new Response(JSON.stringify({ number: 3 }), { status: 201 }); };
  await handle(post({ ...good([fbItem()]), sender: 'a1b2c3d4' }), ENV, { fetchImpl, cache: fakeCache() });
  assert.match(seen[0].body, /^Peon Manager 1\.2\.3 · Absender a1b2c3d4\n/);
  assert.equal(cleanReport({ ...good(), sender: '<b>@x</b>' }).sender, '');
  assert.equal(cleanReport({ ...good(), sender: 'A1B2C3D4' }).sender, '', 'nur Kleinbuchstaben und Ziffern');
  assert.match(buildComment(errItem(), '1.2.3', 'a1b2c3d4').body, /Wieder gemeldet von Peon Manager 1\.2\.3 \(Absender a1b2c3d4\)/);
});

test('Worker: scheitert GitHub mittendrin, wird nur Angelegtes bestaetigt', async () => {
  const { handle } = await worker();
  let calls = 0;
  const fetchImpl = async (url, o) => {
    if (o.method === 'GET') return new Response(JSON.stringify({ items: [] }));
    calls++; return calls === 1 ? new Response(JSON.stringify({ number: 1 })) : new Response('', { status: 500 });
  };
  const res = await handle(post(good()), ENV, { fetchImpl, cache: fakeCache() });
  assert.equal(res.status, 200);
  assert.deepEqual(await res.json(), { ok: false, done: [0], numbers: [1] });
  const down = { fetchImpl: async () => new Response('', { status: 500 }), cache: fakeCache() };
  assert.equal((await handle(post(good()), ENV, down)).status, 502);
});

test('Worker: lehnt Falsches ab, ohne GitHub zu fragen', async () => {
  const { handle } = await worker();
  let calls = 0;
  const opt = { fetchImpl: async () => { calls++; return new Response('{}'); }, cache: fakeCache() };
  const st = async (r) => (await handle(r, ENV, opt)).status;
  assert.equal(await st(new Request('https://w.invalid/bericht')), 404);
  assert.equal(await st(new Request('https://w.invalid/anders', { method: 'POST', body: '{}' })), 404);
  assert.equal(await st(post('kein json')), 400);
  assert.equal(await st(post({ fmt: 1, errors: [] })), 400);
  assert.equal(await st(post(good([]))), 400);
  assert.equal(await st(post(good([errItem({ addon: 'Fremd' })]))), 400);
  assert.equal(await st(post(good([fbItem({ kind: 'quatsch' })]))), 400);
  assert.equal(await st(post(good([fbItem({ text: '  ' })]))), 400);
  assert.equal(await st(post(good(Array.from({ length: 21 }, (_, i) => errItem({ ref: i }))))), 400);
  assert.equal(await st(post('x'.repeat(70000))), 413);
  assert.equal(calls, 0);
});

test('Worker: bremst zu viele Eintraege (nicht Sendungen)', async () => {
  const { handle } = await worker();
  const opt = { fetchImpl: async () => new Response(JSON.stringify({ number: 1 })), cache: fakeCache() };
  for (let i = 0; i < 10; i++) assert.equal((await handle(post(good()), ENV, opt)).status, 200, '10 Sendungen mit je 2 Eintraegen = 20');
  assert.equal((await handle(post(good()), ENV, opt)).status, 429);
  assert.equal((await handle(post(good(), '9.9.9.9'), ENV, opt)).status, 200, 'andere Adresse geht noch');
  const opt2 = { fetchImpl: opt.fetchImpl, cache: fakeCache() };
  const voll = good(Array.from({ length: 20 }, (_, i) => errItem({ ref: i, msg: `kaputt ${i}` })));
  assert.equal((await handle(post(voll, '5.5.5.5'), ENV, opt2)).status, 200);
  assert.equal((await handle(post(good([errItem()]), '5.5.5.5'), ENV, opt2)).status, 429, 'eine volle Sendung braucht die Stunde einer Adresse auf');
  for (const ip of ['6.6.6.6', '7.7.7.7']) assert.equal((await handle(post(voll, ip), ENV, opt2)).status, 200);
  assert.equal((await handle(post(good([errItem()]), '8.8.8.8'), ENV, opt2)).status, 429, 'insgesamt hoechstens 60 Eintraege je Stunde');
});

test('Worker: gleicher Fehler kommt als Kommentar an das offene Issue', async () => {
  const { handle, errorKey } = await worker();
  const calls = [];
  let openIssue = null;
  const fetchImpl = async (url, o) => {
    calls.push({ url, method: o.method, body: o.body ? JSON.parse(o.body) : null });
    if (o.method === 'GET') return new Response(JSON.stringify({ items: openIssue ? [{ number: openIssue }] : [] }));
    return new Response(JSON.stringify({ number: 41 }), { status: 201 });
  };
  // 1. Suche findet ein offenes Issue: Kommentar statt neuem Issue
  openIssue = 12;
  let res = await handle(post(good([errItem({ version: '0.7.5', n: 4 })])), ENV, { fetchImpl, cache: fakeCache() });
  assert.deepEqual(await res.json(), { ok: true, done: [0], numbers: [12] });
  const post1 = calls.filter((c) => c.method === 'POST');
  assert.equal(post1.length, 1);
  assert.equal(post1[0].url, 'https://api.github.com/repos/KarloDerBaer/peon-fehler/issues/12/comments');
  assert.match(post1[0].body.body, /Wieder gemeldet von Peon Manager 1\.2\.3: Peon_Tooltip 0\.7\.5 \| 4x/);
  assert.match(post1[0].body.body, /Notiz:\nbeim Kampf/);
  // 2. Neues Issue, danach findet der Worker es ueber seinen Cache (die Suche von GitHub kennt es noch nicht)
  calls.length = 0; openIssue = null;
  const cache = fakeCache();
  res = await handle(post(good([errItem(), errItem({ ref: 1, version: '0.7.6' })])), ENV, { fetchImpl, cache });
  assert.deepEqual(await res.json(), { ok: true, done: [0, 1], numbers: [41, 41] });
  const posts = calls.filter((c) => c.method === 'POST').map((c) => c.url);
  assert.deepEqual(posts, ['https://api.github.com/repos/KarloDerBaer/peon-fehler/issues', 'https://api.github.com/repos/KarloDerBaer/peon-fehler/issues/41/comments']);
  // 3. Kennung: Version egal, andere Meldung oder Stelle ergibt eine andere Kennung
  const k = await errorKey(errItem());
  assert.equal(await errorKey(errItem({ version: '9.9.9', n: 99 })), k);
  assert.notEqual(await errorKey(errItem({ msg: 'anders' })), k);
  assert.notEqual(await errorKey(errItem({ where: 'Anders' })), k);
  // 4. Suche gescheitert: lieber ein neues Issue als gar keins
  const down = async (url, o) => (o.method === 'GET' ? new Response('', { status: 403 }) : new Response(JSON.stringify({ number: 50 }), { status: 201 }));
  res = await handle(post(good([errItem()])), ENV, { fetchImpl: down, cache: fakeCache() });
  assert.deepEqual(await res.json(), { ok: true, done: [0], numbers: [50] });
});

test('Worker: Text kann den Codeblock nicht verlassen und niemanden benachrichtigen', async () => {
  const { buildIssue, cleanReport } = await worker();
  const r = cleanReport(good([errItem({ msg: '```\n@jemand <b>x</b>', note: '``` @noch', where: 'Bor`der @jemand' }), fbItem({ text: '@jemand ``` schau **hier**' })]));
  const a = buildIssue(r.items[0], '1'), b = buildIssue(r.items[1], '1');
  for (const i of [a, b]) {
    assert.equal(i.body.match(/```/g).length, 2);
    assert.ok(!i.title.includes('@') && !i.title.includes('`') && !i.title.includes('*'));
  }
});
