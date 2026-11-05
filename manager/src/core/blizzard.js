'use strict';
// Peon Manager - Blizzard-API fuer Forever. Allgemeiner Baustein: Zugang, Anmeldung, Abfragen, Pruefabruf.
// Forever hat keine Realms: Die Bereiche (namespace) dynamic-forever-{region} sind nach Regelsatz und Auktionshaus aufgebaut,
// von Blizzard nicht dokumentiert. Geprueftes steht in docs/konzepte/manager/Peon_Blizzard_API.md.
// Der Pruefbericht enthaelt nur Stufen, Antwort-Codes und Beispiel-Angebote. Eingelesen wird in blizzard-import.js.
// Zugang: Jeder Nutzer legt einen eigenen an. Er liegt nur verschluesselt im Datenordner und geht nur an Blizzard.

const fs = require('node:fs');

const REGIONS = ['eu', 'us', 'tw'];    // Kein Forever-Bereich fuer kr (Stand 02.11.2026), tw noch ungeprueft
const OAUTH = 'https://oauth.battle.net';
const TIMEOUT_MS = 60000;

const TEXT = {
  auctions: 'Der Zugang funktioniert, Blizzard liefert Auktionsdaten für Forever.',
  empty: 'Die Abfrage funktioniert, die Auktionshäuser sind aber leer.',
  'no-listings': 'Es gibt eine Liste der Auktionshäuser, die Angebote fehlen aber.',
  'no-auctions': 'Die Forever-Bereiche antworten, aber es gibt keine Auktionsdaten.',
  'no-namespace': 'Blizzard kennt den Forever-Bereich für diese Region nicht.',
  'bad-key': 'Blizzard lehnt den Zugang ab. Bitte Client-ID und Client-Secret prüfen.',
  network: 'Blizzard ist nicht erreichbar. Bitte die Verbindung prüfen und später erneut versuchen.',
};

// Liste aus einer Antwort: der erwartete Name, sonst die erste Liste mit Eintraegen, die eine Nummer haben
function listOf(json, key) {
  if (!json || typeof json !== 'object') return [];
  if (Array.isArray(json[key])) return json[key];
  const other = Object.values(json).find((v) => Array.isArray(v) && v.some((x) => x && x.id != null));
  return other || [];
}
// Angebote einer Antwort. Ein Haus ohne Angebote antwortet nur mit einer Beschreibung (id, name, Links).
const offersOf = (json) => (json && Array.isArray(json.auctions) ? json.auctions.filter((a) => a && a.item) : []);
const failed = (status) => status == null || status === 429 || status >= 500;
const auctionPath = (ruleset, house, commodities) => `/data/wow/ruleset/${ruleset}/auctions/${house}${commodities ? '/commodities' : ''}`;

class BlizzardClient {
  constructor({ clientId, clientSecret, region = 'eu' }, { fetchImpl = fetch, now = () => Math.floor(Date.now() / 1000), oauthBase = OAUTH, apiBase } = {}) {
    if (!REGIONS.includes(region)) throw new Error('Unbekannte Region');
    Object.assign(this, { clientId, clientSecret, region, fetchImpl, now, oauthBase, apiBase });
    this.token = null;
    this.tokenUntil = 0;
  }

  // Ergebnis: ok, status, reason (bad-key oder network)
  async login() {
    this.token = null;
    try {
      const r = await this.fetchImpl(`${this.oauthBase}/token`, { method: 'POST', signal: AbortSignal.timeout(TIMEOUT_MS), body: new URLSearchParams({ grant_type: 'client_credentials' }),
        headers: { Authorization: `Basic ${Buffer.from(`${this.clientId}:${this.clientSecret}`).toString('base64')}`, 'Content-Type': 'application/x-www-form-urlencoded' } });
      if (r.status === 400 || r.status === 401 || r.status === 403) return { ok: false, status: r.status, reason: 'bad-key' };
      if (!r.ok) return { ok: false, status: r.status, reason: 'network' };
      const j = await r.json();
      if (!j.access_token) return { ok: false, status: r.status, reason: 'bad-key' };
      this.token = j.access_token;
      this.tokenUntil = this.now() + (Number(j.expires_in) || 3600) - 60;
      return { ok: true, status: r.status };
    } catch { return { ok: false, status: null, reason: 'network' }; }
  }

  // Eine Abfrage. kind: dynamic oder static. since: Last-Modified des letzten Stands, Antwort 304 wenn unveraendert.
  // Ergebnis: status (null: keine Antwort), lastModified, bytes, json. Fehlertexte von Blizzard kommen nicht mit.
  async get(apiPath, { kind = 'dynamic', since, region = this.region, namespace = `${kind}-forever-${region}` } = {}) {
    const empty = { status: null, lastModified: null, bytes: 0, json: null };
    if (!this.token || this.now() >= this.tokenUntil) {
      const l = await this.login();
      if (!l.ok) return { ...empty, loginFailed: l.reason };
    }
    const base = this.apiBase || `https://${region}.api.blizzard.com`;
    const url = `${base}${apiPath}?namespace=${namespace}&locale=de_DE`;
    const ask = () => this.fetchImpl(url, { signal: AbortSignal.timeout(TIMEOUT_MS), headers: { Authorization: `Bearer ${this.token}`, ...(since ? { 'If-Modified-Since': since } : {}) } });
    try {
      let r = await ask();
      if (r.status === 401) {   // Anmeldung abgelaufen: einmal neu anmelden
        const l = await this.login();
        if (!l.ok) return { ...empty, loginFailed: l.reason };
        r = await ask();
      }
      const res = { status: r.status, lastModified: r.headers.get('last-modified'), bytes: 0, json: null };
      if (!r.ok) return res;
      const text = await r.text();
      res.bytes = Buffer.byteLength(text);
      res.json = JSON.parse(text);
      return res;
    } catch { return empty; }
  }
}

