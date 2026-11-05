'use strict';
// Peon Manager - Gegenstandsdaten der Blizzard-API fuer den Tooltip (Modul Peon Broker Client).
// Geprueftes: docs/konzepte/manager/Peon_Blizzard_API.md. preview_item liefert fertige deutsche Zeilen wie im Spiel.
// static-forever kennt viele Gegenstaende nicht (404), dann gelten die Classic-Daten, gekennzeichnet mit source = 'classic'.
// Neue Gegenstaende bringt der Einleser mit, alle anderen werden erst geholt, wenn jemand sie ansieht.

const { failed } = require('./blizzard');

const QUALITY = { POOR: 0, COMMON: 1, UNCOMMON: 2, RARE: 3, EPIC: 4, LEGENDARY: 5, ARTIFACT: 6, HEIRLOOM: 7 };
const FRESH = 30 * 86400;        // so lange gilt ein Eintrag, danach wird er beim Ansehen erneuert
const NONE_RETRY = 7 * 86400;    // so lange nicht erneut nach Gegenstaenden fragen, die Blizzard nicht kennt

const isGreen = (c) => !!c && c.g > c.r && c.g > c.b;

// Antwort von /data/wow/item/{id} -> Tooltip: Name, Qualitaet, Haendlerpreis, Zeilen { l, r, c } (links, rechts, Art)
function toTip(json, source) {
  const p = (json && json.preview_item) || {};
  const lines = [];
  const add = (l, c, r) => {
    if (!l && !r) return;
    const line = { l: l || '' };
    if (r) line.r = r;
    if (c) line.c = c;
    lines.push(line);
  };
  add(p.level && p.level.display_string, 'level');
  add(p.binding && p.binding.name);
  add(p.unique_equipped);
  const slot = p.inventory_type && p.inventory_type.type !== 'NON_EQUIP' ? p.inventory_type.name : null;
  const sub = !p.is_subclass_hidden && p.item_subclass ? p.item_subclass.name : null;
  if (slot || sub) add(slot || sub, null, slot && sub !== slot ? sub : null);
  if (p.weapon) {
    add(p.weapon.damage && p.weapon.damage.display_string, null, p.weapon.attack_speed && p.weapon.attack_speed.display_string);
    add(p.weapon.dps && p.weapon.dps.display_string);
  }
  add(p.armor && p.armor.display && p.armor.display.display_string);
  add(p.container_slots && p.container_slots.display_string);
  for (const s of Array.isArray(p.stats) ? p.stats : []) {
    const d = s && s.display;
    if (d) add(d.display_string, isGreen(d.color) ? 'good' : null);
  }
  for (const s of Array.isArray(p.spells) ? p.spells : []) add(s && s.description, 'good');
  add(p.charges && p.charges.display_string);
  if (p.requirements) {
    for (const r of Object.values(p.requirements)) add(r && r.display_string);
  }
  add(p.durability && p.durability.display_string);
  if (p.set) {
    add(p.set.display_string, 'set');
    for (const e of Array.isArray(p.set.effects) ? p.set.effects : []) add(e && e.display_string, 'muted');
  }
  if (p.recipe && p.recipe.reagents_display_string) add(`Benötigt: ${p.recipe.reagents_display_string}`);
  add(p.description, 'desc');
  add(p.crafting_reagent, 'reagent');
  const quality = (p.quality || json.quality || {}).type;
  const sell = p.sell_price && p.sell_price.value != null ? p.sell_price.value : json.sell_price;
  return { name: json.name || p.name || null, quality: QUALITY[quality] ?? null, sell: sell > 0 ? sell : null, source, lines };
}

// Eine Abfrage, bei 404 die Classic-Daten. waitMs: Pause je Abfrage, damit Blizzards Grenze haelt
async function fetchItem(client, id, wait = async () => {}) {
  let r = await client.get(`/data/wow/item/${id}`, { kind: 'static' });
  await wait();
  let source = 'forever';
  if (r.status === 404) {
    r = await client.get(`/data/wow/item/${id}`, { namespace: `static-classic1x-${client.region}` });
    await wait();
    source = 'classic';
  }
  return { status: r.status, json: r.json, source };
}

class ItemInfo {
  constructor(db, now) {
    this.db = db;
    this.now = now;
    this.running = new Map();   // laufende Abfragen je Gegenstand, damit Hin- und Herfahren nur einmal fragt
  }

  // Antwort speichern. Ergebnis: Tooltip, null wenn Blizzard ihn nicht kennt, undefined wenn es keine Antwort gab
  save(id, res) {
    if (failed(res.status)) return undefined;
    const tip = res.json && res.json.name ? toTip(res.json, res.source) : null;
    if (!tip && res.status !== 404) return undefined;
    this.db.prepare(`INSERT INTO item_info(item_id, source, tip, t) VALUES (?, ?, ?, ?)
        ON CONFLICT(item_id) DO UPDATE SET source = excluded.source, tip = excluded.tip, t = excluded.t`)
      .run(id, tip ? res.source : 'none', tip ? JSON.stringify(tip) : null, this.now());
    return tip;
  }

  // Fuer die Oberflaeche. state: ok, none (Blizzard kennt ihn nicht), no-access (kein Zugang), unreachable (keine Antwort)
  async get(id, client) {
    if (!Number.isInteger(id) || id <= 0) return { state: 'none', tip: null };
    const row = this.db.prepare('SELECT source, tip, t FROM item_info WHERE item_id = ?').get(id);
    const old = row && row.tip ? JSON.parse(row.tip) : null;
    const known = old ? { state: 'ok', tip: old } : null;
    if (row && this.now() - row.t < (old ? FRESH : NONE_RETRY)) return known || { state: 'none', tip: null };
    if (!client) return known || { state: row ? 'none' : 'no-access', tip: null };
    if (!this.running.has(id)) {
      this.running.set(id, (async () => {
        try { return this.save(id, await fetchItem(client, id)); } finally { this.running.delete(id); }
      })());
    }
    const tip = await this.running.get(id);
    if (tip) return { state: 'ok', tip };
    if (tip === null) return { state: 'none', tip: null };
    return known || { state: 'unreachable', tip: null };
  }
}

module.exports = { ItemInfo, toTip, fetchItem, QUALITY, FRESH, NONE_RETRY };
