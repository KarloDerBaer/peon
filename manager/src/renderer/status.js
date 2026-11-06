// Stand des Datenwegs: Spiel und Blizzard-API liefern an den Manager, der Manager gibt Werte an Broker zurueck.
// Die Lampe zeigt, ob wirklich etwas ankommt, nicht nur wie alt eine Datei ist:
// ok = in Ordnung, alt = aelter oder noch im Aufbau, bad = Fehler, aus = noch nichts da.
import { ago, num, bytes, freshness, pl } from './util.js';

export function gameStation(data, now) {
  const files = data.game.files || [];
  if (!files.length) return { key: 'spiel', title: 'Spiel', state: 'aus', fact: 'Keine Peon_Bridge.lua gefunden', time: 'Komplettscan im Spiel, dann „An Manager“' };
  const f = files.reduce((a, b) => (b.mtime > a.mtime ? b : a));
  return { key: 'spiel', title: 'Spiel', state: freshness(f.mtime, 3 * 86400, now),
    fact: f.entries ? `${pl(f.entries, 'Scan wartet', 'Scans warten')} in der WTF-Datei` : 'Nichts wartet, alles ist eingelesen',
    time: `Datei geschrieben ${ago(f.mtime, now)}. Neues kommt bei /reload oder beim Ausloggen.` };
}

export function apiStation(data, now) {
  const a = data.api;
  const base = { key: 'api', title: 'Blizzard-API' };
  if (!a || !a.selected) return { ...base, state: 'aus', fact: 'Kein Auktionshaus gewählt', time: 'Liefert stündlich alle Angebote, ganz ohne Spiel' };
  if (a.error) return { ...base, state: 'bad', fact: `Abruf fehlgeschlagen${a.error.status ? `, Antwort ${a.error.status}` : ''}`, time: a.last ? `Letzter Stand ${ago(a.last, now)}` : 'Noch kein Stand' };
  if (!a.last) return { ...base, state: 'aus', fact: pl(a.selected, 'Auktionshaus', 'Auktionshäuser'), time: 'Noch nicht abgerufen' };
  const left = Math.ceil((a.last + 3600 - now) / 60);
  return { ...base, state: freshness(a.last, 3 * 3600, now), fact: `${pl(a.selected, 'Auktionshaus', 'Auktionshäuser')}, ${pl(a.stands, 'Stand', 'Stände')}`,
    time: `Letzter Stand ${ago(a.last, now)}. ${left > 0 ? `Nächster in etwa ${left} Min.` : 'Der nächste wird jetzt erwartet.'}` };
}

export function managerStation(data, market, now) {
  const last = market && market.lastScan;
  return { key: 'manager', title: 'Manager', state: last ? freshness(last.t, 2 * 86400, now) : 'aus',
    fact: market ? `${pl(market.scans, 'Scan', 'Scans')}${market.stands ? `, ${pl(market.stands, 'API-Stand', 'API-Stände')}` : ''}, ${pl(market.lives, 'Live-Abfrage', 'Live-Abfragen')}` : 'Noch nichts gespeichert',
    time: `Datenbank ${bytes(data.dbSize)}, ${market ? pl(market.items, 'Gegenstand', 'Gegenstände') : 'keine Gegenstände'}. Liest Neues sofort ein.` };
}

export function brokerStation(data, now) {
  const b = data.back;
  const base = { key: 'broker', title: 'Zurück an Broker' };
  if (!b) return { ...base, state: 'aus', fact: 'Noch keine Werte geschrieben', time: 'Ab 3 Tagen mit Daten bekommt Broker übliche Preise' };
  const time = `Data.lua ${bytes(b.bytes)} ${ago(b.t, now)}. Wirkt nach /reload im Spiel.`;
  if (!b.items && !b.sales) return { ...base, state: 'alt', fact: 'Sammelt noch Daten', time: `Ab 3 Tagen mit Daten bekommt Broker übliche Preise. ${time}` };
  if (!b.items) return { ...base, state: 'alt', fact: `Absatz für ${pl(b.sales, 'Gegenstand', 'Gegenstände')}, üblicher Bereich folgt ab Tag 3`, time };
  return { ...base, state: freshness(b.t, 2 * 86400, now), fact: `Üblicher Bereich für ${num(b.items)}, Absatz für ${pl(b.sales || 0, 'Gegenstand', 'Gegenstände')}`, time };
}

export const LAMP_TITLE = { ok: 'in Ordnung', alt: 'älter oder noch im Aufbau', aus: 'noch keine Daten', bad: 'Fehler' };

// Ein Satz fuer die Uebersicht: das Wichtigste, das nicht stimmt, sonst "aktuell"
export function statusLine(data, market, now) {
  const api = apiStation(data, now), man = managerStation(data, market, now);
  if (api.state === 'bad') return { state: 'bad', text: `Blizzard-API: ${api.fact}` };
  if (man.state === 'aus') return { state: 'aus', text: 'Noch keine Daten eingelesen' };
  const when = market && market.lastScan ? ago(market.lastScan.t, now) : '';
  if (man.state === 'alt') return { state: 'alt', text: `Die Daten sind älter, letzter Stand ${when}` };
  return { state: 'ok', text: `Daten aktuell, letzter Stand ${when}` };
}
