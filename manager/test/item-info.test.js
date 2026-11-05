'use strict';
// Tests fuer die Gegenstandsdaten: Antworten im Aufbau des Pruefabrufs vom 05.11.2026, kein Netz
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { DatabaseSync } = require('node:sqlite');
const { openDb } = require('../src/core/db');
const { ItemInfo, toTip, FRESH, NONE_RETRY } = require('../src/core/item-info');

const HELM = { id: 12640, name: 'Löwenherzhelm', quality: { type: 'EPIC' }, sell_price: 21894, preview_item: {
  quality: { type: 'EPIC' }, name: 'Löwenherzhelm', item_subclass: { name: 'Platte' }, inventory_type: { type: 'HEAD', name: 'Kopf' },
  binding: { name: 'Wird beim Anlegen gebunden' }, armor: { display: { display_string: '565 Rüstung', color: { r: 255, g: 255, b: 255 } } },
  stats: [{ display: { display_string: '+18 Stärke', color: { r: 255, g: 255, b: 255 } } }, { is_equip_bonus: true, display: { display_string: '+20 Trefferwert', color: { r: 0, g: 255, b: 0 } } }],
  sell_price: { value: 21894 }, requirements: { level: { display_string: 'Benötigt Stufe 56' } }, level: { display_string: 'Gegenstandsstufe 61' }, durability: { display_string: 'Haltbarkeit 100 / 100' } } };
const CLOTH = { id: 2589, name: 'Leinenstoff', quality: { type: 'COMMON' }, sell_price: 13, preview_item: { inventory_type: { type: 'NON_EQUIP', name: 'Nicht anlegbar' }, item_subclass: { name: 'Stoff' }, is_subclass_hidden: true, sell_price: { value: 13 }, crafting_reagent: 'Handwerksmaterial' } };

const texts = (t) => t.lines.map((l) => l.l);

test('Tooltip einer Ruestung: Zeilen in der Reihenfolge des Spiels, Boni gruen', () => {
  const t = toTip(HELM, 'forever');
  assert.equal(t.name, 'Löwenherzhelm');
  assert.equal(t.quality, 4);
  assert.equal(t.sell, 21894);
  assert.deepEqual(texts(t), ['Gegenstandsstufe 61', 'Wird beim Anlegen gebunden', 'Kopf', '565 Rüstung', '+18 Stärke', '+20 Trefferwert', 'Benötigt Stufe 56', 'Haltbarkeit 100 / 100']);
  assert.equal(t.lines[2].r, 'Platte');
  assert.equal(t.lines[4].c, undefined);
  assert.equal(t.lines[5].c, 'good');
});

test('Tooltip einer Waffe mit Effekt, Aufladungen und Set', () => {
  const t = toTip({ name: 'Klinge', preview_item: {
    item_subclass: { name: 'Streitkolben' }, inventory_type: { type: 'TWOHWEAPON', name: 'Zweihändig' },
    weapon: { damage: { display_string: '46 - 70 Schaden' }, attack_speed: { display_string: 'Tempo 2,00' }, dps: { display_string: '(29,0 Schaden pro Sekunde)' } },
    spells: [{ description: 'Benutzen: Erhöht Euer Angriffstempo.' }], charges: { display_string: '3 Aufladungen' },
    requirements: { level: { display_string: 'Benötigt Stufe 29' }, playable_classes: { display_string: 'Klassen: Magier' } },
    set: { display_string: 'Ornat (0/8)', effects: [{ display_string: '(3) Set: Mehr Schaden.' }] } } }, 'forever');
  assert.equal(t.lines.find((l) => l.l === '46 - 70 Schaden').r, 'Tempo 2,00');
  assert.ok(texts(t).includes('(29,0 Schaden pro Sekunde)') && texts(t).includes('3 Aufladungen') && texts(t).includes('Klassen: Magier'));
  assert.equal(t.lines.find((l) => l.l.startsWith('Benutzen')).c, 'good');
  assert.equal(t.lines.find((l) => l.l === 'Ornat (0/8)').c, 'set');
  assert.equal(t.lines.find((l) => l.l.startsWith('(3)')).c, 'muted');
});

test('Tooltip von Handwerkswaren, Rezept und Tasche ohne Platzzeile', () => {
  const c = toTip(CLOTH, 'forever');
  assert.deepEqual(texts(c), ['Handwerksmaterial']);
  assert.equal(c.lines[0].c, 'reagent');
  const r = toTip({ name: 'Muster', preview_item: { inventory_type: { type: 'NON_EQUIP' }, is_subclass_hidden: true, description: 'Lehrt Euch.',
    requirements: { skill: { display_string: 'Benötigt Schneiderei (80)' } }, recipe: { reagents_display_string: 'Wollstoffballen (4)' } } }, 'forever');
  assert.deepEqual(texts(r), ['Benötigt Schneiderei (80)', 'Benötigt: Wollstoffballen (4)', 'Lehrt Euch.']);
  const b = toTip({ name: 'Beutel', preview_item: { inventory_type: { type: 'BAG', name: 'Tasche' }, item_subclass: { name: 'Tasche' }, container_slots: { display_string: '6 Platz Behälter' } } }, 'forever');
  assert.equal(b.lines[0].r, undefined);
  assert.equal(b.lines[1].l, '6 Platz Behälter');
});

