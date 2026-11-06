'use strict';
// Peon Manager - Merkliste mit Preisalarm (Modul Peon Broker Client). Je Markt und Gegenstand eine Zeile,
// below = Grenze in Kupfer oder leer (ohne Alarm). hit merkt, dass der Alarm schon gemeldet ist: Gemeldet wird einmal,
// wenn das guenstigste Angebot die Grenze erreicht, und erst wieder, nachdem der Preis darueber lag.

// Letzter Stand je Gegenstand aus dem letzten Scan oder API-Stand des Markts
function lastSnapshot(db, marketId) {
  return db.prepare("SELECT id, t FROM snapshots WHERE market_id = ? AND source = 'scan' ORDER BY t DESC LIMIT 1").get(marketId) || null;
}

function list(db, marketId, bands = new Map()) {
  const last = lastSnapshot(db, marketId);
  const cur = last ? db.prepare('SELECT min, median, qty, auctions FROM item_snap WHERE snapshot_id = ? AND item_key = ?') : null;
  return db.prepare(`SELECT w.item_key AS key, w.below, w.added, w.hit, i.name, i.quality, i.item_id AS item, i.variant
      FROM watchlist w LEFT JOIN items i ON i.key = w.item_key WHERE w.market_id = ?`).all(marketId).map((r) => {
    const c = cur ? cur.get(last.id, r.key) : null;
    const b = bands.get(r.key);
    return { key: r.key, name: r.name, quality: r.quality, item: r.item, variant: r.variant, below: r.below, added: r.added, hit: !!r.hit,
      min: c ? c.min : null, median: c ? c.median : null, qty: c ? c.qty : 0, auctions: c ? c.auctions : 0, lang: b ? b.lang : null };
  }).sort((a, b) => Number(b.hit) - Number(a.hit) || String(a.name || a.key).localeCompare(String(b.name || b.key), 'de'));
}

function get(db, marketId, key) {
  const r = db.prepare('SELECT below, hit FROM watchlist WHERE market_id = ? AND item_key = ?').get(marketId, key);
  return r ? { below: r.below, hit: !!r.hit } : null;
}

// Merken oder die Grenze aendern. Eine neue Grenze darf wieder melden.
function set(db, marketId, key, below, now) {
  const b = below == null || !(Number(below) > 0) ? null : Math.round(Number(below));
  db.prepare(`INSERT INTO watchlist(market_id, item_key, below, added, hit) VALUES (?, ?, ?, ?, 0)
      ON CONFLICT(market_id, item_key) DO UPDATE SET below = excluded.below, hit = 0`).run(marketId, key, b, now);
}

function remove(db, marketId, key) {
  db.prepare('DELETE FROM watchlist WHERE market_id = ? AND item_key = ?').run(marketId, key);
}

// Nach neuen Daten: Was hat die Grenze gerade erreicht? Rueckgabe: [{ market, key, name, min, below }]
function check(db) {
  const out = [];
  const setHit = db.prepare('UPDATE watchlist SET hit = ? WHERE market_id = ? AND item_key = ?');
  for (const m of db.prepare('SELECT id, key FROM markets').all()) {
    const rows = db.prepare('SELECT w.item_key AS key, w.below, w.hit, i.name FROM watchlist w LEFT JOIN items i ON i.key = w.item_key WHERE w.market_id = ? AND w.below IS NOT NULL').all(m.id);
    if (!rows.length) continue;
    const last = lastSnapshot(db, m.id);
    if (!last) continue;
    const cur = db.prepare('SELECT min, qty FROM item_snap WHERE snapshot_id = ? AND item_key = ?');
    for (const r of rows) {
      const c = cur.get(last.id, r.key);
      const under = !!(c && c.qty > 0 && c.min != null && c.min <= r.below);
      if (under && !r.hit) out.push({ market: m.key, key: r.key, name: r.name || r.key, min: c.min, below: r.below });
      if (under !== !!r.hit) setHit.run(under ? 1 : 0, m.id, r.key);
    }
  }
  return out;
}

// Betrag fuer die Meldung von Windows
function money(copper) {
  const c = Math.round(copper);
  const g = Math.floor(c / 10000), s = Math.floor(c / 100) % 100, k = c % 100;
  return [g ? `${g}g` : '', s ? `${s}s` : '', k || (!g && !s) ? `${k}c` : ''].filter(Boolean).join(' ');
}

module.exports = { list, get, set, remove, check, money };
