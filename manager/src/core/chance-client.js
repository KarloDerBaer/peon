'use strict';
// Peon Manager - Chancen und Prognosen im Modul Peon Broker Client (Konzept Peon_Manager_Chancen.md, ab Manager 0.35.0).
// Methoden fuer BrokerClient (broker-client.js haengt sie ein): Seite Chancen, Steckbrief, Marktuebersicht,
// Erfolgskontrolle, Rueckmeldungen, Regler mit Probe, Uebersteuerungen, Kandidatenliste fuer Broker (Data.lua) und
// benoetigte Stufe aller Gegenstaende (D3, im Hintergrund von der Blizzard-API).

const fs = require('node:fs');
const path = require('node:path');
const zlib = require('node:zlib');
const { parseRows, itemKey, unitPrice } = require('./stats');
const { parseLua } = require('./lua');
const { log } = require('./db');
const broker = require('./broker');
const chances = require('./chances');
const spec = require('./spec');
const proof = require('./proof');
const forecast = require('./forecast');
const book = require('./chancebook');
const { fetchItem } = require('./item-info');
const { failed } = require('./blizzard');

const MAX_FOR_BROKER = 200;   // 9.1: hoechstens 200 Eintraege je Markt
const LEVEL_BATCH = 100;      // D3: so viele Gegenstaende je Minute ohne Abruf der Auktionshaeuser (etwa 6000 je Std.)
const LEVEL_FRESH = 90 * 86400;
// Aufkauf wie Broker (Startwerte aus Broker.lua), bis Brokers Einstellungen eingelesen sind
const BROKER_RULES = { hours: 2, minGain: 5000, minQty: 500, minLevels: 4, minSales: 270, targetPct: 0.2 };
const KIND_CODE = { s: 's', l: 'l', b: 'b', v: 'v' };
const RISK_CODE = { low: 0, mid: 1, high: 2 };

