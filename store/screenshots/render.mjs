// Renders store/screenshots/screens.html to PNGs at both stores' phone sizes.
//
//   node render.mjs
//
// Uses the Chromium already installed for the e2e suite. Nothing is fetched at
// render time: the fonts are the repo's own .ttf files and every graphic is
// inline SVG or CSS, for the same reason `--no-web-resources-cdn` exists on the
// web build (docs/e2e-playwright.md).

import { createRequire } from 'node:module';
import { existsSync } from 'node:fs';
import { mkdir, rm } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));

// Playwright may live in the e2e suite's node_modules or in the global Node
// install, depending on the machine. Resolve rather than assume — an absolute
// import that is right on one box and missing on the next is how this script
// stops being runnable.
const require_ = createRequire(import.meta.url);
const CANDIDATES = [
  resolve(here, '../../e2e/node_modules/playwright-core'),
  resolve(here, '../../e2e/node_modules/playwright'),
  '/opt/node22/lib/node_modules/playwright',
  'playwright-core',
  'playwright',
];
let chromium;
for (const c of CANDIDATES) {
  if (c.startsWith('/') && !existsSync(c)) continue;
  try { ({ chromium } = require_(c)); break; } catch { /* try the next one */ }
}
if (!chromium) {
  console.error('Playwright not found. Run `npm install` in e2e/, or `npm i -g playwright`.');
  process.exit(1);
}
const page_url = pathToFileURL(resolve(here, 'screens.html')).href;

// One entry per store slot. Both stores accept a 1:2.17 and a 9:16 phone shot
// respectively; the layout is fluid, so the same markup fills each.
const TARGETS = [
  { name: 'ios',  width: 1290, height: 2796 }, // App Store, iPhone 6.9"/6.7"
  { name: 'play', width: 1080, height: 1920 }, // Google Play, phone
];

const SHOTS = [
  { id: 's1', file: '01-dashboard' },
  { id: 's2', file: '02-workout' },
  { id: 's3', file: '03-food-search' },
  { id: 's4', file: '04-nutrition' },
  { id: 's5', file: '05-progress' },
  { id: 's6', file: '06-coach-chat' },
];

const browser = await chromium.launch();

for (const target of TARGETS) {
  const outDir = resolve(here, 'out', target.name);
  await rm(outDir, { recursive: true, force: true });
  await mkdir(outDir, { recursive: true });

  // deviceScaleFactor stays 1: the viewport is already the store's exact pixel
  // size, so scaling here would multiply it past the upload limits.
  const page = await browser.newPage({
    viewport: { width: target.width, height: target.height },
    deviceScaleFactor: 1,
  });
  await page.goto(page_url, { waitUntil: 'load' });
  await page.evaluate(() => document.fonts.ready);

  for (const shot of SHOTS) {
    // Each section is exactly one viewport tall, so scrolling it into view and
    // shooting the element gives a pixel-exact, full-bleed store image.
    const el = page.locator(`#${shot.id}`);
    await el.scrollIntoViewIfNeeded();
    await el.screenshot({ path: resolve(outDir, `${shot.file}.png`) });
    console.log(`${target.name}/${shot.file}.png  ${target.width}×${target.height}`);
  }
  await page.close();
}

await browser.close();
