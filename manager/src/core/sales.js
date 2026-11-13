'use strict';
// Peon Manager - Absatz (Rechenmodell Kapitel 9, F45 bis F48).
// Vergleicht zwei aufeinanderfolgende Komplettscans eines Markts mit allen Angeboten nach Brokers Regeln
// (Peon_Broker Sales.lua, Konzept Peon_Broker_Absatz.md Abschnitt 3 und 7). Staende der Blizzard-API (art = 'api') werden
// nur untereinander ueber die Angebotsnummern verglichen und haben Vorrang. Eigene Scans zaehlen nur fuer Zeiten ohne
// API-Paar, Live-Abfragen nur fuer Zeiten ohne beides. Ergebnis je Paar und Gegenstand in sales_cmp.

const zlib = require('node:zlib');
const { parseRows, itemKey, unitPrice } = require('./stats');
const { dayOf } = require('./broker');
const { tx } = require('./db');
const proof = require('./proof');

const MIN_GAP = 60;              // Sekunden (wie Broker S.MIN_GAP)
const MAX_GAP = 24 * 3600;       // Sekunden (wie Broker S.MAX_GAP)
const TOL = 60;                  // Toleranz beim Ende (sekundengenau)
const CANCEL = 0.10;             // Einzelgegenstaende: Schaetzwert Abbrueche
const DAYS = 14;                 // Zeitraum fuer Absatz je Tag
const MID_MIN = 60, SURE_MIN = 180;   // Sicherheit nach beobachteter Zeit (Minuten, wie Broker)
const BANDS = { 0: [0, 1800], 1: [0, 1800], 2: [1800, 7200], 3: [7200, 43200], 4: [43200, 172800] };
const KEEP_DAYS = 365;           // Tageswerte des Absatzes so lange aufheben
const FOLD_AFTER = 2 * 86400;    // einzelne Vergleiche nach 2 Tagen zu Tageswerten zusammenfassen (Platz)

function ends(t, band) {
  const b = BANDS[band];
  return b ? [t + b[0], t + b[1]] : [0, 0];
}

// Angebote je Gegenstand: Map key -> [{ id, q, p, lo, hi }], guenstigste zuerst. Gleiche Angebote (n) einzeln.
function offersByItem(rows, t) {
  const out = new Map();
  for (const r of rows) {
    const p = unitPrice(r);
    if (p == null || !(r.qty > 0)) continue;   // reine Gebote zaehlen nicht (wie Broker)
    const key = itemKey(r);
    let list = out.get(key);
    if (!list) { list = []; out.set(key, list); }
    const [lo, hi] = ends(t, r.tl);
    for (let k = 0; k < r.n; k++) list.push({ id: r.id || 0, q: r.qty, p, lo, hi });
  }
  for (const list of out.values()) list.sort((a, b) => a.p - b.p || a.id - b.id);
  return out;
}

// Ende eines verschwundenen Angebots bei tB: 'expired', 'early' oder null (unklar)
function endState(o, tA, tB, scan) {
  if (o.hi > 0) {
    if (tB >= o.hi - TOL) return 'expired';
    if (tB < o.lo) return 'early';
    return null;
  }
  if (scan && tB - tA <= 2 * 3600) return 'early';
  return null;
}

