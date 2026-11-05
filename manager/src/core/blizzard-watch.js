'use strict';
// Peon Manager - Beobachter der Blizzard-API: klaert, wie sich die Auktionsdaten verhalten, bevor der Einleser entsteht.
// Laeuft nur mit PEON_MANAGER_BLIZZARD_WATCH (Testfassung), Nutzer sehen ihn nicht.
// Fragt regelmaessig ein kleines Haus nach einem neuen Stand. Gibt es einen, holt er alle Haeuser, legt die Antworten
// gepackt ab (nur die letzten Staende) und schreibt die Auswertung nach bericht.json: Takt, Felder, Werte, Angebotsnummern.

const fs = require('node:fs');
const path = require('node:path');
const zlib = require('node:zlib');
const { REGIONS, listOf, offersOf, auctionPath, failed } = require('./blizzard');

const KEEP_STANDS = 4;      // so viele Staende bleiben als Dateien liegen
const MAX_REPORT = 300;     // so viele Staende bleiben im Bericht
const MAX_EXAMPLES = 5;
const COMPARE = ['quantity', 'buyout', 'bid', 'unit_price'];
const KINDS = [['einzeln', false], ['masse', true]];

// Welche Felder und Werte kommen vor? Zaehlt in acc, damit mehrere Haeuser zusammen ausgewertet werden.
function addCensus(acc, offers) {
  acc.offers = (acc.offers || 0) + offers.length;
  acc.offerFields = acc.offerFields || {};
  acc.itemFields = acc.itemFields || {};
  acc.timeLeft = acc.timeLeft || {};
  acc.quantityNot1 = acc.quantityNot1 || 0;
  acc.itemExamples = acc.itemExamples || {};
  for (const o of offers) {
    for (const k of Object.keys(o)) acc.offerFields[k] = (acc.offerFields[k] || 0) + 1;
    for (const k of Object.keys(o.item || {})) {
      acc.itemFields[k] = (acc.itemFields[k] || 0) + 1;
      if (k === 'id') continue;
      const ex = acc.itemExamples[k] = acc.itemExamples[k] || [];
      if (ex.length < MAX_EXAMPLES) ex.push(o.item);
    }
    acc.timeLeft[o.time_left] = (acc.timeLeft[o.time_left] || 0) + 1;
    if (o.quantity !== 1) acc.quantityNot1 += 1;
  }
  return acc;
}

// Vergleich zweier Staende eines Hauses ueber die Angebotsnummer
function compareOffers(before, after) {
  const prev = new Map(before.map((o) => [o.id, o]));
  const out = { before: before.length, after: after.length, kept: 0, added: 0, gone: 0, otherItem: 0, changed: {}, timeLeft: {} };
  for (const o of after) {
    const p = prev.get(o.id);
    if (!p) { out.added += 1; continue; }
    out.kept += 1;
    if (JSON.stringify(p.item) !== JSON.stringify(o.item)) out.otherItem += 1;
    for (const k of COMPARE) if (p[k] !== o[k]) out.changed[k] = (out.changed[k] || 0) + 1;
    const move = `${p.time_left} > ${o.time_left}`;
    out.timeLeft[move] = (out.timeLeft[move] || 0) + 1;
  }
  out.gone = out.before - out.kept;
  return out;
}

function addCompare(acc, c) {
  for (const k of ['before', 'after', 'kept', 'added', 'gone', 'otherItem']) acc[k] = (acc[k] || 0) + c[k];
  for (const f of ['changed', 'timeLeft']) {
    acc[f] = acc[f] || {};
    for (const [k, v] of Object.entries(c[f])) acc[f][k] = (acc[f][k] || 0) + v;
  }
  return acc;
}

// Haeufigster Wert, damit ein einzelnes abweichendes Haus den Stand nicht bestimmt
function mostCommon(values) {
  const n = new Map();
  for (const v of values) n.set(v, (n.get(v) || 0) + 1);
  let best = null, top = 0;
  for (const [v, c] of n) if (c > top) { best = v; top = c; }
  return best;
}

class BlizzardWatch {
  constructor({ client, dir, now = () => Math.floor(Date.now() / 1000), log = () => {} }) {
    Object.assign(this, { client, dir, now, log });
    this.file = path.join(dir, 'bericht.json');
    this.busy = false;
    fs.mkdirSync(dir, { recursive: true });
    this.report = this.load();
  }

