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
      window.peon = {
        items: async () => items, item: async (m, k, r) => (item[k] || item['2770'])[r] || (item[k] || item['2770'])['30d'],
        retention: async (d) => retention[d == null ? 30 : d] || retention[30],
        chances: async (m, d) => chances[d] || chances[7],
        overview: async () => ov, settings: async () => st, importNow: async () => ({ imported: 0, files: [{}] }),
        fetchAhledger: async () => [], ahledgerMarkets: async () => [{ id: 'forever.normal.alliance.us', label: 'Normal Alliance US', game: 'forever' }, { id: 'forever.normal.alliance.eu', label: 'Normal Alliance EU', game: 'forever' }],
        saveSettings: async (p) => ({ ...st, ...p }), pickFolder: async () => null, openFolder: async () => {}, openLink: async () => {}, onChanged: () => {},
      };
    }, { ov: mock.overview, st: settings, now: mock.now, items: mock.items, item: mock.item, retention: mock.retention, chances: mock.chances });
    await page.goto(`http://127.0.0.1:${port}/index.html`);
    await page.waitForTimeout(700);
    await page.screenshot({ path: `${out}/uebersicht_${theme}.png`, fullPage: true });
    if (theme === 'dark') {
      await page.click('nav >> text=Gegenstände'); await page.waitForTimeout(400);
      await page.screenshot({ path: `${out}/gegenstaende.png` });
      await page.fill('input[aria-label=Suchen]', 'kriegsaxt'); await page.waitForTimeout(200);
      await page.screenshot({ path: `${out}/gegenstaende_suche.png` });
      await page.fill('input[aria-label=Suchen]', 'kupfererz'); await page.waitForTimeout(200);
      await page.click('.body .tr >> nth=0'); await page.waitForTimeout(900);
      await page.screenshot({ path: `${out}/gegenstand.png`, fullPage: true });
      await page.click('text=Alles'); await page.waitForTimeout(700);
      await page.screenshot({ path: `${out}/gegenstand_alles.png`, fullPage: true });
      await page.click('nav >> text=Chancen'); await page.waitForTimeout(500);
      await page.screenshot({ path: `${out}/chancen_wiederverkauf.png`, fullPage: false });
      for (const [t, f] of [['Händler', 'haendler'], ['Fallend', 'fallend'], ['Steigend', 'steigend'], ['Lohnend', 'lohnend']]) {
        await page.click(`.tabs >> text=${t}`); await page.waitForTimeout(300);
        await page.screenshot({ path: `${out}/chancen_${f}.png`, fullPage: false });
      }
      await page.click('.tabs >> text=Wiederverkauf'); await page.waitForTimeout(200);
      await page.click('.tbl tbody tr >> nth=0'); await page.waitForTimeout(700);
      await page.screenshot({ path: `${out}/gegenstand_aus_chancen.png`, fullPage: true });
      await page.click('nav >> text=Quellen'); await page.waitForTimeout(300);
      await page.screenshot({ path: `${out}/quellen.png`, fullPage: true });
      await page.click('nav >> text=Einstellungen'); await page.waitForTimeout(400);
      await page.screenshot({ path: `${out}/einstellungen.png`, fullPage: true });
    }
    await page.close();
  }
  // leerer Zustand
  const page = await browser.newPage({ viewport: { width: 1280, height: 820 } });
  await page.addInitScript(({ ov, st }) => {
    window.peon = { overview: async () => ({ ...ov, markets: [], back: null, log: [], game: { files: [] }, wowOk: false }), settings: async () => st, importNow: async () => ({}), onChanged: () => {}, ahledgerMarkets: async () => [] };
  }, { ov: mock.overview, st: mock.settings });
  await page.goto(`http://127.0.0.1:${port}/index.html`);
  await page.waitForTimeout(500);
  await page.screenshot({ path: `${out}/leer.png` });
  await browser.close();
  srv.close();
  console.log(errors.length ? 'FEHLER:\n' + errors.join('\n') : 'keine Fehler im Browser');
});
