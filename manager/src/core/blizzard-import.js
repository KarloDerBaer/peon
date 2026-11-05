'use strict';
// Peon Manager - Einleser "Blizzard-API" (Modul Peon Broker Client). Geprueftes: docs/konzepte/manager/Peon_Blizzard_API.md.
// Der Nutzer waehlt Auktionshaeuser unter Quellen. Je Haus entsteht pro Stand eine Momentaufnahme im Format der Scans
// (snapshots.source = 'scan', art = 'api'), damit Verlauf, Chancen und die Werte fuer Broker sie ohne Sonderweg nutzen.
// Der Absatz vergleicht API-Staende nur untereinander (sales.js), weil nur sie Angebotsnummern haben.

const fs = require('node:fs');
const path = require('node:path');
const zlib = require('node:zlib');
const { listOf, offersOf, auctionPath, failed } = require('./blizzard');
const { parseLua } = require('./lua');
const { parseRows } = require('./stats');
const { tx, log } = require('./db');
const game = require('./game');
const { fetchItem, QUALITY } = require('./item-info');

const HOUR = 3600;
const GRACE = 120;          // so lange nach der vollen Stunde warten, Blizzard braucht etwas
const RETRY = 300;          // fehlt der neue Stand noch oder gab es einen Fehler: so oft nachfragen
const INDEX_MAX_AGE = 7 * 86400;
const STATIC_MAX = 1000;    // Spieldaten je Lauf, der Rest kommt mit dem naechsten Stand
const STATIC_WORKERS = 4, STATIC_PAUSE_MS = 80;   // zusammen hoechstens etwa 50 Abfragen je Sekunde
const STATIC_ROUNDS = 3, STATIC_RETRY_MS = 2000;
const MATCH_MIN = 0.5, MATCH_LEAD = 1.5;   // Scan-Vergleich: so viel muss gleich sein und so klar vor dem zweiten Haus liegen

const STEP = { SHORT: 1, MEDIUM: 2, LONG: 3, VERY_LONG: 4 };
const REGION_ID = { eu: 3, us: 1, tw: 4 };
const REGION_OF_ID = { 3: 'eu', 1: 'us', 4: 'tw' };

// Gruppen von je einem Allianz-, Horde- und Neutral-Haus. Nur Gruppe 2 ist belegt (Scan und Testangebot, 05.11.2026).
const GROUPS = {
  1: { houses: [110, 113, 116], name: 'PvP', sure: false, ruleset: 1 },
  2: { houses: [111, 114, 117], name: 'Normal (PvE)', sure: true, ruleset: 2 },
  3: { houses: [112, 115, 118], name: 'Leer', empty: true },
  4: { houses: [119, 120, 121], name: 'Rollenspiel' },
  5: { houses: [123, 124, 125], name: 'Rollenspiel' },
};
const FACTIONS = ['Alliance', 'Horde', 'Neutral'];
const FACTION_LABEL = { Alliance: 'Allianz', Horde: 'Horde', Neutral: 'Neutral' };
const groupOf = (house) => Object.keys(GROUPS).find((g) => GROUPS[g].houses.includes(house)) || null;
const factionOfHouse = (house, name) => {
  if (/allianz|alliance/i.test(name || '')) return 'Alliance';
  if (/horde/i.test(name || '')) return 'Horde';
  if (name) return 'Neutral';
  const g = groupOf(house);
  return g ? FACTIONS[GROUPS[g].houses.indexOf(house)] : 'Neutral';
};
const FALLBACK_HOUSES = Object.values(GROUPS).flatMap((g) => g.houses).sort((a, b) => a - b).map((id) => ({ id, name: null }));

