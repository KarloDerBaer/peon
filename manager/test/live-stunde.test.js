'use strict';
// Live-Abfragen je Gegenstand und Stunde (Manager 0.57.0, Schema 16): guenstigster Preis in low, Zusammenfassen beim
// Aufraeumen und bei der Umstellung, zusammengefasste Nummern bleiben bekannt (Bestaetigung an die Bridge)
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { openDb, tx, migrateLiveHourly } = require('../src/core/db');
const game = require('../src/core/game');
const history = require('../src/core/history');
const retention = require('../src/core/retention');

const M = 'Classic Beta PvE / Alliance';
const H = 1792699200;            // volle Stunde
const NOW = H + 5 * 3600 + 600;  // fuenf Stunden spaeter

function setup() {
  return openDb(fs.mkdtempSync(path.join(os.tmpdir(), 'peon-')), { now: NOW });
}
const live = (id, t, price, extra = {}) => ({ id, kind: 'live', market: M, t, key: '2770', commodity: true,
  rows: price == null ? '' : `2770;;;5;;${price};;1;${t};1`, ...extra });
const put = (db, e) => tx(db, () => game.importEntry(db, e, null));
const liveRows = (db) => db.prepare("SELECT s.id, i.t, i.min, i.low, i.qty FROM item_snap i JOIN snapshots s ON s.sid = i.sid WHERE i.source = 'live' ORDER BY i.t").all();

test('Live: low aus der Bridge, Zusammenfassen beim Aufraeumen, laufende Stunde bleibt', () => {
  const db = setup();
  put(db, live('a', H + 100, 120, { low: 110 }));
  put(db, live('b', H + 900, 90));
  put(db, live('c', H + 1800, 130));
  put(db, live('d', H + 3700, 125));            // naechste Stunde, allein
  put(db, live('e', NOW - 300, 140));           // laufende Stunde
  put(db, live('f', NOW - 100, 145));
  assert.equal(liveRows(db)[0].low, 110, 'low aus e.low der Bridge');
  assert.equal(liveRows(db).length, 6);

  const res = { snaps: 0, hours: 0, blobs: 0 };
  for (const _ of retention.pruneSteps(db, { keepDays: 7, hourDays: 60, now: NOW }, res)) { /* alle Schritte */ }
  const rows = liveRows(db);
  assert.equal(res.liveMerged, 2, 'zwei Abfragen der ersten Stunde aufgegangen');
  assert.deepEqual(rows.map((r) => r.id), ['c', 'd', 'e', 'f'], 'neueste der Stunde bleibt, laufende Stunde unberuehrt');
  assert.equal(rows[0].min, 130, 'Stand ist die neueste Abfrage');
  assert.equal(rows[0].low, 90, 'low ist der guenstigste Preis der Stunde');
  for (const id of ['a', 'b', 'c']) assert.ok(game.knownId(db, id), `${id} bleibt bekannt`);
  assert.equal(put(db, live('a', H + 100, 120)), false, 'nochmal aus der Bridge: nicht neu eingelesen');

  // aktueller Stand und Verlauf fuer das Diagramm
  const d = history.itemDetail(db, M, '2770', { now: NOW });
  assert.equal(d.current.source, 'live');
  assert.equal(d.current.min, 145);
  assert.equal(d.own.find((x) => x.t === H + 1800).low, 90);

  // Nummern fallen nach 7 Tagen weg
  for (const _ of retention.pruneSteps(db, { keepDays: 7, hourDays: 60, now: NOW + 8 * 86400 })) { /* alle Schritte */ }
  assert.equal(db.prepare('SELECT COUNT(*) AS n FROM live_ids').get().n, 0);
});

test('Live: leere Abfrage (Gegenstand weg) behaelt den guenstigsten Preis der Stunde', () => {
  const db = setup();
  put(db, live('a', H + 100, 100));
  put(db, live('b', H + 200, null));
  for (const _ of retention.pruneSteps(db, { keepDays: 7, hourDays: 60, now: NOW })) { /* alle Schritte */ }
  const rows = liveRows(db);
  assert.equal(rows.length, 1);
  assert.equal(rows[0].id, 'b');
  assert.equal(rows[0].qty, 0);
  assert.equal(rows[0].min, null);
  assert.equal(rows[0].low, 100);
});

test('Live: Umstellung auf Schema 16 fasst vorhandene Abfragen einmal zusammen', () => {
  const db = setup();
  put(db, live('a', H + 100, 120));
  put(db, live('b', H + 200, 80));
  put(db, live('c', H + 300, 100));
  db.prepare('UPDATE item_snap SET low = NULL').run();   // wie vor Schema 16
  db.prepare("DELETE FROM meta WHERE key = 'liveHourly'").run();
  assert.equal(migrateLiveHourly(db, NOW), true);
  const rows = liveRows(db);
  assert.deepEqual(rows.map((r) => [r.id, r.min, r.low]), [['c', 100, 80]]);
  assert.ok(game.knownId(db, 'a') && game.knownId(db, 'b'));
  assert.equal(migrateLiveHourly(db, NOW), false, 'nur einmal');
});
