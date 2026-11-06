// Peon Fehlerberichte: Cloudflare Worker zwischen Peon Manager und GitHub.
// Nimmt Fehler und Rueckmeldungen ohne Anmeldung an, prueft sie und legt je Eintrag ein Issue an. Der GitHub-Token liegt
// nur hier (Geheimnis GITHUB_TOKEN), nie im Manager. Einrichtung: README.md in diesem Ordner.
// Die IP-Adresse wird nur als Pruefsumme fuer die Sperre gegen zu viele Anfragen genutzt und nach einer Stunde verworfen.

const MAX_BODY = 64 * 1024;
const MAX_ITEMS = 20;              // Der Manager schickt nicht mehr, Cloudflare erlaubt je Anfrage nur begrenzt viele Abrufe
const LIMIT_PER_IP = 5;            // Sendungen je Stunde und Adresse
const LIMIT_TOTAL = 30;            // Sendungen je Stunde insgesamt
const LIMIT_SECONDS = 3600;

const KINDS = { bug: ['Fehler', 'fehler'], improve: ['Verbesserung', 'verbesserung'], idea: ['Neue Idee', 'idee'], other: ['Sonstiges', 'sonstiges'] };
const PRIOS = { low: 'Niedrig', mid: 'Mittel', high: 'Hoch' };
const ADDON = /^Peon(_\w+)?$/;

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
  return { manager: plain(str(data.manager, 40)), items };
}

export function buildIssue(i, manager) {
  const from = `Peon Manager ${manager || '?'}`;
  if (i.type === 'error') {
    const head = `${i.addon} ${i.version} | ${i.where} | ${i.n}x | zuletzt ${utc(i.last)} | Build ${i.build || '?'} | ${i.source}`;
    const lines = [head, i.msg];
    if (i.stack) lines.push('', i.stack);
    if (i.note) lines.push('', 'Notiz:', i.note);
    return { title: plain(`${i.addon}${i.version ? ` ${i.version}` : ''}: ${i.where || 'Fehler'}`, 120), labels: ['fehler'],
      body: `${from}\n\n\`\`\`text\n${fence(lines.join('\n'))}\n\`\`\`` };
  }
  const [kind, label] = KINDS[i.kind];
  const head = `${kind} | ${i.module} ${i.version} | ${i.area} | Priorität ${PRIOS[i.prio]} | ${utc(i.t)} | aus ${i.origin === 'game' ? 'dem Spiel' : 'dem Manager'}`;
  const where = [i.zone && `Zone: ${i.zone}`, i.market && `Markt: ${i.market}`].filter(Boolean);
  return { title: `[${kind}] ${plain(`${i.module.replace(/^Peon_/, '')}: ${i.text}`, 100)}`, labels: [label],
    body: `${from}\n\n\`\`\`text\n${fence([head, ...where, '', i.text].join('\n'))}\n\`\`\`` };
}

async function sha256(text) {
  const d = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text));
  return [...new Uint8Array(d)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

// Zaehler im Cache von Cloudflare. Er gilt je Rechenzentrum, das reicht als Bremse. Rueckgabe: true, wenn noch frei
async function allow(cache, name, max) {
  if (!cache) return true;
  const key = new Request(`https://peon-fehler.invalid/zaehler/${name}`);
  const hit = await cache.match(key);
  const n = hit ? Number(await hit.text()) || 0 : 0;
  if (n >= max) return false;
  await cache.put(key, new Response(String(n + 1), { headers: { 'Cache-Control': `max-age=${LIMIT_SECONDS}` } }));
  return true;
}

export async function handle(request, env, { fetchImpl = fetch, cache = globalThis.caches && globalThis.caches.default } = {}) {
  if (request.method !== 'POST' || new URL(request.url).pathname !== '/bericht') return json(404, { ok: false, error: 'not found' });
  const raw = await request.text();
  if (raw.length > MAX_BODY) return json(413, { ok: false, error: 'too large' });
  let data;
  try { data = JSON.parse(raw); } catch { return json(400, { ok: false, error: 'invalid json' }); }
  const report = cleanReport(data);
  if (!report) return json(400, { ok: false, error: 'invalid report' });

  const ip = await sha256(request.headers.get('CF-Connecting-IP') || 'unbekannt');
  if (!(await allow(cache, `ip-${ip}`, LIMIT_PER_IP)) || !(await allow(cache, 'gesamt', LIMIT_TOTAL))) {
    return json(429, { ok: false, error: 'too many reports' });
  }

  // Nacheinander anlegen und beim ersten Fehler aufhoeren: Was bestaetigt ist, loescht der Manager, der Rest bleibt bei ihm
  const done = [], numbers = [];
  let failed = null;
  for (const item of report.items) {
    const res = await fetchImpl(`https://api.github.com/repos/${env.GITHUB_REPO}/issues`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${env.GITHUB_TOKEN}`, Accept: 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28', 'User-Agent': 'peon-fehler-worker', 'Content-Type': 'application/json',
      },
      body: JSON.stringify(buildIssue(item, report.manager)),
    });
    if (!res.ok) { failed = res.status; break; }
    const issue = await res.json();
    done.push(item.ref);
    numbers.push(issue.number);
  }
  if (!done.length) return json(502, { ok: false, error: `github ${failed}` });
  return json(200, { ok: !failed, done, numbers });
}

export default { fetch: (request, env) => handle(request, env) };
