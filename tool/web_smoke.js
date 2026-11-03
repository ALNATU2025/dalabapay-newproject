// CI smoke test for the website: serves build/web, opens it in headless
// Chromium and checks the app starts (the loader goes away and the app
// reaches the landing page). Prints console errors as CI annotations.
const http = require('http');
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const root = path.resolve(process.argv[2] || 'build/web');

// The same security headers Render sends (render.yaml, path /*), so the
// test catches a Content-Security-Policy that would break the site.
const headers = {};
try {
  const yaml = fs.readFileSync(path.join(__dirname, '..', 'render.yaml'), 'utf8');
  const re = /- path: \/\*\s*\n\s*name: ([^\n]+)\n\s*value: ("?)(.+?)\2\s*\n/g;
  let m;
  while ((m = re.exec(yaml))) headers[m[1].trim()] = m[3].replace(/https:\/\/newproject-backend-bod8\.onrender\.com/, 'https://newproject-backend-bod8.onrender.com');
} catch (e) {
  console.log(`::warning::render.yaml headers not read: ${e.message}`);
}
const types = { '.html': 'text/html', '.js': 'application/javascript', '.mjs': 'application/javascript', '.wasm': 'application/wasm', '.json': 'application/json', '.png': 'image/png', '.otf': 'font/otf', '.ttf': 'font/ttf', '.css': 'text/css' };
const server = http.createServer((req, res) => {
  let p = decodeURIComponent(req.url.split('?')[0]);
  if (p.endsWith('/')) p += 'index.html';
  const f = path.join(root, p);
  if (!f.startsWith(root) || !fs.existsSync(f)) { res.writeHead(404); return res.end(); }
  res.writeHead(200, { ...headers, 'Content-Type': types[path.extname(f)] || 'application/octet-stream' });
  fs.createReadStream(f).pipe(res);
});

(async () => {
  await new Promise((r) => server.listen(8080, r));
  const browser = await chromium.launch({ args: ['--lang=en-NG'] });
  const page = await browser.newPage({ viewport: { width: 1280, height: 800 }, locale: 'en-NG' });
  const errors = [];
  page.on('console', (m) => { if (m.type() === 'error' || /Content Security Policy/i.test(m.text())) errors.push(m.text()); });
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
  console.log(`::notice title=web smoke headers::${Object.keys(headers).join(', ')}`);
  const csp = errors.filter((e) => /Content Security Policy/i.test(e));
  if (csp.length) { console.log(`::error title=CSP::${csp[0].slice(0, 400)}`); ok = false; }
  console.log(`::notice title=web smoke::ok=${ok} after ${Math.round((Date.now() - t0) / 1000)}s state=${JSON.stringify(state)}`);
  await browser.close();
  server.close();
  process.exit(ok ? 0 : 1);
})();
