// Captures store screenshots FROM THE RUNNING APP.
//
// This drives the real Flutter web bundle in a real browser, signed in as the
// seeded trainee, and photographs the actual screens. It is not a mockup.
//
// Prerequisites (see store/screenshots/README.md for the full runbook):
//   1. Postgres running, database created
//   2. FitTracker.Api running on :5080, seeded via
//      `node e2e/tools/seed-review-data.mjs --api http://127.0.0.1:5080`
//   3. `flutter build web --release --no-web-resources-cdn \
//         --dart-define=FORGE_API_URL=http://127.0.0.1:5080/`
//   4. `node e2e/tools/serve-web.mjs` on :4173
//
// Then: node capture-app.mjs
//
// The sign-in and semantics helpers below are deliberate copies of
// e2e/fixtures/flutter.ts rather than imports — that file is TypeScript inside
// a Playwright-test project, and this is a plain node script. The comments
// there explain *why* each step is shaped the way it is; keep the two in sync.

import { createRequire } from 'node:module';
import { existsSync } from 'node:fs';
import { mkdir, rm } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
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
  try { ({ chromium } = require_(c)); break; } catch { /* next */ }
}
if (!chromium) { console.error('Playwright not found.'); process.exit(1); }

const BASE = process.env.FORGE_WEB_URL ?? 'http://127.0.0.1:4173';
const CREDENTIALS = { username: 'robert.meyer', password: 'ReviewPass!2026' };

// CSS viewport × deviceScaleFactor lands exactly on each store's pixel size,
// so nothing is ever resampled.
const TARGETS = [
  { name: 'ios',  width: 430, height: 932, scale: 3 }, // → 1290×2796
  { name: 'play', width: 360, height: 640, scale: 3 }, // → 1080×1920
];

async function waitForFlutterBoot(page) {
  await page.locator('flutter-view').waitFor({ state: 'attached', timeout: 120_000 });
  await page.locator('flt-semantics-placeholder').waitFor({ state: 'attached', timeout: 120_000 });
}

async function enableFlutterSemantics(page) {
  const placeholder = page.locator('flt-semantics-placeholder[role="button"]');
  await placeholder.waitFor({ state: 'attached', timeout: 60_000 });
  await placeholder.evaluate((el) => el.click());
  await page.locator('flt-semantics[role], flt-semantics[aria-label]')
    .first().waitFor({ state: 'attached', timeout: 30_000 });
}

async function typeReliably(field, value, attempts = 4) {
  for (let attempt = 1; attempt <= attempts; attempt++) {
    await field.click();
    await field.press('ControlOrMeta+a');
    await field.press('Delete');
    await field.pressSequentially(value, { delay: 30 });
    if ((await field.inputValue()) === value) return;
    if (attempt === attempts) throw new Error('field did not accept the value');
  }
}

async function signIn(page) {
  const loginButton = page.getByRole('button', { name: 'Login' });
  await loginButton.waitFor({ state: 'attached', timeout: 60_000 });
  await typeReliably(page.getByRole('textbox', { name: 'Username' }), CREDENTIALS.username);
  await typeReliably(page.getByLabel('Password'), CREDENTIALS.password);
  await loginButton.click();
  await loginButton.waitFor({ state: 'detached', timeout: 120_000 });

  const setUpLater = page.getByRole('button', { name: 'Set up later' });
  await Promise.race([
    setUpLater.waitFor({ state: 'attached', timeout: 60_000 }).catch(() => {}),
    page.getByRole('tablist').first().waitFor({ state: 'attached', timeout: 60_000 }).catch(() => {}),
  ]);
  if (await setUpLater.count()) await setUpLater.click();

  await page.getByRole('tablist')
    .or(page.getByRole('button', { name: 'Dashboard', exact: true }))
    .first().waitFor({ state: 'attached', timeout: 60_000 });
}

function navDestination(page, name) {
  return page.getByRole('tab', { name, exact: true })
    .or(page.getByRole('button', { name, exact: true })).first();
}

// A pull runs on sign-in and each tab paints from the local database once it
// lands. Settling on network-idle plus a frame budget is cruder than waiting
// for a specific widget, but the widget differs per tab and a screenshot taken
// mid-paint is worse than a slow one.
async function settle(page, ms = 2500) {
  await page.waitForLoadState('networkidle').catch(() => {});
  await page.waitForTimeout(ms);
}

