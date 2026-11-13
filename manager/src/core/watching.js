'use strict';
// Peon Manager - Beobachtung (Modul Peon Broker Client), ab 0.30.0 (Angleichung A2, Peon_Manager_Angleichung.md 3.2).
// Gleicher Aufbau wie im Spiel (Peon_Broker, Watch.lua):
//   { items: { [Schluessel]: { u, lim, pct, up, t: { buy, up }, name, q, icon } }, gone: { [Schluessel]: u } }
// lim = Kaufen bis in Kupfer oder pct = Kaufen bis in % unter dem Vergleichspreis (zusammen der Wert "buy"),
// up = Zielpreis in Kupfer. Abgleich je Wert mit den Regeln aus shopping.js. Ein Eintrag als Zahl (bis 0.29.0) ist nur u.
// Die Regeln muessen gleich bleiben wie Wt.Merge in Watch.lua (Test: umbau2.test.js mit test/lua/watch_compare.lua).
// m = Eingabe im Manager, die das Spiel noch nicht hat.

const { stamp, nextU, newFrom, mergeFields } = require('./shopping');

const GONE_DAYS = 365;   // so lange bleiben Loeschmarken stehen (bis 0.29.0 60 Tage)
const SPEC = [{ f: 'buy', keys: ['lim', 'pct'], reset: 'hit' }, { f: 'up', keys: ['up'], reset: 'upHit' }];
const SKIP = new Set(['u', 't', 'm', 'lim', 'pct', 'up', 'hit', 'upHit']);

const num = (v) => Number(v) || 0;
const empty = () => ({ items: {}, gone: {} });

// Eintrag lesbar machen: Zahl = nur u, sonst Kopie (t ebenfalls kopiert)
function entry(v) {
  if (v === null || typeof v !== 'object') return { u: num(v) };
  const c = { ...v, u: num(v.u) };
  if (v.t && typeof v.t === 'object') c.t = { ...v.t };
  return c;
}

function clean(doc) {
  const d = doc && typeof doc === 'object' ? doc : {};
  const items = {};
  for (const [k, v] of Object.entries(d.items || {})) items[String(k)] = entry(v);
  const gone = {};
  for (const [k, u] of Object.entries(d.gone || {})) gone[String(k)] = num(u);
  return { items, gone };
}

// data = { items, gone } aus dem Spiel einmischen (wie Wt.Merge). Rueckgabe: true bei Aenderung
function merge(doc, data) {
  let changed = false;
  const d = data && typeof data === 'object' ? data : {};
  for (const [k, raw] of Object.entries(d.items || {})) {
    const key = String(k);
    const bare = raw === null || typeof raw !== 'object';
    const inc = bare ? { u: num(raw) } : raw;
    const uu = num(inc.u);
    const w = doc.items[key];
    const localU = w ? num(w.u) : num(doc.gone[key]);
    if (!w) {
      if (uu > localU || doc.gone[key] === undefined) {
        doc.items[key] = bare ? { u: uu } : newFrom(inc, SPEC);
        delete doc.gone[key];
        changed = true;
      }
    } else if (bare) {
      if (uu > num(w.u)) { w.u = uu; delete w.m; changed = true; }
    } else if (mergeFields(w, inc, SPEC, SKIP)) {
      changed = true;
    }
  }
  for (const [k, u] of Object.entries(d.gone || {})) {
    const key = String(k), uu = num(u);
    const w = doc.items[key];
    if (w && uu > num(w.u)) { delete doc.items[key]; doc.gone[key] = uu; changed = true; }
    else if (!w && uu > num(doc.gone[key])) { doc.gone[key] = uu; changed = true; }
  }
  return changed;
}

// Alte Loeschmarken entfernen. Rueckgabe: true bei Aenderung
function purge(doc, now) {
  let changed = false;
  const limit = now - GONE_DAYS * 86400;
  for (const [k, u] of Object.entries(doc.gone)) if (u < limit) { delete doc.gone[k]; changed = true; }
  return changed;
}

// Fuer Data.lua: ohne interne Merker. null, wenn nichts da ist
function forGame(doc) {
  if (!Object.keys(doc.items).length && !Object.keys(doc.gone).length) return null;
  const items = {};
  for (const [k, w] of Object.entries(doc.items)) {
    const c = { ...w };
    delete c.m; delete c.hit; delete c.upHit;
    items[k] = c;
  }
  return { items, gone: { ...doc.gone } };
}

// Eingaben im Manager
function add(doc, key, now, { name, quality } = {}) {
  const k = String(key);
  if (doc.items[k]) return false;
  const w = { u: nextU(now, doc.gone[k]), m: 1 };
  if (name) w.name = name;
  if (quality != null) w.q = quality;
  doc.items[k] = w;
  delete doc.gone[k];
  return true;
}

function remove(doc, key, now) {
  const k = String(key);
  const w = doc.items[k];
  if (!w) return false;
  doc.gone[k] = nextU(now, w.u);
  delete doc.items[k];
  return true;
}

// Kaufen bis: kind 'abs' (value Kupfer), 'pct' (value % unter dem Vergleichspreis) oder null = keine Grenze
function setBuy(doc, key, kind, value, now) {
  const w = doc.items[String(key)];
  if (!w) return false;
  delete w.lim; delete w.pct;
  if (kind === 'pct' && Number.isFinite(Number(value))) w.pct = Number(value);
  else if (kind === 'abs' && Number(value) > 0) w.lim = Math.floor(Number(value));
  stamp(w, SPEC, 'buy', now);
  w.m = 1;
  return true;
}

// Zielpreis in Kupfer, leer = keine Grenze
function setUp(doc, key, value, now) {
  const w = doc.items[String(key)];
  if (!w) return false;
  delete w.up;
  if (Number(value) > 0) w.up = Math.floor(Number(value));
  stamp(w, SPEC, 'up', now);
  w.m = 1;
  return true;
}

module.exports = { empty, clean, merge, purge, forGame, add, remove, setBuy, setUp, SPEC, GONE_DAYS };