// Bonus-Nummer -> Zusatz im deutschen Client, aus Scans ermittelt (05.11.2026). Gesehene Paare aus eigenen Scans haben Vorrang.
const BONUS_SUFFIX = {
  12688: 'der Intelligenz', 12689: 'der Willenskraft', 12690: 'der Ausdauer', 12691: 'der Eule',
  12718: 'des Adlers', 12719: 'des Wals', 12720: 'der Eule', 12721: 'des Affen', 12722: 'des Bären', 12723: 'des Gorillas',
  12724: 'des Falken', 12725: 'des Ebers', 12726: 'des Wolfs', 12727: 'des Tigers', 12728: 'der Beweglichkeit', 12729: 'der Intelligenz',
  12730: 'der Willenskraft', 12731: 'der Ausdauer', 12732: 'der Stärke', 12733: 'der Macht', 12734: 'der Magie', 12735: 'der Heilung',
  12736: 'der Verteidigung', 12740: 'des Arkanschutzes', 12741: 'des Feuerschutzes', 12742: 'des Frostschutzes', 12743: 'des Naturschutzes',
  12744: 'des Schattenschutzes', 12745: 'des Zauberers', 12746: 'des Ältesten', 12747: 'des Kanalisierers', 12748: 'des Heilers',
  12749: 'des Propheten', 12750: 'des Hierophanten', 12752: 'der Bestie', 12753: 'des Champions', 12754: 'des Verteidigers',
  12756: 'des arkanen Zorns', 12757: 'des feurigen Zorns', 12758: 'des frostigen Zorns', 12759: 'des heiligen Zorns', 12760: 'des Naturzorns',
  12761: 'des Schattenzorns', 12917: 'der Magie', 12918: 'der Magie', 12919: 'der Heilung', 12920: 'der Heilung',
};

// Wann ist das Haus wieder dran? Erst eine Stunde nach dem letzten Stand, danach alle 5 Minuten, bis der neue da ist.
function dueAt(st) {
  if (!st || !st.checked) return 0;
  if (st.error || !st.t) return st.checked + RETRY;
  const expected = st.t + HOUR + GRACE;
  return st.checked < expected ? expected : st.checked + RETRY;
}

function regionOfRealm(realm, regionId) {
  const m = /\b(EU|US|NA|TW)\d*\b/i.exec(realm || '');
  if (m) return m[1].toUpperCase() === 'NA' ? 'us' : m[1].toLowerCase();
  return REGION_OF_ID[regionId] || null;
}

// Regelsatz aus dem Realm-Namen, zum Beispiel "CAMWOW EU4 Realm 3 PvE". Nummern wie unter /data/wow/ruleset/index.
function rulesetOf(realm) {
  const s = String(realm || '').toLowerCase();
  const rp = /\brp\b|rppvp|rp-pvp|rollenspiel|roleplay/.test(s), pvp = /pvp/.test(s);
  if (rp && pvp) return 15;
  if (rp) return 3;
  return pvp ? 1 : 2;
}

// Haus zu Regelsatz und Fraktion, wenn es dafuer eine Annahme gibt. Bei Rollenspiel hilft nur der Scan-Vergleich.
function houseForRuleset(ruleset, faction) {
  const k = Object.keys(GROUPS).find((g) => GROUPS[g].ruleset === ruleset);
  if (!k) return null;
  const i = FACTIONS.indexOf(faction);
  return i < 0 ? null : { house: GROUPS[k].houses[i], sure: !!GROUPS[k].sure };
}

// Wie viel eines Scans steht auch im Haus? Anteil der Angebote mit gleichem Gegenstand, gleicher Menge und gleichem Preis.
function matchScan(scanRows, offers) {
  const api = new Map();
  for (const o of offers) {
    const price = o.unit_price != null ? o.unit_price * o.quantity : o.buyout;
    if (price == null) continue;
    const k = `${o.item.id}|${o.quantity}|${price}`;
    api.set(k, (api.get(k) || 0) + 1);
  }
  let total = 0, same = 0;
  for (const r of scanRows) {
    if (!(r.buyout > 0)) continue;
    total += r.n;
    const k = `${r.item}|${r.qty}|${r.buyout}`;
    const have = api.get(k) || 0;
    const hit = Math.min(have, r.n);
    if (hit) { same += hit; api.set(k, have - hit); }
  }
  return total ? same / total : 0;
}

// Gegenstaende mit Zusatz brauchen ihren vollen Namen, weil Broker sie danach unterscheidet
function variantName(exact, itemId, bonus, base) {
  if (exact) return exact;
  const suffix = BONUS_SUFFIX[String(bonus).split(',')[0]];
  if (base && suffix) return `${base} ${suffix}`;
  return `${base || itemId} #${bonus}`;
}

