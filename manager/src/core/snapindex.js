'use strict';
// Peon Manager - Zwischenspeicher der Momentaufnahmen je Markt (ab Manager 0.23.0, KarloDerBaer 09.11.2026).
// Gegenstandsliste (history.itemList) und Tageswerte fuer den ueblichen Bereich (longterm.dayValues) lasen bei jedem neuen
// Stand alle Zeilen aus item_snap, mit einigen Tagen Blizzard-Daten mehrere Sekunden. Der Zwischenspeicher liest den Verlauf
// einmal und nimmt danach nur die Zeilen neuer Momentaufnahmen dazu. Die Ergebnisse sind dieselben wie mit den Abfragen.
// Neu gelesen wird, wenn sich die Zahl der Zeilen anders aendert als durch neue Momentaufnahmen (Aufraeumen, Verdichten).
// Die Zeilen aus hist (Broker-Verlauf) sind wenige und werden wie bisher jedes Mal gelesen.

const zlib = require('node:zlib');
const { dayOf } = require('./broker');
const { hourFrom } = require('./db');

const KEEP_DAYS = 17;   // Tageswerte so weit zurueck (Bereich: 14 Tage, Liste: 9 Tage, dazu Spielraum)

class SnapIndex {
  constructor(db) {
    this.db = db;
    this.markets = new Map();
    this.builds = 0;   // fuer Tests: wie oft ganz gelesen wurde
  }

  reset() { this.markets.clear(); }

  // ab Manager 0.41.0: Stand je Markt in der Datenbank sichern (snap_cache) und beim Start laden. Den Verlauf ganz zu lesen
  // dauerte mit echten Daten 12 bis 27 Sek. Beim Laden kommen neuere Staende ueber update dazu, passt die Zahl der Zeilen
  // danach nicht (Aufraeumen ohne Sichern), wird wie bisher neu gelesen.
  save(mid) {
    const s = this.markets.get(mid);
    if (!s) return false;
    const m2a = (m) => [...m].map(([k, v]) => [k, v instanceof Map ? [...v] : v]);
    const data = { v: 1, today: s.today, rowid: s.rowid, snapRows: s.snapRows, hourRows: s.hourRows,
      seen: [...s.seen], counts: [...s.counts], snapDays: m2a(s.snapDays), hourDays: m2a(s.hourDays), qtyDays: m2a(s.qtyDays) };
    this.db.prepare('INSERT OR REPLACE INTO snap_cache(market_id, data) VALUES (?, ?)').run(mid, zlib.deflateSync(Buffer.from(JSON.stringify(data), 'utf8')));
    s.savedAt = Date.now();
    return true;
  }

  load(mid) {
    const r = this.db.prepare('SELECT data FROM snap_cache WHERE market_id = ?').get(mid);
    if (!r) return null;
    try {
      const d = JSON.parse(zlib.inflateSync(Buffer.from(r.data)).toString('utf8'));
      if (d.v !== 1) return null;
      const a2m = (l) => new Map(l.map(([k, v]) => [k, new Map(v)]));
      const s = { today: d.today, rowid: d.rowid, snapRows: d.snapRows, hourRows: d.hourRows, seen: new Map(d.seen), counts: new Map(d.counts),
        snapDays: a2m(d.snapDays), hourDays: a2m(d.hourDays), qtyDays: a2m(d.qtyDays), savedAt: Date.now() };
      this.markets.set(mid, s);
      this.loads = (this.loads || 0) + 1;
      return s;
    } catch { return null; }
  }

  // Neu lesen in Schritten (ein Stand je Schritt), fuer das Aufraeumen: Der bisherige Stand bleibt bis zum Ende gueltig.
  // Zaehlung und hoechste Zahl der Staende am Anfang, Staende, die waehrenddessen dazukommen, nimmt danach update.
  * rebuildSteps(mid, now) {
    const today = dayOf(now);
    const c = this.counts(mid);
    const s = { today, rowid: 0, snapRows: c.snap, hourRows: c.hour, seen: new Map(), counts: new Map(), snapDays: new Map(), hourDays: new Map(), qtyDays: new Map() };
    s.rowid = Number(this.db.prepare('SELECT COALESCE(MAX(sid), 0) AS r FROM snapshots WHERE market_id = ?').get(mid).r);
    const sids = this.db.prepare('SELECT sid FROM snapshots WHERE market_id = ? AND sid <= ? ORDER BY sid').all(mid, s.rowid).map((x) => x.sid);
    const rows = this.db.prepare('SELECT item_key, t, source, min, median, qty, auctions FROM item_snap WHERE sid = ?');
    for (const sid of sids) {
      for (const r of rows.iterate(sid)) this.addRow(s, r);
      yield;
    }
    this.readHours(s, mid, today);
    this.builds++;
    this.markets.set(mid, s);
    this.save(mid);
  }

  counts(mid) {
    const a = this.db.prepare('SELECT COUNT(*) AS n FROM item_snap WHERE market_id = ?').get(mid).n;
    const b = this.db.prepare('SELECT COUNT(*) AS n FROM item_hour WHERE market_id = ?').get(mid).n;
    return { snap: Number(a), hour: Number(b) };
  }

  // Aktueller Stand eines Markts
  of(mid, now) {
    const today = dayOf(now);
    let s = this.markets.get(mid) || this.load(mid);
    if (s && s.today > today) s = null;              // Uhr zurueckgestellt: neu lesen
    if (s && s.today < today) this.shift(s, today);   // neuer Tag: Fenster verschiebt sich (bis 0.39 ganz neu gelesen, 27 Sek.)
    if (s) this.update(s, mid);
    const c = this.counts(mid);
    if (!s || s.snapRows !== c.snap || s.hourRows !== c.hour) s = this.build(mid, today, c);
    return s;
  }

