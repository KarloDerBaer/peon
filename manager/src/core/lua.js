'use strict';
// Peon Manager - Lesen von WoW-SavedVariables (Lua-Tabellen).
// Es wird nichts ausgefuehrt: nur Zuweisungen "Name = Wert" mit Tabellen, Texten, Zahlen, true/false/nil.
// WoW schreibt Texte als Bytes (UTF-8) mit Escapes wie \n, \" und \ddd. Darum wird die Datei als
// latin1 gelesen (ein Zeichen = ein Byte) und jeder Text am Ende als UTF-8 zurueckverwandelt.

class LuaError extends Error {}

function parseLua(input) {
  const s = Buffer.isBuffer(input) ? input.toString('latin1') : Buffer.from(String(input), 'utf8').toString('latin1');
  let i = 0;
  const n = s.length;

  function fail(msg) {
    const line = s.slice(0, i).split('\n').length;
    throw new LuaError(`${msg} (Zeile ${line})`);
  }

  function skip() {
    for (;;) {
      while (i < n) {
        const c = s.charCodeAt(i);
        if (c === 32 || c === 9 || c === 10 || c === 13) i++;
        else break;
      }
      if (s.startsWith('--', i)) {
        if (s.startsWith('--[[', i)) {
          const e = s.indexOf(']]', i + 4);
          i = e < 0 ? n : e + 2;
        } else {
          const e = s.indexOf('\n', i);
          i = e < 0 ? n : e + 1;
        }
        continue;
      }
      return;
    }
  }

  function str() {
    const q = s[i++];
    let out = '';
    let start = i;
    while (i < n) {
      const c = s[i];
      if (c === q) {
        out += s.slice(start, i);
        i++;
        return Buffer.from(out, 'latin1').toString('utf8');
      }
      if (c === '\\') {
        out += s.slice(start, i);
        i++;
        const e = s[i];
        if (e === 'n') { out += '\n'; i++; }
        else if (e === 'r') { out += '\r'; i++; }
        else if (e === 't') { out += '\t'; i++; }
        else if (e === 'a') { out += '\x07'; i++; }
        else if (e === 'b') { out += '\b'; i++; }
        else if (e === 'f') { out += '\f'; i++; }
        else if (e === 'v') { out += '\v'; i++; }
        else if (e === '\n') { out += '\n'; i++; }
        else if (e >= '0' && e <= '9') {
          let d = '';
          while (d.length < 3 && s[i] >= '0' && s[i] <= '9') d += s[i++];
          out += String.fromCharCode(parseInt(d, 10) & 255);
        } else { out += e; i++; }
        start = i;
        continue;
      }
      i++;
    }
    fail('Text ohne Ende');
  }

  function longStr() {
    const m = /^\[(=*)\[/.exec(s.slice(i, i + 20));
    if (!m) fail('Unbekanntes Zeichen [');
    const close = ']' + m[1] + ']';
    let start = i + m[0].length;
    if (s[start] === '\n') start++;
    const e = s.indexOf(close, start);
    if (e < 0) fail('Langer Text ohne Ende');
    i = e + close.length;
    return Buffer.from(s.slice(start, e), 'latin1').toString('utf8');
  }

  function num() {
    const m = /^-?(?:0[xX][0-9a-fA-F]+|(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?)/.exec(s.slice(i, i + 40));
    if (!m) fail('Zahl erwartet');
    i += m[0].length;
    return Number(m[0]);
  }

  function ident() {
    const m = /^[A-Za-z_][A-Za-z0-9_]*/.exec(s.slice(i, i + 200));
    if (!m) fail('Name erwartet');
    i += m[0].length;
    return m[0];
  }

  function value() {
    skip();
    const c = s[i];
    if (c === '{') return table();
    if (c === '"' || c === "'") return str();
    if (c === '[' && (s[i + 1] === '[' || s[i + 1] === '=')) return longStr();
    if (c === '-' || c === '.' || (c >= '0' && c <= '9')) return num();
    const id = ident();
    if (id === 'true') return true;
    if (id === 'false') return false;
    if (id === 'nil') return null;
    fail(`Unerwartet: ${id}`);
  }

  function table() {
    i++; // {
    const obj = {};
    let pos = 1;
    let onlyArray = true;
    for (;;) {
      skip();
      if (s[i] === '}') { i++; break; }
      let key;
      if (s[i] === '[' && s[i + 1] !== '[' && s[i + 1] !== '=') {
        i++;
        key = value();
        skip();
        if (s[i] !== ']') fail('] erwartet');
        i++;
        skip();
        if (s[i] !== '=') fail('= erwartet');
        i++;
        const v = value();
        if (v !== null) obj[key] = v;
        if (!(typeof key === 'number' && Number.isInteger(key) && key >= 1)) onlyArray = false;
      } else {
        const save = i;
        let named = null;
        if (/[A-Za-z_]/.test(s[i] || '')) {
          const id = ident();
          skip();
          if (s[i] === '=' && s[i + 1] !== '=') { i++; named = id; } else i = save;
        }
        if (named !== null) {
          const v = value();
          if (v !== null) obj[named] = v;
          onlyArray = false;
        } else {
          const v = value();
          if (v !== null) obj[pos] = v;
          pos++;
        }
      }
      skip();
      if (s[i] === ',' || s[i] === ';') i++;
    }
    if (onlyArray) {
      const keys = Object.keys(obj);
      if (keys.length === 0) return obj;
      const arr = [];
      for (let k = 1; k <= keys.length; k++) {
        if (!(k in obj)) return obj;
        arr.push(obj[k]);
      }
      return arr;
    }
    return obj;
  }

  const globals = {};
  for (;;) {
    skip();
    if (i >= n) break;
    const name = ident();
    skip();
    if (s[i] !== '=') fail('= erwartet');
    i++;
    globals[name] = value();
    skip();
    if (s[i] === ';') i++;
  }
  return globals;
}

// Lua-Text fuer einen Wert (fuer Data.lua). Nur Tabellen, Texte, Zahlen, Wahrheitswerte.
function toLua(v, indent = '') {
  if (v === null || v === undefined) return 'nil';
  if (typeof v === 'boolean') return v ? 'true' : 'false';
  if (typeof v === 'number') {
    if (!Number.isFinite(v)) return '0';
    return Number.isInteger(v) ? v.toFixed(0) : String(v);
  }
  if (typeof v === 'string') return quote(v);
  const inner = indent + '  ';
  const parts = [];
  if (Array.isArray(v)) {
    for (const x of v) parts.push(inner + toLua(x, inner) + ',');
  } else {
    for (const k of Object.keys(v)) {
      const key = /^\d+$/.test(k) && String(Number(k)) === k ? `[${k}]` : `[${quote(k)}]`;
      parts.push(`${inner}${key} = ${toLua(v[k], inner)},`);
    }
  }
  if (parts.length === 0) return '{}';
  return '{\n' + parts.join('\n') + '\n' + indent + '}';
}

function quote(str) {
  // UTF-8 bleibt als Bytes erhalten; nur Steuerzeichen, " und \ werden geschuetzt
  return '"' + String(str).replace(/[\\"\n\r\0]/g, (c) => ({ '\\': '\\\\', '"': '\\"', '\n': '\\n', '\r': '\\r', '\0': '\\0' }[c])) + '"';
}

module.exports = { parseLua, toLua, LuaError };