  load() {
    try {
      const r = JSON.parse(fs.readFileSync(this.file, 'utf8'));
      if (r.region === this.client.region) return r;
    } catch { /* noch kein Bericht */ }
    return { region: this.client.region, started: this.now(), checks: 0, lastCheck: null, lastError: null, conditional: {}, ruleset: null, rulesets: [], houses: [], refHouse: null, refKind: null, lastModified: null, lastDir: null, stands: [], census: { einzeln: {}, masse: {} }, compare: { einzeln: {}, masse: {} }, once: null };
  }

  save() {
    const tmp = `${this.file}.neu`;
    fs.writeFileSync(tmp, JSON.stringify(this.report, null, 1));
    fs.renameSync(tmp, this.file);
  }

  // Einmal je Lauf: nachsehen, ob es etwas Neues gibt. Ergebnis: new, same, error oder busy
  async tick() {
    if (this.busy) return 'busy';
    this.busy = true;
    try {
      const r = this.report;
      r.checks += 1;
      r.lastCheck = this.now();
      if (r.lastModified && r.refHouse != null) {
        // Die Haeuser eines Stands unterscheiden sich um eine Sekunde, deshalb zaehlt die Zeit des gefragten Hauses
        const stamp = r.refStamp || r.lastModified;
        const c = await this.client.get(auctionPath(r.ruleset, r.refHouse, r.refKind === 'masse'), { since: stamp });
        r.conditional[c.status] = (r.conditional[c.status] || 0) + 1;
        if (c.status === 304 || (c.status === 200 && c.lastModified === stamp)) { r.lastError = null; this.save(); return 'same'; }
        if (c.status !== 200) { r.lastError = { t: r.lastCheck, status: c.status, login: c.loginFailed || null }; this.save(); return 'error'; }
      }
      const done = await this.pull();
      this.save();
      return done ? 'new' : 'error';
    } finally { this.busy = false; }
  }

  async ensureHouses() {
    const r = this.report;
    if (r.ruleset != null && r.houses.length) return true;
    const rs = await this.client.get('/data/wow/ruleset/index');
    const rulesets = listOf(rs.json, 'rulesets').filter((x) => x && x.id != null);
    if (!rulesets.length) { r.lastError = { t: this.now(), status: rs.status, login: rs.loginFailed || null, where: 'Regelsätze' }; return false; }
    r.rulesets = rulesets.map((x) => ({ id: x.id, name: x.name, status: x.status }));
    const idx = await this.client.get(`/data/wow/ruleset/${rulesets[0].id}/auctions/index`);
    const houses = listOf(idx.json, 'auctions').filter((x) => x && x.id != null);
    if (!houses.length) { r.lastError = { t: this.now(), status: idx.status, where: 'Auktionshäuser' }; return false; }
    r.ruleset = rulesets[0].id;
    r.houses = houses.map((x) => ({ id: x.id, name: x.name }));
    return true;
  }