// Clicking a nav destination leaves the pointer on it, and Material shows the
// destination's tooltip on hover — a grey pill that floats above the nav bar
// and lands in the screenshot. Parking the pointer off the bar and giving the
// tooltip time to fade is the whole fix.
// Getting back out of a pushed route.
//
// `page.goBack()` does not pop it, and the food-search screen exposes no back
// control to the accessibility tree at all — its whole semantics tree is the
// list of foods, with no app-bar back button and no search field (worth fixing
// in the app; a screen reader cannot leave that screen either). Reloading is
// the one exit that always works. The JWT is persisted, so the reload lands
// back in the app rather than on login; the sign-in below is a fallback for
// the case where it does not.
async function returnToShell(page) {
  // reload(), not goto(BASE). A pushed route has no URL of its own — the
  // address bar still reads the root — so navigating to the root is a no-op
  // that leaves the app exactly where it was, and the wait for a tablist then
  // times out. Reloading actually tears the route stack down.
  await page.reload();
  await waitForFlutterBoot(page);
  await enableFlutterSemantics(page);
  if (await page.getByRole('button', { name: 'Login' }).count()) {
    await signIn(page);
  }
  await page.getByRole('tablist').first().waitFor({ state: 'attached', timeout: 60_000 });
  await settle(page, 3000);
}

/**
 * Open a screen by its route instead of clicking to it.
 *
 * `main.dart` calls `usePathUrlStrategy()` and `tools/serve-web.mjs` rewrites
 * unknown paths to index.html, so a deep link works. For a screen that has a
 * route this beats driving the UI: fewer steps to break, and no pushed route to
 * escape afterwards, because the next shot simply loads its own URL. The JWT
 * persists, so the load lands signed in.
 */
async function openRoute(page, path) {
  await page.goto(`${BASE}${path}`);
  await waitForFlutterBoot(page);
  await enableFlutterSemantics(page);
  if (await page.getByRole('button', { name: 'Login' }).count()) {
    await signIn(page);
    await page.goto(`${BASE}${path}`);
    await waitForFlutterBoot(page);
    await enableFlutterSemantics(page);
  }
  await settle(page, 3000);
}

async function unhover(page, target) {
  await page.mouse.move(target.width / 2, 12);
  await page.waitForTimeout(900);
}

// Order matters. The Dashboard reads aggregates that are only correct once
// SyncService.pullAll() has finished writing the local database, and shooting
// it first (the obvious order) photographs a dashboard of zeroes on a populated
// account. It goes last.
const SHOTS = [
  { file: '01-food-day', tab: 'Food',
    async after(page) {
      // Step back one day.
      //
      // Today renders empty however it is seeded: `GET api/Meal/all` returns 4
      // meals with 7 food entries for today, the same as every other day, and
      // the app still shows "No foods added yet" for today only. Suspicion
      // falls on the meal shells the screen creates for the current day
      // colliding with the pulled rows in `_deduplicateMealsByContent`, but
      // that is unconfirmed — see README. Yesterday is a real, fully logged
      // day, and stepping to it is one tap a user makes constantly.
      await page.getByRole('button', { name: /^(Previous|previous)/ }).first().click();
    },
    shallow: true,
    note: 'a logged day: calorie total, macro split, meals by category' },
  { file: '02-gym-today', tab: 'Gym',
    note: "today's scheduled session, ready to start" },
  { file: '03-progress-nutrition', tab: 'Progress',
    async after(page) {
      await page.getByRole('tab', { name: 'Nutrition', exact: true }).first().click();
    },
    // A sub-tab, not a pushed route — the nav bar stays put.
    shallow: true,
    note: 'nutrition trends over the selected range' },
  { file: '04-dashboard', tab: 'Dashboard',
    note: 'the daily overview' },
  { file: '07-progress-gym', tab: 'Progress',
    async after(page) {
      // Two things bite here. The Progress sub-tab selection survives leaving
      // and re-entering the tab, so after shot 03 chose Nutrition this lands on
      // Nutrition again unless Gym is clicked explicitly — it shot a duplicate
      // of 03 without this. And "Gym" is role=tab twice on this screen: the
      // sub-tab and the bottom-nav destination. The sub-tab comes first in the
      // semantics tree; `.last()` picked the nav and navigated away entirely.
      await page.getByRole('tab', { name: 'Gym', exact: true }).first().click();
      await page.waitForTimeout(1500);
      // The Time Range picker sits above the numbers and eats the top third of
      // the frame once the device is cropped, leaving the streak tiles — the
      // only reason to show this screen — below the fold. Scroll past it.
      await page.mouse.move(200, 500);
      await page.mouse.wheel(0, 300);
      await page.waitForTimeout(1200);
    },
    shallow: true,
    note: 'workout frequency and streaks' },

  // ── pushed routes, last ──────────────────────────────────────────────
  { file: '05-food-search', tab: 'Food',
    async after(page) {
      await page.getByRole('button', { name: /^(Add|Breakfast|Lunch|Dinner|Snacks)/i })
        .first().click();
    },
    note: 'the food picker for one meal' },
  { file: '08-exercise-library', tab: 'Gym',
    async after(page) {
      // No route for this one; it is reached from the Gym tab's menu.
      // Present in the semantics tree but not actionable — Playwright's
      // visibility and hit-testing checks fail on it, so a normal click times
      // out. Dispatching straight to the node is the same trick
      // `enableFlutterSemantics` uses on the placeholder, and Flutter's
      // semantics nodes act on a synthetic click.
      const manage = page.getByRole('button', { name: /Manage Exercises/i }).first();
      await manage.waitFor({ state: 'attached', timeout: 30_000 });
      await manage.evaluate((el) => el.click());
      // 873 rows do not paint instantly after the route pushes.
      await page.waitForTimeout(2500);
    },
    note: 'the exercise library — 873 with instructions' },

  { file: '06-active-workout', tab: 'Gym',
    async after(page) {
      await page.getByRole('button', { name: /Start Workout/i }).first().click();
      await page.waitForTimeout(2500);
      // Shoot a set being logged, not an untouched form. Best-effort: if the
      // fields are not reachable the screenshot is still a real screen, just
      // an emptier one, and that beats failing the shot.
      try {
        const boxes = page.getByRole('textbox');
        const n = await boxes.count();
        if (n >= 2) {
          await boxes.nth(0).click();
          await boxes.nth(0).press('ControlOrMeta+a');
          await boxes.nth(0).pressSequentially('82.5', { delay: 40 });
          await boxes.nth(1).click();
          await boxes.nth(1).press('ControlOrMeta+a');
          await boxes.nth(1).pressSequentially('8', { delay: 40 });
          // Dismiss the soft-keyboard host so it cannot overlap the shot.
          await page.keyboard.press('Escape');
        }
        else {
          console.log(`  ..   only ${await boxes.count()} textbox(es) on the set form; left as found`);
        }
      } catch (e) {
        // Not fatal — the screenshot is still a real screen — but it must not
        // be silent, or an all-zeros set form ships looking deliberate.
        console.log(`  ..   could not fill the set: ${String(e).split('\n')[0]}`);
      }
    },
    // returnToShell cannot escape this screen — a reload from it never
    // brings the tablist back, which is what starved the exercise library
    // of its Gym tab when this ran before it. Nothing after it needs the
    // shell: 09 and 10 load their own URLs.
    last: true,
    note: 'a set being logged' },

  // ── routed screens: no tab, no clicking, just a URL ──────────────────
  { file: '09-weight', route: '/weight-tracking',
    note: 'weight log, goal and trend' },
  { file: '10-meal-templates', route: '/meal-templates',
    // Nothing follows it, so there is no shell to return to.
    last: true,
    note: 'saved meal templates' },
];

