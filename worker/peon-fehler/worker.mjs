// Peon Fehlerberichte: Cloudflare Worker zwischen Peon Manager und GitHub.
// Nimmt Fehler und Rueckmeldungen ohne Anmeldung an, prueft sie und legt je Eintrag ein Issue an. Der GitHub-Token liegt
// nur hier (Geheimnis GITHUB_TOKEN), nie im Manager. Einrichtung: README.md in diesem Ordner.
// Die IP-Adresse wird nur als Pruefsumme fuer die Sperre gegen zu viele Anfragen genutzt und nach einer Stunde verworfen.
// Ab 18.11.2026: Die Sperre zaehlt Eintraege statt Sendungen (vorher bis zu 20 Eintraege je Sendung), und ein Fehler,
// der schon als offenes Issue da ist, kommt als Kommentar an dieses Issue statt als neues.
// Ab 24.11.2026: Der Worker liest die offenen Issues einmal je Sendung als Verzeichnis (Kennung zu Issue) statt fuer jeden
// Eintrag die Suche zu fragen, gleiche Fehler einer Sendung werden zu einer Meldung gebuendelt, und er hoert vor der
// Grenze von Cloudflare (50 Abrufe je Anfrage in der Gratis-Stufe) auf. Vorher brach er nach 11 Eintraegen ab, der Manager
// hielt alles fuer gescheitert und schickte dieselben Eintraege spaeter noch einmal.

const MAX_BODY = 64 * 1024;
const MAX_ITEMS = 20;              // Der Manager schickt nicht mehr, Cloudflare erlaubt je Anfrage nur begrenzt viele Abrufe
const LIMIT_PER_IP = 20;           // Eintraege je Stunde und Adresse
const LIMIT_TOTAL = 60;            // Eintraege je Stunde insgesamt
const LIMIT_SECONDS = 3600;
const MAX_CALLS = 45;              // Abrufe je Anfrage (GitHub und Cache), Cloudflare erlaubt in der Gratis-Stufe 50
const DIR_PAGES = 3;               // so viele Seiten offener Issues (je 100) liest das Verzeichnis hoechstens

const KINDS = { bug: ['Fehler', 'fehler'], improve: ['Verbesserung', 'verbesserung'], idea: ['Neue Idee', 'idee'], other: ['Sonstiges', 'sonstiges'] };
const PRIOS = { low: 'Niedrig', mid: 'Mittel', high: 'Hoch' };
const ADDON = /^Peon(_\w+)?$/;
const SENDER = /^[0-9a-f]{8}$/;   // ab Manager 0.49.0: anonyme Kennung der Installation (fehlt bei aelteren)