// F45: wie Broker S.Compare. Rueckgabe { sold, expired, cancelled, listed, value }
function compare(A, B, tA, tB, { commodity = false, withIds = false, cap = 0, cancelPct = CANCEL } = {}) {
  let sold = 0, expired = 0, cancelled = 0, value = 0;
  const soldAt = [];   // Preise der Verkaeufe (fuer den hoechsten glaubwuerdigen Verkaufspreis)
  const soldList = [];   // ab Manager 0.35.0 jeder Verkauf mit Preis, Stueck und Angebotsnummer (proof.js, D1 und D2)
  const hi = (p, q, id) => { soldAt.push(p); soldList.push({ p, q, id: id || 0 }); };
  const inCap = (o) => cap === 0 || o.p < cap;
  const used = new Array(B.length).fill(false);
  let gone = [];
  let anchor = null;
  const setAnchor = (p) => { if (anchor === null || p < anchor) anchor = p; };
  if (withIds) {
    const byId = new Map();
    B.forEach((b, i) => byId.set(b.id, i));
    for (const a of A) {
      if (!inCap(a)) continue;
      const i = byId.get(a.id);
      if (i !== undefined) {
        used[i] = true;
        const b = B[i];
        if (b.q < a.q) { sold += a.q - b.q; value += (a.q - b.q) * a.p; hi(a.p, a.q - b.q, a.id); }
        if (b.q > 0) setAnchor(a.p);
      } else gone.push(a);
    }
  } else {
    const idx = new Map();   // "Preis|Menge" -> freie Stellen in B
    B.forEach((b, i) => { const k = b.p + '|' + b.q; if (!idx.has(k)) idx.set(k, []); idx.get(k).push(i); });
    for (const a of A) {
      if (!inCap(a)) continue;
      const l = idx.get(a.p + '|' + a.q);
      if (l && l.length) { used[l.shift()] = true; setAnchor(a.p); } else gone.push(a);
    }
    if (commodity) {
      const still = [];
      for (const a of gone) {
        let hit = -1;
        for (let i = 0; i < B.length; i++) if (!used[i] && B[i].p === a.p && B[i].q < a.q) { hit = i; break; }
        if (hit >= 0) {
          used[hit] = true;
          sold += a.q - B[hit].q; value += (a.q - B[hit].q) * a.p; hi(a.p, a.q - B[hit].q, 0);
          setAnchor(a.p);
        } else still.push(a);
      }
      gone = still;
    }
  }
  const newB = [];
  B.forEach((b, i) => { if (inCap(b) && !used[i]) newB.push(b); });
  let listed = newB.reduce((s, b) => s + b.q, 0);
  for (const a of gone) {
    const st = endState(a, tA, tB, !withIds);
    if (st === 'expired') expired += a.q;
    else if (st === 'early') {
      if (commodity) {
        let repost = false;
        for (let j = 0; j < newB.length; j++) {
          if (newB[j].q === a.q && newB[j].p < a.p) { repost = true; listed -= newB[j].q; newB.splice(j, 1); break; }
        }
        if (repost || (anchor !== null && a.p > anchor)) cancelled += a.q;
        else { sold += a.q; value += a.q * a.p; hi(a.p, a.q, a.id); }
      } else {
        const c = a.q * cancelPct;
        cancelled += c;
        sold += a.q - c; value += (a.q - c) * a.p; hi(a.p, a.q - c, a.id);
      }
    }
  }
  // Massenware wird von unten gekauft: ein "Teilkauf" ueber dem stehenden guenstigsten Angebot ist eher eine Verwechslung
  // (zwei Angebote zum gleichen Preis). Fuer den hoechsten Verkaufspreis zaehlen nur Verkaeufe bis zu diesem Angebot.
  let maxSold = null;
  for (const p of soldAt) if ((!commodity || anchor === null || p <= anchor) && (maxSold === null || p > maxSold)) maxSold = p;
  return { sold, expired, cancelled, listed, value, maxSold, soldList };
}

// Warenart je Gegenstand: Map key -> true/false (Rechenmodell 9.1 WARE)
function commodityOf(db, keys) {
  const out = new Map();
  const get = db.prepare('SELECT commodity, variant FROM items WHERE key = ?');
  for (const k of keys) {
    const r = get.get(k);
    if (r && r.commodity != null) out.set(k, !!r.commodity);
    else if (r && r.variant) out.set(k, false);
    else if (/:/.test(k)) out.set(k, false);
  }
  return out;
}

function rowsOf(db, id) {
  const r = db.prepare('SELECT rows FROM snapshots WHERE id = ?').get(id);
  if (!r || !r.rows) return null;
  return parseRows(zlib.inflateSync(Buffer.from(r.rows)).toString('utf8'));
}