// Pruefabruf: Anmeldung, Regelsaetze, Auktionshaeuser, dann das erste Haus mit Angeboten
async function probe(access, options = {}) {
  const client = new BlizzardClient(access, options);
  const report = { t: client.now(), region: client.region, namespace: `dynamic-forever-${client.region}`, result: null, text: '', steps: [], sample: null };
  const finish = (result) => { report.result = result; report.text = TEXT[result]; return report; };

  const login = await client.login();
  report.steps.push({ name: 'Anmeldung bei Blizzard', status: login.status });
  if (!login.ok) return finish(login.reason);

  async function get(name, apiPath) {
    const step = { name, path: apiPath, status: null };
    report.steps.push(step);
    const r = await client.get(apiPath);
    step.status = r.status;
    return { ...r, step };
  }

  const rs = await get('Regelsätze', '/data/wow/ruleset/index');
  if (!rs.json) return finish(failed(rs.status) ? 'network' : 'no-namespace');
  const rulesets = listOf(rs.json, 'rulesets').filter((x) => x && x.id != null);
  rs.step.note = `${rulesets.length} Regelsätze`;
  if (!rulesets.length) return finish('no-auctions');
  report.rulesets = rulesets.map((x) => ({ id: x.id, name: x.name }));

  // Der Regelsatz im Abrufweg aendert nichts, die Hausnummer bestimmt den Markt
  const ruleset = rulesets[0].id;
  const idx = await get('Auktionshäuser', `/data/wow/ruleset/${ruleset}/auctions/index`);
  if (!idx.json) return finish(failed(idx.status) ? 'network' : 'no-auctions');
  const houses = listOf(idx.json, 'auctions').filter((x) => x && x.id != null);
  idx.step.note = `${houses.length} Auktionshäuser`;
  if (!houses.length) return finish('no-auctions');
  report.houses = houses.map((x) => ({ id: x.id, name: x.name }));

  let answered = false, broken = false;
  const part = (r) => {
    if (!r.json) { if (failed(r.status)) broken = true; return []; }
    answered = true;
    const offers = offersOf(r.json);
    r.step.note = `${offers.length} Angebote`;
    return offers;
  };
  const brief = (offers) => ({ count: offers.length, fields: offers.length ? Object.keys(offers[0]) : [], offers: offers.slice(0, 3) });
  for (const h of houses) {
    const one = await get(`Haus ${h.id}, Einzelgegenstände`, auctionPath(ruleset, h.id, false));
    const mass = await get(`Haus ${h.id}, Massenware`, auctionPath(ruleset, h.id, true));
    const a = part(one), b = part(mass);
    if (a.length || b.length) {
      const main = a.length ? a : b;
      report.sample = { house: h.id, lastModified: (a.length ? one : mass).lastModified, ...brief(main), commodities: brief(b) };
      return finish('auctions');
    }
  }
  if (broken && !answered) return finish('network');
  return finish(answered ? 'empty' : 'no-listings');
}

// Zugang und letzter Bericht im Datenordner. encrypt/decrypt kommen vom Hauptteil (Windows-Schutz je Benutzer).
class BlizzardAccess {
  constructor({ keyFile, reportFile, encrypt, decrypt, available = () => true }) {
    Object.assign(this, { keyFile, reportFile, encrypt, decrypt, available });
  }

  save({ clientId, clientSecret, region = 'eu' } = {}) {
    const id = String(clientId || '').trim(), secret = String(clientSecret || '').trim();
    if (!id || !secret) throw new Error('Bitte Client-ID und Client-Secret eintragen.');
    if (!REGIONS.includes(region)) throw new Error('Unbekannte Region');
    // Nie unverschluesselt ablegen
    if (!this.available()) throw new Error('Windows kann den Zugang auf diesem Rechner nicht verschlüsseln, er wird deshalb nicht gespeichert.');
    const tmp = `${this.keyFile}.neu`;
    fs.writeFileSync(tmp, this.encrypt(JSON.stringify({ clientId: id, clientSecret: secret, region })));
    fs.renameSync(tmp, this.keyFile);
    return this.state();
  }

  // Nur fuer den Abruf im Hauptteil, geht nie an die Oberflaeche. null: nichts gespeichert oder nicht lesbar (anderer Rechner)
  load() {
    try { return JSON.parse(this.decrypt(fs.readFileSync(this.keyFile))); } catch { return null; }
  }

  clear() {
    fs.rmSync(this.keyFile, { force: true });
    return this.state();
  }

  saveReport(report) {
    fs.writeFileSync(this.reportFile, JSON.stringify(report, null, 1));
    return report;
  }

  state() {
    const c = this.load();
    let report = null;
    try { report = JSON.parse(fs.readFileSync(this.reportFile, 'utf8')); } catch { /* noch kein Bericht */ }
    return { saved: !!c, region: c ? c.region : 'eu', idEnd: c ? c.clientId.slice(-4) : null, unreadable: !c && fs.existsSync(this.keyFile), report };
  }
}

module.exports = { probe, BlizzardClient, BlizzardAccess, REGIONS, TEXT, listOf, offersOf, auctionPath, failed };
