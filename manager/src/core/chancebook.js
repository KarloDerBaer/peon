'use strict';
// Peon Manager - Nachpruefen und Korrigieren der Chancen (Konzept Peon_Manager_Chancen.md, Abschnitt 5.5, 7, 8, D5).
//   chance_log   jeder Vorschlag (shown = 1) und jeder Beinahe-Vorschlag (shown = 0) mit allen Werten des Moments,
//                je Gegenstand, Art und Tag einmal. Nach seinem Zeitraum: hit (Ziel erreicht), even (Kaufpreis plus
//                Gebuehr erreicht), miss, none (keine Daten)
//   chance_rate  Rueckmeldungen aus dem Manager (Daumen, Grund, Freitext) und Einschaetzungen aus Broker (ratings)
//   meta chanceRules     Regler je Art (spec.rulesOf)
//   meta chanceOverrides Uebersteuerungen je Gegenstand: { [key]: { never, off: { s, l, b, v }, target, limit, t } }

const { dayOf } = require('./broker');
const spec = require('./spec');
const proof = require('./proof');

const REASONS = ['Scherzpreis', 'verkauft sich nicht', 'Zielpreis zu hoch', 'zu riskant', 'schon bekannt', 'lief gut', 'gekauft'];
const NOTE_MAX = 250;
const WINDOW = { s: 3, b: 1, v: 1 };   // Tage bis zur Nachpruefung (l: Zeitraum der Prognose)
const KEEP = 45;                        // Tage, die D5 aufgehoben wird

function log(db, mid, now, chances, near) {
  const ins = db.prepare(`INSERT OR IGNORE INTO chance_log(market_id, item_key, kind, day, t, shown, buy, target, gain, until, data)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`);
  const promote = db.prepare('UPDATE chance_log SET shown = 1, t = ?, buy = ?, target = ?, gain = ?, until = ?, data = ? WHERE market_id = ? AND item_key = ? AND kind = ? AND day = ? AND shown = 0');
  const day = dayOf(now);
  let n = 0;
  for (const [x, shown] of [...chances.map((c) => [c, 1]), ...near.map((c) => [c, 0])]) {
    const data = JSON.stringify(spec.moment(x));
    const r = ins.run(mid, x.key, x.kind, day, now, shown, x.buy ?? null, x.target ?? null, x.gain ?? null, x.until ?? null, data);
    if (!r.changes && shown) promote.run(now, x.buy ?? null, x.target ?? null, x.gain ?? null, x.until ?? null, data, mid, x.key, x.kind, day);
    n += r.changes;
  }
  return n;
}

// Hoechster belegter Preis in einem Zeitraum (Verkaeufe, sonst Median der Angebote)
function bestPrice(db, mid, key, from, to) {
  const a = db.prepare('SELECT MAX(b) AS b FROM sale_px WHERE market_id = ? AND item_key = ? AND day >= ? AND day <= ?').get(mid, key, dayOf(from), dayOf(to)).b;
  const b = db.prepare("SELECT MAX(median) AS m FROM item_snap WHERE market_id = ? AND item_key = ? AND source = 'scan' AND t > ? AND t <= ?").get(mid, key, from, to).m;
  const c = db.prepare("SELECT MAX(median) AS m FROM item_hour WHERE market_id = ? AND item_key = ? AND source = 'scan' AND t > ? AND t <= ?").get(mid, key, from, to).m;
  const sold = a != null ? proof.priceOf(a) : null;
  const best = Math.max(sold ?? -1, b ?? -1, c ?? -1);
  return best < 0 ? null : { price: best, sold };
}

