'use strict';
// Hilfe fuer Tests (ab Schema 14): Kennzahlen in item_snap gehoeren zu einem Stand (snapshots.sid). Legt den Stand an, wenn
// es ihn noch nicht gibt, und gibt seine Zahl zurueck.
function sidOf(db, id, mid, t, { source = 'scan', art = 'api' } = {}) {
  const have = db.prepare('SELECT sid FROM snapshots WHERE id = ?').get(String(id));
  if (have && have.sid != null) return Number(have.sid);
  const sid = Number(db.prepare('SELECT COALESCE(MAX(sid), 0) + 1 AS s FROM snapshots').get().s);
  if (have) db.prepare('UPDATE snapshots SET sid = ? WHERE id = ?').run(sid, String(id));
  else db.prepare('INSERT INTO snapshots(id, market_id, source, art, t, offers, items, sid) VALUES (?, ?, ?, ?, ?, 1, 1, ?)').run(String(id), mid, source, art, t, sid);
  return sid;
}

module.exports = { sidOf };
