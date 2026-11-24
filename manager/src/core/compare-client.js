'use strict';
// Peon Manager - Marktvergleich mit dem neutralen Haus im Modul Peon Broker Client (ab Manager 0.50.0,
// docs/konzepte/broker/Peon_Broker_Marktvergleich.md). Rechnung in compare.js, hier Paare, Regeln, Zwischenspeicher,
// Ansicht und die Liste fuer Broker (Data.lua, markets[Heimat].cmp).

const fs = require('node:fs');
const path = require('node:path');
const { log } = require('./db');
const broker = require('./broker');
const { parseLua } = require('./lua');

// ab 0.52.0: Erfolgskontrolle. Die Auswahl fuer Broker wird je Tag gemerkt (meta compareLog) und nach CHECK_DAYS Tagen
// mit den Preisen und Verkaeufen der folgenden Tage nachgeprueft.
const CHECK_DAYS = 3;
const LOG_DAYS = 45;
const compare = require('./compare');
const packages = require('./packages');
const proof = require('./proof');
const { parseKey, marketLabel } = require('./markets');

const methods = {
  // Paare Heimat und Neutral desselben internen Namens: [{ home: { id, key }, neutral: { id, key } }]
  comparePairs() {
    const ms = this.db.prepare('SELECT id, key FROM markets').all();
    const neutral = new Map();
    for (const m of ms) { const k = parseKey(m.key); if (k.faction === 'Neutral') neutral.set(k.realm, m); }
    const out = [];
    for (const m of ms) {
      const k = parseKey(m.key);
      if (!k.faction || k.faction === 'Neutral') continue;
      const n = neutral.get(k.realm);
      if (n) out.push({ home: m, neutral: n });
    }
    return out;
  },

  // Paar zu einem Markt (Heimat oder Neutral). Bei Neutral das erste Fraktionshaus.
  comparePairOf(marketKey) {
    return this.comparePairs().find((p) => p.home.key === marketKey || p.neutral.key === marketKey) || null;
  },

  compareRules() { return compare.rules(this.meta('compareRules')); },
  setCompareRules(patch) {
    const next = compare.rules({ ...this.compareRules(), ...(patch || {}) });
    this.meta('compareRules', next);
    return next;
  },
  resetCompareRules() { this.meta('compareRules', null); return this.compareRules(); },

  // Gemessener Anteil des neutralen Hauses aus Peon_Broker.lua (PeonBrokerDB.cut.Neutral.r) oder null
  compareCut() {
    const c = this.meta('brokerCut');
    const r = c && c.Neutral && Number(c.Neutral.r);
    return Number.isFinite(r) && r > 0 && r < 0.5 ? r : null;
  },
  cutFromGame(results) {
    const r = (results || []).filter((x) => x.cut).sort((a, b) => (b.mt || 0) - (a.mt || 0))[0];
    if (!r) return false;
    if (JSON.stringify(r.cut) === JSON.stringify(this.meta('brokerCut'))) return false;
    this.meta('brokerCut', r.cut);
    return true;
  },

  comparePins() { return new Set(this.meta('comparePins') || []); },
  compareHidden() { return new Set(this.meta('compareHide') || []); },
  pinCompare(key, on) {
    const s = this.comparePins();
    if (on) s.add(String(key)); else s.delete(String(key));
    this.meta('comparePins', [...s]);
    this.compareToLua();
    return [...s];
  },
  hideCompare(key, on) {
    const s = this.compareHidden();
    if (on) s.add(String(key)); else s.delete(String(key));
    this.meta('compareHide', [...s]);
    return [...s];
  },

  // Liste fuer Broker gleich in die Werte fuer Data.lua uebernehmen (writeBridge schreibt danach)
  compareToLua() {
    if (!this.lastLua) return;
    for (const p of this.comparePairs()) {
      const v = this.lastLua[p.home.key];
      if (!v) continue;
      const cm = this.compareForBroker(p.home.id);
      if (cm) v.cmp = cm; else delete v.cmp;
      const pk = this.packagesForBroker(p.home.id);   // ab 0.53.0
      if (pk) v.pkg = pk; else delete v.pkg;
    }
  },

  // Rechnung fuer alle Paare, Ergebnis in calc_cache (Heimatmarkt, Name 'compare')
  compareRunAll() {
    const ru = this.compareRules();
    const rsig = JSON.stringify(ru);
    let n = 0;
    // ab 0.52.0: Haendlerpreise fuer die Einstellgebuehr
    const vendor = new Map(this.db.prepare('SELECT key, vendor FROM items WHERE vendor > 0').all().map((x) => [x.key, x.vendor]));
    for (const p of this.comparePairs()) {
      try {
        const res = compare.computePair(this.db, p.home.id, p.neutral.id, { rules: ru, now: this.now(), snaps: this.snaps, cutN: this.compareCut(), vendor });
        res.home = p.home.key;
        res.neutral = p.neutral.key;
        try { res.pkg = this.comparePackages(p, res, ru); this.pkgLogDay(p, res.pkg); } catch (e) { log(this.db, 'marktvergleich', false, `Pakete ${p.home.key}: ${e.message}`); }   // ab 0.53.0
        this.calcPut(p.home.id, 'compare', '', rsig, res);
        n += res.chances.length;
        this.compareLogPicks(p, res);   // ab 0.52.0
      } catch (e) { log(this.db, 'marktvergleich', false, `${p.home.key}: ${e.message}`); }
    }
    return n;
  },

  // ---------- Pakete (ab 0.53.0, Peon_Broker_Pakete.md) ----------
  pkgExcluded() { return new Set(this.meta('pkgExclude') || []); },
  excludePkg(dir, key, on) {
    const s = this.pkgExcluded();
    const id = `${dir}|${key}`;
    if (on) s.add(id); else s.delete(id);
    this.meta('pkgExclude', [...s]);
    return [...s];
  },
  // Je Richtung ein Paket aus allen Kandidaten. Einsatz hoechstens pkgGold vom Gold laut Ledger (Fraktion des Heimatmarkts)
  comparePackages(p, res, ru) {
    const info = new Map(this.db.prepare('SELECT key, commodity, variant, stack, cls, vendor FROM items').all()
      .map((x) => [x.key, { commodity: !x.variant && x.commodity === 1, stack: x.stack, cls: x.cls, vendor: x.vendor }]));
    // Varianten ("Ruestung des Affen") haben keine eigene Kategorie: die des Grundgegenstands
    const infoOf = (k) => {
      const own = info.get(String(k)), base = info.get(String(k).split(':')[0]);
      const x = { ...(base || {}), ...(own || {}) };
      if ((x.cls == null || x.cls < 0) && base && base.cls != null) x.cls = base.cls;
      return x;
    };
    let gold = null;
    try { const g = this.ledgerGold ? this.ledgerGold(p.home.id) : null; gold = g ? g.gold : null; } catch { gold = null; }
    const budget = gold ? Math.floor(gold * ru.pkgGold) : packages.DEFAULT_GOLD;
    const ex = this.pkgExcluded();
    const out = { t: res.t, safe: ru.pkgSafe, budget, gold };
    for (const dir of ['n', 'h']) out[dir] = packages.build(res.chances, dir, infoOf, ru, budget, ex, dir === 'n' ? res.cutN : res.cutH);
    return out;
  },
  // Fuer Data.lua (markets[Heimat].pkg)
  packagesForBroker(homeId) {
    const c = this.calcGet(homeId, 'compare');
    const pk = c && c.value && c.value.pkg;
    if (!pk) return null;
    const n = packages.forBroker(pk.n, pk.n ? pk.n.cut : 0.15), h = packages.forBroker(pk.h, pk.h ? pk.h.cut : 0.05);
    if (!n && !h) return null;
    return { t: pk.t, safe: Math.round(pk.safe * 100), ...(n ? { n } : {}), ...(h ? { h } : {}) };
  },

  // Liste fuer Broker: ohne ausgeblendete, angeheftete immer dabei
  compareForBroker(homeId) {
    const c = this.calcGet(homeId, 'compare');
    if (!c || !c.value) return null;
    const hide = this.compareHidden();
    const v = { ...c.value, chances: c.value.chances.filter((x) => !hide.has(x.key)).map((x) => ({ ...x })) };
    compare.pickTop(v.chances, (v.rules && v.rules.top) || compare.DEFAULTS.top);   // ab 0.51.0: Ausgeblendete ruecken nach
    return compare.forBroker(v, this.comparePins());
  },

  // Ansicht Marktvergleich: Paar, Regeln, Chancen und alle Gegenstaende mit Namen
  compareView(marketKey) {
    const p = this.comparePairOf(marketKey);
    if (!p) return { pair: null, pairs: this.comparePairs().map((x) => ({ home: x.home.key, neutral: x.neutral.key })) };
    const c = this.calcGet(p.home.id, 'compare');
    const base = { pair: { home: p.home.key, neutral: p.neutral.key, homeLabel: marketLabel(p.home.key), neutralLabel: marketLabel(p.neutral.key) },
      rules: this.compareRules(), defaults: compare.DEFAULTS, choices: compare.CHOICES, pins: [...this.comparePins()], hidden: [...this.compareHidden()] };
    if (!c || !c.value) return { ...base, t: null };
    const names = new Map(this.db.prepare('SELECT key, name, quality, item_id, commodity, variant FROM items').all().map((x) => [x.key, x]));
    const decorate = (x) => {
      const i = names.get(x.key) || {};
      return { ...x, name: i.name || null, quality: i.quality ?? null, item: i.item_id ?? Number(String(x.key).split(':')[0]),
        commodity: i.variant ? 0 : (i.commodity ?? null) };
    };
    const v = c.value;
    const pkg = v.pkg ? { budget: v.pkg.budget, gold: v.pkg.gold, safe: v.pkg.safe, excluded: [...this.pkgExcluded()],
      n: v.pkg.n ? { ...v.pkg.n, offers: v.pkg.n.offers.map(decorate) } : null, h: v.pkg.h ? { ...v.pkg.h, offers: v.pkg.h.offers.map(decorate) } : null } : null;
    return { ...base, t: v.t, stale: c.rsig !== JSON.stringify(base.rules), cutN: v.cutN, cutSure: v.cutSure, cutH: v.cutH, days: v.days,
      stand: v.stand, sum: v.sum, chances: v.chances.map(decorate), items: v.items.map(decorate), pkg };
  },

  // ---------- Erfolgskontrolle (ab 0.52.0) ----------
  // Auswahl des Tages merken: je Markt, Gegenstand, Richtung und Tag ein Eintrag mit den Werten der Rechnung
  compareLogPicks(p, res) {
    const day = Math.floor(res.t / 86400);
    const logList = this.meta('compareLog') || [];
    const have = new Set(logList.map((x) => `${x.m}|${x.key}|${x.dir}|${x.day}`));
    let added = 0;
    for (const c of res.chances) {
      if (!c.pick) continue;
      const id = `${p.home.id}|${c.key}|${c.dir}|${day}`;
      if (have.has(id)) continue;
      logList.push({ m: p.home.id, n: p.neutral.id, key: c.key, dir: c.dir, day, t: res.t, buy: c.buy, sell: c.sell, net: c.net, cut: c.dir === 'n' ? res.cutN : res.cutH, minNet: res.rules.minNet });
      added++;
    }
    const old = day - LOG_DAYS;
    const keep = logList.filter((x) => x.day > old);
    if (added || keep.length !== logList.length) this.meta('compareLog', keep);
    return added;
  },

  // Nachpruefen: In den CHECK_DAYS Tagen nach dem Vorschlag der hoechste streng erkannte Verkauf im Zielhaus nach Anteil minus
  // Kaufpreis in der Quelle. held = mindestens die Haelfte des erwarteten Gewinns, partly = immerhin Gewinn, failed = keiner
  // oder gar nicht verkauft, nodata = keine Vergleiche der Blizzard-API im Zielhaus.
  // ab 0.55.0 (KarloDerBaer 25.11.2026): vorher zaehlte das Tagesmittel der Preise beider Haeuser, auch ganz ohne Verkauf.
  compareCheck(e, now) {
    const dst = e.dir === 'n' ? e.n : e.m;
    const from = (e.day + 1) * 86400, to = Math.min((e.day + CHECK_DAYS + 1) * 86400, now);
    if (!proof.covered(this.db, dst, from, to)) return { outcome: 'nodata', real: null };
    const best = proof.soldMax(this.db, dst, String(e.key), e.day + 1, e.day + CHECK_DAYS);
    if (best == null || !(e.buy > 0)) return { outcome: 'failed', real: null };
    const real = best * (1 - (e.cut || 0.05)) - e.buy;
    const outcome = real >= (e.net || 0) * 0.5 ? 'held' : real > 0 ? 'partly' : 'failed';
    return { outcome, real: Math.round(real) };
  },

  // Echte Tausche aus Peon_Ledger.lua (ab Ledger 0.17 tragen Bewegungen im Auktionshaus das Haus h): Verkauf in einem Haus,
  // vorher Kauf desselben Gegenstands im anderen Haus (hoechstens 14 Tage davor). Gewinn = Erloes minus Kaufpreis der Stueck.
  // ab 0.53.0: Bewegungen aus Peon_Ledger.lua (alle Kontoordner), je Realm eine Liste
  ledgerMoveLists() {
    const out = [];
    for (const f of broker.findFiles(this.settings.wowDir)) {
      const file = path.join(path.dirname(f.file), 'Peon_Ledger.lua');
      let realms;
      try { realms = (parseLua(fs.readFileSync(file)).PeonLedgerDB || {}).realms || {}; } catch { continue; }
      for (const r of Object.values(realms)) out.push((Array.isArray(r && r.moves) ? r.moves : Object.values((r && r.moves) || {})).filter(Boolean));
    }
    return out;
  },

  compareTrades(since) {
    const out = [];
    const name = this.db.prepare('SELECT name, quality FROM items WHERE key = ?');
    {
      for (const moves of this.ledgerMoveLists()) {
        const buys = moves.filter((m) => m.k === 'ahbuy' && m.id && (m.h === 'f' || m.h === 'n') && Number(m.m) < 0);
        for (const s of moves) {
          if (s.k !== 'ahsold' || !s.id || !(s.h === 'f' || s.h === 'n') || !(Number(s.m) > 0) || !(s.t >= since)) continue;
          const b = buys.filter((x) => x.id === s.id && x.h !== s.h && x.t < s.t && s.t - x.t <= 14 * 86400).pop();
          if (!b) continue;
          const qty = Number(s.q) || Math.abs(Number(s.n) || 0) || 1;
          const bq = Number(b.q) || Number(b.n) || 1;
          const cost = (-Number(b.m) / bq) * qty;
          const nm = name.get(String(s.id)) || {};
          out.push({ key: String(s.id), name: nm.name || null, quality: nm.quality ?? null, t: s.t, dir: s.h === 'n' ? 'n' : 'h', qty, cost: Math.round(cost), income: Number(s.m), profit: Math.round(Number(s.m) - cost) });
        }
      }
    }
    return out.sort((a, b) => b.t - a.t).slice(0, 200);
  },

  // ---------- Erfolgskontrolle der Pakete (ab 0.53.0) ----------
  // Das erste Paket des Tages je Richtung merken (Angebote mit Menge und Kaufen bis)
  pkgLogDay(p, pkg) {
    if (!pkg) return 0;
    const day = Math.floor(pkg.t / 86400);
    const list = this.meta('pkgLog') || [];
    let added = 0;
    for (const dir of ['n', 'h']) {
      const x = pkg[dir];
      if (!x || !x.offers.length || list.some((e) => e.m === p.home.id && e.dir === dir && e.day === day)) continue;
      list.push({ m: p.home.id, dir, day, t: pkg.t, stake: x.stake, gain: x.gain, gainSafe: x.gainSafe, safe: x.safe,
        offers: x.offers.map((o) => ({ key: o.key, qty: o.qty, buy: o.buy })) });
      added++;
    }
    const keep = list.filter((e) => e.day > day - LOG_DAYS);
    if (added || keep.length !== list.length) this.meta('pkgLog', keep);
    return added;
  },

  // Auswertung eines Pakets mit Ledger: im Haus der Quelle gekauft (bis 7 Tage danach), im Haus des Ziels verkauft
  pkgResult(e, moveLists) {
    const src = e.dir === 'n' ? 'f' : 'n', dst = e.dir === 'n' ? 'n' : 'f';
    const until = e.t + 7 * 86400;
    let bought = 0, sold = 0, cost = 0, income = 0;
    for (const o of e.offers) {
      const id = Number(String(o.key).split(':')[0]);
      let b = 0, s = 0;
      for (const moves of moveLists) {
        for (const m of moves) {
          if (m.id !== id || !(m.t >= e.t)) continue;
          if (m.k === 'ahbuy' && m.h === src && m.t <= until && Number(m.m) < 0 && b < o.qty) {
            b += Number(m.q) || Number(m.n) || 1;
            cost += -Number(m.m);
          } else if (m.k === 'ahsold' && m.h === dst && Number(m.m) > 0 && s < o.qty) {
            s += Number(m.q) || Math.abs(Number(m.n) || 0) || 1;
            income += Number(m.m);
          }
        }
      }
      if (b > 0) bought++;
      if (s > 0) sold++;
    }
    return { bought, sold, cost, income, profit: income - cost, share: bought ? sold / bought : null };
  },

  pkgSuccess(p) {
    const list = (this.meta('pkgLog') || []).filter((e) => e.m === p.home.id);
    if (!list.length) return [];
    let moveLists = [];
    try { moveLists = this.ledgerMoveLists(); } catch { moveLists = []; }
    const names = this.db.prepare('SELECT name FROM items WHERE key = ?');
    return list.slice().sort((a, b) => b.t - a.t).slice(0, 30).map((e) => {
      const r = this.pkgResult(e, moveLists);
      return { dir: e.dir, t: e.t, stake: e.stake, gain: e.gain, gainSafe: e.gainSafe, safe: e.safe, n: e.offers.length, ...r,
        names: e.offers.slice(0, 4).map((o) => (names.get(String(o.key)) || {}).name || o.key) };
    });
  },

  // Teil der Erfolgskontrolle: Quote der Auswahl und die letzten Vorschlaege mit Ergebnis, dazu echte Tausche
  compareSuccess(marketKey) {
    const p = this.comparePairOf(marketKey);
    if (!p) return null;
    const now = this.now();
    const today = Math.floor(now / 86400);
    const logList = this.meta('compareLog') || [];
    let changed = false;
    for (const e of logList) {
      if (e.m !== p.home.id || e.outcome || e.day + CHECK_DAYS >= today) continue;
      try { Object.assign(e, this.compareCheck(e, now), { checked: now }); changed = true; } catch { /* spaeter */ }
    }
    if (changed && !this.readOnly) this.meta('compareLog', logList);
    const names = this.db.prepare('SELECT name, quality FROM items WHERE key = ?');
    const mine = logList.filter((e) => e.m === p.home.id && e.day > today - 30);
    const done = mine.filter((e) => e.outcome && e.outcome !== 'nodata');
    const count = (o) => done.filter((e) => e.outcome === o).length;
    const rows = mine.slice().sort((a, b) => b.t - a.t).slice(0, 100).map((e) => {
      const nm = names.get(String(e.key)) || {};
      return { ...e, name: nm.name || null, quality: nm.quality ?? null, waiting: !e.outcome };
    });
    let trades = [];
    try { trades = this.compareTrades(now - 30 * 86400); } catch { trades = []; }
    return { home: marketLabel(p.home.key), neutral: marketLabel(p.neutral.key), checkDays: CHECK_DAYS, total: mine.length, checked: done.length,
      held: count('held'), partly: count('partly'), failed: count('failed'), rows, trades, packages: this.pkgSuccess(p) };
  },

  // Fuer die Seite eines Gegenstands: beide Richtungen dieses Gegenstands oder null
  compareItem(marketKey, key) {
    const p = this.comparePairOf(marketKey);
    if (!p) return null;
    const c = this.calcGet(p.home.id, 'compare') || { value: { items: [], chances: [], cutN: compare.DEFAULTS.cutN, cutSure: false } };
    const row = c.value.items.find((x) => x.key === key) || null;
    const ch = c.value.chances.filter((x) => x.key === key);
    // ab 0.52.0: Verlauf beider Haeuser fuer das Diagramm (auch ohne Zeile im Vergleich)
    let series = null;
    try { series = compare.itemSeries(this.db, p.home.id, p.neutral.id, key, this.now(), 30); } catch { series = null; }
    if (!row && !ch.length && !(series && series.days.some((_, i) => series.home[i] != null || series.neutral[i] != null))) return null;
    return { home: marketLabel(p.home.key), neutral: marketLabel(p.neutral.key), row, chances: ch, cutN: c.value.cutN, cutSure: c.value.cutSure, series };
  },
};

function install(proto) { Object.assign(proto, methods); }

module.exports = { install, methods };
