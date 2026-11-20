'use strict';
// Peon Manager - Marktvergleich mit dem neutralen Haus im Modul Peon Broker Client (ab Manager 0.50.0,
// docs/konzepte/broker/Peon_Broker_Marktvergleich.md). Rechnung in compare.js, hier Paare, Regeln, Zwischenspeicher,
// Ansicht und die Liste fuer Broker (Data.lua, markets[Heimat].cmp).

const { log } = require('./db');
const compare = require('./compare');
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
    }
  },

  // Rechnung fuer alle Paare, Ergebnis in calc_cache (Heimatmarkt, Name 'compare')
  compareRunAll() {
    const ru = this.compareRules();
    const rsig = JSON.stringify(ru);
    let n = 0;
    for (const p of this.comparePairs()) {
      try {
        const res = compare.computePair(this.db, p.home.id, p.neutral.id, { rules: ru, now: this.now(), snaps: this.snaps, cutN: this.compareCut() });
        res.home = p.home.key;
        res.neutral = p.neutral.key;
        this.calcPut(p.home.id, 'compare', '', rsig, res);
        n += res.chances.length;
      } catch (e) { log(this.db, 'marktvergleich', false, `${p.home.key}: ${e.message}`); }
    }
    return n;
  },

  // Liste fuer Broker: ohne ausgeblendete, angeheftete immer dabei
  compareForBroker(homeId) {
    const c = this.calcGet(homeId, 'compare');
    if (!c || !c.value) return null;
    const hide = this.compareHidden();
    const v = { ...c.value, chances: c.value.chances.filter((x) => !hide.has(x.key)) };
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
    return { ...base, t: v.t, stale: c.rsig !== JSON.stringify(base.rules), cutN: v.cutN, cutSure: v.cutSure, cutH: v.cutH, days: v.days,
      stand: v.stand, sum: v.sum, chances: v.chances.map(decorate), items: v.items.map(decorate) };
  },

  // Fuer die Seite eines Gegenstands: beide Richtungen dieses Gegenstands oder null
  compareItem(marketKey, key) {
    const p = this.comparePairOf(marketKey);
    if (!p) return null;
    const c = this.calcGet(p.home.id, 'compare');
    if (!c || !c.value) return null;
    const row = c.value.items.find((x) => x.key === key) || null;
    const ch = c.value.chances.filter((x) => x.key === key);
    if (!row && !ch.length) return null;
    return { home: marketLabel(p.home.key), neutral: marketLabel(p.neutral.key), row, chances: ch, cutN: c.value.cutN, cutSure: c.value.cutSure };
  },
};

function install(proto) { Object.assign(proto, methods); }

module.exports = { install, methods };