// Angebote -> Zeilen im Format der Scans: item;bonus;name;quantity;buyout;unit_price;bid;time_left;id;n
function toRows(single, mass, nameOf) {
  const lines = [];
  for (const o of single) {
    const bonus = (o.item.bonus_lists || []).join(',');
    lines.push([o.item.id, bonus, bonus ? nameOf(o.item.id, bonus) : '', o.quantity, o.buyout ?? '', '', o.bid ?? '', STEP[o.time_left] || '', o.id, 1].join(';'));
  }
  for (const o of mass) lines.push([o.item.id, '', '', o.quantity, o.unit_price * o.quantity, o.unit_price, '', STEP[o.time_left] || '', o.id, 1].join(';'));
  return lines;
}

// Figuren aus den Addons: Peon_Ledger.lua kennt alle Charaktere mit Realm und Fraktion
function ledgerMarkets(wowDir) {
  const out = [];
  const base = path.join(wowDir, 'WTF', 'Account');
  let accounts = [];
  try { accounts = fs.readdirSync(base); } catch { return out; }
  for (const a of accounts) {
    const f = path.join(base, a, 'SavedVariables', 'Peon_Ledger.lua');
    if (!fs.existsSync(f)) continue;
    try {
      const realms = (parseLua(fs.readFileSync(f)).PeonLedgerDB || {}).realms || {};
      for (const [realm, r] of Object.entries(realms)) {
        for (const c of Object.values((r && r.chars) || {})) if (c && c.faction) out.push({ realm, faction: c.faction });
      }
    } catch { /* Datei kaputt: dann eben keine Figuren von hier */ }
  }
  return out;
}

class BlizzardImport {
  constructor(broker) {
    this.broker = broker;
    this.busy = false;
  }

  get db() { return this.broker.db; }
  get selection() { return this.broker.settings.blizzard.houses; }
  now() { return this.broker.now(); }
  state() { return this.broker.meta('blizzardState') || {}; }

  // Liste der Haeuser einer Region, eine Woche gemerkt. Ohne Netz gilt die bekannte Liste (EU und US).
  async index(client) {
    const c = this.broker.meta('blizzardIndex');
    if (c && c.region === client.region && this.now() - c.t < INDEX_MAX_AGE) return c;
    const rs = await client.get('/data/wow/ruleset/index');
    const rulesets = listOf(rs.json, 'rulesets').filter((x) => x && x.id != null);
    if (rulesets.length) {
      const idx = await client.get(`/data/wow/ruleset/${rulesets[0].id}/auctions/index`);
      const houses = listOf(idx.json, 'auctions').filter((x) => x && x.id != null);
      if (houses.length) return this.broker.meta('blizzardIndex', { region: client.region, t: this.now(), ruleset: rulesets[0].id, houses: houses.map((h) => ({ id: h.id, name: h.name })) });
    }
    if (c && c.region === client.region) return c;
    if (client.region === 'eu' || client.region === 'us') return { region: client.region, t: 0, ruleset: 2, houses: FALLBACK_HOUSES };
    return null;
  }

  // Maerkte, die der Manager aus Scans, Broker und Ledger kennt, in der Region des Zugangs
  known(region) {
    const out = new Map();
    const add = (realm, faction, regionId) => {
      if (!realm || !FACTIONS.includes(faction) || regionOfRealm(realm, regionId) !== region) return;
      const key = `${realm} / ${faction}`;
      if (!out.has(key)) out.set(key, { key, realm, faction });
    };
    for (const m of this.db.prepare('SELECT key, region FROM markets').all()) {
      const k = /^(.*) \/ (Alliance|Horde)$/.exec(m.key);
      if (k && !m.key.startsWith('Blizzard ')) add(k[1], k[2], m.region);
    }
    for (const c of ledgerMarkets(this.broker.settings.wowDir)) add(c.realm, c.faction);
    return [...out.values()];
  }

  // Name des Markts fuer ein Haus: passt ein bekannter Markt, sonst ein Platzhalter, bis ein Vorschlag den echten kennt
  marketFor(region, house, faction) {
    const g = groupOf(house);
    const hit = this.known(region).find((m) => {
      const h = houseForRuleset(rulesetOf(m.realm), m.faction);
      return h && groupOf(h.house) === g;
    });
    if (hit) return `${hit.realm} / ${faction}`;
    return `Blizzard ${region.toUpperCase()} Haus ${house} / ${faction}`;
  }

  setHouse(region, house, on, name) {
    const key = `${region}-${house}`;
    const houses = { ...this.selection };
    if (on) houses[key] = houses[key] || { market: this.marketFor(region, house, factionOfHouse(house, name)), how: 'manual' };
    else delete houses[key];
    this.broker.saveSettings({ blizzard: { ...this.broker.settings.blizzard, houses } });
  }