const json = (status, data) => new Response(JSON.stringify(data), { status, headers: { 'Content-Type': 'application/json' } });
const str = (v, max) => (typeof v === 'string' ? v.slice(0, max) : '');
const num = (v) => (Number.isFinite(v) && v >= 0 ? Math.floor(v) : 0);
// Fuer den Titel: nur harmlose Zeichen, kein @ und keine Formatierung
const plain = (s, max = 80) => s.replace(/\s+/g, ' ').replace(/[^\p{L}\p{N} ._:+/-]/gu, '').trim().slice(0, max);
// Text steht im Issue in einem Codeblock: kann ihn nicht verlassen und niemanden per @ benachrichtigen
const fence = (s) => s.replace(/`{3,}/g, "'''");
const utc = (t) => (t ? `${new Date(t * 1000).toISOString().slice(0, 16).replace('T', ' ')} UTC` : '?');

// Einen Eintrag pruefen und auf bekannte Felder kuerzen. Rueckgabe: Eintrag oder null
function cleanItem(e) {
  if (!e || typeof e !== 'object' || !Number.isInteger(e.ref)) return null;
  if (e.type === 'error') {
    const addon = str(e.addon, 60), msg = str(e.msg, 1000);
    if (!ADDON.test(addon) || !msg) return null;
    return { type: 'error', ref: e.ref, addon, msg, version: plain(str(e.version, 40)), build: plain(str(e.build, 40)), where: plain(str(e.where, 80)),
      source: plain(str(e.source, 20)), stack: str(e.stack, 1500), note: str(e.note, 2000), first: num(e.first), last: num(e.last), n: num(e.n) || 1 };
  }
  if (e.type === 'feedback') {
    const module = str(e.module, 60), text = str(e.text, 2000);
    if (!ADDON.test(module) || !text.trim() || !KINDS[e.kind] || !PRIOS[e.prio]) return null;
    return { type: 'feedback', ref: e.ref, module, text, kind: e.kind, prio: e.prio, area: plain(str(e.area, 80)), version: plain(str(e.version, 40)),
      zone: str(e.zone, 120), market: str(e.market, 120), origin: plain(str(e.origin, 20)), t: num(e.t) };
  }
  return null;
}

// Eingang pruefen. Rueckgabe: Bericht oder null
export function cleanReport(data) {
  if (!data || data.fmt !== 2 || !Array.isArray(data.items)) return null;
  if (data.items.length < 1 || data.items.length > MAX_ITEMS) return null;
  const items = data.items.map(cleanItem);
  if (items.includes(null)) return null;
  return { manager: plain(str(data.manager, 40)), sender: SENDER.test(str(data.sender, 8)) ? data.sender : '', items };
}

// Meldung ohne wechselnde Teile. "script ran too long" nennt die Zeile, an der das Spiel abbrach, die ist fast jedes Mal
// anders: ohne Datei und Zeile. Adressen von Tabellen und Funktionen wechseln mit jedem Laden.
// Gleiche Regeln im Kern (Core.lua) und im Manager (reports.js).
export function errorText(msg) {
  const s = String(msg || '');
  if (s.includes('script ran too long')) return 'script ran too long';
  return s.replace(/\b(table|function|userdata|thread): (?:0x)?[0-9A-Fa-f]{6,}/g, '$1: <Adresse>');
}

// Kennung eines Fehlers: gleiches Addon, gleiche Stelle, gleiche Meldung (Version egal). Steht unter dem Issue.
export async function errorKey(i) {
  return (await sha256(`${i.addon}|${i.where}|${errorText(i.msg)}`)).slice(0, 16);
}

// Gleiche Fehler einer Sendung zu einer Meldung: Anzahl zusammen, Zeitraum gesamt, Version und Text der neuesten
export function mergeErrors(list) {
  const newest = list.reduce((a, b) => (b.last > a.last ? b : a));
  const notes = [...new Set(list.map((i) => i.note).filter(Boolean))];
  return { ...newest, n: list.reduce((s, i) => s + i.n, 0), first: Math.min(...list.map((i) => i.first || newest.last)),
    last: newest.last, note: notes.join('\n').slice(0, 2000) };
}

export function buildIssue(i, manager, key, sender) {
  const from = `Peon Manager ${manager || '?'}${sender ? ` · Absender ${sender}` : ''}`;
  if (i.type === 'error') {
    const head = `${i.addon} ${i.version} | ${i.where} | ${i.n}x | zuletzt ${utc(i.last)} | Build ${i.build || '?'} | ${i.source}`;
    const lines = [head, i.msg];
    if (i.stack) lines.push('', i.stack);
    if (i.note) lines.push('', 'Notiz:', i.note);
    return { title: plain(`${i.addon}${i.version ? ` ${i.version}` : ''}: ${i.where || 'Fehler'}`, 120), labels: ['fehler'],
      body: `${from}\n\n\`\`\`text\n${fence(lines.join('\n'))}\n\`\`\`${key ? `\n\npeon-key: ${key}` : ''}` };
  }
  const [kind, label] = KINDS[i.kind];
  const head = `${kind} | ${i.module} ${i.version} | ${i.area} | Priorität ${PRIOS[i.prio]} | ${utc(i.t)} | aus ${i.origin === 'game' ? 'dem Spiel' : 'dem Manager'}`;
  const where = [i.zone && `Zone: ${i.zone}`, i.market && `Markt: ${i.market}`].filter(Boolean);
  return { title: `[${kind}] ${plain(`${i.module.replace(/^Peon_/, '')}: ${i.text}`, 100)}`, labels: [label],
    body: `${from}\n\n\`\`\`text\n${fence([head, ...where, '', i.text].join('\n'))}\n\`\`\`` };
}

// Weitere Meldung desselben Fehlers: kurzer Kommentar am bestehenden Issue
export function buildComment(i, manager, sender) {
  const head = `Wieder gemeldet von Peon Manager ${manager || '?'}${sender ? ` (Absender ${sender})` : ''}: ${i.addon} ${i.version} | ${i.n}x | zuletzt ${utc(i.last)} | Build ${i.build || '?'}`;
  const lines = [head];
  if (i.note) lines.push('', 'Notiz:', i.note);
  return { body: `\`\`\`text\n${fence(lines.join('\n'))}\n\`\`\`` };
}

