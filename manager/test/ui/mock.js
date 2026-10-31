'use strict';
// Erzeugt Beispieldaten fuer die Bildschirmfotos: echter Scan, zweiter Scan einen Tag spaeter (Preise leicht veraendert),
// mehrere aeltere Scans fuer den Verlauf, eine AHledger-Tabelle. Ausgabe: JSON fuer window.peon.
const fs = require('node:fs'), os = require('node:os'), path = require('node:path');
const { Service } = require('../../src/core/service');
const { parseLua } = require('../../src/core/lua');
const real = fs.readFileSync(path.join(__dirname, '..', 'fixtures', 'Peon_Bridge_echt.lua'));
const q = parseLua(real).PeonBridgeDB.queue[0];
const wow = fs.mkdtempSync(path.join(os.tmpdir(), 'w-'));
const sv = path.join(wow, 'WTF', 'Account', '123456789#2', 'SavedVariables'); fs.mkdirSync(sv, { recursive: true });
const ad = path.join(wow, 'Interface', 'AddOns', 'Peon_Bridge'); fs.mkdirSync(ad, { recursive: true }); fs.writeFileSync(path.join(ad, 'Peon_Bridge.toc'), 'x');
const { toLua } = require('../../src/core/lua');
let seed = 3; const rnd = () => { seed = (seed * 16807) % 2147483647; return seed / 2147483647; };
function variant(t, k, drift) {
  const rows = q.rows.split('\n').filter(() => rnd() > 0.06).map((l) => {
    const f = l.split(';'); if (f[4] && Number(f[4]) > 0) f[4] = String(Math.max(1, Math.round(Number(f[4]) * (1 + (rnd() - 0.5) * drift)))); return f.join(';'); });
  return { ...q, id: `${t}-${k}`, t, rows: rows.join('\n'), offers: undefined, lines: rows.length };
}
const t0 = q.t;
const queue = [];
for (let k = 40; k >= 1; k--) queue.push(variant(t0 - k * 5.3 * 3600 - Math.round(rnd() * 7200), 10 + k, 0.35));
queue.push(q);
queue.push({ ...variant(t0 + 3 * 3600, 99, 0.9) });
fs.writeFileSync(path.join(sv, 'Peon_Bridge.lua'), 'PeonBridgeDB = ' + toLua({ queue, fmt: 1 }));
fs.copyFileSync(path.join(__dirname, '..', 'fixtures', 'Peon_Broker_echt.lua'), path.join(sv, 'Peon_Broker.lua'));
const now = t0 + 3 * 3600 + 600;
const fetchImpl = async () => ({ status: 200, ok: true, headers: new Map([['etag', '"a"']]), text: async () => 'AHL1|forever/normal/alliance/us|' + (now - 2400) + '|3\n35:1900:1900:1:3193:2400:500:10100:12\n117:5:5:54:18:10:1:90:85\n118:29:18:880:16:8:1:89:20961\n' });
const svc = new Service({ enable: ['broker-client'], dbDir: fs.mkdtempSync(path.join(os.tmpdir(), 'd-')), version: '0.1.0', now: () => now, fetchImpl });
svc.saveSettings({ wowDir: wow });
svc.broker.importGame();
// Haendlerpreise fuer einen Teil der Gegenstaende (kommen sonst erst mit Peon_Client 0.3.0)
for (const r of svc.broker.db.prepare("SELECT i.key, AVG(s.median) AS m FROM items i JOIN item_snap s ON s.item_key = i.key GROUP BY i.key").all()) {
  if (r.m && rnd() < 0.2) svc.broker.db.prepare('UPDATE items SET vendor = ? WHERE key = ?').run(Math.max(1, Math.round(r.m * (0.4 + rnd() * 0.5))), r.key);
}
svc.broker.importGame();
svc.saveSettings({ marketMap: { 'Classic Beta PvE / Alliance': { ext: 'forever.normal.alliance.us', confirmed: false } } });
svc.broker.fetchAhledger().then(() => {
  const ov = svc.overview();
  ov.wowDir = 'C:\\Program Files (x86)\\World of Warcraft\\_forever_'; ov.dbDir = 'C:\\Peon Manager\\DB';
  for (const f of ov.game.files) f.file = 'C:\\Program Files (x86)\\...\\Peon_Bridge.lua';
  const st = { ...svc.settings, wowDir: ov.wowDir };
  const M = 'Classic Beta PvE / Alliance';
  const items = svc.broker.itemList(M);
  const item = {};
  for (const key of ['2770', '3201:Barbarische Kriegsaxt des Bären']) {
    item[key] = {};
    for (const r of ['1d', '7d', '30d', '90d', 'all']) item[key][r] = svc.broker.itemDetail(M, key, r);
  }
  const chances = {};
  for (const d of [1, 3, 7, 14]) chances[d] = svc.broker.chances(M, d);
  const retention = {};
  for (const d of [7, 14, 21, 30, 45, 60, 90, 120, 180, 270, 365, 0]) retention[d] = svc.broker.retention(d);
  process.stdout.write(JSON.stringify({ overview: ov, settings: st, now, items, item, retention, chances }));
});
