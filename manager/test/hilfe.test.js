'use strict';
// Hilfe im Manager (ab 0.48.0): Inhalt aus docs/Hilfe.md, jedes ausgelieferte Addon hat einen Abschnitt,
// der kleine Markdown-Leser gibt nur Text weiter (kein HTML), die Seite haengt in der Navigation.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const ROOT = path.join(__dirname, '..', '..');
const MD = fs.readFileSync(path.join(ROOT, 'docs', 'Hilfe.md'), 'utf8');
const markdown = () => import('data:text/javascript,' + encodeURIComponent(fs.readFileSync(path.join(__dirname, '..', 'src', 'renderer', 'markdown.js'), 'utf8')));

test('Hilfe: jedes ausgelieferte Addon und der Manager haben einen Abschnitt', () => {
  const cfg = JSON.parse(fs.readFileSync(path.join(ROOT, 'scripts', 'release.json'), 'utf8'));
  const names = Object.keys(cfg.addons).filter((n) => !cfg.addons[n].local);
  const heads = MD.split(/\r?\n/).filter((l) => l.startsWith('## ')).map((l) => l.slice(3).trim());
  for (const n of [...names, 'Peon Manager']) assert.ok(heads.includes(n), `Abschnitt fehlt: ${n}`);
  const extra = ['Peon Manager', 'Peon unterstützen'];
  for (const h of heads) assert.ok(extra.includes(h) || names.includes(h), `Abschnitt ohne ausgeliefertes Addon: ${h}`);
});

test('Hilfe: Texte ohne Gedankenstriche und Semikolons (Regel in CLAUDE.md)', () => {
  assert.ok(!/ [–—] /.test(MD), 'Gedankenstrich gefunden');
  assert.ok(!/;/.test(MD), 'Semikolon gefunden');
});

test('Hilfe: Markdown-Leser kennt Ueberschriften, Listen, fett und Code, HTML bleibt Text', async () => {
  const { parse, sections, plain, inline } = await markdown();
  const b = parse('# Titel\n\nErster Satz\nzweiter Satz.\n\n## Peon_Test\n\n- **Fett** und `/cmd`\n  weiter\n- <b>kein HTML</b>\n\nAbsatz');
  assert.equal(b[0].t, 'h1');
  assert.equal(b[1].t, 'p');
  assert.equal(b[1].parts.map((p) => p.v).join(''), 'Erster Satz zweiter Satz.');
  assert.equal(b[2].t, 'h2');
  assert.equal(b[2].id, 'peon-test');
  assert.equal(b[3].t, 'ul');
  assert.deepEqual(b[3].items[0].map((p) => p.t), ['b', 'text', 'code', 'text', 'text']);
  assert.equal(b[3].items[0].map((p) => p.v).join(''), 'Fett und /cmd weiter');
  assert.deepEqual(b[3].items[1], [{ t: 'text', v: '<b>kein HTML</b>' }]);
  assert.equal(b[4].t, 'p');
  assert.deepEqual(inline('ohne'), [{ t: 'text', v: 'ohne' }]);
  const s = sections(MD);
  assert.equal(s[0].title, '');
  assert.ok(s.length > 10);
  const broker = s.find((x) => x.title === 'Peon_Broker');
  assert.ok(plain(broker).includes('/broker'));
});

test('Hilfe: Seite liest docs/Hilfe.md, ohne v-html, steht in der Navigation', () => {
  const vue = fs.readFileSync(path.join(__dirname, '..', 'src', 'renderer', 'views', 'Help.vue'), 'utf8');
  assert.match(vue, /import md from '\.\.\/\.\.\/\.\.\/\.\.\/docs\/Hilfe\.md\?raw'/);
  assert.ok(fs.existsSync(path.join(__dirname, '..', 'src', 'renderer', 'views', '..', '..', '..', '..', 'docs', 'Hilfe.md')));
  assert.ok(!vue.includes('v-html'));
  const app = fs.readFileSync(path.join(__dirname, '..', 'src', 'renderer', 'App.vue'), 'utf8');
  assert.match(app, /\{ key: 'help', label: 'Hilfe', always: true \}/);
  assert.match(app, /<Help v-else-if="view === 'help'" \/>/);
});

test('Peon unterstuetzen (ab 0.49.0): Eintrag unten in der Seitenleiste, nur genau diese Adresse darf sich oeffnen', () => {
  const URL = 'https://buymeacoffee.com/karloderbaer';
  const app = fs.readFileSync(path.join(__dirname, '..', 'src', 'renderer', 'App.vue'), 'utf8');
  assert.ok(app.includes('☕ Peon unterstützen') && app.includes(`const COFFEE_URL = '${URL}'`));
  assert.ok(app.indexOf('☕ Peon unterstützen') > app.indexOf('rail-bottom'), 'unten in der Seitenleiste');
  const main = fs.readFileSync(path.join(__dirname, '..', 'electron', 'main.js'), 'utf8');
  assert.ok(main.includes(`const COFFEE_URL = '${URL}'`) && main.includes('const coffee = url === COFFEE_URL;'), 'Freigabe nur fuer genau diese Adresse');
  assert.ok(MD.includes(URL) && MD.includes('freut sich KarloDerBaer'), 'Absatz in der Hilfe');
});
