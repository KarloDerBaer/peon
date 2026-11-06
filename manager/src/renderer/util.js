// Hilfen fuer die Anzeige
// Qualitaetsfarben aus dem Spiel, fuer die helle Ansicht abgedunkelt (style.css, --q0 bis --q7)
export function qualityColor(q) {
  return q == null || q < 0 || q > 7 ? 'var(--text)' : `var(--q${q})`;
}

// Kupfer -> { g, s, c } (gerundet auf ganze Kupfer)
export function coins(copper) {
  if (copper == null || !Number.isFinite(copper)) return null;
  const v = Math.round(copper);
  return { g: Math.floor(v / 10000), s: Math.floor((v % 10000) / 100), c: v % 100 };
}

export function num(n) {
  if (n == null) return '–';
  return Number(n).toLocaleString('de-DE');
}

export function pct(p) {
  if (p == null) return '';
  const v = Math.round(p * 100);
  return (v > 0 ? '+' : '') + v.toLocaleString('de-DE') + ' %';
}

// "vor 5 Min.", "vor 3 Std.", "vor 2 Tagen"
export function ago(t, now = Math.floor(Date.now() / 1000)) {
  if (!t) return 'noch nie';
  const d = Math.max(0, now - t);
  if (d < 60) return 'gerade eben';
  if (d < 3600) return `vor ${Math.floor(d / 60)} Min.`;
  if (d < 48 * 3600) return `vor ${Math.floor(d / 3600)} Std.`;
  return `vor ${Math.floor(d / 86400)} Tagen`;
}

export function when(t) {
  if (!t) return '';
  return new Date(t * 1000).toLocaleString('de-DE', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' });
}

export function bytes(b) {
  if (b == null) return '';
  if (b >= 1024 * 1024 * 1024) return (b / 1024 / 1024 / 1024).toLocaleString('de-DE', { maximumFractionDigits: 1 }) + ' GB';
  if (b >= 1024 * 1024) return (b / 1024 / 1024).toLocaleString('de-DE', { maximumFractionDigits: 1 }) + ' MB';
  return Math.max(1, Math.round(b / 1024)).toLocaleString('de-DE') + ' KB';
}

// Zustand einer Station nach Alter: ok (frisch), alt, aus
export function freshness(t, okSec, now = Math.floor(Date.now() / 1000)) {
  if (!t) return 'aus';
  return now - t <= okSec ? 'ok' : 'alt';
}

// Zahl mit Einzahl/Mehrzahl: pl(1, 'Scan', 'Scans') -> "1 Scan"
export function pl(n, one, many) {
  return `${num(n)} ${n === 1 ? one : many}`;
}

// kurzer Geldbetrag fuer Achsen: 1,2g / 35s / 12c
export function shortMoney(c) {
  if (c == null || !Number.isFinite(c)) return '';
  const a = Math.abs(c);
  if (a >= 10000) { const g = c / 10000; return (a >= 100000 ? Math.round(g).toLocaleString('de-DE') : g.toLocaleString('de-DE', { maximumFractionDigits: 1 })) + 'g'; }
  if (a >= 1000) return Math.round(c / 100) + 's';
  if (a >= 100) { const r = Math.round(a); const cc = r % 100; return `${Math.floor(r / 100)}s` + (cc ? ` ${cc}c` : ''); }
  return Math.round(c) + 'c';
}

// Suche: Gross/klein und Umlaute egal
export function fold(s) {
  return String(s || '').toLowerCase().replace(/ä/g, 'a').replace(/ö/g, 'o').replace(/ü/g, 'u').replace(/ß/g, 'ss')
    .normalize('NFD').replace(/[̀-ͯ]/g, '');
}

export function itemName(it) {
  return it.name || `Gegenstand ${it.item}`;
}

// Absatz je Tag: "960", "4,5", "0,3"
export function perDay(v) {
  if (v == null || !Number.isFinite(v)) return '–';
  if (v >= 10) return Math.round(v).toLocaleString('de-DE');
  return v.toLocaleString('de-DE', { maximumFractionDigits: 1 });
}

// Sicherheit des Absatzes (wie Broker): 1 rot, 2 gelb, 3 gruen
export function levelTitle(l) {
  return { 1: 'unsicher, weniger als 1 Std. beobachtet', 2: 'mittel, mindestens 1 Std. beobachtet', 3: 'sicher, mindestens 3 Std. beobachtet' }[l] || '';
}

// 3-Stunden-Abschnitt als Text
export function slotText(s) {
  return s == null ? '' : `${s * 3}–${s * 3 + 3} Uhr`;
}

// Ein Satz zum Gegenstand: Lohnt sich der Kauf gerade? Vergleich des guenstigsten Angebots mit dem ueblichen Preis, sonst dem Mittel aus 7 Tagen
export function verdict(d) {
  if (!d) return null;
  const c = d.current;
  const parts = [];
  let tone = '';
  if (c && c.qty > 0 && c.min != null) {
    const ref = d.longterm ? d.longterm.lang : d.median7;
    const was = d.longterm ? 'dem üblichen Preis' : 'dem Mittel aus 7 Tagen';
    if (ref > 0) {
      const p = Math.round((c.min / ref - 1) * 100);
      if (p <= -5) { parts.push(`Das günstigste Angebot liegt ${-p} % unter ${was}`); tone = 'good'; }
      else if (p >= 5) { parts.push(`Das günstigste Angebot liegt ${p} % über ${was}`); tone = 'bad'; }
      else parts.push(`Das günstigste Angebot entspricht ${was}`);
    }
  } else if (c) {
    parts.push('Gerade gibt es keine Angebote');
  }
  if (d.sales) {
    const v = d.sales.perDay;
    parts.push(v >= 5 ? 'verkauft sich gut' : v >= 1 ? 'verkauft sich mäßig' : 'verkauft sich selten');
  }
  return parts.length ? { text: `${parts.join(', ')}.`, tone } : null;
}
