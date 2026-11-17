'use strict';
// Peon Manager - Stabilitaet der Preise je Gegenstand, Kategorie und Markt (ab Manager 0.45.0, KarloDerBaer 17.11.2026,
// Messung mit echten Daten in Peon_Manager_Stabilitaet.md).
// Preis: Massenware die guenstigsten 25 % (p25), sonst das guenstigste Angebot (min).
// Zwei Teile:
//   Stunden: mittlere Bewegung von Stand zu Stand der Blizzard-API (7 Tage, Paare hoechstens gut 2 Std. auseinander,
//            die groessten 5 % zaehlen nicht). Mindestens 48 Staende und im Schnitt 3 Angebote.
//   Tage:    Schwankung der Tageswerte wie F36 (1,4826 x MAD / Mitte, mindestens 5 %), 14 Tage, Tageswert = Median aller
//            Preise des Tages (Kennzahlen und 3-Stunden-Werte), mindestens 3 Preise je Tag und 5 Tage.
// Stufe je Teil nach Grenzen, Index 0 bis 100 so, dass die Grenzen bei 80, 60, 40 und 20 liegen. Gesamt zaehlt der
// schlechtere Teil. Die Richtung (erster zu letztem Tageswert) steht daneben und zaehlt nicht.
// Kategorien und Markt: Median der Gegenstaende, ohne Gegenstaende mit weniger als 20 Angeboten im Schnitt (alle Staende).

const { dayOf } = require('./broker');
const { hourFrom } = require('./db');

const HOUR_DAYS = 7, DAY_DAYS = 14;
const MIN_STANDS = 48, MIN_MOVES = 40, MIN_AUC = 3, MAX_GAP = 2 * 3600 + 600, TRIM = 0.95;
const MIN_DAY_VALUES = 3, MIN_DAYS = 5, MIN_SCHW = 0.05;
const FEW = 20;                        // darunter: wenig Angebote, zaehlt nicht fuer Kategorie und Markt (Messung: duenne Maerkte springen)
const CRAFT_CLASS = 7;                 // Klasse Handwerkswaren
const HOUR_LIMITS = [0.01, 0.03, 0.06, 0.10];
const DAY_LIMITS = [0.08, 0.15, 0.25, 0.40];
const LEVELS = ['sehr stabil', 'stabil', 'mittel', 'unruhig', 'unsicher'];
const HIST_DAYS = 30;

const median = (xs) => {
  if (!xs.length) return null;
  const v = Float64Array.from(xs).sort();
  const m = v.length >> 1;
  return v.length % 2 ? v[m] : (v[m - 1] + v[m]) / 2;
};

// Wert eines Teils -> Index 0 bis 100. Bis zur ersten Grenze 100 bis 80, dann je Stufe 20, ab der letzten Grenze bis
// zum Doppelten auf 0.
function indexOf(x, limits) {
  if (x == null) return null;
  let lo = 0;
  for (let k = 0; k < limits.length; k++) {
    if (x <= limits[k]) return 100 - 20 * k - 20 * (x - lo) / (limits[k] - lo);
    lo = limits[k];
  }
  const top = limits[limits.length - 1];
  return Math.max(0, 20 - 20 * (x - top) / top);
}

// Index -> Stufe 0 (sehr stabil) bis 4 (unsicher)
function levelOf(idx) {
  if (idx == null) return null;
  if (idx >= 80) return 0;
  if (idx >= 60) return 1;
  if (idx >= 40) return 2;
  if (idx >= 20) return 3;
  return 4;
}

// Stundenteil aus Zeit- und Preisreihe (aufsteigend nach Zeit)
function hourPart(ts, ps) {
  const moves = [];
  for (let i = 1; i < ts.length; i++) {
    if (ts[i] - ts[i - 1] > MAX_GAP || !(ps[i] > 0) || !(ps[i - 1] > 0)) continue;
    moves.push(Math.abs(Math.log(ps[i] / ps[i - 1])));
  }
  if (moves.length < MIN_MOVES) return null;
  moves.sort((a, b) => a - b);
  const n = Math.ceil(moves.length * TRIM);
  let s = 0;
  for (let i = 0; i < n; i++) s += moves[i];
  return Math.exp(s / n) - 1;
}

// Tagesteil aus Map Tag -> Preise. Rueckgabe { schw, days, dir, span } oder null
function dayPart(days) {
  const dv = [...days.entries()].filter(([, v]) => v.length >= MIN_DAY_VALUES).sort((a, b) => a[0] - b[0]);
  if (dv.length < MIN_DAYS) return null;
  const xs = dv.map(([, v]) => median(v));
  const mitte = median(xs);
  if (!(mitte > 0)) return null;
  const schw = Math.max(1.4826 * median(xs.map((x) => Math.abs(x - mitte))) / mitte, MIN_SCHW);
  const first = xs[0], last = xs[xs.length - 1];
  return { schw, days: xs.length, dir: first > 0 ? last / first - 1 : null, span: dv[dv.length - 1][0] - dv[0][0] };
}

