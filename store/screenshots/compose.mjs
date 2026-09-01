// Wraps the real app captures in store marketing frames.
//
//   node capture-app.mjs   # photographs the running app  -> out/ios, out/play
//   node compose.mjs       # frames those captures        -> out/store/...
//
// The phone pixels in every frame are the PNG `capture-app.mjs` took of the
// running app. Nothing here redraws a screen: this step only adds the headline
// band, the background and the device bezel that a store listing needs and a
// bare screenshot does not. If a frame ever disagrees with the app, the fix is
// to re-run the capture, never to edit the markup.

import { createRequire } from 'node:module';
import { existsSync } from 'node:fs';
import { writeFile, mkdir, rm } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const require_ = createRequire(import.meta.url);
const CANDIDATES = [
  resolve(here, '../../e2e/node_modules/playwright-core'),
  resolve(here, '../../e2e/node_modules/playwright'),
  '/opt/node22/lib/node_modules/playwright',
  'playwright-core', 'playwright',
];
let chromium;
for (const c of CANDIDATES) {
  if (c.startsWith('/') && !existsSync(c)) continue;
  try { ({ chromium } = require_(c)); break; } catch { /* next */ }
}
if (!chromium) { console.error('Playwright not found.'); process.exit(1); }

const TARGETS = [
  { name: 'ios',  width: 1290, height: 2796 },
  { name: 'play', width: 1080, height: 1920 },
];

// Store order, not capture order: slot 1 has to carry the whole proposition,
// because it is the only one most people see in search results.
const FRAMES = [
  { src: '01-food-day',            eyebrow: 'ForgeForm',  head: 'Training and nutrition.<em>One app.</em>',
    sub: 'Your lifts, your macros and your weight in one log.' },
  { src: '06-active-workout',      eyebrow: 'In the gym', head: 'Log a set.<em>Keep moving.</em>',
    sub: 'One set at a time, with the timer a tap away.' },
  { src: '05-food-search',         eyebrow: 'Fast entry', head: 'Log food<em>in seconds.</em>',
    sub: 'Scan a barcode, or pick straight from what you eat most.' },
  { src: '03-progress-nutrition',  eyebrow: 'Nutrition',  head: 'See the trend,<em>not just today.</em>',
    sub: 'Calories and macros over the range you choose.' },
  { src: '02-gym-today',           eyebrow: 'Your plan',  head: 'Your plan,<em>on your calendar.</em>',
    sub: 'Build a session once, then schedule it as often as you like.' },
];

// Five frames, not seven, and both omissions are deliberate.
//
// The Dashboard reads *today*, and today renders empty on this account however
// it is seeded — see store/screenshots/README.md. A frame showing 0 kcal on a
// fully logged account is worse than one fewer frame, and faking it is not an
// option: these are photographs.
//
// Progress -> Gym is captured (07) but not framed. Its Time Range picker takes
// the top third, which pushes the streak tiles — the only reason to show that
// screen — below the crop, and the Exercise Progress chart under them cannot be
// filled at all because sync never pulls logged sets back down. Play asks for a
// minimum of two screenshots; five that all earn their place is the better
// trade.

const FONTS = resolve(here, '../../fittnes_tracker/assets/fonts');

/**
 * One frame's markup.
 *
 * Everything is sized in `rem`, where 1rem is 1% of the frame's height, so the
 * same layout fills a 1290×2796 iOS frame and a shorter 1080×1920 Play frame
 * without a second design. The device is deliberately cropped by the bottom
 * edge: it reads as a phone continuing past the frame rather than a small
 * picture floating in a box, and it buys the headline room at the top.
 */
