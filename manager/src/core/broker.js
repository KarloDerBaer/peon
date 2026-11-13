'use strict';
// Peon Manager - Einleser "Broker-Verlauf": Tages- und Wochenwerte aus WTF\Account\<Konto>\SavedVariables\Peon_Broker.lua
// (Peon_Client_Design.md Abschnitt 5.7). Je Tag speichert Broker Summen ueber alle Scans des Tages:
//   e.d = "Tag:SummeMin:SummeMedian:SummeMenge:AnzahlScans;..."   (Tag wie Broker: lokale Mittagszeit / 86400)
//   e.w = "Woche:MittelMin:MittelMedian:MittelMenge:AnzahlTage;..." (Woche = floor(Tag / 7), Mittel der Tagesmittel)
// Daraus werden Tagesmittel bzw. Wochenmittel. Art: Momentaufnahme, aber gemittelt (gekennzeichnet als Quelle "broker").
// Bei jedem Einlesen werden die Werte eines Markts ersetzt (Broker verdichtet selbst, alte Tage verschwinden).

const fs = require('node:fs');
const path = require('node:path');
const { parseLua } = require('./lua');
const { tx, marketId } = require('./db');

const FILE = 'Peon_Broker.lua';

function findFiles(wowDir) {
  const base = path.join(wowDir, 'WTF', 'Account');
  let accounts = [];
  try { accounts = fs.readdirSync(base, { withFileTypes: true }).filter((d) => d.isDirectory()).map((d) => d.name); } catch { return []; }
  const out = [];
  for (const a of accounts) {
    const f = path.join(base, a, 'SavedVariables', FILE);
    if (fs.existsSync(f)) out.push({ account: a, file: f });
  }
  return out;
}

// Tag wie Broker (D.Day): lokale Mittagszeit des Tages / 86400
function dayOf(t) {
  const d = new Date(t * 1000);
  return Math.floor(new Date(d.getFullYear(), d.getMonth(), d.getDate(), 12).getTime() / 1000 / 86400);
}

// Zeitpunkt fuer einen Broker-Tag: lokale Mittagszeit dieses Tages
function dayTime(day) {
  const u = new Date(day * 86400 * 1000);
  return Math.floor(new Date(u.getUTCFullYear(), u.getUTCMonth(), u.getUTCDate(), 12).getTime() / 1000);
}

function parseList(s) {
  if (typeof s !== 'string' || !s) return [];
  const out = [];
  for (const part of s.split(';')) {
    const f = part.split(':');
    if (f.length < 5) continue;
    const v = f.map(Number);
    if (v.some((x) => !Number.isFinite(x))) continue;
    out.push(v);
  }
  return out;
}

// Schluessel aus Broker: Zahl, "itemID:voller Name" (Variante) oder alte Form "itemID:Zusatznummer"
function keyInfo(key) {
  const k = String(key);
  const m = /^(\d+)(?::(.+))?$/.exec(k);
  if (!m) return null;
  const rest = m[2];
  return { key: k, item: Number(m[1]), variant: rest && !/^-?\d+$/.test(rest) ? rest : null };
}

