import {
  test,
  expect,
  navDestination,
  enableFlutterSemantics,
  waitForFlutterBoot,
} from '../fixtures/flutter';
import { auditScreen, waitForSync, type ScreenAudit } from '../tools/audit';
import { AUDIT_DIR } from '../tools/audit';
import { mkdir, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import type { Page } from '@playwright/test';

/**
 * The other three quarters of the app.
 *
 * `audit.spec.ts` covers the twelve screens you land on: five trainee tabs,
 * five console sections, Login and Register. The repo has ~41 views with a
 * Scaffold. Everything else is a *pushed* screen — where food is actually
 * logged, workouts are actually built, a client is actually opened — and none
 * of it had ever been rendered by a test.
 *
 * That distribution is not accidental. Landing screens are the ones people
 * demo, so they are the ones that get fixed; the screens you reach by tapping
 * twice are where the unnamed buttons live.
 *
 * Screens that cannot be reached are reported as skipped with a reason rather
 * than quietly omitted, so the coverage number stays honest.
 */
const AUDIT_ENABLED = !!process.env.AUDIT;

type Journey = {
  name: string;
  /** Null when the screen has a URL of its own. */
  open: ((page: Page) => Promise<void>) | null;
  url?: string;
  /** A string that must appear once the screen is up. */
  expect: string;
};

test.describe('design audit — pushed screens', () => {
  test.skip(!AUDIT_ENABLED, 'set AUDIT=1 and run tools/seed-review-data.mjs first');
  test.describe.configure({ mode: 'serial' });

  const results: ScreenAudit[] = [];
  const skipped: Array<{ name: string; reason: string }> = [];

  test.afterAll(async () => {
    if (!results.length && !skipped.length) return;
    const width = results[0]?.viewport ?? 'unknown';
    await mkdir(AUDIT_DIR, { recursive: true });
    await writeFile(
      join(AUDIT_DIR, `deep-${width}.json`),
      JSON.stringify({ results, skipped }, null, 2),
    );
    const rows = results.map((r) =>
      `| ${r.screen} | ${r.viewport} | ${r.nodes.length} | ${r.unnamed.length} | ` +
      `${r.belowTapTarget.length} | ${r.adjacent.length} | ${r.widest?.fraction ?? '-'} |`
    );
    const skips = skipped.map((s) => `| ${s.name} | — | — | — | — | — | not reached: ${s.reason} |`);
    await writeFile(
      join(AUDIT_DIR, `deep-${width}.md`),
      [
        '| Screen | Width | Controls | Unnamed | Below target | <8px gap | Widest |',
        '|---|---|---:|---:|---:|---:|---:|',
        ...rows, ...skips,
      ].join('\n') + '\n',
    );
  });

  /** URL-addressable trainee screens: four of them have a GoRoute. */
  const byUrl: Journey[] = [
    { name: 'trainee-WeightTracking', open: null, url: '/weight-tracking', expect: 'Weight' },
    { name: 'trainee-WeightGoal', open: null, url: '/weight-goals', expect: 'Goal' },
    { name: 'trainee-MealTemplates', open: null, url: '/meal-templates', expect: 'Templates' },
    { name: 'trainee-FoodAdd', open: null, url: '/add-food', expect: 'Add' },
  ];

  test('trainee: screens with their own URL', async ({ traineePage }) => {
    test.setTimeout(240_000);
    const page = traineePage;
    const viewport = String(page.viewportSize()?.width ?? 0);
    await waitForSync(page);

    for (const journey of byUrl) {
      try {
        await page.goto(journey.url!);
        // A full navigation re-boots the Flutter engine, and the semantics
        // tree does not survive it -- Flutter builds it only when asked. Skip
        // this and `collect()` returns zero nodes, which reads as a screen
        // with no controls rather than as a screen that was never measured.
        await waitForFlutterBoot(page);
        await enableFlutterSemantics(page);
        await page.waitForTimeout(2500);
        results.push(await auditScreen(page, journey.name, viewport));
      } catch (err) {
        skipped.push({ name: journey.name, reason: String(err).slice(0, 120) });
      }
    }
    expect(results.length + skipped.length).toBe(byUrl.length);
  });

  test('trainee: screens reached by tapping', async ({ traineePage }) => {
    test.setTimeout(300_000);
    const page = traineePage;
    const viewport = String(page.viewportSize()?.width ?? 0);
    await waitForSync(page);

    const journeys: Journey[] = [
      {
        name: 'trainee-FoodSearch',
        expect: 'Search',
        open: async (p) => {
          await navDestination(p, 'Food').click();
          await p.waitForTimeout(1200);
          await p.getByRole('button', { name: /Add food to/ }).first().click({ timeout: 15_000 });
        },
      },
      {
        name: 'trainee-WorkoutsList',
        expect: 'Workouts',
        open: async (p) => {
          await navDestination(p, 'Gym').click();
          await p.waitForTimeout(1200);
          await p.getByRole('button', { name: /Manage workouts|Workouts/ }).first().click({ timeout: 15_000 });
        },
      },
      {
        name: 'trainee-Exercises',
        expect: 'Exercises',
        open: async (p) => {
          await navDestination(p, 'Gym').click();
          await p.waitForTimeout(1200);
          await p.getByRole('button', { name: /exercise/i }).first().click({ timeout: 15_000 });
        },
      },
      {
        name: 'trainee-AccountSettings',
        expect: 'Account',
        open: async (p) => {
          await navDestination(p, 'Profile').click();
          await p.waitForTimeout(1200);
          await p.getByRole('button', { name: /Account Settings/i }).first().click({ timeout: 15_000 });
        },
      },
      {
        name: 'trainee-CoachChat',
        expect: 'coach',
        open: async (p) => {
          await navDestination(p, 'Profile').click();
          await p.waitForTimeout(1200);
          await p.getByRole('button', { name: /Your coach/i }).first().click({ timeout: 15_000 });
        },
      },
    ];

    for (const journey of journeys) {
      try {
        await page.goto('/');
        await waitForFlutterBoot(page);
        await enableFlutterSemantics(page);
        await page.waitForTimeout(2500);
        await journey.open!(page);
        await page.waitForTimeout(2500);
        results.push(await auditScreen(page, journey.name, viewport));
      } catch (err) {
        skipped.push({ name: journey.name, reason: String(err).split('\n')[0].slice(0, 120) });
      }
    }
  });

  test('console: pushed screens', async ({ trainerPage }) => {
    test.setTimeout(240_000);
    const page = trainerPage;
    const viewport = String(page.viewportSize()?.width ?? 0);

    const journeys: Journey[] = [
      {
        name: 'console-Licence',
        expect: 'plan',
        open: async (p) => {
          await p.getByRole('button', { name: /Upgrade|plan|seat/i }).first().click({ timeout: 15_000 });
        },
      },
      {
        name: 'console-InviteClient',
        expect: 'Invite',
        open: async (p) => {
          await p.getByRole('button', { name: /Invite/i }).first().click({ timeout: 15_000 });
        },
      },
    ];

    for (const journey of journeys) {
      try {
        await page.goto('/console/dashboard');
        await waitForFlutterBoot(page);
        await enableFlutterSemantics(page);
        await page.waitForTimeout(3000);
        await journey.open!(page);
        await page.waitForTimeout(2000);
        results.push(await auditScreen(page, journey.name, viewport));
      } catch (err) {
        skipped.push({ name: journey.name, reason: String(err).split('\n')[0].slice(0, 120) });
      }
    }
  });

  test('pre-auth: the rest', async ({ appPage }) => {
    const page = appPage;
    const viewport = String(page.viewportSize()?.width ?? 0);
    try {
      await page.getByRole('button', { name: 'Forgot password?' }).click({ timeout: 15_000 });
      await page.waitForTimeout(2000);
      results.push(await auditScreen(page, 'auth-ForgotPassword', viewport));
    } catch (err) {
      skipped.push({ name: 'auth-ForgotPassword', reason: String(err).split('\n')[0].slice(0, 120) });
    }
  });
});
