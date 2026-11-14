'use strict';
// Peon Manager - Datenordner waehlen und umziehen (ab 0.36.0).
// Der gewaehlte Ordner steht in datenordner.json im Programmordner fuer Daten (%APPDATA%\Peon Manager), also ausserhalb
// des Datenordners selbst. Umzug: Der Manager merkt sich das Ziel (umzug.json), startet neu und kopiert vor dem Oeffnen
// der Datenbanken alles hinueber. Erst wenn die Kopie vollstaendig ist, zeigt datenordner.json auf den neuen Ordner.
// Der alte Ordner bleibt als Sicherung liegen, geloescht wird nichts.

const fs = require('node:fs');
const path = require('node:path');

const POINTER = 'datenordner.json';
const PENDING = 'umzug.json';
const SUBDIR = 'Peon Manager Daten';
const SKIP = new Set(['tmp']);   // Zwischendateien ziehen nicht mit

const same = (a, b) => path.resolve(a).toLowerCase() === path.resolve(b).toLowerCase();
const inside = (dir, parent) => {
  const rel = path.relative(path.resolve(parent).toLowerCase(), path.resolve(dir).toLowerCase());
  return rel !== '' && !rel.startsWith('..') && !path.isAbsolute(rel);
};

function readJson(file) {
  try { return JSON.parse(fs.readFileSync(file, 'utf8').replace(/^﻿/, '')); } catch { return null; }
}

// Gewaehlter Ordner: { dir, from, t } oder null
function pointer(base) {
  const p = readJson(path.join(base, POINTER));
  return p && typeof p.dir === 'string' && p.dir ? p : null;
}

// Datenordner beim Start: der gewaehlte, wenn es ihn gibt, sonst der Standard
function resolve(base, fallback) {
  const p = pointer(base);
  return p && fs.existsSync(p.dir) ? p.dir : fallback;
}

// Groesse eines Ordners samt Unterordnern (ohne tmp)
function folderBytes(dir, top = true) {
  let n = 0;
  let list = [];
  try { list = fs.readdirSync(dir, { withFileTypes: true }); } catch { return 0; }
  for (const e of list) {
    if (top && SKIP.has(e.name)) continue;
    const p = path.join(dir, e.name);
    if (e.isDirectory()) n += folderBytes(p, false);
    else if (e.isFile()) { try { n += fs.statSync(p).size; } catch { /* weg */ } }
  }
  return n;
}

const isEmptyDir = (d) => { try { return fs.readdirSync(d).length === 0; } catch { return false; } };

// Naechster vorhandener Ordner auf dem Weg nach oben (fuer freien Platz und Schreibprobe)
function existingParent(dir) {
  let d = path.resolve(dir);
  while (!fs.existsSync(d)) {
    const up = path.dirname(d);
    if (up === d) return null;
    d = up;
  }
  return d;
}

function freeBytes(dir) {
  try {
    const s = fs.statfsSync(dir);
    return Number(s.bavail) * Number(s.bsize);
  } catch { return null; }
}

// Fertiges Ziel pruefen: Fehlertext oder null
function targetError(from, to) {
  if (same(to, from)) return 'Das ist schon der Datenordner.';
  if (inside(to, from)) return 'Der neue Ordner darf nicht im bisherigen Datenordner liegen.';
  if (inside(from, to)) return 'Der bisherige Datenordner darf nicht im neuen Ordner liegen.';
  if (fs.existsSync(to) && !isEmptyDir(to)) return `Im Ordner ${to} liegen schon Dateien. Wähle einen leeren Ordner.`;
  if (!existingParent(to)) return 'Den Ordner gibt es nicht.';
  return null;
}