// Warenart aus den Angeboten nachtragen: ein Angebot mit mehr als 1 Stueck -> Massenware
function learnCommodity(db, rows) {
  const multi = new Set();
  for (const r of rows) if (r.qty > 1 && !r.name) multi.add(String(r.item));
  const up = db.prepare('UPDATE items SET commodity = 1 WHERE key = ? AND commodity IS NULL');
  for (const k of multi) up.run(k);
}

function addPair(db, marketId, a, b, src, itemKeyOnly) {
  const ra = rowsOf(db, a.id), rb = rowsOf(db, b.id);
  if (!ra || !rb) return false;
  if (src === 'scan') { learnCommodity(db, ra); learnCommodity(db, rb); }
  const withIds = src !== 'scan';
  // ab Manager 0.35.0: Staende der Blizzard-API liefern belegte Verkaeufe und Standzeiten (proof.js)
  const keep = src === 'api';
  let start = null;
  if (keep) { proof.noteSeen(db, marketId, ra, a.t); start = proof.startOf(db, marketId); proof.noteSeen(db, marketId, rb, b.t); }
  const A = offersByItem(ra, a.t), B = offersByItem(rb, b.t);
  const keys = itemKeyOnly ? [itemKeyOnly] : [...new Set([...A.keys(), ...B.keys()])];
  const comm = commodityOf(db, keys);
  const pair = db.prepare('INSERT INTO sales_pair(market_id, a_id, b_id, ta, tb, src, item_key) VALUES (?, ?, ?, ?, ?, ?, ?)')
    .run(marketId, a.id, b.id, a.t, b.t, src, itemKeyOnly || null);
  const pid = Number(pair.lastInsertRowid);
  const ins = db.prepare(`INSERT INTO sales_cmp(pair_id, market_id, item_key, day, tb, secs, sold, expired, cancelled, listed, value, max_sold)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`);
  const day = dayOf(b.t), secs = b.t - a.t;
  for (const k of keys) {
    const la = A.get(k) || [], lb = B.get(k) || [];
    if (!la.length && !lb.length) continue;
    let cap = 0;
    if (src === 'live') {
      // Teil-Ergebnis: nur bis zum hoechsten Preis vergleichen, den beide sicher enthalten
      const ca = a.partial && la.length ? la[la.length - 1].p : 0, cb = b.partial && lb.length ? lb[lb.length - 1].p : 0;
      cap = ca && cb ? Math.min(ca, cb) : (ca || cb);
    }
    const commodity = src === 'live' && a.commodity != null ? !!a.commodity : (comm.get(k) || false);
    const r = compare(la, lb, a.t, b.t, { commodity, withIds, cap });
    ins.run(pid, marketId, k, day, b.t, secs, r.sold, r.expired, r.cancelled, r.listed, r.value, r.maxSold);
    if (keep) proof.record(db, marketId, k, day, r.soldList, a.t, b.t, start);
  }
  return true;
}

