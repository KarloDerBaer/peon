// Peon Manager - kleiner Markdown-Leser fuer die Hilfe (ab 0.48.0). Kennt nur, was docs/Hilfe.md braucht:
// Ueberschriften (#, ##, ###), Absaetze, Listen mit "- ", **fett** und `Code`. Ergebnis sind Bloecke mit Textteilen,
// die Vue als Text ausgibt (kein v-html), so kann aus der Datei kein HTML ins Fenster gelangen.

// Textteile einer Zeile: [{ t: 'text' | 'b' | 'code', v }]
export function inline(text) {
  const out = [];
  const re = /(\*\*([^*]+)\*\*|`([^`]+)`)/g;
  let at = 0;
  let m;
  while ((m = re.exec(text))) {
    if (m.index > at) out.push({ t: 'text', v: text.slice(at, m.index) });
    if (m[2] !== undefined) out.push({ t: 'b', v: m[2] });
    else out.push({ t: 'code', v: m[3] });
    at = m.index + m[0].length;
  }
  if (at < text.length) out.push({ t: 'text', v: text.slice(at) });
  return out;
}

// Bloecke: { t: 'h1' | 'h2' | 'h3', parts, id } | { t: 'p', parts } | { t: 'ul', items: [parts] }
export function parse(md) {
  const blocks = [];
  let para = null;
  let list = null;
  const end = () => { para = null; list = null; };
  for (const raw of String(md || '').replace(/\r/g, '').split('\n')) {
    const line = raw.trimEnd();
    const h = /^(#{1,3})\s+(.*)$/.exec(line);
    if (h) {
      end();
      const text = h[2].trim();
      blocks.push({ t: `h${h[1].length}`, parts: inline(text), text, id: text.toLowerCase().replace(/[^a-z0-9äöüß]+/g, '-').replace(/^-|-$/g, '') });
    } else if (/^\s*-\s+/.test(line)) {
      para = null;
      if (!list) { list = { t: 'ul', items: [] }; blocks.push(list); }
      list.items.push(inline(line.replace(/^\s*-\s+/, '')));
    } else if (!line.trim()) {
      end();
    } else if (list && /^\s+\S/.test(raw)) {
      const last = list.items[list.items.length - 1];
      last.push({ t: 'text', v: ' ' }, ...inline(line.trim()));
    } else {
      list = null;
      if (!para) { para = { t: 'p', parts: [] }; blocks.push(para); } else para.parts.push({ t: 'text', v: ' ' });
      para.parts.push(...inline(line.trim()));
    }
  }
  return blocks;
}

// Abschnitte ab "##": [{ title, id, blocks }], davor der Kopf (h1 und Einleitung) als Abschnitt ohne Titel
export function sections(md) {
  const out = [{ title: '', id: '', blocks: [] }];
  for (const b of parse(md)) {
    if (b.t === 'h2') out.push({ title: b.text, id: b.id, blocks: [] });
    else out[out.length - 1].blocks.push(b);
  }
  return out;
}

// Volltext eines Abschnitts fuer die Suche
export function plain(section) {
  const txt = (parts) => parts.map((p) => p.v).join('');
  return [section.title, ...section.blocks.map((b) => (b.t === 'ul' ? b.items.map(txt).join(' ') : txt(b.parts)))].join(' ').toLowerCase();
}