// Eine Peon_Broker.lua einlesen. Rueckgabe { markets: [{ key, items, rows }] }
function importFile(db, file) {
  const g = parseLua(fs.readFileSync(file));
  const acc = g.PeonBrokerDB;
  // Kennung des WoW-Kontos (ab Broker 0.85, Manager 0.29.0), fehlt bei aelterem Broker
  const res = { file, acct: acc && typeof acc.acct === 'string' && acc.acct ? acc.acct : null, markets: [], shop: acc && (acc.lists || acc.listsGone) ? { lists: acc.lists, gone: acc.listsGone } : null };
  // Beobachtung (ab Broker 0.49, Manager 0.24): { items: { Schluessel: Eintrag }, gone: { Schluessel: u } }.
  // Ab Manager 0.30.0 der ganze Eintrag mit Kaufen bis, Zielpreis und Zeiten je Wert (watching.js), ohne Merker des Alarms
  if (acc && (acc.watch || acc.watchGone)) {
    const items = {};
    for (const [k, w] of Object.entries(acc.watch || {})) {
      if (!w || typeof w !== 'object') { items[String(k)] = Number(w) || 0; continue; }
      const e = { u: Number(w.u) || 0 };
      for (const f of ['lim', 'pct', 'up', 'name', 'q', 'icon']) if (w[f] !== undefined && w[f] !== null && typeof w[f] !== 'object') e[f] = w[f];
      if (w.t && typeof w.t === 'object') e.t = { ...w.t };
      items[String(k)] = e;
    }
    const gone = {};
    for (const [k, u] of Object.entries(acc.watchGone || {})) gone[String(k)] = Number(u) || 0;
    res.watch = { items, gone };
  }
  // Haendler (ab Broker 0.52, Manager 0.25): je NPC Name, Zone, Ort, Zeit und Angebote
  if (acc && acc.vendors && typeof acc.vendors === 'object') res.vendors = acc.vendors;
  // Ab Manager 0.35.0 (Peon_Manager_Chancen.md): Einschaetzungen (ab Broker 0.91), Feste aus dem Kalender des Spiels
  // (ab Broker 0.93, D4) und die Regeln des Aufkaufs, damit Manager und Broker gleich rechnen (4.4)
  if (acc && acc.ratings && typeof acc.ratings === 'object') res.ratings = acc.ratings;
  if (acc && acc.feste && typeof acc.feste === 'object') res.feste = acc.feste;
  if (acc) {
    const n = (k) => (typeof acc[k] === 'number' && Number.isFinite(acc[k]) ? acc[k] : undefined);
    const rules = { hours: n('buyoutHours'), minGain: n('dealMinMarket') != null ? n('dealMinMarket') * 100 : undefined, minQty: n('buyoutMinQty'),
      minLevels: n('buyoutMinLevels'), minSales: n('buyoutMinSales'), targetPct: n('buyoutTargetPct') != null ? n('buyoutTargetPct') / 100 : undefined };
    for (const k of Object.keys(rules)) if (rules[k] === undefined) delete rules[k];
    if (Object.keys(rules).length) res.rules = rules;
  }
  if (!acc || typeof acc.markets !== 'object') return res;
  const cleared = new Set();   // zwei Namen desselben Markts: den ersten nicht wieder loeschen
  const now = Math.floor(Date.now() / 1000);
  for (const [mkey, m] of Object.entries(acc.markets)) {
    if (!m || typeof m.items !== 'object' || !/ \/ /.test(mkey)) continue;
    const r = tx(db, () => {
      const mid = marketId(db, mkey, {});
      if (!cleared.has(mid)) db.prepare("DELETE FROM hist WHERE market_id = ? AND source = 'broker'").run(mid);
      cleared.add(mid);
      const ins = db.prepare(`INSERT OR REPLACE INTO hist(market_id, item_key, source, period, num, t, min, median, qty, n)
          VALUES (?, ?, 'broker', ?, ?, ?, ?, ?, ?, ?)`);
      const up = db.prepare(`INSERT INTO items(key, item_id, variant, name, quality, updated) VALUES (?, ?, ?, ?, ?, ?)
          ON CONFLICT(key) DO UPDATE SET name = COALESCE(items.name, excluded.name), quality = COALESCE(items.quality, excluded.quality)`);
      let items = 0, rows = 0;
      for (const [k, e] of Object.entries(m.items)) {
        const ki = keyInfo(k);
        if (!ki || !e || typeof e !== 'object') continue;
        let any = false;
        for (const x of parseList(e.d)) {
          const [day, smin, smed, sqty, n] = x;
          if (n <= 0) continue;
          ins.run(mid, ki.key, 'day', day, dayTime(day), smin / n, smed / n, sqty / n, n);
          rows++; any = true;
        }
        for (const x of parseList(e.w)) {
          const [week, min, med, qty, n] = x;
          ins.run(mid, ki.key, 'week', week, dayTime(week * 7 + 3), min, med, qty, n);
          rows++; any = true;
        }
        const name = typeof e.nm === 'string' && e.nm ? e.nm : ki.variant;
        const ql = typeof e.ql === 'number' && e.ql >= 0 ? e.ql : null;
        if (any || name) up.run(ki.key, ki.item, ki.variant, name || null, ql, now);
        if (any) items++;
      }
      return { key: mkey, items, rows };
    });
    res.markets.push(r);
  }
  // Warenart, die Broker vom Spiel kennt (PeonBrokerDB.commodity[Schluessel] = true/false)
  if (acc.commodity && typeof acc.commodity === 'object') {
    const up = db.prepare(`INSERT INTO items(key, item_id, variant, commodity, updated) VALUES (?, ?, ?, ?, ?)
        ON CONFLICT(key) DO UPDATE SET commodity = excluded.commodity`);
    tx(db, () => {
      for (const [k, v] of Object.entries(acc.commodity)) {
        const ki = keyInfo(k);
        if (ki && typeof v === 'boolean') { up.run(ki.key, ki.item, ki.variant, v ? 1 : 0, now); res.commodity = (res.commodity || 0) + 1; }
      }
    });
  }
  return res;
}

module.exports = { findFiles, importFile, dayOf, dayTime, parseList, keyInfo, FILE };
