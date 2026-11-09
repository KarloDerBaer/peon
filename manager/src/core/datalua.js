'use strict';
// Peon Manager - Rueckgabe ans Spiel: AddOns\Peon_Bridge\Data.lua (PeonBridgeData, Format 2).
// channels = Kanaele, die die Bridge nutzen darf (Peon_GitHub_Design.md 4.2, 4.3). Ohne Eintrag zeichnet sie nichts auf.
// ack = abgeholte Momentaufnahmen (die Bridge loescht sie beim naechsten Start aus der Warteschlange),
// markets = Preisbereiche und Absatz fuer Broker (Kanal broker),
// errorsClearBefore, feedbackClearBefore = das Spiel loescht bis zu diesem Zeitpunkt, was der Manager schon hat (reports.js),
// aliases = andere interne Namen eines Markts, shop = Einkaufslisten (shopping.js),
// tipWant = Gegenstaende, deren genaue Werte der Manager noch nicht kennt: Schluessel -> Link (broker-client.js tipWants).
// Geschrieben wird in eine neue Datei, die dann die alte ersetzt, damit das Spiel nie eine halbe Datei laedt.

const fs = require('node:fs');
const path = require('node:path');
const { toLua, parseLua } = require('./lua');

const FMT = 2;
const ADDON = 'Peon_Bridge';

function addonDir(wowDir) {
  return path.join(wowDir, 'Interface', 'AddOns', ADDON);
}

function writeData(wowDir, { ack = [], markets = {}, channels = { broker: true }, version = '0.0.0', now = Math.floor(Date.now() / 1000), errorsClearBefore = 0, feedbackClearBefore = 0, aliases = null, shop = null, tipWant = null, watch = null } = {}) {
  const dir = addonDir(wowDir);
  if (!fs.existsSync(path.join(dir, ADDON + '.toc'))) {
    throw new Error(`${ADDON} nicht gefunden: ${dir}`);
  }
  const ackObj = {};
  for (const id of ack) ackObj[String(id)] = true;
  const ch = {};
  for (const [k, v] of Object.entries(channels || {})) if (v) ch[k] = true;
  const data = { fmt: FMT, t: now, manager: version, channels: ch, ack: ackObj, markets };
  if (errorsClearBefore) data.errorsClearBefore = errorsClearBefore;
  if (feedbackClearBefore) data.feedbackClearBefore = feedbackClearBefore;
  if (aliases && Object.keys(aliases).length) data.aliases = aliases;
  if (shop) data.shop = shop;
  if (watch) data.watch = watch;   // Beobachtung (ab 0.24)
  if (tipWant && Object.keys(tipWant).length) data.tipWant = tipWant;
  const text = '-- Peon_Bridge - Data.lua\n'
    + '-- Geschrieben vom Peon Manager. Nicht von Hand aendern, nie mit ausliefern.\n'
    + 'PeonBridgeData = ' + toLua(data) + '\n';
  const file = path.join(dir, 'Data.lua');
  const tmp = file + '.neu';
  fs.writeFileSync(tmp, text, 'utf8');
  fs.renameSync(tmp, file);
  return { file, bytes: Buffer.byteLength(text), ack: ack.length };
}

// Steht in der Datei auf der Platte das Format, die Kanaele und die Marken der Rueckmeldungen, die der Manager erwartet?
// Sie kann sich aendern, ohne dass der Manager es merkt: neu installierte Bridge, geloeschte Datei, anderes Programm.
function dataMatches(wowDir, channels = {}, { errorsClearBefore = 0, feedbackClearBefore = 0 } = {}) {
  try {
    const d = parseLua(fs.readFileSync(path.join(addonDir(wowDir), 'Data.lua'))).PeonBridgeData;
    if (!d || d.fmt !== FMT) return false;
    if ((d.errorsClearBefore || 0) !== errorsClearBefore || (d.feedbackClearBefore || 0) !== feedbackClearBefore) return false;
    const have = Object.keys(d.channels || {}).filter((k) => d.channels[k] === true).sort();
    const want = Object.keys(channels).filter((k) => channels[k]).sort();
    return have.join() === want.join();
  } catch { return false; }
}

module.exports = { writeData, dataMatches, addonDir, FMT, ADDON };
