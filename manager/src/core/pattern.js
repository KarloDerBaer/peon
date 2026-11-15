'use strict';
// Peon Manager - Muster nach Tageszeit und Wochentag (ab 0.38.0, Konzept Peon_Chancen_Reiter_Muster.md, Abschnitt 5).
// Einmal am Tag je Markt aus den Kennzahlen der letzten 28 Tage (item_snap, verdichtet item_hour):
//   Preis (guenstigstes Angebot) je Gegenstand, Tag und 3-Stunden-Abschnitt in Ortszeit des Rechners.
//   Der Trend wird herausgerechnet: jeder Abschnitt gegen das Tagesmittel, das zwischen den Tagesmitten gleitend verlaeuft.
//   Ohne das ist in einem fallenden Markt der spaete Abend immer am guenstigsten (Messung 14.11.2026).
// Tageszeit: >= 14 Tage, an >= 70 % der Tage derselbe guenstigste Abschnitt, Abstand nach Gebuehr >= 15 %.
// Wochentag: >= 3 Wochen, derselbe guenstigste Wochentag in >= 3 Wochen und >= 75 % der Wochen, Abstand nach Gebuehr >= 15 %.
// Nur Gegenstaende mit im Schnitt mindestens 5 Angeboten.
// Ergebnis: Map key -> { kind: 'tod' | 'wd', lo, hi, rel: { lo, hi }, spread, hits, n } (lo/hi: Abschnitt 0-7 oder Wochentag 0-6, Montag 0)

const SLOTS = 8, SLOT_H = 3;
const SPAN_DAYS = 28;
const P = { todDays: 14, todSure: 0.7, wdWeeks: 3, wdSure: 0.75, spread: 0.15, minAuctions: 5, cut: 0.05, minSlots: 6 };

const med = (xs) => { const v = [...xs].sort((a, b) => a - b); const m = v.length >> 1; return v.length % 2 ? v[m] : (v[m - 1] + v[m]) / 2; };

// Abstand der Ortszeit zu UTC in Sekunden (fuer Tag und Abschnitt in SQL)
function tzOffset(t) { return -new Date(t * 1000).getTimezoneOffset() * 60; }

// Mittel je Gegenstand, Ortstag und Abschnitt. Rueckgabe Map key -> Map day -> Array(8) Preis oder null, dazu Angebote.
// Als Schritte (yield alle 20000 Zeilen), damit der Arbeitsprozess dazwischen anderes erledigen kann.
function* gridSteps(db, mid, now, out = new Map()) {
  const off = tzOffset(now);
  const from = now - SPAN_DAYS * 86400;
  const put = (k, day, slot, v, a) => {
    let it = out.get(k);
    if (!it) { it = { days: new Map(), auc: 0, n: 0 }; out.set(k, it); }
    let d = it.days.get(day);
    if (!d) { d = new Array(SLOTS).fill(null); it.days.set(day, d); }
    d[slot] = d[slot] == null ? v : (d[slot] + v) / 2;
    if (a != null) { it.auc += a; it.n++; }
  };
  // ab Manager 0.40.0 je Ortstag eine Abfrage ueber den Index der Zeit ("+market_id"). Vorher eine Abfrage ueber alle Zeilen
  // des Markts, mit echten Daten rund 20 Sek. am Stueck, in denen der Manager nichts anderes tun konnte.
  const q = (table) => `SELECT item_key AS k, CAST((t + ?) / 86400 AS INTEGER) AS day, CAST(((t + ?) % 86400) / ${SLOT_H * 3600} AS INTEGER) AS slot,
      AVG(min) AS v, AVG(auctions) AS a FROM ${table} WHERE +market_id = ? AND source = 'scan' AND t >= ? AND t < ? AND min > 0 GROUP BY item_key, day, slot`;
  const first = Math.floor((from + off) / 86400), last = Math.floor((now + off) / 86400);
  for (const table of ['item_snap', 'item_hour']) {
    const st = db.prepare(q(table));
    for (let day = first; day <= last; day++) {
      const a = Math.max(from, day * 86400 - off), b = (day + 1) * 86400 - off;
      for (const r of st.all(off, off, mid, a, b)) put(r.k, Number(r.day), Number(r.slot), r.v, r.a);
      yield;
    }
  }
  return out;
}
function grid(db, mid, now) {
  const out = new Map();
  for (const _ of gridSteps(db, mid, now, out)) { /* am Stueck */ }
  return out;
}

// Tagesmittel als gleitende Linie: Wert zur Zeit (Tag + Abschnitt) zwischen den Mitten benachbarter Tage
function detrend(days) {
  const list = [...days.keys()].sort((a, b) => a - b);
  const mean = new Map();
  for (const d of list) {
    const v = days.get(d).filter((x) => x != null);
    if (v.length) mean.set(d, med(v));
  }
  const at = (d, slot) => {
    const x = d + (slot + 0.5) / SLOTS - 0.5;   // Tagesmitte = d
    const a = Math.floor(x), b = a + 1;
    const ma = mean.get(a), mb = mean.get(b);
    if (ma != null && mb != null) return ma + (mb - ma) * (x - a);
    return ma ?? mb ?? mean.get(d);
  };
  const rel = new Map();
  for (const d of list) {
    const row = days.get(d).map((v, s) => (v == null ? null : v / at(d, s)));
    rel.set(d, row);
  }
  return { rel, mean };
}

