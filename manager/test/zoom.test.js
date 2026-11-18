'use strict';
// Groesse der Oberflaeche (ab 0.47.0): Stufen, Tasten, Einstellung
const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const { ZOOM_STEPS, zoomOf, zoomStep, zoomKey } = require('../src/core/zoom');

test('Zoom: nur erlaubte Stufen, Unsinn wird 100 %', () => {
  assert.equal(zoomOf(1.25), 1.25);
  assert.equal(zoomOf('1.5'), 1.5);
  for (const v of [undefined, null, 'gross', 3, 0, -1, 1.2]) assert.equal(zoomOf(v), 1);
});

test('Zoom: Schritte bleiben in den Grenzen, 0 setzt zurueck', () => {
  assert.equal(zoomStep(1, 1), 1.1);
  assert.equal(zoomStep(1, -1), 0.9);
  assert.equal(zoomStep(ZOOM_STEPS[ZOOM_STEPS.length - 1], 1), ZOOM_STEPS[ZOOM_STEPS.length - 1]);
  assert.equal(zoomStep(ZOOM_STEPS[0], -1), ZOOM_STEPS[0]);
  assert.equal(zoomStep(1.5, 0), 1);
  assert.equal(zoomStep('kaputt', 1), 1.1, 'unbekannter Wert zaehlt als 100 %');
});

test('Zoom: Strg und Plus, Minus, 0 (auch Ziffernblock), sonst nichts', () => {
  const k = (key, more = {}) => zoomKey({ type: 'keyDown', control: true, alt: false, meta: false, key, code: '', ...more });
  assert.equal(k('+'), 1);
  assert.equal(k('='), 1);
  assert.equal(k('-'), -1);
  assert.equal(k('0'), 0);
  assert.equal(k('x', { code: 'NumpadAdd' }), 1);
  assert.equal(k('x', { code: 'NumpadSubtract' }), -1);
  assert.equal(k('a'), null);
  assert.equal(k('+', { control: false }), null, 'ohne Strg');
  assert.equal(k('+', { alt: true }), null, 'Strg und Alt ist AltGr');
  assert.equal(k('+', { type: 'keyUp' }), null);
  assert.equal(zoomKey(null), null);
});

test('Zoom: Auswahl in den Einstellungen hat dieselben Stufen', () => {
  const vue = fs.readFileSync(path.join(__dirname, '..', 'src', 'renderer', 'views', 'Settings.vue'), 'utf8');
  const m = vue.match(/const ZOOM_STEPS = (\[[^\]]+\])/);
  assert.ok(m, 'ZOOM_STEPS in Settings.vue');
  assert.deepEqual(JSON.parse(m[1]), ZOOM_STEPS);
});