  // Vorschlag: bekannte Maerkte auf Haeuser abbilden. Mit eigenem Scan zaehlt der Vergleich, sonst der Regelsatz.
  async suggest(client) {
    const idx = await this.index(client);
    if (!idx) throw new Error('Blizzard ist nicht erreichbar. Bitte später erneut versuchen.');
    const out = [];
    const cache = new Map();
    const offersOfHouse = async (id) => {
      if (cache.has(id)) return cache.get(id);
      const a = await client.get(auctionPath(idx.ruleset, id, false));
      const b = await client.get(auctionPath(idx.ruleset, id, true));
      const list = (failed(a.status) || failed(b.status)) ? null : [...offersOf(a.json), ...offersOf(b.json)];
      cache.set(id, list);
      return list;
    };
    const houses = { ...this.selection };
    for (const m of this.known(client.region)) {
      let pick = null;
      const scan = this.db.prepare(`SELECT s.rows FROM snapshots s JOIN markets k ON k.id = s.market_id
          WHERE k.key = ? AND s.source = 'scan' AND s.art <> 'api' AND s.rows IS NOT NULL ORDER BY s.t DESC LIMIT 1`).get(m.key);
      if (scan) {
        const rows = parseRows(zlib.inflateSync(Buffer.from(scan.rows)).toString('utf8'));
        const scores = [];
        for (const h of idx.houses.filter((x) => factionOfHouse(x.id, x.name) === m.faction)) {
          const list = await offersOfHouse(h.id);
          if (list && list.length) scores.push({ house: h.id, score: matchScan(rows, list) });
        }
        scores.sort((a, b) => b.score - a.score);
        const [a, b] = scores;
        if (a && a.score >= MATCH_MIN && (!b || a.score >= MATCH_LEAD * b.score)) pick = { house: a.house, how: 'scan', score: a.score };
      }
      if (!pick) {
        const t = houseForRuleset(rulesetOf(m.realm), m.faction);
        if (t) pick = { house: t.house, how: t.sure ? 'ruleset' : 'guess' };
      }
      if (!pick) { out.push({ market: m.key, house: null }); continue; }
      const key = `${client.region}-${pick.house}`;
      const old = houses[key];
      if (old && old.market !== m.key) this.renamePlaceholder(old.market, m);
      houses[key] = { market: m.key, how: pick.how, ...(pick.score != null ? { score: Math.round(pick.score * 1000) / 1000 } : {}) };
      out.push({ market: m.key, house: pick.house, how: pick.how, score: pick.score ?? null });
    }
    this.broker.saveSettings({ blizzard: { ...this.broker.settings.blizzard, houses } });
    log(this.db, 'blizzard', true, `Vorschlag: ${out.filter((x) => x.house).length} von ${out.length} Märkten zugeordnet`);
    return out;
  }

  // Platzhalter bekommt den echten Namen, solange es den Markt noch nicht gibt. Sonst bleiben seine Daten unter dem alten Namen.
  renamePlaceholder(oldKey, m) {
    if (!oldKey.startsWith('Blizzard ')) return;
    if (this.db.prepare('SELECT 1 FROM markets WHERE key = ?').get(m.key)) return;
    this.db.prepare('UPDATE markets SET key = ?, realm = ?, faction = ? WHERE key = ?').run(m.key, m.realm, m.faction, oldKey);
  }

  // Einmalig: Paare aus Gegenstand und Bonus aus Scans lernen, die vor Schema 4 eingelesen wurden
  learnOldScans() {
    if (this.broker.meta('variantsLearned')) return;
    const ins = this.db.prepare('INSERT OR REPLACE INTO variant_names(item_id, bonus, name) VALUES (?, ?, ?)');
    for (const s of this.db.prepare("SELECT rows FROM snapshots WHERE source IN ('scan', 'live') AND art <> 'api' AND rows IS NOT NULL").all()) {
      for (const r of parseRows(zlib.inflateSync(Buffer.from(s.rows)).toString('utf8'))) if (r.bonus && r.name) ins.run(r.item, r.bonus, r.name);
    }
    this.broker.meta('variantsLearned', true);
  }

