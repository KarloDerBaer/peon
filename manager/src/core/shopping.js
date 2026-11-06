'use strict';
// Peon Manager - Einkaufslisten (Modul Peon Broker Client). Gleicher Aufbau wie im Spiel (Peon_Broker, Shop.lua):
//   { lists: [{ id, name, pct, u, items: { [Schluessel]: { wish, max, name, q, icon, u } } }], gone: { lists: { id: t }, items: { 'id|Schluessel': t } } }
// u = letzte Aenderung, gone = Loeschmarken. Beide Seiten koennen aendern, je Eintrag gewinnt die neuere Aenderung.
// Das Spiel liefert ueber Peon_Broker.lua, der Manager ueber Data.lua. Die Regeln muessen gleich bleiben wie in Shop.lua (Test: umbau2.test.js).

const GONE_DAYS = 60;   // so lange bleiben Loeschmarken stehen

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
      l = { id: il.id, name: il.name, pct: il.pct, u: il.u, items: {} };
      doc.lists.push(l);
      if (goneL) delete doc.gone.lists[il.id];
      changed = true;
    } else if (il.u > l.u) {
      l.name = il.name; l.pct = il.pct; l.u = il.u; delete l.m;
      changed = true;
    }
    for (const [key, it] of Object.entries(il.items)) {
      const u = Number(it && it.u) || 0;
      const gk = `${il.id}|${key}`;
      const goneI = Number(doc.gone.items[gk]) || 0;
      const cur = l.items[key];
      if (cur ? u > (Number(cur.u) || 0) : u > goneI) {
        const next = { ...it, u };
        delete next.m;
        l.items[key] = next;
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
      return { id: l.id, name: l.name, pct: l.pct, u: l.u, items };
    }),
    gone: doc.gone,
  };
}

// Neue Zeit fuer eine Aenderung: immer spaeter als die letzte, auch innerhalb einer Sekunde
const nextU = (now, ...old) => Math.max(now, ...old.map((x) => (Number(x) || 0) + 1));

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
  if (name !== undefined && String(name).trim()) l.name = String(name).trim();
  if (pct !== undefined) l.pct = Math.max(0, Math.min(90, Math.round(Number(pct) || 0)));
  l.u = nextU(now, l.u);
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
  if (wish !== undefined) { if (Number(wish) >= 1) it.wish = Math.floor(Number(wish)); else delete it.wish; }
  if (max !== undefined) { if (Number(max) > 0) it.max = Math.round(Number(max)); else delete it.max; }
  it.u = nextU(now, it.u);
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

module.exports = { empty, clean, merge, purge, forGame, newList, deleteList, updateList, addItem, removeItem, setItem, pending, money, GONE_DAYS };
