'use strict';
// Bildschirmfotos der Oberflaeche mit Beispieldaten (Chromium aus Playwright, window.peon nachgebaut)
const { chromium } = require('playwright-core');
const http = require('node:http'), fs = require('node:fs'), path = require('node:path');
const mock = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const out = process.argv[3];
const dist = path.join(__dirname, '..', '..', 'dist');
const types = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.woff2': 'font/woff2', '.woff': 'font/woff', '.png': 'image/png' };
const srv = http.createServer((req, res) => {
  const p = path.join(dist, decodeURIComponent(req.url.split('?')[0]).replace(/^\/$/, '/index.html'));
  fs.readFile(p, (e, b) => { if (e) { res.writeHead(404); res.end(); return; } res.writeHead(200, { 'Content-Type': types[path.extname(p)] || 'application/octet-stream' }); res.end(b); });
});
srv.listen(0, async () => {
  const port = srv.address().port;
  const browser = await chromium.launch({ executablePath: process.env.PW_CHROME || undefined });
  const errors = [];
  for (const theme of ['dark', 'light']) {
    const page = await browser.newPage({ viewport: { width: 1280, height: 820 } });
    page.on('pageerror', (e) => errors.push(String(e)));
    page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
    const settings = { ...mock.settings, theme };
    await page.addInitScript(({ ov, st, now, items, item, retention, chances }) => {
      Date.now = () => now * 1000;
      const favs = new Set(['2770']);
      const shop = { hasLedger: true, lists: [{ id: 'a', name: 'Erze', pct: 10, items: [
        { key: '2770', item: 2770, name: 'Kupfererz', quality: 1, wish: 40, max: null, limit: 118, rule: 118, cheapest: 110, median: 130, qty: 300, hits: 85, stock: 12 },
        { key: '2589', item: 2589, name: 'Leinenstoff', quality: 1, wish: null, max: 45, limit: 45, rule: 60, cheapest: 70, median: 75, qty: 900, hits: 0, stock: 3 } ] }, { id: 'b', name: 'Für den Twink', pct: 25, items: [] }] };
      window.peon = {
        items: async () => items, item: async (m, k, r) => (item[k] || item['2770'])[r] || (item[k] || item['2770'])['30d'],
        itemInfo: async () => ({ state: 'ok', tip: { name: 'Löwenherzhelm', quality: 4, sell: 21894, source: 'classic', lines: [
          { l: 'Gegenstandsstufe 61', c: 'level' }, { l: 'Wird beim Anlegen gebunden' }, { l: 'Kopf', r: 'Platte' }, { l: '565 Rüstung' }, { l: '+18 Stärke' },
          { l: '+20 Trefferwert', c: 'good' }, { l: 'Anlegen: Erhöht Eure Trefferchance um 2%.', c: 'good' }, { l: 'Benötigt Stufe 56' }, { l: 'Haltbarkeit 100 / 100' },
          { l: 'Ornat des Beispiels (0/8)', c: 'set' }, { l: '(3) Set: Erhöht den Schaden.', c: 'muted' } ] } }),
        favorites: async () => [...favs], setFavorite: async (k, on) => { if (on) favs.add(k); else favs.delete(k); return [...favs]; },
        shopView: async () => shop, shopBuyable: async () => shop.lists[0].items.filter((x) => x.hits > 0).map((x) => ({ ...x, list: 'Erze' })), shopLists: async () => shop.lists.map((l) => ({ id: l.id, name: l.name, on: false })),
        shopNewList: async () => 'x', shopAdd: async () => true, shopRemove: async () => true, shopSet: async () => true, shopDeleteList: async () => true, shopUpdateList: async () => true, addons: async () => ({ wowValid: true, wowRunning: false }), onOpenItem: () => {},
        updateInfo: async () => ({ manager: null, addons: [], count: 0, ready: true, popup: false }), updatesShown: async () => true,
        retention: async (d) => retention[d == null ? 30 : d] || retention[30],
        chanceView: async () => chances.view, marketOverview: async () => chances.market, successView: async () => chances.success,
        chanceRules: async () => chances.rules, chanceRatings: async () => ({ list: [], reasons: [] }), overrides: async () => [], fests: async () => [],
        chanceItem: async (m, k) => ({ key: k, checks: [], forecast: null, override: {} }),
        overview: async () => ov, settings: async () => st,
        blizzardState: async () => ({ saved: false, region: 'eu', report: null, watch: null }), blizzardHouses: async () => ({ saved: false, houses: [] }),
        saveSettings: async (p) => ({ ...st, ...p }), pickFolder: async () => null, openFolder: async () => {}, openLink: async () => {}, onChanged: () => {},
      };
    }, { ov: mock.overview, st: settings, now: mock.now, items: mock.items, item: mock.item, retention: mock.retention, chances: mock.chances });
    await page.goto(`http://127.0.0.1:${port}/index.html`);
    await page.waitForTimeout(700);
    await page.screenshot({ path: `${out}/uebersicht_${theme}.png`, fullPage: true });
    if (theme === 'dark') {
      await page.click('nav >> text=Einkaufen'); await page.waitForTimeout(300);
      await page.screenshot({ path: `${out}/einkaufsliste.png` });
      await page.click('nav >> text=Beobachten'); await page.waitForTimeout(300);
      await page.screenshot({ path: `${out}/favoriten.png` });
      await page.click('nav >> text=Markt'); await page.waitForTimeout(400);
      await page.screenshot({ path: `${out}/gegenstaende.png` });
      await page.hover('.body .tr >> nth=2'); await page.waitForTimeout(500);
      await page.screenshot({ path: `${out}/gegenstaende_tooltip.png` });
      await page.mouse.move(5, 5);
      await page.fill('input[aria-label=Suchen]', 'schwert'); await page.waitForTimeout(200);
      await page.screenshot({ path: `${out}/gegenstaende_suche.png` });
      await page.fill('input[aria-label=Suchen]', ''); await page.waitForTimeout(200);
      await page.click('.body .tr >> nth=0'); await page.waitForTimeout(900);
      await page.screenshot({ path: `${out}/gegenstand.png`, fullPage: true });
      await page.click('.seg >> text=Alles'); await page.waitForTimeout(700);
      await page.screenshot({ path: `${out}/gegenstand_alles.png`, fullPage: true });
      await page.click('[aria-label=Zurück]'); await page.waitForTimeout(400);
      await page.screenshot({ path: `${out}/zurueck.png` });
      await page.click('nav >> text=Radar'); await page.waitForTimeout(500);
      await page.screenshot({ path: `${out}/radar_aufkauf.png`, fullPage: false });
      for (const [t, f] of [['Händler', 'haendler'], ['Fallend', 'fallend'], ['Steigend', 'steigend'], ['Lohnend', 'lohnend']]) {
        await page.click(`.tabs >> text=${t}`); await page.waitForTimeout(300);
        await page.screenshot({ path: `${out}/chancen_${f}.png`, fullPage: false });
      }
      await page.click('.tabs >> text=Wiederverkauf'); await page.waitForTimeout(200);
      await page.click('.tbl tbody tr >> nth=0'); await page.waitForTimeout(700);
      await page.screenshot({ path: `${out}/gegenstand_aus_chancen.png`, fullPage: true });
      await page.click('nav >> text=Datenlage'); await page.waitForTimeout(300);
      await page.screenshot({ path: `${out}/quellen.png`, fullPage: true });
      await page.click('nav >> text=Einstellungen'); await page.waitForTimeout(400);
      await page.screenshot({ path: `${out}/einstellungen.png`, fullPage: true });
    }
    await page.close();
  }
  // leerer Zustand
  const page = await browser.newPage({ viewport: { width: 1280, height: 820 } });
  await page.addInitScript(({ ov, st }) => {
    window.peon = { overview: async () => ({ ...ov, markets: [], back: null, log: [], game: { files: [] }, wowOk: false }), settings: async () => st, onChanged: () => {}, onOpenItem: () => {}, updateInfo: async () => ({ manager: null, addons: [], count: 0, ready: true, popup: false }), favorites: async () => [], addons: async () => ({ wowValid: false }), shopView: async () => ({ lists: [] }), blizzardState: async () => ({ saved: false, region: 'eu', report: null, watch: null }), blizzardHouses: async () => ({ saved: false, houses: [] }) };
  }, { ov: mock.overview, st: mock.settings });
  await page.goto(`http://127.0.0.1:${port}/index.html`);
  await page.waitForTimeout(500);
  await page.screenshot({ path: `${out}/leer.png` });
  await browser.close();
  srv.close();
  console.log(errors.length ? 'FEHLER:\n' + errors.join('\n') : 'keine Fehler im Browser');
});