  // Spieldaten fuer unbekannte Gegenstaende. Gegenstaende mit Zusatz zuerst, weil ihr Schluessel den Namen braucht.
  async fetchItems(client, ids, needFirst) {
    const has = this.db.prepare('SELECT name FROM items WHERE key = ?');
    const missing = [...ids].filter((id) => { const r = has.get(String(id)); return !r || !r.name; })
      .sort((a, b) => Number(needFirst.has(b)) - Number(needFirst.has(a))).slice(0, STATIC_MAX);
    const up = this.db.prepare(`INSERT INTO items(key, item_id, variant, name, quality, vendor, commodity, updated) VALUES (?, ?, NULL, ?, ?, ?, NULL, ?)
        ON CONFLICT(key) DO UPDATE SET name = COALESCE(items.name, excluded.name), quality = COALESCE(items.quality, excluded.quality),
          vendor = COALESCE(items.vendor, excluded.vendor), updated = excluded.updated`);
    // Blizzard erlaubt 100 Abfragen je Sekunde und antwortet darueber mit 429. Abgelehnte kommen in die naechste Runde.
    let queue = missing, unanswered = [];
    for (let round = 0; round < STATIC_ROUNDS && queue.length; round++) {
      if (round) await this.wait(STATIC_RETRY_MS);
      unanswered = [];
      let next = 0;
      const list = queue;
      const work = async () => {
        while (next < list.length) {
          const id = list[next++];
          // static-forever kennt viele Gegenstaende nicht (404, geprueft 05.11.2026), die Classic-Daten schon
          const r = await fetchItem(client, id, () => this.wait(STATIC_PAUSE_MS));
          if (failed(r.status)) { unanswered.push(id); continue; }
          if (r.json && r.json.name) up.run(String(id), id, r.json.name, QUALITY[r.json.quality && r.json.quality.type] ?? null, r.json.sell_price ?? null, this.now());
          this.broker.info.save(id, r);   // gleich fuer den Tooltip behalten, das spart spaeter eine Abfrage
        }
      };
      await Promise.all(Array.from({ length: STATIC_WORKERS }, work));
      queue = unanswered;
    }
    return { asked: missing.length, unanswered };
  }

  wait(ms) { return new Promise((r) => setTimeout(r, ms)); }

  // Ein Haus: nur eine Rueckfrage, wenn sich nichts geaendert hat. Ergebnis true, wenn ein neuer Stand eingelesen wurde.
  async pullHouse(client, idx, key, sel, st) {
    const house = Number(key.split('-')[1]);
    const now = this.now();
    st.checked = now;
    const mass = await client.get(auctionPath(idx.ruleset, house, true), { since: st.stamp });
    if (mass.status === 304 || (mass.status === 200 && st.stamp && mass.lastModified === st.stamp)) { st.error = null; return false; }
    if (mass.status !== 200) { st.error = { t: now, status: mass.status }; return false; }
    const single = await client.get(auctionPath(idx.ruleset, house, false));
    if (single.status !== 200) { st.error = { t: now, status: single.status }; return false; }
    const a = offersOf(single.json), b = offersOf(mass.json);
    const t = Math.floor(Date.parse(mass.lastModified || single.lastModified) / 1000) || now;

    this.learnOldScans();
    const ids = new Set([...a, ...b].map((o) => o.item.id));
    const variants = new Set(a.filter((o) => o.item.bonus_lists && o.item.bonus_lists.length).map((o) => o.item.id));
    const items = await this.fetchItems(client, ids, variants);
    // Ohne Grundnamen bekaeme eine Variante einen Schluessel, der nie zu den Scans passt: lieber den Stand spaeter einlesen.
    // Antwortet Blizzard fuer einen Gegenstand endgueltig nicht (404), bleibt es beim Ersatznamen.
    const open = items.unanswered.filter((id) => variants.has(id));
    if (open.length) { st.error = { t: now, status: 429, text: `Spieldaten für ${open.length} Gegenstände fehlen noch` }; return false; }

    const exact = this.db.prepare('SELECT name FROM variant_names WHERE item_id = ? AND bonus = ?');
    const base = this.db.prepare('SELECT name, quality, vendor FROM items WHERE key = ?');
    const nameOf = (id, bonus) => {
      const e = exact.get(id, bonus), bn = base.get(String(id));
      return variantName(e && e.name, id, bonus, bn && bn.name);
    };
    const rows = toRows(a, b, nameOf);
    const massIds = new Set(b.map((o) => o.item.id));
    const names = {};
    for (const id of ids) {
      const r = base.get(String(id));
      names[id] = `${(r && r.name) || ''}|${(r && r.quality) ?? ''}|${(r && r.vendor) ?? ''}|${massIds.has(id) ? 1 : 0}`;
    }
    const faction = factionOfHouse(house, (idx.houses.find((h) => h.id === house) || {}).name);
    const realmPart = sel.market.replace(/ \/ [^/]*$/, '');
    const entry = { id: `api-${client.region}-${house}-${t}`, kind: 'scan', art: 'api', market: sel.market, realm: realmPart, faction, region: REGION_ID[client.region],
      t, total: rows.length, offers: rows.length, lines: rows.length, partial: false, names, rows: rows.join('\n') };
    const done = tx(this.db, () => game.importEntry(this.db, entry, null));
    st.stamp = mass.lastModified || single.lastModified;
    st.t = t;
    st.offers = rows.length;
    st.error = null;
    if (done) log(this.db, 'blizzard', true, `Haus ${house}: ${rows.length} Angebote, Stand ${new Date(t * 1000).toLocaleString('de-DE')}`);
    return !!done;
  }

