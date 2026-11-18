'use strict';
// Peon Manager - Groesse der Oberflaeche (ab 0.47.0). Einstellung settings.zoom als Faktor, nur diese Stufen.
// Tasten wie im Browser: Strg und Plus groesser, Strg und Minus kleiner, Strg und 0 zurueck auf 100 %.

const ZOOM_STEPS = [0.8, 0.9, 1, 1.1, 1.25, 1.5, 1.75];
const ZOOM_DEFAULT = 1;

// Gespeicherter Wert auf eine erlaubte Stufe bringen
function zoomOf(v) {
  const n = Number(v);
  return ZOOM_STEPS.includes(n) ? n : ZOOM_DEFAULT;
}

// Naechste Stufe: dir +1 groesser, -1 kleiner, 0 zurueck
function zoomStep(cur, dir) {
  if (dir === 0) return ZOOM_DEFAULT;
  const i = ZOOM_STEPS.indexOf(zoomOf(cur));
  return ZOOM_STEPS[Math.max(0, Math.min(ZOOM_STEPS.length - 1, i + (dir > 0 ? 1 : -1)))];
}

// Tastendruck aus before-input-event: Richtung (+1, -1, 0) oder null, wenn es kein Zoom-Kuerzel ist
function zoomKey(input) {
  if (!input || input.type !== 'keyDown' || !input.control || input.alt || input.meta) return null;
  const k = input.key, c = input.code;
  if (k === '+' || k === '=' || c === 'NumpadAdd') return 1;
  if (k === '-' || c === 'NumpadSubtract') return -1;
  if (k === '0' || c === 'Numpad0') return 0;
  return null;
}

module.exports = { ZOOM_STEPS, ZOOM_DEFAULT, zoomOf, zoomStep, zoomKey };