const browser = await chromium.launch();

for (const target of TARGETS) {
  const outDir = resolve(here, 'out', target.name);
  await rm(outDir, { recursive: true, force: true });
  await mkdir(outDir, { recursive: true });

  const context = await browser.newContext({
    viewport: { width: target.width, height: target.height },
    deviceScaleFactor: target.scale,
    // Chromium here reports a locale `intl` cannot parse, and the app throws
    // "Incorrect locale information provided" before it ever mounts
    // <flutter-view> — which surfaces only as a boot timeout.
    locale: 'en-US',
    timezoneId: 'Europe/Berlin',
    // The app reads the platform brightness; the design is strongest dark and
    // that is what the listing copy describes.
    colorScheme: 'dark',
  });
  const page = await context.newPage();
  page.on('pageerror', (e) => console.error(`  [pageerror] ${e}`));

  await page.goto(BASE);
  await waitForFlutterBoot(page);
  await enableFlutterSemantics(page);
  await signIn(page);
  await settle(page, 4000);

  for (const shot of SHOTS) {
    // One screen failing to open must not cost the other five. A missing
    // screenshot is obvious; a run that aborts halfway is not.
    try {
      if (shot.route) {
        await openRoute(page, shot.route);
      } else if (shot.tab) {
        await navDestination(page, shot.tab).click();
        await settle(page);
      }
      if (shot.after) {
        await shot.after(page);
        await settle(page);
      }
      await unhover(page, target);
      await page.screenshot({ path: resolve(outDir, `${shot.file}.png`) });
      console.log(`  ok   ${target.name}/${shot.file}.png — ${shot.note}`);
    } catch (err) {
      console.log(`  MISS ${target.name}/${shot.file}.png — ${String(err).split('\n')[0]}`);
    } finally {
      // Only shots that pushed a route need rescuing. A routed shot loads its
      // own URL and the next one loads whatever it needs, so sending it back to
      // the shell in between achieves nothing except a way to fail.
      if (shot.after && !shot.route && !shot.shallow && !shot.last) {
        await returnToShell(page).catch((e) =>
          console.log(`  !! could not return to shell: ${String(e).split('\n')[0]}`));
      }
    }
  }

  await context.close();
}

await browser.close();