  // Alle gewaehlten Haeuser, die dran sind. force: nicht auf die volle Stunde warten.
  async tick(client, { force = false } = {}) {
    const res = { imported: 0, checked: 0, errors: 0 };
    if (this.busy) return { ...res, busy: true };
    const keys = Object.keys(this.selection).filter((k) => k.startsWith(`${client.region}-`));
    const now = this.now();
    const state = this.state();
    const due = keys.filter((k) => force || now >= dueAt(state[k]));
    if (!due.length) return res;
    this.busy = true;
    try {
      const idx = await this.index(client);
      if (!idx) { res.errors += 1; return res; }
      for (const k of due) {
        const st = state[k] = state[k] || {};
        const hadError = !!st.error;
        res.checked += 1;
        try {
          if (await this.pullHouse(client, idx, k, this.selection[k], st)) res.imported += 1;
        } catch (e) {
          st.error = { t: now, status: null, text: e.message };
        }
        if (st.error) {
          res.errors += 1;
          if (!hadError) log(this.db, 'blizzard', false, `Haus ${k.split('-')[1]}: ${st.error.text || `Antwort ${st.error.status == null ? 'fehlt' : st.error.status}`}`);
        }
        this.broker.meta('blizzardState', state);
      }
    } finally { this.busy = false; }
    return res;
  }

  // Fuer die Ansicht Quellen
  async view(client) {
    const idx = await this.index(client);
    const state = this.state();
    const sel = this.selection;
    const count = this.db.prepare("SELECT COUNT(*) AS n FROM snapshots WHERE id LIKE ? AND art = 'api'");
    const known = this.known(client.region);
    return {
      saved: true, region: client.region, reachable: !!idx, known,
      houses: ((idx && idx.houses) || []).map((h) => {
        const key = `${client.region}-${h.id}`;
        const g = groupOf(h.id), group = g ? GROUPS[g] : null;
        const st = state[key] || {};
        return { id: h.id, faction: factionOfHouse(h.id, h.name), factionLabel: FACTION_LABEL[factionOfHouse(h.id, h.name)], group: g ? Number(g) : null,
          ruleset: group ? group.name : 'Unbekannt', sure: !!(group && group.sure), empty: !!(group && group.empty),
          selected: !!sel[key], market: sel[key] ? sel[key].market : null, how: sel[key] ? sel[key].how : null, score: sel[key] ? sel[key].score ?? null : null,
          t: st.t || null, offers: st.offers ?? null, error: st.error || null, stands: count.get(`api-${client.region}-${h.id}-%`).n };
      }),
    };
  }

  // Kurzfassung fuer die Uebersicht
  summary() {
    const state = this.state();
    const keys = Object.keys(this.selection);
    let last = null, error = null;
    for (const k of keys) {
      const st = state[k] || {};
      if (st.t && (!last || st.t > last)) last = st.t;
      if (st.error) error = st.error;
    }
    return { selected: keys.length, last, error, stands: this.db.prepare("SELECT COUNT(*) AS n FROM snapshots WHERE art = 'api'").get().n };
  }
}

module.exports = { BlizzardImport, dueAt, rulesetOf, regionOfRealm, houseForRuleset, matchScan, variantName, toRows, factionOfHouse, groupOf, GROUPS, BONUS_SUFFIX };
