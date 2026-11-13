'use strict';
// Peon Manager - Abgleich nachvollziehen (ab 0.31.0, Angleichung A3, Peon_Manager_Angleichung.md 3.3 bis 3.6).
// Reine Funktionen ohne Datenbank:
//   diffShop, diffWatch   Was hat sich zwischen zwei Staenden geaendert? Je Aenderung ein Eintrag fuer das Protokoll
//   pendFrom              Eingaben im Manager, die das Spiel noch bestaetigen muss (Zustand je Zeile)
//   checkPending          Bestaetigung aus Peon_Broker.lua, dabei Werte erkennen, die an beiden Stellen geaendert wurden
// Schluessel einer Aenderung (pkey): l|Liste|Wert, i|Liste|Gegenstand|Wert, w|Gegenstand|Wert,
// Wert "+" = angelegt, "-" = geloescht, sonst name, pct, wish, max (Listen) oder buy, up (Beobachtung).

const { fieldT } = require('./shopping');

const LOG_DAYS = 90;     // so lange bleibt das Protokoll
const TRASH_DAYS = 30;   // so lange laesst sich Geloeschtes wiederherstellen
const PEND_DAYS = 60;    // so lange wartet eine Eingabe auf die Bestaetigung aus dem Spiel

const LIST_F = ['name', 'pct'];
const ITEM_F = ['wish', 'max'];
const WATCH_F = ['buy', 'up'];

const num = (v) => Number(v) || 0;
const clone = (x) => JSON.parse(JSON.stringify(x === undefined ? null : x));
const same = (a, b) => JSON.stringify(a ?? null) === JSON.stringify(b ?? null);

// Wert einer Beobachtung: Kaufen bis als { lim } oder { pct }, Zielpreis als Zahl
function watchVal(w, f) {
  if (!w) return null;
  if (f === 'buy') return w.lim != null ? { lim: w.lim } : w.pct != null ? { pct: w.pct } : null;
  return w.up ?? null;
}

function shopVal(e, f) { return e ? (e[f] ?? null) : null; }

// Einkaufslisten: Aenderungen von before nach after
function diffShop(before, after) {
  const out = [];
  const bl = new Map(before.lists.map((l) => [l.id, l]));
  const al = new Map(after.lists.map((l) => [l.id, l]));
  for (const [id, l] of al) {
    const o = bl.get(id);
    if (!o) {
      out.push({ area: 'shop', kind: 'neu', listId: id, listName: l.name, field: '+', pkey: `l|${id}|+`, t: num(l.u), n: Object.keys(l.items).length });
      continue;
    }
    for (const f of LIST_F) {
      if (!same(o[f], l[f])) out.push({ area: 'shop', kind: 'geändert', listId: id, listName: l.name, field: f, old: o[f] ?? null, new: l[f] ?? null, pkey: `l|${id}|${f}`, t: fieldT(l, f), base: fieldT(o, f) });
    }
    for (const [k, it] of Object.entries(l.items)) {
      const oi = o.items[k];
      if (!oi) { out.push({ area: 'shop', kind: 'neu', listId: id, listName: l.name, key: k, name: it.name || null, field: '+', pkey: `i|${id}|${k}|+`, t: num(it.u) }); continue; }
      for (const f of ITEM_F) {
        if (!same(oi[f], it[f])) out.push({ area: 'shop', kind: 'geändert', listId: id, listName: l.name, key: k, name: it.name || oi.name || null, field: f, old: oi[f] ?? null, new: it[f] ?? null, pkey: `i|${id}|${k}|${f}`, t: fieldT(it, f), base: fieldT(oi, f) });
      }
    }
    for (const [k, oi] of Object.entries(o.items)) {
      if (!l.items[k]) out.push({ area: 'shop', kind: 'gelöscht', listId: id, listName: l.name, key: k, name: oi.name || null, field: '-', pkey: `i|${id}|${k}|-`, t: num(after.gone.items[`${id}|${k}`]), data: clone(oi) });
    }
  }
  for (const [id, o] of bl) {
    if (!al.has(id)) out.push({ area: 'shop', kind: 'gelöscht', listId: id, listName: o.name, field: '-', pkey: `l|${id}|-`, t: num(after.gone.lists[id]), n: Object.keys(o.items).length, data: clone(o) });
  }
  return out;
}