// Alle fehlenden Vergleiche eines Markts anlegen, ueberholte (weil ein Scan dazwischen kam) entfernen
function updateMarket(db, marketId, now = Math.floor(Date.now() / 1000)) {
  const res = { added: 0, removed: 0 };
  tx(db, () => {
    // Blizzard-API: je zwei aufeinanderfolgende Staende, die Nummern machen den Vergleich genau
    const apis = db.prepare("SELECT id, t FROM snapshots WHERE market_id = ? AND source = 'scan' AND art = 'api' AND rows IS NOT NULL ORDER BY t").all(marketId);
    const haveApi = new Set(db.prepare("SELECT a_id || '>' || b_id AS k FROM sales_pair WHERE market_id = ? AND src = 'api'").all(marketId).map((x) => x.k));
    for (let i = 1; i < apis.length; i++) {
      const a = apis[i - 1], b = apis[i];
      const gap = b.t - a.t;
      if (gap < MIN_GAP || gap > MAX_GAP || haveApi.has(a.id + '>' + b.id)) continue;
      if (addPair(db, marketId, a, b, 'api')) res.added++;
    }
    const apiPairs = db.prepare("SELECT ta, tb FROM sales_pair WHERE market_id = ? AND src = 'api'").all(marketId);
    const hasApi = (ta, tb) => apiPairs.some((c) => c.ta < tb && c.tb > ta);

    const scans = db.prepare("SELECT id, t FROM snapshots WHERE market_id = ? AND source = 'scan' AND art <> 'api' AND rows IS NOT NULL ORDER BY t").all(marketId);
    const want = new Map();
    for (let i = 1; i < scans.length; i++) {
      const a = scans[i - 1], b = scans[i];
      const gap = b.t - a.t;
      if (gap >= MIN_GAP && gap <= MAX_GAP && !hasApi(a.t, b.t)) want.set(a.id + '>' + b.id, [a, b]);
    }
    const have = db.prepare("SELECT id, a_id, b_id, ta, tb, folded FROM sales_pair WHERE market_id = ? AND src = 'scan'").all(marketId);
    const oldest = scans.length ? scans[0].t : Infinity;
    for (const p of have) {
      const k = p.a_id + '>' + p.b_id;
      if (want.has(k)) { want.delete(k); continue; }
      if (p.ta < oldest || p.folded) continue;   // Angebote schon verdichtet oder zusammengefasst: Ergebnis behalten
      db.prepare('DELETE FROM sales_cmp WHERE pair_id = ?').run(p.id);
      db.prepare('DELETE FROM sales_pair WHERE id = ?').run(p.id);
      res.removed++;
    }
    for (const [a, b] of want.values()) if (addPair(db, marketId, a, b, 'scan')) res.added++;

    // Live-Abfragen: Paare je Gegenstand, nur wo kein Scan-Paar die Zeit abdeckt
    const covered = db.prepare("SELECT ta, tb FROM sales_pair WHERE market_id = ? AND src IN ('scan', 'api')").all(marketId);
    const overlaps = (ta, tb) => covered.some((c) => c.ta < tb && c.tb > ta);
    const lives = db.prepare("SELECT id, t, item_key, partial, commodity FROM snapshots WHERE market_id = ? AND source = 'live' AND rows IS NOT NULL AND item_key IS NOT NULL ORDER BY item_key, t").all(marketId);
    const haveLive = new Set(db.prepare("SELECT a_id || '>' || b_id AS k FROM sales_pair WHERE market_id = ? AND src = 'live'").all(marketId).map((x) => x.k));
    for (let i = 1; i < lives.length; i++) {
      const a = lives[i - 1], b = lives[i];
      if (a.item_key !== b.item_key) continue;
      const gap = b.t - a.t;
      if (gap < MIN_GAP || gap > MAX_GAP || haveLive.has(a.id + '>' + b.id) || overlaps(a.t, b.t)) continue;
      if (addPair(db, marketId, a, b, 'live', a.item_key)) res.added++;
    }

    // Aeltere Vergleiche zu Tageswerten zusammenfassen
    const old = db.prepare('SELECT id FROM sales_pair WHERE market_id = ? AND folded = 0 AND tb < ?').all(marketId, now - FOLD_AFTER).map((x) => x.id);
    if (old.length) {
      const list = old.join(',');
      for (const r of db.prepare(`SELECT item_key, day, SUM(secs) AS secs, COUNT(*) AS cmp, SUM(sold) AS sold, SUM(expired) AS expired,
          SUM(cancelled) AS cancelled, SUM(listed) AS listed, SUM(value) AS value, MAX(max_sold) AS max_sold
          FROM sales_cmp WHERE pair_id IN (${list}) GROUP BY item_key, day`).all()) {
        db.prepare(`INSERT INTO sales_day(market_id, item_key, day, secs, cmp, sold, expired, cancelled, listed, value, max_sold)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(market_id, day, item_key) DO UPDATE SET secs = secs + excluded.secs, cmp = cmp + excluded.cmp,
              sold = sold + excluded.sold, expired = expired + excluded.expired, cancelled = cancelled + excluded.cancelled,
              listed = listed + excluded.listed, value = value + excluded.value, max_sold = MAX(COALESCE(max_sold, 0), COALESCE(excluded.max_sold, 0))`)
          .run(marketId, r.item_key, r.day, r.secs, r.cmp, r.sold, r.expired, r.cancelled, r.listed, r.value, r.max_sold);
      }
      db.prepare(`DELETE FROM sales_cmp WHERE pair_id IN (${list})`).run();
      db.prepare(`UPDATE sales_pair SET folded = 1 WHERE id IN (${list})`).run();
      res.folded = old.length;
    }
  });
  return res;
}