// Ablage je Gegenstand als Liste (bei vielen tausend Gegenstaenden etwa halb so gross wie Objekte)
const FIELDS = ['h', 'd', 'i', 'g', 'ih', 'id', 'dir', 'days', 'span', 'a', 'm', 'f', 'c', 's'];
const r4 = (x) => (x == null ? null : Math.round(x * 10000) / 10000);
function pack(x) { return FIELDS.map((k) => (k === 'h' || k === 'd' || k === 'dir' ? r4(x[k]) : x[k])); }
function unpack(a) {
  if (!Array.isArray(a)) return null;
  const x = {};
  FIELDS.forEach((k, i) => { x[k] = a[i]; });
  return x;
}

// Ergebnis eines Gegenstands aus beiden Teilen
function rate(h, d) {
  const ih = indexOf(h, HOUR_LIMITS);
  const id = d ? indexOf(d.schw, DAY_LIMITS) : null;
  const idx = ih == null ? id : id == null ? ih : Math.min(ih, id);
  return { idx, lv: levelOf(idx), ih, id };
}

// Zusammenfassung einer Gruppe von Gegenstaenden (nur zaehlende)
function summary(list) {
  const xs = list.filter((x) => !x.f && x.i != null);
  if (!xs.length) return null;
  const idx = median(xs.map((x) => x.i));
  const hs = xs.filter((x) => x.h != null).map((x) => x.h);
  const ds = xs.filter((x) => x.d != null).map((x) => x.d);
  const per = [0, 0, 0, 0, 0];
  for (const x of xs) per[x.g]++;
  return { n: xs.length, i: Math.round(idx), g: levelOf(idx), h: median(hs), d: median(ds), per };
}