// Abgelaufene Vorschlaege nachpruefen (Erfolgskontrolle, F55 ist darin aufgegangen)
function check(db, mid, now) {
  const open = db.prepare('SELECT id, item_key, kind, t, buy, target, until FROM chance_log WHERE market_id = ? AND checked IS NULL AND kind <> ?').all(mid, 'v');
  const up = db.prepare('UPDATE chance_log SET outcome = ?, checked = ? WHERE id = ?');
  let n = 0;
  for (const x of open) {
    const end = x.kind === 'l' ? Math.max(x.until || 0, x.t + 86400) : x.t + (WINDOW[x.kind] || 3) * 86400;
    if (end > now) continue;
    const p = bestPrice(db, mid, x.item_key, x.t, end);
    let out = 'none';
    if (p && x.target > 0) out = p.price >= x.target * 0.98 ? 'hit' : x.buy > 0 && p.price * (1 - spec.CUT) >= x.buy ? 'even' : 'miss';
    up.run(out, now, x.id);
    n++;
  }
  db.prepare("UPDATE chance_log SET outcome = 'hit', checked = ? WHERE market_id = ? AND kind = 'v' AND checked IS NULL AND t < ?").run(now, mid, now - 86400);
  db.prepare('DELETE FROM chance_log WHERE t < ?').run(now - KEEP * 86400);
  return n;
}

// Trefferquote je Art ueber days Tage, dazu Verlauf je Tag (Erfolgskontrolle)
function rates(db, mid, now, days = 30) {
  const from = now - days * 86400;
  const out = {};
  for (const k of Object.keys(spec.KINDS)) out[k] = { n: 0, hit: 0, even: 0, miss: 0, open: 0, rate: null, days: [] };
  const byDay = new Map();
  for (const r of db.prepare('SELECT kind, day, outcome FROM chance_log WHERE market_id = ? AND shown = 1 AND t >= ?').iterate(mid, from)) {
    const x = out[r.kind];
    if (!x) continue;
    if (!r.outcome) { x.open++; continue; }
    if (r.outcome === 'none') continue;
    x.n++; x[r.outcome]++;
    const k = `${r.kind}|${r.day}`;
    const d = byDay.get(k) || { kind: r.kind, day: r.day, n: 0, hit: 0 };
    d.n++; if (r.outcome === 'hit') d.hit++;
    byDay.set(k, d);
  }
  for (const x of Object.values(out)) x.rate = x.n ? x.hit / x.n : null;
  for (const d of byDay.values()) out[d.kind].days.push({ day: d.day, n: d.n, rate: d.hit / d.n });
  for (const x of Object.values(out)) x.days.sort((a, b) => a.day - b.day);
  return out;
}

// ---------- Regler mit Probe (7.3) ----------
// Mit anderen Werten: wie viele Vorschlaege waeren es in den letzten 14 Tagen gewesen, wie viele davon haetten sich
// gelohnt, und wie hast du sie bewertet? rules = aktuelle Regeln, next = Regeln mit dem verschobenen Regler
function probe(db, mid, now, kind, rules, next) {
  const res = { kind, days: 14, before: { n: 0, judged: 0, hit: 0 }, after: { n: 0, judged: 0, hit: 0 }, ratingsAdded: {}, ratingsRemoved: {} };
  const rated = new Map();
  for (const r of db.prepare('SELECT item_key, t, up, reason FROM chance_rate WHERE t >= ?').iterate(now - 16 * 86400)) {
    const k = `${r.item_key}|${dayOf(r.t)}`;
    if (!rated.has(k)) rated.set(k, []);
    rated.get(k).push(r);
  }
  const note = (bag, r) => { const label = r.reason || (r.up ? 'Daumen hoch' : r.up === 0 ? 'Daumen runter' : 'bewertet'); bag[label] = (bag[label] || 0) + 1; };
  for (const r of db.prepare('SELECT item_key, day, data, outcome FROM chance_log WHERE market_id = ? AND kind = ? AND t >= ?').iterate(mid, kind, now - 14 * 86400)) {
    let d;
    try { d = JSON.parse(r.data); } catch { continue; }
    const a = spec.passes(kind, d, rules), b = spec.passes(kind, d, next);
    for (const [on, x] of [[a, res.before], [b, res.after]]) {
      if (!on) continue;
      x.n++;
      if (r.outcome && r.outcome !== 'none') { x.judged++; if (r.outcome === 'hit') x.hit++; }
    }
    if (a !== b) for (const rt of rated.get(`${r.item_key}|${r.day}`) || []) note(b ? res.ratingsAdded : res.ratingsRemoved, rt);
  }
  for (const x of [res.before, res.after]) x.rate = x.judged ? x.hit / x.judged : null;
  return res;
}

