'use strict';
// Suche nach Updates im eingestellten Abstand und Meldung von Windows (ab 0.20.0)
const test = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { Service, DEFAULTS, updateCheckMs, UPDATE_CHECK_CHOICES } = require('../src/core/service');

test('Standard: alle 10 Minuten suchen, Meldung an', () => {
  assert.strictEqual(DEFAULTS.updateCheckMin, 10);
  assert.strictEqual(DEFAULTS.updateNotify, true);
  assert.deepStrictEqual(UPDATE_CHECK_CHOICES, [10, 30, 60, 360]);
});

test('Abstand: nur erlaubte Werte, sonst 10 Minuten', () => {
  assert.strictEqual(updateCheckMs(10), 10 * 60 * 1000);
  assert.strictEqual(updateCheckMs(360), 6 * 60 * 60 * 1000);
  assert.strictEqual(updateCheckMs(7), 10 * 60 * 1000);
  assert.strictEqual(updateCheckMs('30'), 10 * 60 * 1000);
  assert.strictEqual(updateCheckMs(undefined), 10 * 60 * 1000);
});

test('Einstellungen werden gespeichert und bleiben erhalten', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'peon-upd-'));
  try {
    let svc = new Service({ dbDir: dir });
    assert.strictEqual(svc.settings.updateCheckMin, 10);
    svc.saveSettings({ updateCheckMin: 60, updateNotify: false });
    svc.close && svc.close();
    svc = new Service({ dbDir: dir });
    assert.strictEqual(svc.settings.updateCheckMin, 60);
    assert.strictEqual(svc.settings.updateNotify, false);
    svc.close && svc.close();
  } finally {
    try { fs.rmSync(dir, { recursive: true, force: true }); } catch { /* Windows haelt die Datei manchmal noch */ }
  }
});
