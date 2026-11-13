'use strict';
// Peon Manager - Einkaufslisten (Modul Peon Broker Client). Gleicher Aufbau wie im Spiel (Peon_Broker, Shop.lua):
//   { lists: [{ id, name, pct, u, t, items: { [Schluessel]: { wish, max, name, q, icon, u, t } } }], gone: { lists: { id: t }, items: { 'id|Schluessel': t } } }
// u = letzte Aenderung des ganzen Eintrags (Anlegen, Loeschen), t = Zeit je Wert, gone = Loeschmarken.
// Ab 0.30.0 (Angleichung A2, Peon_Manager_Angleichung.md 3.2): Abgleich je Wert. Name und Rabatt einer Liste, Menge und
// Hoechstpreis eines Eintrags tragen ihre eigene Zeit, die neuere gewinnt. Ohne t (Daten von vor 0.30.0) gilt u.
// Name, Qualitaet und Symbol eines Gegenstands sind nur Anzeige und werden ergaenzt, wo sie fehlen.
// Das Spiel liefert ueber Peon_Broker.lua, der Manager ueber Data.lua. Die Regeln muessen gleich bleiben wie in Shop.lua
// (Test: umbau2.test.js mit test/lua/shop_compare.lua). m = Eingabe im Manager, die das Spiel noch nicht hat.

const GONE_DAYS = 365;   // so lange bleiben Loeschmarken stehen (bis 0.29.0 60 Tage)

// Werte mit eigener Zeit: f = Name der Zeit in t, keys = Felder dieses Werts, reset = Merker, der bei neuem Wert wegfaellt
const LIST_SPEC = [{ f: 'name', keys: ['name'] }, { f: 'pct', keys: ['pct'] }];
const ITEM_SPEC = [{ f: 'wish', keys: ['wish'] }, { f: 'max', keys: ['max'] }];

const num = (v) => Number(v) || 0;

// Felder, die nicht als Anzeige ergaenzt werden
function skipOf(spec, extra = []) {
  return new Set(['u', 't', 'm', ...spec.flatMap((s) => s.keys), ...extra]);
}
const LIST_SKIP = skipOf(LIST_SPEC, ['id', 'items']);
const ITEM_SKIP = skipOf(ITEM_SPEC);

// Zeit eines Werts: eigene Zeit, sonst die Zeit des ganzen Eintrags
function fieldT(obj, f) {
  const t = obj.t && typeof obj.t === 'object' ? obj.t[f] : undefined;
  return typeof t === 'number' ? t : num(obj.u);
}

// Fehlende Zeiten aus u eintragen, bevor sich u aendert
function fill(obj, spec) {
  if (!obj.t || typeof obj.t !== 'object') obj.t = {};
  for (const s of spec) if (typeof obj.t[s.f] !== 'number') obj.t[s.f] = num(obj.u);
}

// Neue Zeit fuer eine Aenderung: immer spaeter als die letzte, auch innerhalb einer Sekunde
const nextU = (now, ...old) => Math.max(now, ...old.map((x) => num(x) + 1));

// Eigene Aenderung eines Werts vermerken (wie S.Stamp)
function stamp(obj, spec, f, now) {
  fill(obj, spec);
  obj.u = nextU(now, obj.u, obj.t[f]);
  obj.t[f] = obj.u;
  return obj.u;
}

// Neuer Eintrag aus dem Abgleich: Kopie ohne Tabellen, Zeiten je Wert eingetragen
function newFrom(inc, spec) {
  const c = {};
  for (const [k, v] of Object.entries(inc)) if (k !== 'm' && v !== null && v !== undefined && typeof v !== 'object') c[k] = v;
  c.u = num(inc.u);
  c.t = {};
  for (const s of spec) c.t[s.f] = fieldT(inc, s.f);
  return c;
}

