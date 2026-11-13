'use strict';
// Peon Manager - Zwischenspeicher der Momentaufnahmen je Markt (ab Manager 0.23.0, KarloDerBaer 09.11.2026).
// Gegenstandsliste (history.itemList) und Tageswerte fuer den ueblichen Bereich (longterm.dayValues) lasen bei jedem neuen
// Stand alle Zeilen aus item_snap, mit einigen Tagen Blizzard-Daten mehrere Sekunden. Der Zwischenspeicher liest den Verlauf
// einmal und nimmt danach nur die Zeilen neuer Momentaufnahmen dazu. Die Ergebnisse sind dieselben wie mit den Abfragen.
// Neu gelesen wird, wenn sich die Zahl der Zeilen anders aendert als durch neue Momentaufnahmen (Aufraeumen, Verdichten).
// Die Zeilen aus hist (Broker-Verlauf) sind wenige und werden wie bisher jedes Mal gelesen.

const { dayOf } = require('./broker');

const KEEP_DAYS = 17;   // Tageswerte so weit zurueck (Bereich: 14 Tage, Liste: 9 Tage, dazu Spielraum)

class SnapIndex {
  constructor(db) {
    this.db = db;
    this.markets = new Map();
    this.builds = 0;   // fuer Tests: wie oft ganz gelesen wurde
  }

  reset() { this.markets.clear(); }

  counts(mid) {
    const a = this.db.prepare('SELECT COUNT(*) AS n FROM item_snap WHERE market_id = ?').get(mid).n;
    const b = this.db.prepare('SELECT COUNT(*) AS n FROM item_hour WHERE market_id = ?').get(mid).n;
    return { snap: Number(a), hour: Number(b) };
  }

  // Aktueller Stand eines Markts
  of(mid, now) {
    const today = dayOf(now);
    let s = this.markets.get(mid);
    if (s && s.today !== today) s = null;   // neuer Tag: Fenster verschiebt sich
    if (s) this.update(s, mid);
    const c = this.counts(mid);
    if (!s || s.snapRows !== c.snap || s.hourRows !== c.hour) s = this.build(mid, today, c);
    return s;
  }

  addRow(s, r) {
    if (r.qty > 0) { const x = s.seen.get(r.item_key); if (!x || r.t > x.t) s.seen.set(r.item_key, { t: r.t, row: r }); }
    const c = s.counts.get(r.item_key) || {};
    c[r.source] = (c[r.source] || 0) + 1;
    s.counts.set(r.item_key, c);
    if (r.source !== 'scan' || r.median == null) return;
    const day = dayOf(r.t);
    if (day <= s.today - KEEP_DAYS) return;
    this.noteQty(s, r.item_key, day, r.t, r.qty);
    let m = s.snapDays.get(r.item_key);
    if (!m) { m = new Map(); s.snapDays.set(r.item_key, m); }
    const x = m.get(day);
    if (x) { x.sum += r.median; x.n++; } else m.set(day, { sum: r.median, n: 1 });
  }

  // ab Manager 0.35.0 (Reichweite F60): Menge im Angebot je Tag aus dem letzten Stand des Tages
  noteQty(s, key, day, t, qty) {
    if (qty == null) return;
    let m = s.qtyDays.get(key);
    if (!m) { m = new Map(); s.qtyDays.set(key, m); }
    const x = m.get(day);
    if (!x || t >= x.t) m.set(day, { t, qty });
  }

  // Map key -> Map tag -> Menge im Angebot (letzter Stand des Tages)
  dayQty(mid, now, span) {
    const s = this.of(mid, now);
    const from = s.today - span;
    const out = new Map();
    for (const [k, m] of s.qtyDays) {
      const d = new Map();
      for (const [day, x] of m) if (day > from && day <= s.today) d.set(day, x.qty);
      if (d.size) out.set(k, d);
    }
    return out;
  }

