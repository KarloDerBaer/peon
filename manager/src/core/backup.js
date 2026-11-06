'use strict';
// Peon Manager - Datensicherung: ein Ordner Peon-Sicherung-<Datum> mit den Datenbanken und den Einstellungen.
// Der Zugang zur Blizzard-API bleibt aussen vor: Er ist fuer dieses Windows-Konto verschluesselt und waere woanders wertlos.
// Einspielen: Das Programm merkt sich den Ordner (restore.json), startet neu und tauscht vor dem Oeffnen der Datenbanken.
// Der bisherige Stand wandert in den Ordner vor-Wiederherstellung-<Datum>, geloescht wird nichts.

const fs = require('node:fs');
const path = require('node:path');
const sqlite = require('node:sqlite');

const INFO = 'sicherung.json';
const PENDING = 'restore.json';
const DBS = ['peon.db', 'broker-client.db'];

function stamp(now) {
  const d = new Date(now * 1000);
  const p = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}-${p(d.getHours())}${p(d.getMinutes())}`;
}

function freeDir(base) {
  if (!fs.existsSync(base)) return base;
  for (let i = 2; ; i++) if (!fs.existsSync(`${base}-${i}`)) return `${base}-${i}`;
}

// open = { 'peon.db': Datenbank, ... } fuer offene Datenbanken. Die laufen weiter, waehrend gesichert wird.
async function create({ dbDir, open = {}, target, version, now }) {
  const dir = freeDir(path.join(target, `Peon-Sicherung-${stamp(now)}`));
  fs.mkdirSync(dir, { recursive: true });
  try {
    const files = [];
    for (const name of DBS) {
      const from = path.join(dbDir, name);
      const to = path.join(dir, name);
      if (open[name]) {
        if (typeof sqlite.backup === 'function') await sqlite.backup(open[name], to);
        else open[name].prepare('VACUUM INTO ?').run(to);
      } else if (fs.existsSync(from)) {
        // Geschlossen (Modul ausgeschaltet): Die Datei samt Protokoll passt zusammen
        fs.copyFileSync(from, to);
        if (fs.existsSync(`${from}-wal`)) fs.copyFileSync(`${from}-wal`, `${to}-wal`);
      } else continue;
      files.push(name);
    }
    const settings = path.join(dbDir, 'settings.json');
    if (fs.existsSync(settings)) fs.copyFileSync(settings, path.join(dir, 'settings.json'));
    fs.writeFileSync(path.join(dir, INFO), JSON.stringify({ app: 'Peon Manager', version, t: now, files }, null, 1));
    let bytes = 0;
    for (const f of fs.readdirSync(dir)) bytes += fs.statSync(path.join(dir, f)).size;
    return { dir, bytes, files };
  } catch (e) {
    fs.rmSync(dir, { recursive: true, force: true });   // eine halbe Sicherung darf nicht wie eine ganze aussehen
    throw e;
  }
}

// Ist das eine Sicherung? Rueckgabe: { version, t, files, bytes }
function inspect(dir) {
  let info;
  try { info = JSON.parse(fs.readFileSync(path.join(dir, INFO), 'utf8')); } catch { throw new Error('In diesem Ordner liegt keine Sicherung des Peon Managers.'); }
  if (!info || info.app !== 'Peon Manager' || !Array.isArray(info.files) || !info.files.includes('peon.db')) throw new Error('In diesem Ordner liegt keine Sicherung des Peon Managers.');
  for (const f of info.files) if (!DBS.includes(f) || !fs.existsSync(path.join(dir, f))) throw new Error(`Die Sicherung ist unvollständig, es fehlt ${f}.`);
  let bytes = 0;
  for (const f of info.files) bytes += fs.statSync(path.join(dir, f)).size;
  return { version: info.version, t: info.t, files: info.files, bytes };
}

function request(dbDir, from) {
  inspect(from);
  fs.writeFileSync(path.join(dbDir, PENDING), JSON.stringify({ from }));
}

// Vor dem Oeffnen der Datenbanken. Rueckgabe: null, wenn nichts ansteht, sonst { ok, from, old, error }
function applyPending(dbDir, now = Math.floor(Date.now() / 1000)) {
  const file = path.join(dbDir, PENDING);
  if (!fs.existsSync(file)) return null;
  let from = null, old = null;
  const moved = [];
  try {
    from = JSON.parse(fs.readFileSync(file, 'utf8')).from;
    const info = inspect(from);
    old = freeDir(path.join(dbDir, `vor-Wiederherstellung-${stamp(now)}`));
    fs.mkdirSync(old, { recursive: true });
    const names = [...DBS.flatMap((d) => [d, `${d}-wal`, `${d}-shm`]), 'settings.json'];
    let keepWow = null;
    try { keepWow = JSON.parse(fs.readFileSync(path.join(dbDir, 'settings.json'), 'utf8').replace(/^﻿/, '')).wowDir; } catch { /* keine */ }
    for (const n of names) {
      const p = path.join(dbDir, n);
      if (fs.existsSync(p)) { fs.renameSync(p, path.join(old, n)); moved.push(n); }
    }
    const copied = [];
    try {
      for (const n of [...info.files, ...info.files.map((d) => `${d}-wal`), 'settings.json']) {
        const p = path.join(from, n);
        if (fs.existsSync(p)) { fs.copyFileSync(p, path.join(dbDir, n)); copied.push(n); }
      }
      // Der WoW-Ordner gehoert zu diesem Rechner, nicht zur Sicherung
      const sf = path.join(dbDir, 'settings.json');
      if (keepWow && fs.existsSync(sf)) {
        const s = JSON.parse(fs.readFileSync(sf, 'utf8').replace(/^﻿/, ''));
        if (!s.wowDir || !fs.existsSync(s.wowDir)) { s.wowDir = keepWow; fs.writeFileSync(sf, JSON.stringify(s, null, 2)); }
      }
    } catch (e) {
      for (const n of copied) fs.rmSync(path.join(dbDir, n), { force: true });
      for (const n of moved) fs.renameSync(path.join(old, n), path.join(dbDir, n));
      moved.length = 0;
      throw e;
    }
    return { ok: true, from, old };
  } catch (e) {
    return { ok: false, from, old: moved.length ? old : null, error: e.message };
  } finally {
    fs.rmSync(file, { force: true });   // Gelingt es nicht, soll nicht jeder Start es erneut versuchen
  }
}

module.exports = { create, inspect, request, applyPending };