// Beobachtung: Aenderungen von before nach after
function diffWatch(before, after) {
  const out = [];
  for (const [k, w] of Object.entries(after.items)) {
    const o = before.items[k];
    if (!o) { out.push({ area: 'watch', kind: 'neu', key: k, name: w.name || null, field: '+', pkey: `w|${k}|+`, t: num(w.u) }); continue; }
    for (const f of WATCH_F) {
      const a = watchVal(o, f), b = watchVal(w, f);
      if (!same(a, b)) out.push({ area: 'watch', kind: 'geändert', key: k, name: w.name || o.name || null, field: f, old: a, new: b, pkey: `w|${k}|${f}`, t: fieldT(w, f), base: fieldT(o, f) });
    }
  }
  for (const [k, o] of Object.entries(before.items)) {
    if (!after.items[k]) out.push({ area: 'watch', kind: 'gelöscht', key: k, name: o.name || null, field: '-', pkey: `w|${k}|-`, t: num(after.gone[k]), data: clone(o) });
  }
  return out;
}

// Aus Aenderungen im Manager die wartenden Eintraege: pkey -> { t, base, v }
function pendFrom(changes) {
  const out = {};
  for (const c of changes) out[c.pkey] = { t: c.t, base: c.base ?? 0, v: c.new ?? null };
  return out;
}

// Eintrag und Loeschmarke im Stand des Spiels finden
function gameShopEntry(game, listId, key) {
  const lists = Array.isArray(game.lists) ? game.lists : Object.values(game.lists || {});
  const l = lists.find((x) => x && x.id === listId);
  const gone = game.gone || {};
  if (key === undefined) return { e: l || null, gone: num((gone.lists || {})[listId]) };
  const items = (l && l.items) || {};
  return { e: items[key] || items[Number(key)] || null, gone: num((gone.items || {})[`${listId}|${key}`]) };
}

function gameWatchEntry(game, key) {
  const items = game.items || {};
  let e = items[key] ?? items[Number(key)] ?? null;
  if (e !== null && typeof e !== 'object') e = { u: num(e) };
  return { e, gone: num((game.gone || {})[key] ?? (game.gone || {})[Number(key)]) };
}

// Wartende Eintraege eines Bereichs gegen den Stand aus dem Spiel pruefen. pend wird veraendert.
// Rueckgabe: Werte, die an beiden Stellen geaendert wurden: [{ pkey, mv, gv, wins: 'spiel' | 'manager' }]
function checkPending(pend, area, game, now) {
  const conflicts = [];
  if (!game) return conflicts;
  for (const [pkey, p] of Object.entries(pend)) {
    const parts = pkey.split('|');
    const kind = parts[0];
    if ((area === 'shop') !== (kind === 'l' || kind === 'i')) continue;
    if (p.t < now - PEND_DAYS * 86400) { delete pend[pkey]; continue; }
    const f = parts[parts.length - 1];
    let found;
    if (kind === 'l') found = gameShopEntry(game, parts[1]);
    else if (kind === 'i') found = gameShopEntry(game, parts[1], parts.slice(2, -1).join('|'));
    else found = gameWatchEntry(game, parts.slice(1, -1).join('|'));
    const { e, gone } = found;
    if (f === '+') { if ((e && num(e.u) >= p.t) || gone >= p.t) delete pend[pkey]; continue; }
    if (f === '-') { if (gone >= p.t || (e && num(e.u) > p.t)) delete pend[pkey]; continue; }
    if (!e) { if (gone >= p.t) delete pend[pkey]; continue; }
    const gt = fieldT(e, f);
    const gv = kind === 'w' ? watchVal(e, f) : shopVal(e, f);
    if (gt === p.t) { delete pend[pkey]; continue; }
    if (gt > p.t) { if (!same(gv, p.v)) conflicts.push({ pkey, mv: p.v, gv, wins: 'spiel' }); delete pend[pkey]; continue; }
    if (gt > p.base) {
      if (!same(gv, p.v)) conflicts.push({ pkey, mv: p.v, gv, wins: 'manager' });
      p.base = gt;   // nur einmal melden
    }
  }
  return conflicts;
}

module.exports = { diffShop, diffWatch, pendFrom, checkPending, watchVal, clone, LOG_DAYS, TRASH_DAYS, PEND_DAYS };
