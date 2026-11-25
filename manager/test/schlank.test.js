'use strict';
// Manager schlank (ab 0.56.0, docs/konzepte/manager/Peon_Manager_Schlank.md): sechs Eintraege mit Unterreitern,
// Startseite Heute, Einstellungen mit Allgemein und Erweitert nach dem Leitfaden, Hilfe mit den neuen Namen.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const SRC = path.join(__dirname, '..', 'src', 'renderer');
const read = (...p) => fs.readFileSync(path.join(SRC, ...p), 'utf8');
const APP = read('App.vue');
const block = (src, start) => { const i = src.indexOf(start); assert.ok(i >= 0, start); return src.slice(i, src.indexOf('];', i)); };

test('Seitenleiste: sechs Eintraege in fester Reihenfolge mit den Unterreitern aus dem Konzept', () => {
  const sec = block(APP, 'const SECTIONS = [');
  const rows = [...sec.matchAll(/label: '([^']+)', views: \[([^\]]*)\]/g)].map((m) => [m[1], m[2].split(',').map((x) => x.trim().replace(/'/g, ''))]);
  assert.deepEqual(rows, [
    ['Heute', ['today']],
    ['Chancen', ['chances', 'compare', 'packages', 'success']],
    ['Listen', ['shopping', 'favorites']],
    ['Markt', ['market', 'items', 'vendors']],
    ['Addons', ['modules']],
    ['Mehr', ['sources', 'reports', 'help', 'settings']],
  ]);
  const all = block(APP, 'const ALL = [');
  const label = (k) => (all.match(new RegExp(`key: '${k}', label: '([^']+)'`)) || [])[1];
  assert.deepEqual(['chances', 'compare', 'packages', 'success', 'shopping', 'favorites', 'market', 'items', 'vendors'].map(label),
    ['Spekulation', 'Marktvergleich', 'Pakete', 'Erfolg', 'Einkaufslisten', 'Beobachten', 'Übersicht', 'Gegenstände', 'Händler']);
  // Ohne Broker Client bleiben nur Heute, Addons und Mehr (Eintraege mit always)
  for (const k of ['today', 'modules', 'reports', 'help', 'settings']) assert.match(all, new RegExp(`key: '${k}', label: '[^']+', always: true`));
  for (const k of ['chances', 'compare', 'success', 'shopping', 'favorites', 'market', 'items', 'vendors', 'sources']) assert.doesNotMatch(all, new RegExp(`key: '${k}', label: '[^']+', always: true`));
});

test('Seitenleiste: alte Spruenge zeigen auf den neuen Platz, Unterreiter bleiben gemerkt', () => {
  assert.match(APP, /const MOVED = \{ overview: 'today', 'market:items': 'items', 'compare:pkg': 'packages' \}/);
  assert.match(APP, /saveQuiet\(\{ navSubs:/);
  const svc = fs.readFileSync(path.join(__dirname, '..', 'src', 'core', 'service.js'), 'utf8');
  assert.match(svc, /navSubs: \{\},/);
  assert.match(APP, /class="subtabs"/);
  assert.ok(!APP.includes('wipPage') && !APP.includes('NAV_BOTTOM'), 'alte Gruppen der Seitenleiste entfernt');
});

test('Heute: hoechstens vier Karten, Kacheln und Diagramme stehen unter Markt, Uebersicht', () => {
  const today = read('views', 'Today.vue');
  const cards = [...today.matchAll(/<section class="card[^"]*"[^>]*aria-label="([^"]+)"/g)].map((m) => m[1]);
  assert.deepEqual(cards, ['Updates', 'Daten', 'Lohnt sich jetzt', 'Meine Listen']);
  assert.match(today, /\.slice\(0, 5\)/, 'fuenf beste Eintraege');
  const market = read('views', 'Market.vue');
  assert.match(market, /\{ key: 'sum', label: 'Übersicht' \}/);
  assert.ok(!market.includes("key: 'items'"), 'Gegenstaende sind ein eigener Unterreiter');
  const sum = read('views', 'MarketSummary.vue');
  assert.ok(sum.includes('<MarketChart') && sum.includes('<StabilityChart') && sum.includes('class="tiles"'));
});

test('Einstellungen: Reiter Allgemein und Erweitert, hoechstens sechs Schalter, keine Pruefknoepfe', () => {
  const set = read('views', 'Settings.vue');
  assert.match(set, /\{ key: 'gen', label: 'Allgemein' \}, \{ key: 'adv', label: 'Erweitert' \}/);
  const gen = set.slice(set.indexOf("<template v-if=\"tab === 'gen'\">"), set.indexOf('<template v-else>'));
  assert.ok(gen.length > 100);
  assert.ok((gen.match(/type="checkbox"/g) || []).length <= 6, 'hoechstens sechs Schalter');
  for (const l of gen.match(/<label class="check"[^>]*>/g)) assert.match(l, /title="/, 'jeder Schalter hat einen Tooltip');
  for (const w of ['WoW-Ordner', 'Kanal', 'Aussehen', 'Größe']) assert.ok(gen.includes(`<span>${w}</span>`), w);
  const adv = set.slice(set.indexOf('<template v-else>'));
  assert.ok(adv.includes('Normalerweise musst du hier nichts ändern.'));
  for (const w of ['Datenordner', 'Spieldaten sichern', 'Aufbewahrung', '<BlizzardCheck', 'ChanceRules']) assert.ok(adv.includes(w), w);
  const bc = read('components', 'BlizzardCheck.vue');
  assert.ok(!bc.includes('Zugang prüfen</'), 'kein Knopf Zugang pruefen');
  assert.ok(!bc.includes('st.watch'), 'keine Testausgabe des Beobachters');
  assert.ok(!read('views', 'Modules.vue').includes('setAddonChannel'), 'Kanal nur unter Einstellungen');
});

test('Hilfe: nennt die sechs Eintraege und die neuen Namen', () => {
  const md = fs.readFileSync(path.join(__dirname, '..', '..', 'docs', 'Hilfe.md'), 'utf8');
  const man = md.slice(md.indexOf('## Peon Manager'), md.indexOf('## Peon unterstützen'));
  for (const w of ['**Heute:**', '**Chancen:**', '**Listen:**', '**Markt:**', '**Addons:**', '**Mehr:**', 'Einkaufslisten', 'Allgemein', 'Erweitert']) assert.ok(man.includes(w), w);
  assert.ok(!man.includes('Marktübersicht'), 'alter Seitenname');
});
