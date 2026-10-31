'use strict';
// Kennzahlen einer Momentaufnahme je Gegenstand (wie Broker, Rechenmodell Kapitel 1 und 2):
// Min, Median je Stueck ueber alle Stueck, unteres und oberes Viertel, Menge, Angebote.
// Reine Gebote (ohne Sofortkauf) zaehlen fuer die Preise nicht.

// Feldreihenfolge einer Zeile (Peon_Bridge, Format 1):
// item;bonus;name;quantity;buyout;unit_price;bid;time_left;id;n
function parseRow(line) {
  const f = line.split(';');
  if (f.length < 10) return null;
  const num = (x) => (x === '' || x === undefined ? null : Number(x));
  const item = num(f[0]);
  if (!Number.isFinite(item)) return null;
  return {
    item,
    bonus: f[1] || '',
    name: f[2] || '',
    qty: num(f[3]) || 0,
    buyout: num(f[4]),
    unit: num(f[5]),
    bid: num(f[6]),
    tl: num(f[7]),
    id: num(f[8]),
    n: num(f[9]) || 1,
  };
}

function parseRows(text) {
  if (typeof text !== 'string' || text === '') return [];
  const out = [];
  for (const line of text.split('\n')) {
    if (!line) continue;
    const r = parseRow(line);
    if (r) out.push(r);
  }
  return out;
}

// Schluessel wie in Broker: itemID, bei Gegenstaenden mit Zusatz "itemID:voller Name"
function itemKey(r) {
  return r.name ? `${r.item}:${r.name}` : String(r.item);
}

// Preis je Stueck einer Zeile, null = kein Sofortkauf
function unitPrice(r) {
  if (r.unit != null && r.unit > 0) return r.unit;
  if (r.buyout != null && r.buyout > 0 && r.qty > 0) return r.buyout / r.qty;
  return null;
}

// rows einer Momentaufnahme -> Map key -> { item, name, min, median, p25, p75, qty, auctions }
function summarize(rows) {
  const groups = new Map();
  for (const r of rows) {
    const key = itemKey(r);
    let g = groups.get(key);
    if (!g) { g = { key, item: r.item, name: r.name, list: [] }; groups.set(key, g); }
    const p = unitPrice(r);
    if (p != null && r.qty > 0) g.list.push([p, r.qty * r.n, r.n]);
  }
  const out = new Map();
  for (const [key, g] of groups) out.set(key, stats(g));
  return out;
}

function stats(g) {
  const list = g.list.sort((a, b) => a[0] - b[0]);
  let qty = 0, auctions = 0;
  for (const x of list) { qty += x[1]; auctions += x[2]; }
  const res = { key: g.key, item: g.item, name: g.name, min: null, median: null, p25: null, p75: null, qty, auctions };
  if (qty === 0) return res;
  const at = (k) => {
    let seen = 0;
    for (const x of list) { seen += x[1]; if (seen >= k) return x[0]; }
    return list[list.length - 1][0];
  };
  res.min = list[0][0];
  res.median = qty % 2 === 1 ? at((qty + 1) / 2) : (at(qty / 2) + at(qty / 2 + 1)) / 2;
  res.p25 = at(Math.max(1, Math.ceil(qty * 0.25)));
  res.p75 = at(Math.max(1, Math.ceil(qty * 0.75)));
  return res;
}

module.exports = { parseRow, parseRows, itemKey, unitPrice, summarize };