  // Alle Haeuser eines neuen Stands. Fehlt eine Antwort, zaehlt der Stand nicht und der naechste Lauf holt ihn neu.
  async pull() {
    const r = this.report;
    if (!await this.ensureHouses()) return false;
    const t = this.now();
    const standDir = path.join(this.dir, `stand-${t}`);
    fs.mkdirSync(standDir, { recursive: true });
    const stand = { seen: t, lastModified: null, requests: 0, bytes: 0, complete: true, offers: 0, houses: {} };
    const stamps = [], census = { einzeln: {}, masse: {} }, compare = { einzeln: {}, masse: {} };
    let smallest = null;

    for (const h of r.houses) {
      const row = stand.houses[h.id] = {};
      for (const [kind, mass] of KINDS) {
        const res = await this.client.get(auctionPath(r.ruleset, h.id, mass));
        stand.requests += 1;
        stand.bytes += res.bytes;
        if (failed(res.status)) stand.complete = false;
        if (!res.json) { row[kind] = { status: res.status }; continue; }
        const offers = offersOf(res.json);
        row[kind] = { status: res.status, offers: offers.length, items: new Set(offers.map((o) => o.item.id)).size, bytes: res.bytes, lastModified: res.lastModified };
        stand.offers += offers.length;
        if (res.lastModified) stamps.push(res.lastModified);
        if (!offers.length) continue;
        addCensus(census[kind], offers);
        const before = this.readHouse(r.lastDir, h.id, kind);
        if (before) addCompare(compare[kind], compareOffers(before, offers));
        fs.writeFileSync(path.join(standDir, `h${h.id}-${kind}.json.gz`), zlib.gzipSync(JSON.stringify(res.json)));
        if (!smallest || res.bytes < smallest.bytes) smallest = { house: h.id, kind, bytes: res.bytes, stamp: res.lastModified };
      }
    }

    stand.lastModified = mostCommon(stamps);
    stand.sameStamp = new Set(stamps).size === 1;
    r.stands.push(stand);
    if (r.stands.length > MAX_REPORT) r.stands.splice(0, r.stands.length - MAX_REPORT);
    if (!stand.complete || !stand.lastModified) {
      r.lastError = { t, status: null, where: 'Stand unvollständig' };
      fs.rmSync(standDir, { recursive: true, force: true });
      return false;
    }
    r.lastError = null;
    r.lastModified = stand.lastModified;
    r.lastDir = path.basename(standDir);
    if (smallest) { r.refHouse = smallest.house; r.refKind = smallest.kind; r.refStamp = smallest.stamp; }
    for (const kind of Object.keys(census)) {
      r.census[kind] = census[kind];              // immer der neueste Stand
      if (Object.keys(compare[kind]).length) { r.compare[kind] = compare[kind]; stand.compare = stand.compare || {}; stand.compare[kind] = compare[kind]; }
    }
    if (!r.once) r.once = await this.oneOff();
    this.prune();
    this.log(true, `Neuer Stand ${stand.lastModified}: ${stand.offers} Angebote, ${Math.round(stand.bytes / 1048576)} MB`);
    return true;
  }

  // Liest die gepackte Antwort eines Hauses aus einem frueheren Stand
  readHouse(dirName, house, kind) {
    if (!dirName) return null;
    try { return offersOf(JSON.parse(zlib.gunzipSync(fs.readFileSync(path.join(this.dir, dirName, `h${house}-${kind}.json.gz`))))); } catch { return null; }
  }

  // Einmalige Fragen: andere Regionen und Spieldaten (Name, Haendlerpreis, Bild), Leinenstoff als Beispiel
  async oneOff() {
    const once = { regions: {}, item: null, media: null };
    for (const region of REGIONS.filter((x) => x !== this.client.region)) {
      const rs = await this.client.get('/data/wow/ruleset/index', { region });
      once.regions[region] = { status: rs.status, rulesets: listOf(rs.json, 'rulesets').length };
    }
    const region = await this.client.get('/data/wow/region/index');
    once.regionIndex = { status: region.status, json: region.json };
    const item = await this.client.get('/data/wow/item/2589', { kind: 'static' });
    once.item = { status: item.status, json: item.json };
    const media = await this.client.get('/data/wow/media/item/2589', { kind: 'static' });
    once.media = { status: media.status, json: media.json };
    return once;
  }

  prune() {
    const dirs = fs.readdirSync(this.dir).filter((n) => /^stand-\d+$/.test(n)).sort((a, b) => Number(a.slice(6)) - Number(b.slice(6)));
    for (const n of dirs.slice(0, Math.max(0, dirs.length - KEEP_STANDS))) fs.rmSync(path.join(this.dir, n), { recursive: true, force: true });
  }

  // Kurzfassung fuer die Oberflaeche. Abstaende in Minuten zwischen den Staenden laut Blizzard.
  summary() {
    const r = this.report;
    const done = r.stands.filter((s) => s.complete && s.lastModified);
    const times = [...new Set(done.map((s) => Date.parse(s.lastModified) / 1000))];
    const gaps = times.slice(1).map((v, i) => Math.round((v - times[i]) / 60));
    return { checks: r.checks, lastCheck: r.lastCheck, lastModified: r.lastModified, stands: done.length, gaps: gaps.slice(-6), lastError: r.lastError };
  }
}

module.exports = { BlizzardWatch, addCensus, compareOffers, mostCommon };
