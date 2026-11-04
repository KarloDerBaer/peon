'use strict';
// Peon Manager - Pruefabruf "Blizzard-API": Liefert die Schnittstelle Auktionsdaten fuer Forever?
// Die Bereiche (namespace) dynamic-forever-{region} gibt es seit Anfang November 2026, sie sind nicht dokumentiert.
// Eingelesen wird noch nichts (Peon_Client_Design.md 5.5). Der Bericht enthaelt nur Stufen, Antwort-Codes und Beispiel-Angebote.
// Zugang: Jeder Nutzer legt einen eigenen an. Er liegt nur verschluesselt im Datenordner und geht nur an Blizzard.

const fs = require('node:fs');

const REGIONS = ['eu', 'us', 'tw'];    // Kein Forever-Bereich fuer kr (Stand 02.11.2026)
const OAUTH = 'https://oauth.battle.net';
const MAX_REALMS = 3;                  // so viele Realm-Gruppen probieren, jede Stufe ist eine Abfrage bei Blizzard
const TIMEOUT_MS = 60000;

const TEXT = {
  auctions: 'Blizzard liefert Auktionsdaten für Forever. Der Einleser kann gebaut werden.',
  empty: 'Die Abfrage funktioniert, die Listen sind aber leer. Nach dem Start erneut prüfen.',
  'no-listings': 'Es gibt eine Liste der Auktionshäuser, die Angebote fehlen aber. So verhalten sich auch Classic Era und Anniversary.',
  'no-auctions': 'Die Forever-Bereiche antworten, aber es gibt keine Auktionsdaten.',
  'no-namespace': 'Blizzard kennt den Forever-Bereich für diese Region nicht.',
  'bad-key': 'Blizzard lehnt den Zugang ab. Bitte Client-ID und Client-Secret prüfen.',
  network: 'Blizzard ist nicht erreichbar. Bitte die Verbindung prüfen und später erneut versuchen.',
};

// Liste der Angebote aus einer Antwort, null wenn die Antwort keine hat
const offersOf = (json) => (json && Array.isArray(json.auctions) && json.auctions.some((a) => a && a.item) ? json.auctions : (json && Array.isArray(json.auctions) && !json.auctions.length ? [] : null));
// Liste der Auktionshaeuser, zum Beispiel { auctions: [{ id: 2, name: 'Alliance' }] }
const housesOf = (json) => (json && Array.isArray(json.auctions) ? json.auctions.filter((a) => a && !a.item && a.id != null) : []);
const idFromHref = (href) => { const m = /\/connected-realm\/(\d+)/.exec(String(href)); return m ? Number(m[1]) : null; };

async function probe({ clientId, clientSecret, region = 'eu' }, { fetchImpl = fetch, now = () => Math.floor(Date.now() / 1000), oauthBase = OAUTH, apiBase } = {}) {
  if (!REGIONS.includes(region)) throw new Error('Unbekannte Region');
  const base = apiBase || `https://${region}.api.blizzard.com`;
  const namespace = `dynamic-forever-${region}`;
  const report = { t: now(), region, namespace, result: null, text: '', steps: [], sample: null };
  const finish = (result) => { report.result = result; report.text = TEXT[result]; return report; };
  const signal = () => AbortSignal.timeout(TIMEOUT_MS);

  let token;
  try {
    const r = await fetchImpl(`${oauthBase}/token`, { method: 'POST', signal: signal(), body: new URLSearchParams({ grant_type: 'client_credentials' }),
      headers: { Authorization: `Basic ${Buffer.from(`${clientId}:${clientSecret}`).toString('base64')}`, 'Content-Type': 'application/x-www-form-urlencoded' } });
    report.steps.push({ name: 'Anmeldung bei Blizzard', status: r.status });
    if (r.status === 400 || r.status === 401 || r.status === 403) return finish('bad-key');
    if (!r.ok) return finish('network');
    token = (await r.json()).access_token;
    if (!token) return finish('bad-key');
  } catch {
    report.steps.push({ name: 'Anmeldung bei Blizzard', status: null });
    return finish('network');
  }

  // Eine Stufe: Der Code kommt in den Bericht, Fehlertexte von Blizzard nicht
  async function get(name, apiPath) {
    const step = { name, path: apiPath, status: null };
    report.steps.push(step);
    try {
      const r = await fetchImpl(`${base}${apiPath}?namespace=${namespace}&locale=de_DE`, { signal: signal(), headers: { Authorization: `Bearer ${token}` } });
      step.status = r.status;
      if (!r.ok) return null;
      return await r.json();
    } catch { return null; }
  }

  const realms = await get('Realms', '/data/wow/realm/index');
  const groups = await get('Realm-Gruppen', '/data/wow/connected-realm/index');
  if (realms) report.steps[report.steps.length - 2].note = `${(realms.realms || []).length} Realms`;
  if (!realms && !groups) return finish(report.steps.some((s) => s.status === null || s.status >= 500) ? 'network' : 'no-namespace');

  // Realm-Gruppen, sonst die Realm-Nummern (ist die Gruppe noch nicht freigeschaltet, passen sie oft)
  let ids = ((groups && groups.connected_realms) || []).map((c) => idFromHref(c.href)).filter((x) => x != null);
  if (!ids.length) ids = ((realms && realms.realms) || []).map((r) => r.id).filter((x) => x != null);

  let houses = 0, empty = false;
  const found = (house, offers, step) => {
    step.note = `${offers.length} Angebote`;
    report.sample = { house, count: offers.length, fields: Object.keys(offers[0]), offers: offers.slice(0, 3) };
  };
  for (const id of ids.slice(0, MAX_REALMS)) {
    const list = housesOf(await get(`Auktionshäuser von ${id}`, `/data/wow/connected-realm/${id}/auctions/index`));
    houses += list.length;
    for (const h of list) {
      const offers = offersOf(await get(`Angebote von ${id}, Haus ${h.id}`, `/data/wow/connected-realm/${id}/auctions/${h.id}`));
      if (offers && offers.length) { found(h.id, offers, report.steps[report.steps.length - 1]); return finish('auctions'); }
      if (offers) empty = true;
    }
    // Aufbau wie bei Retail: alle Angebote einer Gruppe ohne Auktionshaus
    const offers = offersOf(await get(`Angebote von ${id}`, `/data/wow/connected-realm/${id}/auctions`));
    if (offers && offers.length) { found(null, offers, report.steps[report.steps.length - 1]); return finish('auctions'); }
    if (offers) empty = true;
  }
  const com = offersOf(await get('Massenware', '/data/wow/auctions/commodities'));
  if (com && com.length) { found(null, com, report.steps[report.steps.length - 1]); return finish('auctions'); }
  if (com) empty = true;
  if (empty) return finish('empty');
  return finish(houses ? 'no-listings' : 'no-auctions');
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

module.exports = { probe, BlizzardAccess, REGIONS, TEXT };
