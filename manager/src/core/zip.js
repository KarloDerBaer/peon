'use strict';
// Peon Manager - Zip lesen und schreiben (nur Node, keine Pakete). Auch fuer scripts/build_release.js.
// Schreiben: feste Zeit 01.01.2026 00:00, damit gleiche Inhalte gleiche Zips ergeben.
// Lesen: Die Daten kommen aus dem Netz, deshalb sind Groessen begrenzt und alle Angaben werden geprueft.

const zlib = require('node:zlib');

const DOS_TIME = 0;
const DOS_DATE = ((2026 - 1980) << 9) | (1 << 5) | 1;
const MAX_ENTRY = 64 * 1024 * 1024;     // groesste einzelne Datei beim Lesen
const MAX_TOTAL = 256 * 1024 * 1024;    // alle Dateien zusammen beim Lesen
const MAX_COUNT = 5000;

function makeZip(entries) {   // entries: [{ name, data }] (Ordner enden mit "/", data leer)
  const locals = [], centrals = [];
  let offset = 0;
  for (const e of entries) {
    const name = Buffer.from(e.name, 'utf8');
    const data = e.data || Buffer.alloc(0);
    const crc = zlib.crc32(data) >>> 0;
    let method = 0, body = data;
    if (data.length > 0) {
      const d = zlib.deflateRawSync(data, { level: 9 });
      if (d.length < data.length) { method = 8; body = d; }
    }
    const lh = Buffer.alloc(30);
    lh.writeUInt32LE(0x04034b50, 0); lh.writeUInt16LE(20, 4); lh.writeUInt16LE(0x0800, 6);   // UTF-8-Namen
    lh.writeUInt16LE(method, 8); lh.writeUInt16LE(DOS_TIME, 10); lh.writeUInt16LE(DOS_DATE, 12);
    lh.writeUInt32LE(crc, 14); lh.writeUInt32LE(body.length, 18); lh.writeUInt32LE(data.length, 22);
    lh.writeUInt16LE(name.length, 26); lh.writeUInt16LE(0, 28);
    locals.push(lh, name, body);
    const ch = Buffer.alloc(46);
    ch.writeUInt32LE(0x02014b50, 0); ch.writeUInt16LE(20, 4); ch.writeUInt16LE(20, 6); ch.writeUInt16LE(0x0800, 8);
    ch.writeUInt16LE(method, 10); ch.writeUInt16LE(DOS_TIME, 12); ch.writeUInt16LE(DOS_DATE, 14);
    ch.writeUInt32LE(crc, 16); ch.writeUInt32LE(body.length, 20); ch.writeUInt32LE(data.length, 24);
    ch.writeUInt16LE(name.length, 28); ch.writeUInt16LE(0, 30); ch.writeUInt16LE(0, 32); ch.writeUInt16LE(0, 34);
    ch.writeUInt16LE(0, 36); ch.writeUInt32LE(e.name.endsWith('/') ? 0x10 : 0, 38); ch.writeUInt32LE(offset, 42);
    centrals.push(ch, name);
    offset += lh.length + name.length + body.length;
  }
  const cd = Buffer.concat(centrals);
  const end = Buffer.alloc(22);
  end.writeUInt32LE(0x06054b50, 0); end.writeUInt16LE(0, 4); end.writeUInt16LE(0, 6);
  end.writeUInt16LE(entries.length, 8); end.writeUInt16LE(entries.length, 10);
  end.writeUInt32LE(cd.length, 12); end.writeUInt32LE(offset, 16); end.writeUInt16LE(0, 20);
  return Buffer.concat([...locals, cd, end]);
}

// Zip lesen: [{ name, data }]. Wirft bei allem, was nicht stimmt (Pruefsumme, Groesse, Aufbau).
function readZip(buf) {
  const endAt = buf.lastIndexOf(Buffer.from([0x50, 0x4b, 0x05, 0x06]));
  if (endAt < 0 || endAt + 22 > buf.length) throw new Error('Kein gültiges Zip');
  const count = buf.readUInt16LE(endAt + 10);
  if (count > MAX_COUNT) throw new Error('Zip enthält zu viele Dateien');
  let p = buf.readUInt32LE(endAt + 16);
  let total = 0;
  const out = [];
  for (let i = 0; i < count; i++) {
    if (p + 46 > buf.length || buf.readUInt32LE(p) !== 0x02014b50) throw new Error('Zip ist beschädigt');
    const flags = buf.readUInt16LE(p + 8), method = buf.readUInt16LE(p + 10), crc = buf.readUInt32LE(p + 16);
    const csize = buf.readUInt32LE(p + 20), usize = buf.readUInt32LE(p + 24);
    const nlen = buf.readUInt16LE(p + 28), xlen = buf.readUInt16LE(p + 30), clen = buf.readUInt16LE(p + 32);
    const lo = buf.readUInt32LE(p + 42);
    if (p + 46 + nlen > buf.length) throw new Error('Zip ist beschädigt');
    const name = buf.toString('utf8', p + 46, p + 46 + nlen);
    if (flags & 1) throw new Error(`Zip verschlüsselt: ${name}`);
    if (method !== 0 && method !== 8) throw new Error(`Zip-Methode unbekannt: ${name}`);
    if (usize > MAX_ENTRY || total + usize > MAX_TOTAL) throw new Error(`Zip zu groß: ${name}`);
    if (lo + 30 > buf.length) throw new Error('Zip ist beschädigt');
    const start = lo + 30 + buf.readUInt16LE(lo + 26) + buf.readUInt16LE(lo + 28);
    if (start + csize > buf.length) throw new Error('Zip ist beschädigt');
    const body = buf.subarray(start, start + csize);
    const data = method === 8 ? zlib.inflateRawSync(body, { maxOutputLength: Math.max(usize, 1) }) : Buffer.from(body);
    if (data.length !== usize || (zlib.crc32(data) >>> 0) !== crc) throw new Error(`Prüfsumme falsch: ${name}`);
    total += usize;
    out.push({ name, data });
    p += 46 + nlen + xlen + clen;
  }
  return out;
}

module.exports = { makeZip, readZip };