// Rechnung fuer einen Markt in Schritten (yield nach groesseren Abschnitten). Ergebnis in out.value
function* marketSteps(db, mid, now, out = {}) {
  const fromH = now - HOUR_DAYS * 86400, fromD = now - DAY_DAYS * 86400;
  const info = new Map();
  for (const r of db.prepare('SELECT key, item_id, variant, commodity FROM items').iterate()) info.set(r.key, r);
  const cls = new Map();
  for (const r of db.prepare('SELECT item_id, cls, sub, cls_name, sub_name, stack FROM items WHERE variant IS NULL AND cls IS NOT NULL AND cls >= 0').iterate()) cls.set(r.item_id, r);
  const massOf = (key) => {
    const i = info.get(key);
    if (!i) return false;
    if (i.variant) return false;
    if (i.commodity != null) return i.commodity === 1;
    const c = cls.get(i.item_id);
    return !!(c && c.stack === 1);   // wie Broker: stapelbar gilt als Massenware, solange das Spiel nichts anderes sagt
  };
  yield;

  // Staende: alle Komplettscans und Staende der API der letzten 14 Tage, die API-Staende der letzten 7 Tage fuer die Stunden
  const stands = new Map();
  let apiStands = 0;
  for (const s of db.prepare("SELECT sid, t, art FROM snapshots WHERE market_id = ? AND source = 'scan' AND t >= ? AND sid IS NOT NULL").iterate(mid, fromD)) {
    const api = s.art === 'api' && s.t >= fromH;
    if (api) apiStands++;
    stands.set(s.sid, { t: s.t, api, day: dayOf(s.t) });
  }
  const items = new Map();
  const get = (key) => {
    let it = items.get(key);
    if (!it) { it = { mass: massOf(key), ts: [], ps: [], auc: 0, n: 0, aucAll: 0, nAll: 0, days: new Map() }; items.set(key, it); }
    return it;
  };
  const addDay = (it, d, p) => {
    let v = it.days.get(d);
    if (!v) { v = []; it.days.set(d, v); }
    v.push(p);
  };
  let rows = 0;
  // ueber die Nummern der Staende statt den Index je Markt: mit echten Daten 5 statt 19 Sek. (3,7 Mio. Zeilen)
  for (const r of db.prepare("SELECT sid, item_key, min, p25, auctions FROM item_snap WHERE sid IN (SELECT sid FROM snapshots WHERE market_id = ? AND source = 'scan' AND t >= ? AND sid IS NOT NULL)").iterate(mid, fromD)) {
    const s = stands.get(r.sid);
    if (!s) continue;
    const it = get(r.item_key);
    const p = it.mass && r.p25 > 0 ? r.p25 : r.min;
    if (!(p > 0)) continue;
    addDay(it, s.day, p);
    it.aucAll += r.auctions || 0;
    it.nAll++;
    if (s.api) { it.ts.push(s.t); it.ps.push(p); it.auc += r.auctions || 0; it.n++; }
    if (++rows % 200000 === 0) yield;
  }
  // aeltere Tage, schon zu 3-Stunden-Werten verdichtet (Tag je Zeitpunkt nur einmal rechnen)
  const dayAt = new Map();
  for (const r of db.prepare("SELECT item_key, t, min, p25 FROM item_hour WHERE market_id = ? AND hour >= ? AND source = 'scan' AND t >= ?").iterate(mid, hourFrom(fromD), fromD)) {
    const it = get(r.item_key);
    const p = it.mass && r.p25 > 0 ? r.p25 : r.min;
    if (p > 0) {
      let d = dayAt.get(r.t);
      if (d == null) { d = dayOf(r.t); dayAt.set(r.t, d); }
      addDay(it, d, p);
    }
    if (++rows % 200000 === 0) yield;
  }
  yield;

  const list = {};
  const all = [];
  for (const [key, it] of items) {
    let h = null;
    if (it.n >= MIN_STANDS && it.auc / it.n >= MIN_AUC) {
      const order = it.ts.map((t, i) => i).sort((a, b) => it.ts[a] - it.ts[b]);
      h = hourPart(order.map((i) => it.ts[i]), order.map((i) => it.ps[i]));
    }
    const d = dayPart(it.days);
    if (h == null && !d) continue;
    const r = rate(h, d);
    const auc = it.nAll ? it.aucAll / it.nAll : null;
    const i = info.get(key);
    const c = i ? cls.get(i.item_id) : null;
    const x = { h, d: d ? d.schw : null, i: Math.round(r.idx), g: r.lv, ih: r.ih == null ? null : Math.round(r.ih), id: r.id == null ? null : Math.round(r.id),
      dir: d ? d.dir : null, days: d ? d.days : 0, span: d ? d.span : 0, a: auc == null ? null : Math.round(auc * 10) / 10, m: it.mass ? 1 : 0,
      f: auc == null || auc < FEW ? 1 : 0, c: c ? c.cls : null, s: c ? c.sub : null };
    list[key] = pack(x);
    all.push(x);
  }
  yield;

  // Kategorien wie im Auktionshaus: Klasse und darunter Unterklasse
  const names = new Map();
  for (const c of cls.values()) {
    if (c.cls_name && !names.has(`c${c.cls}`)) names.set(`c${c.cls}`, c.cls_name);
    if (c.sub != null && c.sub_name && !names.has(`c${c.cls}/s${c.sub}`)) names.set(`c${c.cls}/s${c.sub}`, c.sub_name);
  }
  const groupsOf = new Map();
  const put = (k, x) => { let g = groupsOf.get(k); if (!g) { g = []; groupsOf.set(k, g); } g.push(x); };
  for (const x of all) {
    if (x.c == null) { put('c?', x); continue; }
    put(`c${x.c}`, x);
    if (x.s != null) put(`c${x.c}/s${x.s}`, x);
  }
  const cats = [];
  for (const [k, g] of groupsOf) {
    const sm = summary(g);
    if (!sm) continue;
    const sub = k.includes('/');
    cats.push({ key: k, parent: sub ? k.split('/')[0] : null, name: names.get(k) || (k === 'c?' ? 'Ohne Kategorie' : k), ...sm,
      mass: summary(g.filter((x) => x.m)) });
  }
  const top = (c) => (c.key === 'c?' ? '￿' : names.get(c.parent || c.key) || c.parent || c.key);
  cats.sort((a, b) => top(a).localeCompare(top(b), 'de') || (a.parent ? 1 : 0) - (b.parent ? 1 : 0) || a.name.localeCompare(b.name, 'de'));

  out.value = {
    t: now, apiStands, items: list,
    groups: {
      all: summary(all),
      mass: summary(all.filter((x) => x.m)),
      craft: summary(all.filter((x) => x.c === CRAFT_CLASS)),
      single: summary(all.filter((x) => !x.m)),
    },
    cats,
  };
  return out.value;
}

// Verlauf des Markts: ein Eintrag je Rechnung, HIST_DAYS Tage
function addHistory(hist, value) {
  const list = Array.isArray(hist) ? hist.filter((x) => x && x.t > value.t - HIST_DAYS * 86400 && x.t < value.t) : [];
  const g = value.groups;
  const pick = (s) => (s ? { i: s.i, n: s.n, h: s.h, d: s.d } : null);
  list.push({ t: value.t, all: pick(g.all), mass: pick(g.mass), craft: pick(g.craft) });
  return list;
}

module.exports = { marketSteps, pack, unpack, addHistory, indexOf, levelOf, hourPart, dayPart, rate, summary, HOUR_LIMITS, DAY_LIMITS, LEVELS, FEW, CRAFT_CLASS,
  HOUR_DAYS, DAY_DAYS, MIN_STANDS, MIN_DAYS };