// inc in einen vorhandenen Eintrag cur einmischen (wie S.MergeFields). true, wenn sich etwas geaendert hat
function mergeFields(cur, inc, spec, skip) {
  let changed = false;
  fill(cur, spec);
  for (const s of spec) {
    const ti = fieldT(inc, s.f);
    if (ti > cur.t[s.f]) {
      for (const k of s.keys) { if (inc[k] === undefined || inc[k] === null) delete cur[k]; else cur[k] = inc[k]; }
      if (s.reset) delete cur[s.reset];
      cur.t[s.f] = ti;
      changed = true;
    }
  }
  for (const [k, v] of Object.entries(inc)) {
    if (!skip.has(k) && cur[k] === undefined && v !== null && v !== undefined && typeof v !== 'object') { cur[k] = v; changed = true; }
  }
  if (num(inc.u) > num(cur.u)) { cur.u = num(inc.u); delete cur.m; changed = true; }
  return changed;
}

const empty = () => ({ lists: [], gone: { lists: {}, items: {} } });

function clean(doc) {
  const d = doc && typeof doc === 'object' ? doc : {};
  const lists = Array.isArray(d.lists) ? d.lists : Object.values(d.lists || {});
  const gone = d.gone && typeof d.gone === 'object' ? d.gone : {};
  return {
    lists: lists.filter((l) => l && typeof l.id === 'string').map((l) => ({ ...l, u: Number(l.u) || 0, items: l.items && typeof l.items === 'object' ? { ...l.items } : {} })),
    gone: { lists: { ...(gone.lists || {}) }, items: { ...(gone.items || {}) } },
    ...(d.touched ? { touched: d.touched } : {}),
  };
}

// inc in doc einmischen. Rueckgabe: true, wenn sich etwas geaendert hat. Bei gleicher Zeit bleibt der eigene Stand.
function merge(doc, inc) {
  const incoming = clean(inc);
  let changed = false;
  for (const il of incoming.lists) {
    const goneL = Number(doc.gone.lists[il.id]) || 0;
    let l = doc.lists.find((x) => x.id === il.id);
    if (!l) {
      if (goneL >= il.u) continue;
      l = newFrom(il, LIST_SPEC);
      l.items = {};
      doc.lists.push(l);
      if (goneL) delete doc.gone.lists[il.id];
      changed = true;
    } else if (mergeFields(l, il, LIST_SPEC, LIST_SKIP)) {
      changed = true;
    }
    for (const [key, it] of Object.entries(il.items)) {
      if (!it || typeof it !== 'object') continue;
      const u = Number(it.u) || 0;
      const gk = `${il.id}|${key}`;
      const goneI = Number(doc.gone.items[gk]) || 0;
      const cur = l.items[key];
      if (cur) {
        if (mergeFields(cur, it, ITEM_SPEC, ITEM_SKIP)) changed = true;
      } else if (u > goneI) {
        l.items[key] = newFrom(it, ITEM_SPEC);
        if (goneI) delete doc.gone.items[gk];
        changed = true;
      }
    }
  }
  for (const [id, t] of Object.entries(incoming.gone.lists)) {
    const when = Number(t) || 0;
    const at = doc.lists.findIndex((x) => x.id === id);
    let there = at >= 0;
    if (there && when >= doc.lists[at].u) { doc.lists.splice(at, 1); there = false; changed = true; }
    if (!there && when > (Number(doc.gone.lists[id]) || 0)) { doc.gone.lists[id] = when; changed = true; }
  }
  for (const [gk, t] of Object.entries(incoming.gone.items)) {
    const when = Number(t) || 0;
    const cut = gk.indexOf('|');
    const id = gk.slice(0, cut), key = gk.slice(cut + 1);
    const l = doc.lists.find((x) => x.id === id);
    const cur = l && l.items[key];
    if (cur && when >= (Number(cur.u) || 0)) { delete l.items[key]; changed = true; }
    if (!(l && l.items[key]) && when > (Number(doc.gone.items[gk]) || 0)) { doc.gone.items[gk] = when; changed = true; }
  }
  return changed;
}

// Alte Loeschmarken entfernen. Rueckgabe: true, wenn sich etwas geaendert hat
function purge(doc, now) {
  let changed = false;
  const limit = now - GONE_DAYS * 86400;
  for (const part of [doc.gone.lists, doc.gone.items]) {
    for (const k of Object.keys(part)) if (Number(part[k]) < limit) { delete part[k]; changed = true; }
  }
  return changed;
}

