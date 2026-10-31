'use strict';
// Peon Manager - Einleser "AHledger" (Fremdmessung, bis zur Quellenpruefung nur zum Vergleich).
// Schnittstelle https://api.ahledger.com (ohne Schluessel, 300 Abfragen/Min.). Bedingung: Quelle mit Link nennen,
// nicht als eigenen Scan ausgeben, nicht weiterverkaufen.
// Preistabelle: Kopf "AHL1|forever/normal/alliance/us|<Zeit>|<Anzahl>", je Gegenstand
// "id:median:min:menge:median7:median30:tief30:hoch30:absatzJeTagx10" (leer = unbekannt).

const { tx } = require('./db');

const BASE = 'https://api.ahledger.com';
const UA = 'PeonManager (personal use)';
const LINK = 'https://ahledger.com';

function parsePricetable(text) {
  const lines = String(text).split(/\r?\n/);
  const head = (lines[0] || '').split('|');
  if (head.length < 4) throw new Error('Preistabelle: Kopfzeile fehlt');
  const rows = [];
  const num = (x) => (x === '' || x === undefined ? null : Number(x));
  for (let k = 1; k < lines.length; k++) {
    const l = lines[k];
    if (!l) continue;
    const f = l.split(':');
    const id = num(f[0]);
    if (!Number.isFinite(id)) continue;
    const pd = num(f[8]);
    rows.push({ id, median: num(f[1]), min: num(f[2]), qty: num(f[3]), med7: num(f[4]), med30: num(f[5]),
      low30: num(f[6]), high30: num(f[7]), perDay: pd == null ? null : pd / 10 });
  }
  return { format: head[0], market: head[1].replace(/\//g, '.'), t: Number(head[2]), count: Number(head[3]), rows };
}

async function fetchMarkets(fetchImpl = fetch) {
  const r = await fetchImpl(`${BASE}/v1/markets`, { headers: { 'User-Agent': UA, Accept: 'application/json' } });
  if (!r.ok) throw new Error(`AHledger Maerkte: HTTP ${r.status}`);
  const j = await r.json();
  return Array.isArray(j.markets) ? j.markets : [];
}

// Holt die Preistabelle eines Markts, speichert sie bei Aenderung. Rueckgabe { status, fetchId, rows, t }
async function fetchPricetable(db, market, fetchImpl = fetch) {
  const last = db.prepare("SELECT etag, t_data FROM ext_fetch WHERE source = 'ahledger' AND market = ? AND status = 200 ORDER BY t_fetch DESC LIMIT 1").get(market);
  const headers = { 'User-Agent': UA, Accept: 'text/plain' };
  if (last && last.etag) headers['If-None-Match'] = last.etag;
  const now = Math.floor(Date.now() / 1000);
  const r = await fetchImpl(`${BASE}/v1/pricetable/${encodeURIComponent(market)}`, { headers });
  if (r.status === 304) {
    db.prepare("INSERT INTO ext_fetch(source, market, t_data, t_fetch, rows, etag, status) VALUES ('ahledger', ?, ?, ?, 0, ?, 304)")
      .run(market, last ? last.t_data : null, now, last ? last.etag : null);
    return { status: 304, rows: 0, t: last ? last.t_data : null };
  }
  if (!r.ok) throw new Error(`AHledger ${market}: HTTP ${r.status}`);
  const text = await r.text();
  const pt = parsePricetable(text);
  if (last && last.t_data === pt.t) {
    // gleicher Stand ohne ETag: nicht doppelt speichern
    db.prepare("INSERT INTO ext_fetch(source, market, t_data, t_fetch, rows, etag, status) VALUES ('ahledger', ?, ?, ?, 0, ?, 304)")
      .run(market, pt.t, now, r.headers.get('etag'));
    return { status: 304, rows: 0, t: pt.t };
  }
  const fetchId = tx(db, () => {
    const res = db.prepare("INSERT INTO ext_fetch(source, market, t_data, t_fetch, rows, etag, status) VALUES ('ahledger', ?, ?, ?, ?, ?, 200)")
      .run(market, pt.t, now, pt.rows.length, r.headers.get('etag'));
    const id = Number(res.lastInsertRowid);
    const ins = db.prepare(`INSERT OR REPLACE INTO ext_ahledger(fetch_id, item_id, median, min, qty, med7, med30, low30, high30, per_day)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`);
    for (const x of pt.rows) ins.run(id, x.id, x.median, x.min, x.qty, x.med7, x.med30, x.low30, x.high30, x.perDay);
    return id;
  });
  return { status: 200, fetchId, rows: pt.rows.length, t: pt.t };
}

// Vorschlag fuer die Zuordnung Broker-Markt -> AHledger-Markt (nur ein Vorschlag, KarloDerBaer bestaetigt)
// "Classic Beta PvE / Alliance" -> forever.normal.alliance.us (Beta-Markt bei AHledger, wird in C5 geprueft)
function suggestMarket(key, region) {
  const m = /^(.*) \/ (Alliance|Horde)$/.exec(key || '');
  if (!m) return null;
  const realm = m[1].toLowerCase();
  const faction = m[2].toLowerCase();
  const ruleset = /pvp/.test(realm) ? 'pvp' : /\brp\b|rollenspiel/.test(realm) ? 'rp' : 'normal';
  const reg = region === 3 ? 'eu' : region === 5 ? 'cn' : 'us';
  return `forever.${ruleset}.${faction}.${reg}`;
}

module.exports = { parsePricetable, fetchMarkets, fetchPricetable, suggestMarket, BASE, LINK };