// ---------- Rueckmeldungen (7.1) ----------
function rate(db, now, { market = null, key, name = null, kind = null, up = null, reason = null, note = '', say = null, data = null, logId = null }) {
  if (!key) return null;
  const r = REASONS.includes(reason) ? reason : null;
  const text = String(note || '').slice(0, NOTE_MAX);
  const res = db.prepare(`INSERT INTO chance_rate(t, origin, market, item_key, item_name, kind, up, reason, note, say, data, log_id)
      VALUES (?, 'manager', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`).run(now, market, String(key), name, kind, up == null ? null : up ? 1 : 0, r, text, say, data ? JSON.stringify(data) : null, logId);
  return Number(res.lastInsertRowid);
}

function deleteRate(db, id) { return db.prepare("DELETE FROM chance_rate WHERE id = ? AND origin = 'manager'").run(Number(id)).changes > 0; }

// Einschaetzungen aus Broker (PeonBrokerDB.ratings, ab Broker 0.91, Art und Satz ab 0.93) einlesen. Einmal je Eintrag.
// added: Liste, in die neue Eintraege kommen (ab 0.35.1, fuer den Reiter Rueckmeldungen)
const RATE_MAP = { bad: 0, mid: null, good: 1 };
function importBroker(db, ratings, added = null) {
  if (!Array.isArray(ratings)) ratings = Object.values(ratings || {});
  const ins = db.prepare(`INSERT OR IGNORE INTO chance_rate(t, origin, market, item_key, item_name, kind, up, reason, note, say, data, ext)
      VALUES (?, 'broker', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`);
  let n = 0;
  for (const r of ratings) {
    if (!r || typeof r !== 'object' || r.key == null || !r.t) continue;
    const radar = r.radar && typeof r.radar === 'object' ? r.radar : null;
    const kind = typeof r.kind === 'string' ? r.kind : radar && radar.kind === 'spec' ? (radar.mk || 's') : radar && radar.kind === 'buyout' ? 'b' : radar && radar.kind === 'vendor' ? 'v' : null;
    const ext = `${r.t}|${r.key}|${r.rate || ''}`;
    const res = ins.run(Number(r.t), r.market || null, String(r.key), r.name || null, kind, r.rate in RATE_MAP ? RATE_MAP[r.rate] : null,
      r.rate === 'mid' ? 'mittel' : null, String(r.note || '').slice(0, NOTE_MAX), typeof r.say === 'string' ? r.say : null, JSON.stringify({ data: r.data || null, radar }), ext);
    n += res.changes;
    if (res.changes && added) added.push({ origin: 'broker', market: r.market || null, key: String(r.key), name: r.name || null, kind,
      up: r.rate in RATE_MAP ? RATE_MAP[r.rate] : null, reason: r.rate === 'mid' ? 'mittel' : null, note: String(r.note || '').slice(0, NOTE_MAX),
      say: typeof r.say === 'string' ? r.say : null, data: { data: r.data || null, radar } });
  }
  return n;
}