  // ab Manager 0.40.0: Tage, die aus dem Fenster fallen, entfernen. Gleiches Ergebnis wie neu lesen (build liest Scans ab
  // dem Tag nach today - KEEP_DAYS, Stundenwerte ab diesem Tag).
  shift(s, today) {
    s.today = today;
    const cut = today - KEEP_DAYS;
    const drop = (map, keep) => { for (const [k, m] of map) { for (const day of [...m.keys()]) if (!keep(day)) m.delete(day); if (!m.size) map.delete(k); } };
    drop(s.snapDays, (d) => d > cut);
    drop(s.hourDays, (d) => d >= cut);
    drop(s.qtyDays, (d) => d >= cut);
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
    // ab Manager 0.50.0 (Marktvergleich): dazu der guenstigste Preis je Tag (msum, mn). Aeltere gesicherte Staende haben ihn nicht.
    const mn = r.min > 0 ? 1 : 0, ms = r.min > 0 ? r.min : 0;
    if (x) { x.sum += r.median; x.n++; x.msum = (x.msum || 0) + ms; x.mn = (x.mn || 0) + mn; } else m.set(day, { sum: r.median, n: 1, msum: ms, mn });
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
    s.rowid = Number(this.db.prepare('SELECT COALESCE(MAX(sid), 0) AS r FROM snapshots WHERE market_id = ?').get(mid).r);
    for (const r of this.db.prepare('SELECT item_key, t, source, min, median, qty, auctions FROM item_snap WHERE market_id = ?').iterate(mid)) this.addRow(s, r);
    this.readHours(s, mid, today);
    this.markets.set(mid, s);
    return s;
  }

  // 3-Stunden-Werte (aus dem Verdichten): fuer den Bereich gewichtet (n), fuer die Liste je Abschnitt einmal, wie in den Abfragen
  readHours(s, mid, today) {
    for (const r of this.db.prepare("SELECT item_key, t, median, n, qty, min FROM item_hour WHERE market_id = ? AND hour >= ? AND source = 'scan' AND t >= ?").iterate(mid, hourFrom((today - KEEP_DAYS) * 86400), (today - KEEP_DAYS) * 86400)) {
      if (r.median == null) continue;
      const day = dayOf(r.t);
      this.noteQty(s, r.item_key, day, r.t, r.qty);
      let m = s.hourDays.get(r.item_key);
      if (!m) { m = new Map(); s.hourDays.set(r.item_key, m); }
      const x = m.get(day) || { wsum: 0, w: 0, sum: 0, n: 0, msum: 0, mn: 0 };
      x.wsum += r.median * r.n; x.w += r.n; x.sum += r.median; x.n++;
      if (r.min > 0) { x.msum = (x.msum || 0) + r.min * r.n; x.mn = (x.mn || 0) + r.n; }
      m.set(day, x);
    }
  }

  // Zeilen neuer Momentaufnahmen dazunehmen
  update(s, mid) {
    const fresh = this.db.prepare('SELECT sid AS r FROM snapshots WHERE market_id = ? AND sid > ? ORDER BY sid').all(mid, s.rowid);
    if (!fresh.length) return;
    const rows = this.db.prepare('SELECT item_key, t, source, min, median, qty, auctions FROM item_snap WHERE sid = ?');
    for (const f of fresh) {
      for (const r of rows.iterate(f.r)) { this.addRow(s, r); s.snapRows++; }
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

  // ab Manager 0.50.0 (Marktvergleich): Map key -> Map tag -> { min, qty }. min = Mittel der guenstigsten Preise des Tages
  // (ohne Wert aus aelteren Sicherungen der Median), qty = Menge im letzten Stand des Tages
  dayMins(mid, now, span) {
    const s = this.of(mid, now);
    const today = s.today, from = today - span;
    const out = new Map();
    const keys = new Set([...s.snapDays.keys(), ...s.hourDays.keys()]);
    for (const k of keys) {
      const a = s.snapDays.get(k), b = s.hourDays.get(k), q = s.qtyDays.get(k);
      const d = new Map();
      const days = new Set([...(a ? a.keys() : []), ...(b ? b.keys() : [])]);
      for (const day of days) {
        if (day <= from || day > today) continue;
        const x = a && a.get(day), y = b && b.get(day);
        const ms = (x && x.mn ? x.msum : 0) + (y && y.mn ? y.msum : 0), mn = (x && x.mn ? x.mn : 0) + (y && y.mn ? y.mn : 0);
        let min = mn ? ms / mn : null;
        if (min == null) {
          const sum = (x ? x.sum : 0) + (y ? y.wsum : 0), n = (x ? x.n : 0) + (y ? y.w : 0);
          min = n ? sum / n : null;
        }
        if (!(min > 0)) continue;
        const qx = q && q.get(day);
        d.set(day, { min, qty: qx ? qx.qty || 0 : 0 });
      }
      if (d.size) out.set(k, d);
    }
    return out;
  }

  // ab Manager 0.50.0: letzter Stand mit Angebot je Gegenstand, Map key -> { t, min, qty }
  lastSeen(mid, now) {
    const s = this.of(mid, now);
    const out = new Map();
    for (const [k, x] of s.seen) out.set(k, { t: x.t, min: x.row.min, qty: x.row.qty || 0 });
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