// Gewaehlten Ordner pruefen. Ist er leer (oder neu), kommen die Daten direkt hinein, sonst in einen Unterordner
// „Peon Manager Daten“. Rueckgabe: { to, bytes, free, error }
function check(from, chosen) {
  const out = { to: null, bytes: folderBytes(from), free: null, error: null };
  if (!chosen || typeof chosen !== 'string') { out.error = 'Kein Ordner gewählt.'; return out; }
  const to = !fs.existsSync(chosen) || isEmptyDir(chosen) ? path.resolve(chosen) : path.join(path.resolve(chosen), SUBDIR);
  out.to = to;
  out.error = targetError(from, to);
  if (out.error) return out;
  const parent = existingParent(to);
  out.free = freeBytes(parent);
  if (out.free != null && out.free < out.bytes * 1.1 + 50 * 1024 * 1024) { out.error = 'Auf dem Laufwerk ist nicht genug Platz frei.'; return out; }
  // Schreibprobe
  const probe = path.join(parent, `.peon-probe-${process.pid}`);
  try { fs.writeFileSync(probe, 'x'); fs.rmSync(probe, { force: true }); } catch { out.error = 'In diesen Ordner darf der Manager nicht schreiben.'; }
  return out;
}

// Umzug fuer den naechsten Start vormerken. to: fertiges Ziel aus check()
function request(base, from, to) {
  const err = targetError(from, to);
  if (err) throw new Error(err);
  fs.mkdirSync(base, { recursive: true });
  fs.writeFileSync(path.join(base, PENDING), JSON.stringify({ from, to }));
}

function pending(base) { return readJson(path.join(base, PENDING)); }

// Alle Dateien von from nach to kopieren (ohne tmp). onFile(name) meldet den Fortschritt.
async function copyAll(from, to, onFile, top = true) {
  await fs.promises.mkdir(to, { recursive: true });
  for (const e of await fs.promises.readdir(from, { withFileTypes: true })) {
    if (top && SKIP.has(e.name)) continue;
    const a = path.join(from, e.name), b = path.join(to, e.name);
    if (e.isDirectory()) await copyAll(a, b, onFile, false);
    else if (e.isFile()) {
      if (onFile) onFile(e.name);
      await fs.promises.copyFile(a, b, fs.constants.COPYFILE_EXCL);
    }
  }
}

// Vor dem Oeffnen der Datenbanken. fallback: Standardordner. Rueckgabe: null, wenn nichts ansteht, sonst { ok, from, to, error }
async function applyPending(base, fallback, { onFile, now = Math.floor(Date.now() / 1000) } = {}) {
  const file = path.join(base, PENDING);
  const job = pending(base);
  if (!job) return null;
  fs.rmSync(file, { force: true });   // Gelingt es nicht, soll nicht jeder Start es erneut versuchen
  const { from, to } = job;
  const existed = fs.existsSync(to);
  try {
    if (!from || !to || !fs.existsSync(from)) throw new Error('Den bisherigen Datenordner gibt es nicht mehr.');
    if (existed && !isEmptyDir(to)) throw new Error(`Im Ordner ${to} liegen schon Dateien.`);
    const want = folderBytes(from);
    await copyAll(from, to, onFile);
    const got = folderBytes(to);
    if (got !== want) throw new Error(`Die Kopie ist unvollständig (${got} von ${want} Bytes).`);
    if (same(to, fallback)) fs.rmSync(path.join(base, POINTER), { force: true });
    else fs.writeFileSync(path.join(base, POINTER), JSON.stringify({ dir: to, from, t: now }, null, 1));
    return { ok: true, from, to };
  } catch (e) {
    // nur die eigene, halbe Kopie wegraeumen
    try {
      if (!existed) fs.rmSync(to, { recursive: true, force: true });
      else for (const n of fs.readdirSync(to)) fs.rmSync(path.join(to, n), { recursive: true, force: true });
    } catch { /* bleibt liegen */ }
    return { ok: false, from, to, error: e.message };
  }
}

module.exports = { POINTER, PENDING, SUBDIR, pointer, resolve, folderBytes, check, request, pending, applyPending };