// Text fuer den Reiter Rueckmeldungen (ab 0.35.1): Rueckmeldungen zu Chancen gehen so mit „Senden“ als Bericht hinaus.
// Nur Gegenstand, Art, Bewertung und die Werte des Moments, der Markt nur als Fraktion.
const KIND_TEXT = { s: 'Spekulation schnell', l: 'Spekulation langfristig', b: 'Aufkauf', v: 'Händler' };
function feedbackText(f) {
  const fac = (m) => (m ? (/Alliance|Allianz/i.test(m) ? 'Allianz' : /Horde/i.test(m) ? 'Horde' : 'Neutral') : '');
  const lines = [`Rückmeldung zu einer Chance (${f.origin === 'broker' ? 'aus Broker' : 'aus dem Manager'}): ${f.name || 'Gegenstand'} (${f.key})`];
  lines.push(`Art: ${KIND_TEXT[f.kind] || f.kind || 'unbekannt'}${f.market ? `, Markt: ${fac(f.market)}` : ''}`);
  const judge = [f.up === true || f.up === 1 ? 'Daumen hoch' : f.up === false || f.up === 0 ? 'Daumen runter' : null, f.reason].filter(Boolean).join(', ');
  if (judge) lines.push(`Bewertung: ${judge}`);
  if (f.note && String(f.note).trim()) lines.push(`Bemerkung: ${String(f.note).trim()}`);
  if (f.say) lines.push(`Satz: ${f.say}`);
  const d = f.data || {};
  const vals = [['Kaufen bis', d.buy], ['Zielpreis', d.target], ['Gewinn', d.gain]].filter(([, v]) => v != null).map(([k, v]) => `${k} ${spec.gold(v)}`);
  if (d.days != null) vals.push(`Verkaufsdauer ${spec.daysText(d.days)}`);
  if (d.risk) vals.push(`Risiko ${d.risk}`);
  if (vals.length) lines.push(`Werte: ${vals.join(', ')}`);
  for (const k of Array.isArray(d.checks) ? d.checks : []) {
    lines.push(`- ${k.ok ? 'ok' : 'nicht erfüllt'}: ${k.text || k.id}${k.value != null && !k.text ? ` (Wert ${k.value}, Grenze ${k.limit})` : ''}`);
  }
  if (d.radar && typeof d.radar === 'object') lines.push(`Radar: ${Object.entries(d.radar).slice(0, 12).map(([k, v]) => `${k}=${v}`).join(', ')}`);
  return lines.join('\n');
}

function ratings(db, limit = 500) {
  return db.prepare('SELECT * FROM chance_rate ORDER BY t DESC LIMIT ?').all(limit).map((r) => ({ ...r, data: r.data ? JSON.parse(r.data) : null }));
}

// Datei fuer die Auswertung durch Claude (ohne Konto- und Charakternamen): Regeln, Rueckmeldungen mit den Werten des
// Moments, Trefferquoten. Markt nur als „Fraktion“, interne Namen fallen weg.
function exportText(db, rulesNow, rateByMarket, now) {
  const fac = (m) => (m ? (/Alliance|Allianz/i.test(m) ? 'Allianz' : /Horde/i.test(m) ? 'Horde' : 'Neutral') : null);
  const items = ratings(db, 2000).map((r) => ({ t: new Date(r.t * 1000).toISOString(), from: r.origin, market: fac(r.market), key: r.item_key, name: r.item_name,
    kind: r.kind, up: r.up, reason: r.reason, note: r.note, say: r.say, data: r.data }));
  return JSON.stringify({ made: new Date(now * 1000).toISOString(), what: 'Peon Manager: Rückmeldungen zu Chancen', rules: rulesNow, rates: rateByMarket, ratings: items }, null, 1);
}

// ---------- Uebersteuerung je Gegenstand (7.2) ----------
function cleanOverride(o) {
  const x = {};
  if (o && o.never) x.never = true;
  if (o && o.off) { const off = {}; for (const k of Object.keys(spec.KINDS)) if (o.off[k]) off[k] = true; if (Object.keys(off).length) x.off = off; }
  for (const f of ['target', 'limit']) if (o && Number.isFinite(Number(o[f])) && Number(o[f]) > 0) x[f] = Math.round(Number(o[f]));
  return x;
}

module.exports = { REASONS, NOTE_MAX, log, check, rates, probe, rate, deleteRate, importBroker, ratings, exportText, feedbackText, cleanOverride, bestPrice, KEEP };