const html = (frame, shotUrl) => `<!doctype html>
<meta charset="utf-8">
<style>
@font-face{font-family:M;font-weight:700;src:url('${pathToFileURL(FONTS + '/Montserrat-Bold.ttf').href}')}
@font-face{font-family:E;font-weight:400;src:url('${pathToFileURL(FONTS + '/Exo2-Regular.ttf').href}')}
@font-face{font-family:E;font-weight:700;src:url('${pathToFileURL(FONTS + '/Exo2-Bold.ttf').href}')}
*{margin:0;padding:0;box-sizing:border-box}
html,body{width:100%;height:100%;overflow:hidden}
.frame{
  position:relative;width:100vw;height:100vh;font-size:calc(100vh/100);
  display:flex;flex-direction:column;align-items:center;
  font-family:E,system-ui,sans-serif;color:#fff;
  background:
    radial-gradient(130% 55% at 50% 0%, #7a3418 0%, rgba(122,52,24,0) 60%),
    linear-gradient(178deg,#241a15 0%,#181410 45%,#0d0b0a 100%);
}
.frame::before{content:'';position:absolute;inset:0 0 auto 0;height:.5rem;
  background:linear-gradient(90deg,#FF6B3E,#ffb08e 55%,#FF6B3E)}
.cap{padding:6.5rem 7rem 0;width:100%;flex:0 0 auto;text-align:center}
.eyebrow{font-weight:700;font-size:1.5rem;letter-spacing:.3em;text-transform:uppercase;
  color:#FF6B3E;margin-bottom:1.6rem}
h1{font-family:M;font-size:4.6rem;line-height:1.14;letter-spacing:-.015em}
h1 em{display:block;font-style:normal;color:#FF6B3E}
.sub{margin:1.8rem auto 0;font-size:1.85rem;line-height:1.45;color:rgba(255,255,255,.66);max-width:32ch}
/* The device. Bezel and radius are chrome; everything inside <img> is the app. */
.phone{
  /* flex:0 0 auto, not 1 1 auto. Letting the box flex made it exactly the
     remaining height while the image kept its own, which left a strip of bare
     bezel under the app's nav bar. Sized by its content, the device is always
     image-height and simply bleeds off the bottom edge. */
  margin-top:4.6rem;flex:0 0 auto;
  /* A percentage of the frame's WIDTH. Sizing it in rem (1% of HEIGHT) worked
     on the 1290x2796 iOS frame by coincidence and overflowed the 1080x1920
     Play frame badly, blowing the app up to about 130% and cropping it. */
  width:78%;padding:.85rem .85rem 0;border-radius:5.4rem 5.4rem 0 0;
  background:linear-gradient(160deg,#4a4a4a,#2a2a2a);
  box-shadow:0 -1rem 8rem rgba(0,0,0,.7),0 0 0 .2rem rgba(255,255,255,.06);
  overflow:hidden;
}
.phone img{
  display:block;width:100%;height:auto;border-radius:4.6rem 4.6rem 0 0;
  /* Full width, natural height, clipped by .phone's overflow. object-fit
     cover was the obvious choice and the wrong one: the frame's device slot is
     proportionally narrower than the capture, so cover shaved the left and
     right edges and cut the nav labels in half. Cropping only the bottom keeps
     every pixel of the app's width intact. (No backticks in here -- the whole
     stylesheet lives inside a template literal.) */
}
</style>
<div class="frame">
  <div class="cap">
    <div class="eyebrow">${frame.eyebrow}</div>
    <h1>${frame.head}</h1>
    <p class="sub">${frame.sub}</p>
  </div>
  <div class="phone"><img src="${shotUrl}"></div>
</div>`;

const browser = await chromium.launch();

for (const target of TARGETS) {
  const inDir = resolve(here, 'out', target.name);
  const outDir = resolve(here, 'out', 'store', target.name);
  await rm(outDir, { recursive: true, force: true });
  await mkdir(outDir, { recursive: true });

  const page = await browser.newPage({
    viewport: { width: target.width, height: target.height },
    deviceScaleFactor: 1,
  });

  for (const [i, frame] of FRAMES.entries()) {
    const shot = resolve(inDir, `${frame.src}.png`);
    if (!existsSync(shot)) {
      console.log(`  MISS ${target.name}/${frame.src} — no capture; run capture-app.mjs first`);
      continue;
    }
    const tmp = resolve(outDir, `.frame-${i}.html`);
    await writeFile(tmp, html(frame, pathToFileURL(shot).href));
    await page.goto(pathToFileURL(tmp).href, { waitUntil: 'load' });
    await page.evaluate(() => document.fonts.ready);

    const n = String(i + 1).padStart(2, '0');
    const out = resolve(outDir, `${n}-${frame.src.replace(/^\d+-/, '')}.png`);
    await page.screenshot({ path: out });
    await rm(tmp);
    console.log(`  ok   store/${target.name}/${n}-${frame.src.replace(/^\d+-/, '')}.png`);
  }
  await page.close();
}

// ── Play Store assets that are not phone screenshots ────────────────────────
//
// Play refuses a listing without a 1024x500 feature graphic, and wants the icon
// at 512x512 while the repo's source art is 1254x1254. Both are produced here
// rather than by hand so they are reproducible and stay on the brand tokens.

const FEATURE = { width: 1024, height: 500 };