function todPattern(rel) {
  const days = [...rel.values()].filter((r) => r.filter((x) => x != null).length >= P.minSlots);
  if (days.length < P.todDays) return null;
  const lowCnt = new Array(SLOTS).fill(0);
  const per = Array.from({ length: SLOTS }, () => []);
  for (const r of days) {
    let lo = -1;
    r.forEach((v, s) => { if (v != null) { per[s].push(v); if (lo < 0 || v < r[lo]) lo = s; } });
    lowCnt[lo]++;
  }
  const m = per.map((x) => (x.length ? med(x) : null));
  let lo = -1, hi = -1;
  m.forEach((v, s) => { if (v == null) return; if (lo < 0 || v < m[lo]) lo = s; if (hi < 0 || v > m[hi]) hi = s; });
  const hits = lowCnt[lo];
  const spread = m[hi] * (1 - P.cut) / m[lo] - 1;
  if (hits / days.length < P.todSure || spread < P.spread) return null;
  return { kind: 'tod', lo, hi, rel: { lo: m[lo], hi: m[hi] }, spread, hits, n: days.length };
}

// Wochentag: Tagesmittel gegen das gleitende 7-Tage-Mittel, je Kalenderwoche der guenstigste Tag
function wdPattern(mean) {
  const days = [...mean.keys()].sort((a, b) => a - b);
  if (days.length < P.wdWeeks * 7 * 0.8) return null;
  const wd = (d) => (d + 3) % 7;   // Tag 0 (1.1.1970) war ein Donnerstag, Montag = 0
  const weeks = new Map();
  const per = Array.from({ length: 7 }, () => []);
  for (const d of days) {
    const around = days.filter((x) => Math.abs(x - d) <= 3).map((x) => mean.get(x));
    if (around.length < 5) continue;
    const r = mean.get(d) / (around.reduce((a, b) => a + b, 0) / around.length);
    per[wd(d)].push(r);
    const w = Math.floor((d + 3) / 7);
    if (!weeks.has(w)) weeks.set(w, new Map());
    weeks.get(w).set(wd(d), r);
  }
  const full = [...weeks.values()].filter((w) => w.size >= 6);
  if (full.length < P.wdWeeks) return null;
  const m = per.map((x) => (x.length ? med(x) : null));
  let lo = -1, hi = -1;
  m.forEach((v, s) => { if (v == null) return; if (lo < 0 || v < m[lo]) lo = s; if (hi < 0 || v > m[hi]) hi = s; });
  let hits = 0;
  for (const w of full) {
    let best = -1;
    for (const [k, v] of w) if (best < 0 || v < w.get(best)) best = k;
    if (best === lo) hits++;
  }
  const spread = m[hi] * (1 - P.cut) / m[lo] - 1;
  if (hits < P.wdWeeks || hits / full.length < P.wdSure || spread < P.spread) return null;
  return { kind: 'wd', lo, hi, rel: { lo: m[lo], hi: m[hi] }, spread, hits, n: full.length };
}

// Alle Muster eines Markts. Ist beides da, zaehlt das mit dem groesseren Abstand.
function marketPatterns(db, mid, now) {
  const out = new Map();
  for (const _ of marketPatternSteps(db, mid, now, out)) { /* am Stueck */ }
  return out;
}
function* marketPatternSteps(db, mid, now, out = new Map()) {
  const g = new Map();
  yield* gridSteps(db, mid, now, g);
  let i = 0;
  for (const [k, it] of g) {
    if (++i % 2000 === 0) yield;
    if (!it.n || it.auc / it.n < P.minAuctions) continue;
    const { rel, mean } = detrend(it.days);
    const a = todPattern(rel), b = wdPattern(mean);
    const p = a && b ? (a.spread >= b.spread ? a : b) : a || b;
    if (p) out.set(k, p);
  }
  return out;
}

// Texte: Abschnitt "0 bis 3 Uhr", Wochentag "Montag"
const WD = ['Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag', 'Sonntag'];
function windowText(kind, x) { return kind === 'tod' ? `${x * SLOT_H} bis ${x * SLOT_H + SLOT_H} Uhr` : WD[x]; }

// Fenster fuer Broker: "Wochentage/Abschnitt", Wochentage als 7 Bits (Montag = 1), Abschnitt -1 = ganzer Tag
function windowCode(kind, x) { return kind === 'tod' ? `127/${x}` : `${1 << x}/-1`; }

// Liegt die Zeit t (Ortszeit) im Fenster?
function inWindow(kind, x, t) {
  const d = new Date(t * 1000);
  if (kind === 'tod') return Math.floor(d.getHours() / SLOT_H) === x;
  return (d.getDay() + 6) % 7 === x;
}

module.exports = { marketPatterns, marketPatternSteps, windowText, windowCode, inWindow, P, SLOTS, SLOT_H, WD, grid, detrend, todPattern, wdPattern };
