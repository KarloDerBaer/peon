// Erzeugt die Eckbilder von Peon_Panel: node scripts/panel_media.js
// Ein Bild zeigt die untere linke Ecke, weiss mit Alphakanal. Das Addon spiegelt und faerbt es selbst.
// Die Linie ist so dick, dass sie bei der Anzeigegroesse ns.CORNER (12) etwa einen Punkt breit ist.

const fs = require('fs');
const path = require('path');

const SIZE = 32;
const SAMPLES = 8;
const LINE = SIZE / 12;
const OUT = path.join(__dirname, '..', 'addons', 'Peon_Panel', 'Media');

// Deckkraft eines Bildpunkts (x nach rechts, y nach oben), gemittelt fuer weiche Kanten
function coverage(x, y, inside) {
  let hits = 0;
  for (let i = 0; i < SAMPLES; i++) {
    for (let j = 0; j < SAMPLES; j++) {
      const dx = SIZE - (x + (i + 0.5) / SAMPLES);
      const dy = SIZE - (y + (j + 0.5) / SAMPLES);
      if (inside(Math.sqrt(dx * dx + dy * dy))) hits++;
    }
  }
  return Math.round((hits * 255) / (SAMPLES * SAMPLES));
}

// TGA unkomprimiert, 32 Bit, Zeilen von unten nach oben (wie die Bilder von Peon_Broker)
function tga(inside) {
  const buf = Buffer.alloc(18 + SIZE * SIZE * 4, 0);
  buf[2] = 2;
  buf.writeUInt16LE(SIZE, 12);
  buf.writeUInt16LE(SIZE, 14);
  buf[16] = 32;
  buf[17] = 8;
  let o = 18;
  for (let y = 0; y < SIZE; y++) {
    for (let x = 0; x < SIZE; x++) {
      buf[o] = 255;
      buf[o + 1] = 255;
      buf[o + 2] = 255;
      buf[o + 3] = coverage(x, y, inside);
      o += 4;
    }
  }
  return buf;
}

fs.mkdirSync(OUT, { recursive: true });
fs.writeFileSync(path.join(OUT, 'corner_fill.tga'), tga((d) => d <= SIZE));
fs.writeFileSync(path.join(OUT, 'corner_line.tga'), tga((d) => d <= SIZE && d >= SIZE - LINE));