/** Landscape, so it needs its own template — the phone frame does not scale. */
const featureHtml = (shotUrl, iconUrl) => `<!doctype html>
<meta charset="utf-8">
<style>
@font-face{font-family:M;font-weight:700;src:url('${pathToFileURL(FONTS + '/Montserrat-Bold.ttf').href}')}
@font-face{font-family:E;font-weight:400;src:url('${pathToFileURL(FONTS + '/Exo2-Regular.ttf').href}')}
@font-face{font-family:E;font-weight:700;src:url('${pathToFileURL(FONTS + '/Exo2-Bold.ttf').href}')}
*{margin:0;padding:0;box-sizing:border-box}
/* The scale goes on <html>, not on .g. A rem is always relative to the ROOT
   font-size — setting it on the container and sizing children in rem looks like
   it scales and does not, which is how the first render came out at roughly
   three times the intended size with the headline wrapped onto four lines.
   (No backticks anywhere in this stylesheet: it lives in a template literal.) */
html{font-size:calc(100vh/100)}
html,body{width:100%;height:100%;overflow:hidden}
.g{
  position:relative;width:100vw;height:100vh;
  display:flex;align-items:center;color:#fff;overflow:hidden;
  font-family:E,system-ui,sans-serif;
  background:
    radial-gradient(90% 130% at 78% 50%, #7a3418 0%, rgba(122,52,24,0) 62%),
    linear-gradient(100deg,#141110 0%,#1d1714 55%,#0d0b0a 100%);
}
.g::before{content:'';position:absolute;inset:0 0 auto 0;height:1rem;
  background:linear-gradient(90deg,#FF6B3E,#ffb08e 55%,#FF6B3E)}
.copy{padding-left:7rem;max-width:58%;z-index:2}
.brand{display:flex;align-items:center;gap:2.4rem;margin-bottom:3.4rem}
.brand img{width:12rem;height:12rem;border-radius:2.6rem;display:block}
.brand span{font-family:M;font-size:7.2rem;letter-spacing:-.02em}
h1{font-family:M;font-size:6.4rem;line-height:1.12;letter-spacing:-.015em}
h1 em{font-style:normal;color:#FF6B3E}
.sub{margin-top:2.6rem;font-size:3.1rem;color:rgba(255,255,255,.68)}
/* The device bleeds off the right edge and is tilted, so the graphic reads as
   artwork rather than as a screenshot that was pasted in at an angle. */
.shot{
  position:absolute;right:-6%;top:50%;width:34%;
  transform:translateY(-50%) rotate(-7deg);
  border-radius:4rem;overflow:hidden;
  border:.7rem solid #3a3a3a;
  box-shadow:0 3rem 9rem rgba(0,0,0,.75);
}
.shot img{display:block;width:100%;height:auto}
</style>
<div class="g">
  <div class="copy">
    <div class="brand"><img src="${iconUrl}"><span>ForgeForm</span></div>
    <h1>Train, eat, track.<em> One app.</em></h1>
    <p class="sub">873 exercises &middot; barcode macros &middot; works offline</p>
  </div>
  <div class="shot"><img src="${shotUrl}"></div>
</div>`;

{
  const playDir = resolve(here, 'out', 'store', 'play');
  const iconSrc = resolve(here, '../../fittnes_tracker/assets/icon/app_icon.png');
  const heroShot = resolve(here, 'out', 'ios', '01-food-day.png');

  // 512x512 icon. Rendering it through the same browser keeps this script free
  // of an image-processing dependency for the sake of one resize.
  if (existsSync(iconSrc)) {
    const iconPage = await browser.newPage({
      viewport: { width: 512, height: 512 }, deviceScaleFactor: 1,
    });
    await iconPage.setContent(
      `<style>*{margin:0;padding:0}html,body{width:512px;height:512px;overflow:hidden}` +
      `img{width:512px;height:512px;display:block}</style>` +
      `<img src="${pathToFileURL(iconSrc).href}">`);
    await iconPage.locator('img').waitFor();
    await iconPage.screenshot({ path: resolve(playDir, 'icon-512.png') });
    await iconPage.close();
    console.log('  ok   store/play/icon-512.png  512x512');
  } else {
    console.log('  MISS icon-512.png — assets/icon/app_icon.png not found');
  }

  if (existsSync(heroShot)) {
    const fgPage = await browser.newPage({
      viewport: FEATURE, deviceScaleFactor: 1,
    });
    const tmp = resolve(playDir, '.feature.html');
    await writeFile(tmp, featureHtml(
      pathToFileURL(heroShot).href, pathToFileURL(iconSrc).href));
    await fgPage.goto(pathToFileURL(tmp).href, { waitUntil: 'load' });
    await fgPage.evaluate(() => document.fonts.ready);
    await fgPage.screenshot({ path: resolve(playDir, 'feature-graphic.png') });
    await rm(tmp);
    await fgPage.close();
    console.log('  ok   store/play/feature-graphic.png  1024x500');
  } else {
    console.log('  MISS feature-graphic.png — run capture-app.mjs first');
  }
}

await browser.close();