const methods = {
  chanceRules() { return spec.rulesOf(this.meta('chanceRules')); },
  setChanceRules(patch) {
    const cur = this.chanceRules();
    const next = spec.rulesOf({ ...cur, ...patch, f: { ...cur.f, ...(patch && patch.f), signals: { ...cur.f.signals, ...(patch && patch.f && patch.f.signals) } } });
    this.meta('chanceRules', next);
    this.chanceCache = null;
    log(this.db, 'chancen', true, 'Regler geändert');
    return next;
  },
  resetChanceRules(kind) {
    const cur = this.chanceRules();
    if (kind && spec.DEFAULTS[kind]) cur[kind] = JSON.parse(JSON.stringify(spec.DEFAULTS[kind]));
    this.meta('chanceRules', cur);
    this.chanceCache = null;
    return cur;
  },
  overridesDoc() { return this.meta('chanceOverrides') || {}; },
  overrides() {
    const d = this.overridesDoc();
    const name = this.db.prepare('SELECT name, quality FROM items WHERE key = ?');
    return Object.entries(d).map(([key, o]) => ({ key, ...o, ...(name.get(key) || {}) })).sort((a, b) => (b.t || 0) - (a.t || 0));
  },
  setOverride(key, o) {
    const d = this.overridesDoc();
    const x = book.cleanOverride(o);
    if (Object.keys(x).length) d[String(key)] = { ...x, t: this.now() }; else delete d[String(key)];
    this.meta('chanceOverrides', d);
    this.chanceCache = null;
    log(this.db, 'chancen', true, `Übersteuerung ${Object.keys(x).length ? 'gesetzt' : 'zurückgenommen'}: ${key}`);
    return true;
  },
  brokerRules() { return { ...BROKER_RULES, ...(this.meta('brokerRules') || {}) }; },

  // Stand eines Markts fuer die Chancen: letzter vollstaendiger Stand mit Angeboten
  chanceCtx(mid) {
    const sig = `${this.dataSig(mid)}|${JSON.stringify([this.meta('chanceRules'), this.meta('chanceOverrides'), this.meta('brokerRules'), this.meta('feste')])}`;
    this.chanceCache = this.chanceCache || new Map();
    const c0 = this.chanceCache.get(mid);
    if (c0 && c0.sig === sig) return c0.ctx;
    const db = this.db;
    const now = this.now();
    const today = broker.dayOf(now);
    const last = db.prepare("SELECT id, t FROM snapshots WHERE market_id = ? AND source = 'scan' AND partial = 0 AND rows IS NOT NULL ORDER BY t DESC LIMIT 1").get(mid);
    const rows = last ? chances.rowsOf(db, last.id) || [] : [];
    const offers = new Map();
    for (const r of rows) {
      const p = unitPrice(r);
      if (p == null || !(r.qty > 0)) continue;
      const k = itemKey(r);
      let m = offers.get(k);
      if (!m) { m = new Map(); offers.set(k, m); }
      const pr = Math.round(p);
      m.set(pr, (m.get(pr) || 0) + r.qty * (r.n || 1));
    }
    for (const [k, m] of offers) offers.set(k, [...m.entries()].sort((a, b) => a[0] - b[0]).map(([p, q]) => ({ p, q })));
    const bd = this.bands(mid);
    const stats = this.statsOf(mid);
    const pr = proof.soldPrices(db, mid, today);
    const refs = new Map([...pr].map(([k, x]) => [k, x.median]));
    const dur = proof.durabilityAll(db, mid, refs, today);
    const items = new Map(db.prepare('SELECT key, name, quality, item_id, vendor, commodity, variant FROM items').all().map((x) => [x.key, x]));
    const over = this.overridesDoc();
    const rules = this.chanceRules();
    const levels = new Map(db.prepare('SELECT item_id, req, equip FROM item_level WHERE req IS NOT NULL').all().map((x) => [x.item_id, x]));
    const fc = forecast.marketForecasts({ db, mid, now, today, bands: bd.items, values: bd.days, qty: this.snaps.dayQty(mid, now, 14), sales: stats,
      levels, fests: this.fests(), switches: rules.f.signals });
    const ctx = {
      mid, now, today, t: last ? last.t : null, age: last ? Math.max(0, now - last.t) : Infinity, rows, offers, stats, bands: bd.items, shifts: bd.shifts,
      proof: pr, dur, rules, broker: this.brokerRules(), forecasts: fc.list, index: fc.index, signalRates: fc.rates,
      over: (k) => over[k] || {},
      vendor: (k) => { const i = items.get(k) || items.get(String(k).split(':')[0]); return i && i.vendor > 0 ? i.vendor : null; },
      isCommodity: (k) => { const i = items.get(k); return !!(i && !i.variant && i.commodity === 1); },
      info: (k) => items.get(k) || { name: null, quality: null, item_id: Number(String(k).split(':')[0]) },
      hold: (k) => dur.get(k) || null,
    };
    this.chanceCache.set(mid, { sig, ctx });
    return ctx;
  },

  // Rechnen, speichern (D5), nachpruefen. Laeuft nach jedem Einlesen je Markt (buildMarkets)
  chanceRun(mid) {
    const ctx = this.chanceCtx(mid);
    const res = spec.marketChances(ctx);
    if (ctx.t) {
      book.log(this.db, mid, ctx.now, [...res.list, ...res.live], res.near);
      book.check(this.db, mid, ctx.now);
      forecast.logForecasts(this.db, mid, ctx.forecasts, ctx.now);
      forecast.checkForecasts(this.db, mid, ctx.now);
    }
    this.chanceRes = this.chanceRes || new Map();
    this.chanceRes.set(mid, { t: ctx.t, sig: ctx, res });
    return res;
  },
  chanceResult(mid) {
    const ctx = this.chanceCtx(mid);
    const c = this.chanceRes && this.chanceRes.get(mid);
    if (c && c.sig === ctx) return c.res;
    return this.chanceRun(mid);
  },

  // Kandidatenliste fuer Broker (9.1): { t, list = { [key] = "Art:KaufenBis:Zielpreis:GueltigBis:Gewinn:Risiko" }, say }
  chancesForBroker(mid) {
    const res = this.chanceResult(mid);
    const pinned = this.meta('chancePinned') || {};
    const now = this.now();
    const all = [...res.list, ...res.live].filter((x) => x.buy > 0 && (x.until || 0) > now).sort((a, b) => (b.gain || 0) - (a.gain || 0));
    const list = {}, say = {};
    let n = 0;
    const put = (x) => {
      if (list[x.key]) return;
      list[x.key] = `${KIND_CODE[x.kind]}:${Math.round(x.buy)}:${Math.round(x.target || 0)}:${Math.round(x.until || 0)}:${Math.max(0, Math.round(x.gain || 0))}:${RISK_CODE[x.risk] ?? 1}:${Math.max(1, Math.round(x.qty || 1))}`;
      if (x.say) say[x.key] = x.liveOnly ? `${x.say} Nur live erreichbar.` : x.say;
      n++;
    };
    for (const x of all) if (pinned[x.key]) put(x);
    for (const x of all) { if (n >= MAX_FOR_BROKER) break; put(x); }
    const ctx = this.chanceCtx(mid);
    return n ? { t: ctx.t || now, list, say } : null;
  },
  pinChance(key, on = true) {
    const p = this.meta('chancePinned') || {};
    if (on) p[String(key)] = this.now(); else delete p[String(key)];
    this.meta('chancePinned', p);
    // gleich in die Werte fuer Data.lua uebernehmen (writeBridge schreibt danach)
    if (this.lastLua) {
      for (const [mk, v] of Object.entries(this.lastLua)) {
        const mid = this.marketId(mk);
        const ch = mid != null ? this.chancesForBroker(mid) : null;
        if (ch) v.chances = ch;
      }
    }
    return true;
  },

  // ---------- Ansichten ----------
  chanceView(marketKey) {
    const mid = this.marketId(marketKey);
    if (mid == null) return null;
    const ctx = this.chanceCtx(mid);
    const res = this.chanceResult(mid);
    const rated = new Map();
    for (const r of this.db.prepare('SELECT item_key, up, reason, t FROM chance_rate WHERE t >= ? ORDER BY t').iterate(this.now() - 14 * 86400)) rated.set(r.item_key, r);
    const pinned = this.meta('chancePinned') || {};
    const fav = new Set(this.favorites());
    const strip = (x) => ({ ...x, rated: rated.get(x.key) || null, pinned: !!pinned[x.key], watched: fav.has(x.key) });
    const proven = ctx.proof.size;
    return { market: marketKey, now: ctx.now, t: ctx.t, age: ctx.age, list: res.list.map(strip), live: res.live.map(strip), near: res.near.length,
      proven, holdKnown: ctx.dur.size, bands: ctx.bands.size, salesItems: ctx.stats.size, forecasts: ctx.forecasts.size, rules: ctx.rules,
      start: proof.startOf(this.db, mid), kinds: spec.KINDS };
  },

  // Pruefliste fuer einen beliebigen Gegenstand (Warum nicht?)
  chanceItem(marketKey, key) {
    const mid = this.marketId(marketKey);
    if (mid == null) return null;
    const ctx = this.chanceCtx(mid);
    const out = spec.itemChecks(ctx, String(key));
    const fc = ctx.forecasts.get(String(key)) || null;
    return { key: String(key), checks: out, forecast: fc, override: ctx.over(String(key)), t: ctx.t };
  },

  // Steckbrief (6.1 Stufe 3)
  brief(marketKey, key, days = 14) {
    const mid = this.marketId(marketKey);
    if (mid == null) return null;
    key = String(key);
    const db = this.db;
    const ctx = this.chanceCtx(mid);
    const now = this.now();
    const today = broker.dayOf(now);
    const from = now - days * 86400;
    const i = ctx.info(key);
    const offers = [];
    for (const r of db.prepare("SELECT t, min, median FROM item_snap WHERE market_id = ? AND item_key = ? AND source = 'scan' AND t >= ? ORDER BY t").iterate(mid, key, from)) offers.push({ t: r.t, min: r.min, median: r.median });
    for (const r of db.prepare("SELECT t, min, median FROM item_hour WHERE market_id = ? AND item_key = ? AND source = 'scan' AND t >= ? ORDER BY t").iterate(mid, key, from)) offers.push({ t: r.t, min: r.min, median: r.median });
    offers.sort((a, b) => a.t - b.t);
    const sales = proof.salesOf(db, mid, key, broker.dayOf(from)).map((x) => ({ ...x, t: broker.dayTime(x.day) }));
    const checks = spec.itemChecks(ctx, key);
    const best = checks.filter((x) => x.ok).sort((a, b) => (b.gain || 0) - (a.gain || 0))[0] || checks[0];
    const pr = ctx.proof.get(key) || null;
    const st = ctx.stats.get(key) || null;
    const b = ctx.bands.get(key) || null;
    const steps = [];
    if (best && best.qty > 0 && best.target) {
      steps.push(`Einsatz ${spec.gold(best.cost)} für ${best.qty.toLocaleString('de-DE')} Stück bis ${spec.gold(best.buy)}`);
      steps.push(`Erlös nach 5 % Gebühr ${spec.gold(best.target * 0.95 * best.qty)} zu ${spec.gold(best.target)}`);
      if (best.fees) steps.push(`Einstellgebühr für ${best.relists} weiteres Einstellen ${spec.gold(best.fees)}`);
      steps.push(`Gewinn ${spec.gold(best.gain)}`);
    }
    const fc = ctx.forecasts.get(key) || null;
    const wk = forecast.weekGrid(db, mid, key, now);
    const fests = this.fests().filter((f) => f.s > now - 7 * 86400 && f.s < now + 42 * 86400);
    return { key, name: i.name, quality: i.quality, item: i.item_id, t: ctx.t, offers, sales, checks, best, steps, proof: pr, sales14: st, band: b ? { low: chances.low(b), high: chances.high(b), lang: b.lang } : null,
      hold: ctx.hold(key), life: proof.lifeOf(db, mid, key, today), forecast: fc, week: wk, fests, override: ctx.over(key) };
  },

  // Marktuebersicht (8): Fallend, Steigend, Lohnend, groesste Aenderungen, Stufenbereiche, Feste, Prognosen
  marketOverview(marketKey) {
    const mid = this.marketId(marketKey);
    if (mid == null) return null;
    const ctx = this.chanceCtx(mid);
    const lt = this.bands(mid);
    const last = this.db.prepare("SELECT id, t FROM snapshots WHERE market_id = ? AND source = 'scan' ORDER BY t DESC LIMIT 1").get(mid);
    const mv = chances.moves(this.db, mid, lt.items, lt.days, last, lt.day);
    const biggest = [...mv.up, ...mv.down].sort((a, b) => Math.abs(b.change) - Math.abs(a.change)).slice(0, 50);
    const name = (k) => { const i = ctx.info(k); return { key: k, name: i.name, quality: i.quality, item: i.item_id }; };
    const index = [...ctx.index.values()].sort((a, b) => a.band - b.band || a.equip - b.equip).map((x) => ({ ...x, keys: undefined, rank: x.rank.map((r) => ({ ...r, ...name(r.key) })) }));
    const fs_ = forecast.festSignals(this.db, mid, this.fests(), this.now());
    const fests = this.fests().filter((f) => f.s > this.now() - 3 * 86400).sort((a, b) => a.s - b.s).map((f) => ({ ...f,
      items: [...fs_].filter(([, l]) => l.some((x) => x.name === f.n && x.start === f.s)).map(([k, l]) => ({ ...name(k), change: l.find((x) => x.name === f.n).change }))
        .sort((a, b) => Math.abs(b.change) - Math.abs(a.change)).slice(0, 30) }));
    const fc = [...ctx.forecasts.values()].filter((f) => forecast.SURE.indexOf(f.sure) >= forecast.SURE.indexOf(ctx.rules.f.minSure))
      .map((f) => ({ ...f, ...name(f.key) })).sort((a, b) => forecast.SURE.indexOf(b.sure) - forecast.SURE.indexOf(a.sure) || b.expect - a.expect).slice(0, 300);
    return { market: marketKey, t: ctx.t, up: mv.up, down: mv.down, worth: chances.worth(this.db, lt.items, ctx.stats), biggest, index, fests, forecasts: fc,
      signals: [...ctx.signalRates].map(([id, r]) => ({ id, label: forecast.SIGNALS[id].label, ...r, on: ctx.rules.f.signals[id] })), levelsKnown: this.db.prepare('SELECT COUNT(*) AS n FROM item_level').get().n };
  },

  // Erfolgskontrolle (8): Trefferquote je Art und Signal, eigene Kaeufe aus Ledger
  successView(marketKey) {
    const mid = this.marketId(marketKey);
    if (mid == null) return null;
    const now = this.now();
    const rates = book.rates(this.db, mid, now);
    const sig = forecast.signalRates(this.db, mid, now);
    const buys = this.ledgerTrades(mid);
    return { market: marketKey, rates, signals: [...sig].map(([id, r]) => ({ id, label: forecast.SIGNALS[id].label, ...r })), buys };
  },

  // Kaeufe im Auktionshaus aus Peon_Ledger.lua (alle Kontoordner), verknuepft mit Vorschlaegen des Managers
  ledgerTrades(mid) {
    const out = [];
    const since = this.now() - 30 * 86400;
    const sugg = this.db.prepare('SELECT kind, t, target FROM chance_log WHERE market_id = ? AND item_key = ? AND shown = 1 AND t <= ? AND t >= ? ORDER BY t DESC LIMIT 1');
    const name = this.db.prepare('SELECT name, quality FROM items WHERE key = ?');
    for (const f of broker.findFiles(this.settings.wowDir)) {
      const file = path.join(path.dirname(f.file), 'Peon_Ledger.lua');
      let realms;
      try { realms = (parseLua(fs.readFileSync(file)).PeonLedgerDB || {}).realms || {}; } catch { continue; }
      for (const r of Object.values(realms)) {
        const moves = Array.isArray(r && r.moves) ? r.moves : Object.values((r && r.moves) || {});
        const sold = moves.filter((m) => m && m.k === 'ahsold' && m.id);
        for (const m of moves) {
          if (!m || m.k !== 'ahbuy' || !m.id || !(m.n > 0) || !(m.t >= since)) continue;
          const key = String(m.id);
          const s = sugg.get(mid, key, m.t, m.t - 3 * 86400);
          const later = sold.filter((x) => String(x.id) === key && x.t > m.t);
          const income = later.reduce((a, x) => a + (Number(x.m) || 0), 0);
          const nm = name.get(key) || {};
          out.push({ key, name: nm.name || null, quality: nm.quality ?? null, t: m.t, qty: m.n, cost: -(Number(m.m) || 0), income: income || null,
            soldQty: later.reduce((a, x) => a + Math.abs(Number(x.n) || 0), 0), hours: later.length ? (later[0].t - m.t) / 3600 : null, kind: s ? s.kind : null });
        }
      }
    }
    return out.sort((a, b) => b.t - a.t).slice(0, 300);
  },

  // ---------- Rueckmeldungen (7.1) ----------
  rateChance(f) {
    const mid = f.market ? this.marketId(f.market) : null;
    let logId = null;
    if (mid != null && f.kind) {
      const r = this.db.prepare('SELECT id FROM chance_log WHERE market_id = ? AND item_key = ? AND kind = ? ORDER BY t DESC LIMIT 1').get(mid, String(f.key), f.kind);
      logId = r ? r.id : null;
    }
    const id = book.rate(this.db, this.now(), { ...f, logId });
    log(this.db, 'chancen', true, `Rückmeldung zu ${f.name || f.key}`);
    return id;
  },
  chanceRatings() { return { list: book.ratings(this.db), reasons: book.REASONS }; },
  deleteChanceRating(id) { return book.deleteRate(this.db, id); },
  exportChanceRatings(file) {
    const rates = {};
    for (const m of this.db.prepare('SELECT id, key FROM markets').all()) rates[/Alliance|Allianz/i.test(m.key) ? 'Allianz' : /Horde/i.test(m.key) ? 'Horde' : 'Neutral'] = book.rates(this.db, m.id, this.now());
    fs.writeFileSync(file, book.exportText(this.db, this.chanceRules(), rates, this.now()), 'utf8');
    return { file };
  },
  chanceProbe(marketKey, kind, next) {
    const mid = this.marketId(marketKey);
    if (mid == null) return null;
    const cur = this.chanceRules();
    const nx = spec.rulesOf({ ...cur, [kind]: { ...cur[kind], ...(next || {}) } });
    return book.probe(this.db, mid, this.now(), kind, cur, nx);
  },

  // ---------- Feste (D4, aus Broker) und eigene Ereignisse ----------
  fests() {
    const out = [...(this.meta('feste') || [])];
    for (const e of this.meta('events') || []) out.push({ ...e, own: true });
    return out;
  },
  festsFromGame(results) {
    const have = this.meta('feste') || [];
    const seen = new Set(have.map((f) => `${f.n}|${f.s}`));
    let added = 0;
    for (const r of results) {
      const list = r.feste && Array.isArray(r.feste.list) ? r.feste.list : r.feste && typeof r.feste.list === 'object' ? Object.values(r.feste.list) : [];
      for (const f of list) {
        if (!f || typeof f.n !== 'string' || !(Number(f.s) > 0)) continue;
        const k = `${f.n}|${Number(f.s)}`;
        if (seen.has(k)) continue;
        seen.add(k);
        have.push({ n: f.n, s: Number(f.s), e: Number(f.e) || Number(f.s) });
        added++;
      }
    }
    if (added) {
      const keep = have.filter((f) => f.s > this.now() - 400 * 86400).sort((a, b) => a.s - b.s);
      this.meta('feste', keep);
      log(this.db, 'chancen', true, `${added} ${added === 1 ? 'Fest' : 'Feste'} aus dem Spiel`);
    }
    return added;
  },
  setEvents(list) {
    const out = (Array.isArray(list) ? list : []).filter((e) => e && String(e.n || '').trim() && Number(e.s) > 0)
      .map((e) => ({ n: String(e.n).trim().slice(0, 60), s: Math.floor(Number(e.s)), e: Math.floor(Number(e.e) || Number(e.s)) }));
    this.meta('events', out);
    this.chanceCache = null;
    return out;
  },
  ratingsFromGame(results) {
    let n = 0;
    for (const r of results) if (r.ratings) n += book.importBroker(this.db, r.ratings);
    if (n) log(this.db, 'chancen', true, `${n} Einschätzungen aus Broker`);
    return n;
  },
  rulesFromGame(results) {
    const r = results.filter((x) => x.rules).sort((a, b) => (b.mt || 0) - (a.mt || 0))[0];
    if (!r) return false;
    const next = { ...BROKER_RULES, ...r.rules };
    if (JSON.stringify(next) === JSON.stringify(this.meta('brokerRules'))) return false;
    this.meta('brokerRules', next);
    return true;
  },

  // ---------- D3: benoetigte Stufe und Gegenstandsstufe aller Gegenstaende ----------
  async fetchLevels(client, max = LEVEL_BATCH) {
    if (!client || this.levelBusy) return 0;
    this.levelBusy = true;
    let n = 0;
    try {
      const ids = this.db.prepare(`SELECT DISTINCT i.item_id AS id FROM items i LEFT JOIN item_level l ON l.item_id = i.item_id
          WHERE l.item_id IS NULL OR l.t < ? LIMIT ?`).all(this.now() - LEVEL_FRESH, max).map((x) => x.id);
      const put = this.db.prepare(`INSERT INTO item_level(item_id, req, ilvl, equip, t) VALUES (?, ?, ?, ?, ?)
          ON CONFLICT(item_id) DO UPDATE SET req = excluded.req, ilvl = excluded.ilvl, equip = excluded.equip, t = excluded.t`);
      for (const id of ids) {
        if (this.closed) break;
        const r = await fetchItem(client, id);
        if (failed(r.status) && r.status !== 404) break;   // Grenze oder keine Verbindung: spaeter weiter
        const lv = levelOf(r.json);
        put.run(id, lv.req, lv.ilvl, lv.equip, this.now());
        n++;
      }
    } finally { this.levelBusy = false; }
    if (n) this.chanceCache = null;
    return n;
  },
};

// Stufen aus der Antwort von /data/wow/item/{id}
function levelOf(json) {
  const p = (json && json.preview_item) || {};
  const req = p.requirements && p.requirements.level ? Number(p.requirements.level.value) || null : json && Number(json.required_level) > 0 ? Number(json.required_level) : null;
  const ilvl = json && Number(json.level) > 0 ? Number(json.level) : null;
  const t = (p.inventory_type && p.inventory_type.type) || (json && json.inventory_type && json.inventory_type.type) || 'NON_EQUIP';
  return { req: req || (json ? 0 : null), ilvl, equip: t !== 'NON_EQUIP' ? 1 : 0 };
}

function install(proto) { Object.assign(proto, methods); }

module.exports = { install, levelOf, BROKER_RULES, MAX_FOR_BROKER, zlib, parseRows };
