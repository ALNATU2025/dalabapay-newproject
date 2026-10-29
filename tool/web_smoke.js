// CI smoke test for the website: serves build/web, opens it in headless
// Chromium and checks the app starts (the loader goes away and the app
// reaches the landing page). Prints console errors as CI annotations.
const http = require('http');
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const root = path.resolve(process.argv[2] || 'build/web');
const types = { '.html': 'text/html', '.js': 'application/javascript', '.mjs': 'application/javascript', '.wasm': 'application/wasm', '.json': 'application/json', '.png': 'image/png', '.otf': 'font/otf', '.ttf': 'font/ttf', '.css': 'text/css' };
const server = http.createServer((req, res) => {
  let p = decodeURIComponent(req.url.split('?')[0]);
  if (p.endsWith('/')) p += 'index.html';
  const f = path.join(root, p);
  if (!f.startsWith(root) || !fs.existsSync(f)) { res.writeHead(404); return res.end(); }
  res.writeHead(200, { 'Content-Type': types[path.extname(f)] || 'application/octet-stream' });
  fs.createReadStream(f).pipe(res);
});

(async () => {
  await new Promise((r) => server.listen(8080, r));
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1280, height: 800 } });
  const errors = [];
  page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
  page.on('pageerror', (e) => errors.push(String(e)));
  const t0 = Date.now();
  await page.goto('http://localhost:8080/', { waitUntil: 'load' });
  let ok = false;
  for (let i = 0; i < 90; i++) {
    const s = await page.evaluate(() => ({
      loader: Boolean(document.getElementById('dp-loading')),
      view: Boolean(document.querySelector('flutter-view, flt-glass-pane')),
      hash: location.hash,
    }));
    if (s.view && !s.loader && s.hash.includes('landing')) { ok = true; break; }
    if (i % 10 === 9) console.log(`after ${i + 1}s: ${JSON.stringify(s)}`);
    await page.waitForTimeout(1000);
  }
  const state = await page.evaluate(() => ({ loader: Boolean(document.getElementById('dp-loading')), view: Boolean(document.querySelector('flutter-view, flt-glass-pane')), hash: location.hash }));
  await page.screenshot({ path: 'web_smoke.png' });
  for (const e of errors.slice(0, 15)) console.log(`::warning title=browser console::${e.slice(0, 300).replace(/\n/g, ' ')}`);
  console.log(`::notice title=web smoke::ok=${ok} after ${Math.round((Date.now() - t0) / 1000)}s state=${JSON.stringify(state)}`);
  await browser.close();
  server.close();
  process.exit(ok ? 0 : 1);
})();