  build(mid, today, c) {
    this.builds++;
    const s = { today, rowid: 0, snapRows: c.snap, hourRows: c.hour, seen: new Map(), counts: new Map(), snapDays: new Map(), hourDays: new Map(), qtyDays: new Map() };
    s.rowid = Number(this.db.prepare('SELECT COALESCE(MAX(rowid), 0) AS r FROM snapshots WHERE market_id = ?').get(mid).r);
    for (const r of this.db.prepare('SELECT item_key, t, source, min, median, qty, auctions FROM item_snap WHERE market_id = ?').iterate(mid)) this.addRow(s, r);
    // Stundenwerte (aus dem Verdichten): fuer den Bereich gewichtet (n), fuer die Liste je Stunde einmal, wie in den Abfragen
    for (const r of this.db.prepare("SELECT item_key, t, median, n, qty FROM item_hour WHERE market_id = ? AND source = 'scan' AND t >= ?").iterate(mid, (today - KEEP_DAYS) * 86400)) {
      if (r.median == null) continue;
      const day = dayOf(r.t);
      this.noteQty(s, r.item_key, day, r.t, r.qty);
      let m = s.hourDays.get(r.item_key);
      if (!m) { m = new Map(); s.hourDays.set(r.item_key, m); }
      const x = m.get(day) || { wsum: 0, w: 0, sum: 0, n: 0 };
      x.wsum += r.median * r.n; x.w += r.n; x.sum += r.median; x.n++;
      m.set(day, x);
    }
    this.markets.set(mid, s);
    return s;
  }

  // Zeilen neuer Momentaufnahmen dazunehmen
  update(s, mid) {
    const fresh = this.db.prepare('SELECT rowid AS r, id FROM snapshots WHERE market_id = ? AND rowid > ? ORDER BY rowid').all(mid, s.rowid);
    if (!fresh.length) return;
    const rows = this.db.prepare('SELECT item_key, t, source, min, median, qty, auctions FROM item_snap WHERE snapshot_id = ?');
    for (const f of fresh) {
      for (const r of rows.iterate(f.id)) { this.addRow(s, r); s.snapRows++; }
      s.rowid = Number(f.r);
    }
  }

  // Wie longterm.dayValues fuer alle Gegenstaende: Map key -> Map tag -> { value, own }
  dayValues(mid, now, span) {
    const s = this.of(mid, now);
    const today = s.today, from = today - span;
    const out = new Map();
    const keys = new Set([...s.snapDays.keys(), ...s.hourDays.keys()]);
    for (const k of keys) {
      const a = s.snapDays.get(k), b = s.hourDays.get(k);
      const d = new Map();
      const days = new Set([...(a ? a.keys() : []), ...(b ? b.keys() : [])]);
      for (const day of days) {
        if (day <= from || day > today) continue;
        const x = a && a.get(day), y = b && b.get(day);
        const sum = (x ? x.sum : 0) + (y ? y.wsum : 0), n = (x ? x.n : 0) + (y ? y.w : 0);
        d.set(day, { value: sum / n, own: true });
      }
      if (d.size) out.set(k, d);
    }
    for (const r of this.db.prepare("SELECT item_key, num, median FROM hist WHERE market_id = ? AND source = 'broker' AND period = 'day' AND num > ? AND num <= ?").iterate(mid, from, today)) {
      if (r.median == null) continue;
      let d = out.get(r.item_key);
      if (!d) { d = new Map(); out.set(r.item_key, d); }
      if (!d.has(r.num)) d.set(r.num, { value: r.median, own: false });
    }
    return out;
  }

  // Fuer history.itemList: zuletzt gesehen, Zahl der Zeilen je Quelle, Tageswerte (Mittel je Tag, Stunden je einmal)
  listParts(mid, now) {
    const s = this.of(mid, now);
    const daily = new Map();
    const keys = new Set([...s.snapDays.keys(), ...s.hourDays.keys()]);
    for (const k of keys) {
      const a = s.snapDays.get(k), b = s.hourDays.get(k);
      const m = new Map();
      for (const [day, x] of a || []) m.set(day, { sum: x.sum, n: x.n, own: true });
      for (const [day, y] of b || []) { const x = m.get(day); if (x) { x.sum += y.sum; x.n += y.n; } else m.set(day, { sum: y.sum, n: y.n, own: true }); }
      daily.set(k, m);
    }
    return { seen: s.seen, counts: s.counts, daily };
  }
}

module.exports = { SnapIndex, KEEP_DAYS };