// Fuer Data.lua: ohne interne Merker
function forGame(doc) {
  return {
    lists: doc.lists.map((l) => {
      const items = {};
      for (const [k, it] of Object.entries(l.items)) { const c = { ...it }; delete c.m; items[k] = c; }
      return { id: l.id, name: l.name, pct: l.pct, u: l.u, ...(l.t ? { t: l.t } : {}), items };
    }),
    gone: doc.gone,
  };
}

function newList(doc, name, now) {
  const id = `m${now}_${Math.floor(Math.random() * 1e6)}`;
  const list = { id, name: String(name || '').trim() || `Liste ${doc.lists.length + 1}`, pct: 10, u: now, m: 1, items: {} };
  doc.lists.push(list);
  return list;
}

function deleteList(doc, id, now) {
  const at = doc.lists.findIndex((x) => x.id === id);
  if (at < 0) return false;
  doc.gone.lists[id] = nextU(now, doc.lists[at].u);
  doc.touched = { ...(doc.touched || {}), [`l:${id}`]: doc.gone.lists[id] };
  doc.lists.splice(at, 1);
  return true;
}

function updateList(doc, id, { name, pct } = {}, now) {
  const l = doc.lists.find((x) => x.id === id);
  if (!l) return null;
  if (name !== undefined && String(name).trim()) { l.name = String(name).trim(); stamp(l, LIST_SPEC, 'name', now); }
  if (pct !== undefined) { l.pct = Math.max(0, Math.min(90, Math.round(Number(pct) || 0))); stamp(l, LIST_SPEC, 'pct', now); }
  l.m = 1;
  return l;
}

function addItem(doc, id, key, { name, quality } = {}, now) {
  const l = doc.lists.find((x) => x.id === id);
  if (!l) return null;
  const k = String(key);
  if (l.items[k]) return l.items[k];
  const it = { u: nextU(now, doc.gone.items[`${id}|${k}`]), m: 1 };
  if (name) it.name = name;
  if (quality != null) it.q = quality;
  l.items[k] = it;
  delete doc.gone.items[`${id}|${k}`];
  return it;
}

function removeItem(doc, id, key, now) {
  const l = doc.lists.find((x) => x.id === id);
  const k = String(key);
  if (!l || !l.items[k]) return false;
  const t = nextU(now, l.items[k].u);
  doc.gone.items[`${id}|${k}`] = t;
  doc.touched = { ...(doc.touched || {}), [`i:${id}|${k}`]: t };
  delete l.items[k];
  return true;
}

// wish: Menge, max: Hoechstpreis je Stueck in Kupfer, leer = keine Vorgabe
function setItem(doc, id, key, { wish, max } = {}, now) {
  const l = doc.lists.find((x) => x.id === id);
  const it = l && l.items[String(key)];
  if (!it) return null;
  if (wish !== undefined) { if (Number(wish) >= 1) it.wish = Math.floor(Number(wish)); else delete it.wish; stamp(it, ITEM_SPEC, 'wish', now); }
  if (max !== undefined) { if (Number(max) > 0) it.max = Math.round(Number(max)); else delete it.max; stamp(it, ITEM_SPEC, 'max', now); }
  it.m = 1;
  return it;
}

// Eingaben im Manager, die das Spiel seit `since` noch nicht geladen hat
function pending(doc, since) {
  let n = 0;
  for (const l of doc.lists) {
    if (l.m && l.u > since) n++;
    for (const it of Object.values(l.items)) if (it.m && it.u > since) n++;
  }
  for (const t of Object.values(doc.touched || {})) if (t > since) n++;
  return n;
}

// Betrag fuer die Meldung von Windows
function money(copper) {
  const c = Math.round(copper);
  const g = Math.floor(c / 10000), s = Math.floor(c / 100) % 100, k = c % 100;
  return [g ? `${g}g` : '', s ? `${s}s` : '', k || (!g && !s) ? `${k}c` : ''].filter(Boolean).join(' ');
}

module.exports = { empty, clean, merge, purge, forGame, newList, deleteList, updateList, addItem, removeItem, setItem, pending, money, GONE_DAYS,
  LIST_SPEC, ITEM_SPEC, fieldT, fill, stamp, nextU, newFrom, mergeFields };
