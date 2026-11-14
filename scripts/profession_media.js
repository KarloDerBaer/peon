// Erzeugt den Pfeil des Guides fuer Peon_Profession: node scripts/profession_media.js
// Weisses Dreieck nach rechts mit Alphakanal, das Addon faerbt es Peon-Gruen (Craft.lua, C.ARROW).

const fs = require('fs');
const path = require('path');

const SIZE = 32;
const SAMPLES = 8;
const OUT = path.join(__dirname, '..', 'addons', 'Peon_Profession', 'Media');

// Dreieck: links oben (6, 4), links unten (6, 28), Spitze rechts (28, 16); y nach unten
function inside(px, py) {
  const ax = 6, ay = 4, bx = 6, by = 28, cx = 28, cy = 16;
  const s1 = (bx - ax) * (py - ay) - (by - ay) * (px - ax);
  const s2 = (cx - bx) * (py - by) - (cy - by) * (px - bx);
  const s3 = (ax - cx) * (py - cy) - (ay - cy) * (px - cx);
  return (s1 <= 0 && s2 <= 0 && s3 <= 0) || (s1 >= 0 && s2 >= 0 && s3 >= 0);
}

function coverage(x, y) {
  let hits = 0;
  for (let i = 0; i < SAMPLES; i++) {
    for (let j = 0; j < SAMPLES; j++) {
      if (inside(x + (i + 0.5) / SAMPLES, y + (j + 0.5) / SAMPLES)) hits++;
    }
  }
  return Math.round((hits * 255) / (SAMPLES * SAMPLES));
}

// TGA unkomprimiert, 32 Bit, Zeilen von unten nach oben (wie die Bilder von Peon_Broker und Peon_Panel)
function tga() {
  const buf = Buffer.alloc(18 + SIZE * SIZE * 4, 0);
  buf[2] = 2;
  buf.writeUInt16LE(SIZE, 12);
  buf.writeUInt16LE(SIZE, 14);
  buf[16] = 32;
  buf[17] = 8;
  let o = 18;
  for (let row = 0; row < SIZE; row++) {
    const y = SIZE - 1 - row;
    for (let x = 0; x < SIZE; x++) {
      buf[o] = 255;
      buf[o + 1] = 255;
      buf[o + 2] = 255;
      buf[o + 3] = coverage(x, y);
      o += 4;
    }
  }
  return buf;
}

fs.mkdirSync(OUT, { recursive: true });
fs.writeFileSync(path.join(OUT, 'guide_arrow.tga'), tga());
