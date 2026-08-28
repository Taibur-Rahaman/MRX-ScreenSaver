#!/usr/bin/env bash
# Capture README screenshots from the built web demo.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/docs/screenshots"
PORT=1429

cd "$ROOT"
npm run build
npm install playwright@1.49.1 --no-save 2>/dev/null || true

export ROOT OUT PORT
node --input-type=module <<'NODE'
import { chromium } from 'playwright';
import { createServer } from 'http';
import { readFileSync, existsSync } from 'fs';
import { join, extname } from 'path';

const root = process.env.ROOT;
const dist = join(root, 'dist');
const out = join(root, 'docs', 'screenshots');
const port = Number(process.env.PORT);

const mime = {
  '.html': 'text/html',
  '.js': 'text/javascript',
  '.css': 'text/css',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
};

const server = createServer((req, res) => {
  const path = req.url?.split('?')[0] || '/';
  const file = join(dist, path === '/' ? 'index.html' : path.replace(/^\//, ''));
  if (!existsSync(file)) {
    res.writeHead(404);
    res.end('not found');
    return;
  }
  res.writeHead(200, { 'Content-Type': mime[extname(file)] || 'application/octet-stream' });
  res.end(readFileSync(file));
});

await new Promise((resolve) => server.listen(port, '127.0.0.1', resolve));

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });

for (const [name, scene] of [['flipclock', 'flipclock'], ['starfield', 'starfield']]) {
  await page.goto(`http://127.0.0.1:${port}/?scene=${scene}&mode=screensaver`, { waitUntil: 'networkidle' });
  await page.waitForTimeout(2000);
  await page.screenshot({ path: join(out, `${name}.png`) });
  console.log(`Wrote ${name}.png`);
}

await browser.close();
server.close();
NODE

echo "✅ Screenshots in $OUT"