test('Antwort ohne preview_item bricht nicht ab', () => {
  const t = toTip({ name: 'Alt', quality: { type: 'RARE' }, sell_price: 0 }, 'classic');
  assert.deepEqual(t, { name: 'Alt', quality: 3, sell: null, source: 'classic', lines: [] });
});

function setup() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'peon-info-'));
  const db = openDb(dir);
  const clock = { t: 1000000 };
  const world = { forever: { 12640: HELM }, classic: { 16802: { ...HELM, id: 16802, name: 'Gürtel' } }, broken: false, calls: [] };
  const client = { region: 'eu', get: async (p, o) => {
    world.calls.push(p);
    if (world.broken) return { status: 503, json: null };
    const id = Number(/(\d+)$/.exec(p)[1]);
    const list = o.kind === 'static' ? world.forever : (o.namespace === 'static-classic1x-eu' ? world.classic : {});
    return list[id] ? { status: 200, json: list[id] } : { status: 404, json: null };
  } };
  return { db, clock, world, client, info: new ItemInfo(db, () => clock.t), done: () => { db.close(); fs.rmSync(dir, { recursive: true, force: true }); } };
}

test('Abruf wird gespeichert, zweites Ansehen fragt nicht erneut', async () => {
  const s = setup();
  const a = await s.info.get(12640, s.client);
  assert.equal(a.state, 'ok');
  assert.equal(a.tip.source, 'forever');
  assert.equal(s.world.calls.length, 1);
  const b = await s.info.get(12640, s.client);
  assert.deepEqual(b, a);
  assert.equal(s.world.calls.length, 1);
  s.done();
});

test('Fehlt der Gegenstand in Forever, gelten die Classic-Daten und sind gekennzeichnet', async () => {
  const s = setup();
  const a = await s.info.get(16802, s.client);
  assert.equal(a.tip.name, 'Gürtel');
  assert.equal(a.tip.source, 'classic');
  assert.equal(s.world.calls.length, 2);
  s.done();
});

test('Unbekannter Gegenstand: gemerkt, erst nach einer Woche neue Frage', async () => {
  const s = setup();
  assert.deepEqual(await s.info.get(7779, s.client), { state: 'none', tip: null });
  assert.equal(s.world.calls.length, 2);
  await s.info.get(7779, s.client);
  assert.equal(s.world.calls.length, 2);
  s.clock.t += NONE_RETRY + 1;
  s.world.forever[7779] = CLOTH;
  assert.equal((await s.info.get(7779, s.client)).state, 'ok');
  s.done();
});

test('Ohne Zugang und ohne Antwort: Hinweis statt Fehler, nichts gemerkt', async () => {
  const s = setup();
  assert.deepEqual(await s.info.get(12640, null), { state: 'no-access', tip: null });
  s.world.broken = true;
  assert.deepEqual(await s.info.get(12640, s.client), { state: 'unreachable', tip: null });
  assert.equal(s.db.prepare('SELECT COUNT(*) AS n FROM item_info').get().n, 0);
  s.world.broken = false;
  assert.equal((await s.info.get(12640, s.client)).state, 'ok');
  s.done();
});

test('Alter Eintrag: wird erneuert, ohne Antwort oder Zugang bleibt der alte', async () => {
  const s = setup();
  await s.info.get(12640, s.client);
  s.clock.t += FRESH + 1;
  assert.equal((await s.info.get(12640, null)).state, 'ok');
  s.world.broken = true;
  const old = await s.info.get(12640, s.client);
  assert.equal(old.tip.name, 'Löwenherzhelm');
  s.world.broken = false;
  s.world.forever[12640] = { ...HELM, name: 'Neu' };
  assert.equal((await s.info.get(12640, s.client)).tip.name, 'Neu');
  s.done();
});

test('Gleichzeitiges Ansehen fragt nur einmal, ungueltige Nummer fragt gar nicht', async () => {
  const s = setup();
  const [a, b] = await Promise.all([s.info.get(12640, s.client), s.info.get(12640, s.client)]);
  assert.equal(a.state, 'ok');
  assert.equal(b.state, 'ok');
  assert.equal(s.world.calls.length, 1);
  assert.equal((await s.info.get(Number.NaN, s.client)).state, 'none');
  assert.equal(s.world.calls.length, 1);
  s.done();
});

test('Vorhandene Datenbank bekommt die Tabelle beim Oeffnen', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'peon-info-'));
  const old = new DatabaseSync(path.join(dir, 'broker-client.db'));
  old.exec('CREATE TABLE items (key TEXT PRIMARY KEY, item_id INTEGER NOT NULL, variant TEXT, name TEXT, quality INTEGER, updated INTEGER);');
  old.close();
  const db = openDb(dir);
  assert.ok(db.prepare("SELECT 1 FROM sqlite_master WHERE name = 'item_info'").get());
  db.close();
  fs.rmSync(dir, { recursive: true, force: true });
});
