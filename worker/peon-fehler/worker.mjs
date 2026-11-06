// Peon Fehlerberichte: Cloudflare Worker zwischen Peon Manager und GitHub.
// Nimmt Berichte ohne Anmeldung an, prueft sie und legt je Bericht ein Issue an. Der GitHub-Token liegt nur hier
// (Geheimnis GITHUB_TOKEN), nie im Manager. Einrichtung: README.md in diesem Ordner.
// Die IP-Adresse wird nur als Prueftsumme fuer die Sperre gegen zu viele Anfragen genutzt und nach einer Stunde verworfen.

const MAX_BODY = 64 * 1024;
const MAX_ISSUE = 60000;           // GitHub erlaubt 65536 Zeichen
const MAX_ERRORS = 100;
const LIMIT_PER_IP = 5;            // Berichte je Stunde und Adresse
const LIMIT_TOTAL = 30;            // Berichte je Stunde insgesamt
const LIMIT_SECONDS = 3600;

const json = (status, data) => new Response(JSON.stringify(data), { status, headers: { 'Content-Type': 'application/json' } });
const str = (v, max) => (typeof v === 'string' ? v.slice(0, max) : '');
const num = (v) => (Number.isFinite(v) && v >= 0 ? Math.floor(v) : 0);
const plain = (s) => s.replace(/[^\p{L}\p{N} ._:+-]/gu, '').slice(0, 80);
// Text steht im Issue in einem Codeblock: kann ihn nicht verlassen und niemanden per @ benachrichtigen
const fence = (s) => s.replace(/`{3,}/g, "'''");

// Eingang pruefen und auf bekannte Felder kuerzen. Rueckgabe: Bericht oder null
export function cleanReport(data) {
  if (!data || data.fmt !== 1 || !Array.isArray(data.errors)) return null;
  if (data.errors.length < 1 || data.errors.length > MAX_ERRORS) return null;
  const errors = [];
  for (const e of data.errors) {
    if (!e || typeof e !== 'object') return null;
    const addon = str(e.addon, 60), msg = str(e.msg, 1000);
    if (!/^Peon(_\w+)?$/.test(addon) || !msg) return null;
    errors.push({ addon, msg, version: plain(str(e.version, 40)), build: plain(str(e.build, 40)), where: plain(str(e.where, 80)),
      source: plain(str(e.source, 20)), stack: str(e.stack, 1500), first: num(e.first), last: num(e.last), n: num(e.n) || 1 });
  }
  return { manager: plain(str(data.manager, 40)), omitted: num(data.omitted), errors };
}

export function buildIssue(report) {
  const first = report.errors[0];
  const more = report.errors.length > 1 ? `, +${report.errors.length - 1} weitere` : '';
  const title = `${first.addon}${first.version ? ` ${first.version}` : ''}: ${first.where || 'Fehler'}${more}`;
  const parts = [`Peon Manager ${report.manager || '?'}, ${report.errors.length} Fehler${report.omitted ? `, ${report.omitted} weitere passten nicht in den Bericht` : ''}`];
  for (const e of report.errors) {
    const when = e.last ? new Date(e.last * 1000).toISOString().slice(0, 16).replace('T', ' ') : '?';
    const head = `${e.addon} ${e.version} | ${e.where} | ${e.n}x | zuletzt ${when} UTC | Build ${e.build || '?'} | ${e.source}`;
    parts.push(`\`\`\`text\n${fence(`${head}\n${e.msg}${e.stack ? `\n\n${e.stack}` : ''}`)}\n\`\`\``);
  }
  let body = parts.join('\n\n');
  if (body.length > MAX_ISSUE) body = `${body.slice(0, MAX_ISSUE)}\n\`\`\`\n\n(gekürzt)`;
  return { title, body };
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

  const res = await fetchImpl(`https://api.github.com/repos/${env.GITHUB_REPO}/issues`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${env.GITHUB_TOKEN}`, Accept: 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28', 'User-Agent': 'peon-fehler-worker', 'Content-Type': 'application/json',
    },
    body: JSON.stringify(buildIssue(report)),
  });
  if (!res.ok) return json(502, { ok: false, error: `github ${res.status}` });
  const issue = await res.json();
  return json(200, { ok: true, number: issue.number });
}

export default { fetch: (request, env) => handle(request, env) };
