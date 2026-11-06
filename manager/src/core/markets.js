'use strict';
// Peon Manager - Maerkte. Forever hat keine Realms: Je Region gibt es ein Auktionshaus je Regelsatz und Fraktion
// (docs/konzepte/manager/Peon_Blizzard_API.md). Das Spiel meldet trotzdem einen internen Namen wie "CAMWOW EU4 Realm 3 PvE".
// Der Schluessel "<interner Name> / <Fraktion>" bleibt, weil Broker damit seine Werte findet. Angezeigt wird nur "PvE Allianz".

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
const RULESET_LABEL = { 1: 'PvP', 2: 'PvE', 3: 'Rollenspiel', 15: 'Rollenspiel PvP' };
const REGION_OF_ID = { 3: 'eu', 1: 'us', 4: 'tw' };

const groupOf = (house) => Object.keys(GROUPS).find((g) => GROUPS[g].houses.includes(house)) || null;

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

// "<Realm> / <Fraktion>" zerlegen. placeholder: Haus, das noch keinem Markt des Spiels zugeordnet ist
function parseKey(key) {
  const k = /^(.*) \/ ([^/]*)$/.exec(String(key || ''));
  if (!k) return { realm: String(key || ''), faction: null, house: null };
  const h = /^Blizzard \w+ Haus (\d+)$/.exec(k[1]);
  return { realm: k[1], faction: k[2], house: h ? Number(h[1]) : null };
}

// Name fuer die Anzeige: "PvE Allianz"
function marketLabel(key) {
  const { realm, faction, house } = parseKey(key);
  if (!faction) return String(key || '');
  const f = FACTION_LABEL[faction] || faction;
  if (house != null) {
    const g = groupOf(house);
    const name = g && GROUPS[g].ruleset ? RULESET_LABEL[GROUPS[g].ruleset] : g && GROUPS[g].name;
    return name ? `${name} ${f}` : `Haus ${house} ${f}`;
  }
  return `${RULESET_LABEL[rulesetOf(realm)]} ${f}`;
}

// Derselbe Markt unter einem anderen internen Namen? Gleiche Region, gleicher Regelsatz, gleiche Fraktion.
// Haeuser ohne Zuordnung zaehlen nicht, ihr Regelsatz ist nicht bekannt.
function sameMarket(a, regionA, b, regionB) {
  const x = parseKey(a), y = parseKey(b);
  if (!x.faction || !y.faction || x.house != null || y.house != null) return false;
  return x.faction === y.faction && rulesetOf(x.realm) === rulesetOf(y.realm)
    && regionOfRealm(x.realm, regionA) === regionOfRealm(y.realm, regionB);
}

module.exports = { GROUPS, FACTIONS, FACTION_LABEL, RULESET_LABEL, REGION_OF_ID, groupOf, regionOfRealm, rulesetOf, parseKey, marketLabel, sameMarket };