async function sha256(text) {
  const d = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text));
  return [...new Uint8Array(d)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

// Zaehler im Cache von Cloudflare. Er gilt je Rechenzentrum, das reicht als Bremse.
// Rueckgabe: true, wenn noch add Eintraege frei sind (dann sind sie gezaehlt)
async function allow(cache, name, max, add = 1) {
  if (!cache) return true;
  const key = new Request(`https://peon-fehler.invalid/zaehler/${name}`);
  const hit = await cache.match(key);
  const n = hit ? Number(await hit.text()) || 0 : 0;
  if (n + add > max) return false;
  await cache.put(key, new Response(String(n + add), { headers: { 'Cache-Control': `max-age=${LIMIT_SECONDS}` } }));
  return true;
}

// Verzeichnis der offenen Issues: Fehlerkennung -> Nummer. Liest die Liste der Issues direkt (nicht die Suche, die neue
// Issues erst nach einer Weile kennt). Scheitert das Lesen, ist das Verzeichnis leer: lieber ein neues Issue als keins.
async function openIssues(env, gh) {
  const dir = new Map();
  for (let page = 1; page <= DIR_PAGES; page++) {
    const res = await gh(`https://api.github.com/repos/${env.GITHUB_REPO}/issues?state=open&per_page=100&page=${page}`);
    if (!res || !res.ok) break;
    let list;
    try { list = await res.json(); } catch { break; }
    if (!Array.isArray(list)) break;
    for (const i of list) {
      const m = !i.pull_request && typeof i.body === 'string' && /\npeon-key:\s*([0-9a-f]{16})\s*$/.exec(i.body);
      if (m && Number.isInteger(i.number) && !dir.has(m[1])) dir.set(m[1], i.number);
    }
    if (list.length < 100) break;
  }
  return dir;
}

export async function handle(request, env, { fetchImpl = fetch, cache = globalThis.caches && globalThis.caches.default } = {}) {
  if (request.method !== 'POST' || new URL(request.url).pathname !== '/bericht') return json(404, { ok: false, error: 'not found' });
  const raw = await request.text();
  if (raw.length > MAX_BODY) return json(413, { ok: false, error: 'too large' });
  let data;
  try { data = JSON.parse(raw); } catch { return json(400, { ok: false, error: 'invalid json' }); }
  const report = cleanReport(data);
  if (!report) return json(400, { ok: false, error: 'invalid report' });

  // Jeder Abruf (GitHub und Cache) zaehlt gegen die Grenze von Cloudflare. Wer sie reisst, bricht mit Fehler ab, und
  // der Manager erfaehrt nicht, was schon angelegt ist. Darum zaehlt der Worker mit und hoert vorher auf.
  let calls = 0;
  const counted = cache && { match: (k) => { calls++; return cache.match(k); }, put: (k, r) => { calls++; return cache.put(k, r); } };

  const n = report.items.length;
  const ip = await sha256(request.headers.get('CF-Connecting-IP') || 'unbekannt');
  if (!(await allow(counted, `ip-${ip}`, LIMIT_PER_IP, n)) || !(await allow(counted, 'gesamt', LIMIT_TOTAL, n))) {
    return json(429, { ok: false, error: 'too many reports' });
  }

  const headers = {
    Authorization: `Bearer ${env.GITHUB_TOKEN}`, Accept: 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28', 'User-Agent': 'peon-fehler-worker', 'Content-Type': 'application/json',
  };
  const gh = (url, body) => { calls++; return fetchImpl(url, body ? { method: 'POST', headers, body: JSON.stringify(body) } : { method: 'GET', headers }); };

  // Gleiche Fehler zu einer Gruppe, Reihenfolge wie gesendet. Rueckmeldungen bleiben einzeln.
  const groups = [], byKey = new Map();
  for (const item of report.items) {
    const key = item.type === 'error' ? await errorKey(item) : null;
    if (key && byKey.has(key)) { byKey.get(key).items.push(item); continue; }
    const g = { key, items: [item] };
    groups.push(g);
    if (key) byKey.set(key, g);
  }
  const dir = byKey.size ? await openIssues(env, gh) : new Map();

  // Nacheinander anlegen und beim ersten Fehler aufhoeren: Was bestaetigt ist, loescht der Manager, der Rest bleibt bei ihm.
  // Gleicher Fehler wie ein offenes Issue: Kommentar daran statt neuem Issue.
  const done = [], numbers = [];
  let failed = null;
  for (const g of groups) {
    if (calls >= MAX_CALLS) { failed = 'limit'; break; }
    const item = g.items.length > 1 ? mergeErrors(g.items) : g.items[0];
    const open = g.key ? dir.get(g.key) : null;
    const res = open
      ? await gh(`https://api.github.com/repos/${env.GITHUB_REPO}/issues/${open}/comments`, buildComment(item, report.manager, report.sender))
      : await gh(`https://api.github.com/repos/${env.GITHUB_REPO}/issues`, buildIssue(item, report.manager, g.key, report.sender));
    if (!res.ok) { failed = res.status; break; }
    let number = open;
    if (!number) { try { number = (await res.json()).number; } catch { number = null; } }
    if (g.key && number) dir.set(g.key, number);
    for (const i of g.items) { done.push(i.ref); numbers.push(number); }
  }
  if (!done.length) return json(502, { ok: false, error: `github ${failed}` });
  return json(200, { ok: !failed, done, numbers });
}

export default { fetch: (request, env) => handle(request, env) };
