'use strict';
// Peon Manager - Liste der Manager-Module (Peon_GitHub_Design.md 5.2, Variante B).
// Der Code jedes Moduls steckt im Manager, ist aber standardmaessig aus. "Installieren" schaltet es ein.
// Je Modul: Schluessel, Name, Beschreibung, noetige Addons, Kanaele der Peon_Bridge, Ansichten, Datenbankdatei.

const MODULES = [
  {
    key: 'broker-client',
    title: 'Peon Broker Client',
    navTitle: 'Broker',   // Ueberschrift der Gruppe in der Seitenleiste
    desc: 'Sammelt die Auktionsdaten von Broker, wertet sie aus (Verlauf, Chancen, Absatz) und gibt Broker bessere Preise zurück.',
    needs: ['Peon_Broker', 'Peon_Bridge'],
    channels: ['broker'],
    views: ['overview', 'items', 'favorites', 'shopping', 'chances', 'sources'],
    dataFile: 'broker-client.db',
  },
];

function find(key) {
  return MODULES.find((m) => m.key === key) || null;
}

// Ist ein Modul in den Einstellungen eingeschaltet?
function enabled(settings, key) {
  const s = settings && settings.modules && settings.modules[key];
  return !!(s && s.enabled);
}

// Kanaele fuer Data.lua aus allen aktiven Modulen: { broker: true }
function channels(settings) {
  const out = {};
  for (const m of MODULES) if (enabled(settings, m.key)) for (const c of m.channels) out[c] = true;
  return out;
}

// Ansichten in der Seitenleiste aus allen aktiven Modulen
function views(settings) {
  const out = [];
  for (const m of MODULES) if (enabled(settings, m.key)) for (const v of m.views) if (!out.includes(v)) out.push(v);
  return out;
}

module.exports = { MODULES, find, enabled, channels, views };