// Vergleiche und Tageswerte zusammen (fuer die Auswertung)
const ALL = `(SELECT market_id, item_key, day, secs, 1 AS cmp, sold, expired, cancelled, listed, value, max_sold FROM sales_cmp
  UNION ALL SELECT market_id, item_key, day, secs, cmp, sold, expired, cancelled, listed, value, max_sold FROM sales_day)`;

// F46 bis F48 fuer alle Gegenstaende eines Markts: Map key -> { perDay, rate, minutes, cmp, sold, expired, cancelled, listed, level, avgPrice }
function marketStats(db, marketId, now, onlyKey = null) {
  const today = dayOf(now);
  const out = new Map();
  const sql = `SELECT item_key AS key, SUM(sold) AS sold, SUM(expired) AS expired, SUM(cancelled) AS cancelled,
      SUM(listed) AS listed, SUM(secs) AS secs, SUM(cmp) AS cmp, SUM(value) AS value, MAX(max_sold) AS maxSold
      FROM ${ALL} WHERE market_id = ? AND day > ? AND day <= ?${onlyKey != null ? ' AND item_key = ?' : ''} GROUP BY item_key`;
  const args = onlyKey != null ? [marketId, today - DAYS, today, onlyKey] : [marketId, today - DAYS, today];
  for (const r of db.prepare(sql).iterate(...args)) {
    if (!(r.secs > 0)) continue;
    const minutes = r.secs / 60;
    out.set(r.key, {
      perDay: r.sold / r.secs * 86400, rate: r.sold + r.expired > 0 ? r.sold / (r.sold + r.expired) : null,
      minutes, cmp: r.cmp, sold: r.sold, expired: r.expired, cancelled: r.cancelled, listed: r.listed,
      avgPrice: r.sold > 0 ? r.value / r.sold : null, maxSold: r.maxSold,
      level: minutes >= SURE_MIN ? 3 : minutes >= MID_MIN ? 2 : 1,
    });
  }
  return out;
}

// Tageswerte fuer einen Gegenstand (Diagramm): [{ day, sold, secs }]
function itemDays(db, marketId, key, fromDay) {
  return db.prepare(`SELECT day, SUM(sold) AS sold, SUM(expired) AS expired, SUM(secs) AS secs FROM ${ALL}
      WHERE market_id = ? AND item_key = ? AND day >= ? GROUP BY day ORDER BY day`).all(marketId, key, fromDay);
}

// Text fuer Data.lua (Rechenmodell 9.4): "ABSATZ:QUOTE:MINUTEN"
function encode(s) {
  return `${Math.round(s.perDay * 10)}:${s.rate == null ? -1 : Math.round(s.rate * 100)}:${Math.round(s.minutes)}`;
}

function prune(db, now) {
  const cut = now - KEEP_DAYS * 86400;
  db.prepare('DELETE FROM sales_day WHERE day < ?').run(dayOf(cut));
  const ids = db.prepare('SELECT id FROM sales_pair WHERE tb < ?').all(cut).map((x) => x.id);
  for (const id of ids) {
    db.prepare('DELETE FROM sales_cmp WHERE pair_id = ?').run(id);
    db.prepare('DELETE FROM sales_pair WHERE id = ?').run(id);
  }
  return ids.length;
}

module.exports = { compare, offersByItem, updateMarket, marketStats, itemDays, encode, prune, DAYS, MID_MIN, SURE_MIN };
