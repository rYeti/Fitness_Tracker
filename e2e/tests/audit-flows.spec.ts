import {
  test,
  expect,
  navDestination,
  enableFlutterSemantics,
  waitForFlutterBoot,
  typeReliably,
  TRAINEE_CREDENTIALS,
} from '../fixtures/flutter';
import { auditScreen, waitForSync, type ScreenAudit } from '../tools/audit';
import { AUDIT_DIR } from '../tools/audit';
import { mkdir, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import type { Page } from '@playwright/test';

/**
 * The last quarter: the workout flow, and everything else still unmeasured.
 *
 * `audit.spec.ts` covers the twelve screens you land on. `audit-deep.spec.ts`
 * covers eleven you reach by tapping once, and found 68 unnamed controls behind
 * screens that had measured 0. This file covers the rest — most of it the gym
 * half of the app, which is the half the owner uses and the half no test had
 * ever rendered.
 *
 * Two rules carried over from those files, both learned the expensive way:
 *
 * 1. A screen that could not be opened is pushed onto `skipped` with a reason,
 *    never omitted. An omitted screen and a clean screen look identical in a
 *    summary table, and the difference is the entire point of the exercise.
 * 2. A `page.goto()` re-boots the Flutter engine and the semantics tree does
 *    not survive it, so every journey re-enables semantics after navigating.
 *    Skipping that reports zero controls, which reads as clean.
 *
 * And one rule this file adds. The three ways a screen can be unreachable are
 * kept apart in the reason string, because they mean different things:
 *
 * | kind | example | what it means |
 * |---|---|---|
 * | by definition | `ScheduleView` | nothing constructs it; dead code |
 * | by fixture | coach chat, before the seed linked the accounts | our gap |
 * | by platform | barcode scanner, welcome screen | correct on web |
 *
 * §13 collapsed those into one column and so reported a fixture gap as a
 * possible app defect.
 */
const AUDIT_ENABLED = !!process.env.AUDIT;

type Journey = {
  name: string;
  /** Where to start. Defaults to '/'. */
  url?: string;
  /** Drive the UI from that root to the screen under audit. */
  open: (page: Page) => Promise<void>;
};

/** Boot, turn semantics on, settle. Every journey starts here. */
async function land(page: Page, url = '/'): Promise<void> {
  await page.goto(url);
  await waitForFlutterBoot(page);
  await enableFlutterSemantics(page);
  await page.waitForTimeout(2500);
}

test.describe('design audit — the workout flow and the last views', () => {
  test.skip(!AUDIT_ENABLED, 'set AUDIT=1 and run tools/seed-review-data.mjs first');
  test.describe.configure({ mode: 'serial' });

  const results: ScreenAudit[] = [];
  const skipped: Array<{ name: string; kind: string; reason: string }> = [];

  test.afterAll(async () => {
    if (!results.length && !skipped.length) return;
    const width = results[0]?.viewport ?? 'unknown';
    await mkdir(AUDIT_DIR, { recursive: true });
    await writeFile(
      join(AUDIT_DIR, `flows-${width}.json`),
      JSON.stringify({ results, skipped }, null, 2),
    );
    const rows = results.map((r) =>
      `| ${r.screen} | ${r.viewport} | ${r.nodes.length} | ${r.unnamed.length} | ` +
      `${r.belowTapTarget.length} | ${r.adjacent.length} | ${r.widest?.fraction ?? '-'} |`
    );
    const skips = skipped.map(
      (s) => `| ${s.name} | — | — | — | — | — | unreachable ${s.kind}: ${s.reason} |`,
    );
    await writeFile(
      join(AUDIT_DIR, `flows-${width}.md`),
      [
        '| Screen | Width | Controls | Unnamed | Below target | <8px gap | Widest |',
        '|---|---|---:|---:|---:|---:|---:|',
        ...rows, ...skips,
      ].join('\n') + '\n',
    );
  });

  /** Run a list of journeys, recording each as measured or as unreachable. */
  async function walk(page: Page, journeys: Journey[]): Promise<void> {
    const viewport = String(page.viewportSize()?.width ?? 0);
    for (const journey of journeys) {
      try {
        await land(page, journey.url);
        await journey.open(page);
        await page.waitForTimeout(2500);
        results.push(await auditScreen(page, journey.name, viewport));
      } catch (err) {
        skipped.push({
          name: journey.name,
          kind: 'by fixture',
          reason: String(err).split('\n')[0].slice(0, 120),
        });
      }
    }
  }

  /** Open the Gym tab and wait for the scheduled list to paint. */
  async function gymTab(p: Page): Promise<void> {
    await navDestination(p, 'Gym').click();
    await p.waitForTimeout(1800);
    // The ActiveWorkout journey starts a workout and never finishes it, which
    // leaves the app carrying an in-progress session. Every Gym-tab landing
    // after that point shows "Resume workout?" over the list, and it isn't
    // one of the controls any later journey is looking for — so its click
    // just times out and burns 15s per attempt, five journeys in a row.
    // Discarding it here, once, keeps the rest of the flow reachable.
    const discard = p.getByRole('button', { name: /^Discard$/i });
    if (await discard.first().isVisible({ timeout: 500 }).catch(() => false)) {
      await discard.first().click();
      await p.waitForTimeout(800);
    }
  }

  /** Gym tab -> the workout list behind the app bar's list action. */
  async function workoutsList(p: Page): Promise<void> {
    await gymTab(p);
    await p.getByRole('button', { name: /Manage Workouts/i }).first().click({ timeout: 15_000 });
    await p.waitForTimeout(2000);
  }

  test('trainee: the workout flow', async ({ traineePage }) => {
    test.setTimeout(600_000);
    const page = traineePage;
    await waitForSync(page);

    await walk(page, [
      {
        name: 'trainee-WorkoutsList',
        open: workoutsList,
      },
      {
        // The live workout: the primary interaction of the app, and the one
        // screen here that is used one-handed in a gym, which is why 390 is
        // not optional for it.
        name: 'trainee-ActiveWorkout',
        open: async (p) => {
          await gymTab(p);
          await p.getByRole('button', { name: /Start Workout/i }).first().click({ timeout: 20_000 });
          await p.waitForTimeout(3000);
        },
      },
      {
        // Deliberately the Gym FAB rather than the list's create action: the
        // list's is premium-gated once a trainee has one plan, and the seeded
        // trainee has two, so that route opens the paywall instead.
        name: 'trainee-CreateWorkout',
        open: async (p) => {
          await gymTab(p);
          await p.getByRole('button', { name: /Create or edit workouts/i }).first().click({ timeout: 15_000 });
          await p.waitForTimeout(1200);
          await p.getByRole('button', { name: /New Workout/i }).first().click({ timeout: 15_000 });
          await p.waitForTimeout(2000);
        },
      },
      {
        name: 'trainee-EditWorkout',
        open: async (p) => {
          await workoutsList(p);
          await p.getByRole('button', { name: /More Options/i }).first().click({ timeout: 15_000 });
          await p.waitForTimeout(1200);
          await p.getByRole('button', { name: /Edit Details/i }).first().click({ timeout: 15_000 });
          await p.waitForTimeout(2500);
        },
      },
      {
        name: 'trainee-EditSingleWorkout',
        open: async (p) => {
          await workoutsList(p);
          await p.getByRole('button', { name: /More Options/i }).first().click({ timeout: 15_000 });
          await p.waitForTimeout(1200);
          await p.getByRole('button', { name: /Edit Details/i }).first().click({ timeout: 15_000 });
          await p.waitForTimeout(2500);
          await p.getByRole('button', { name: /Edit this workout|Edit workout details/i }).first().click({ timeout: 15_000 });
          await p.waitForTimeout(2500);
        },
      },
      {
        name: 'trainee-FitNotesImport',
        open: async (p) => {
          await workoutsList(p);
          await p.getByRole('button', { name: /Import Options/i }).first().click({ timeout: 15_000 });
          await p.waitForTimeout(1200);
          await p.getByRole('button', { name: /Import FitNotes/i }).first().click({ timeout: 15_000 });
          await p.waitForTimeout(2000);
        },
      },
      {
        name: 'trainee-CsvImport',
        open: async (p) => {
          await workoutsList(p);
          await p.getByRole('button', { name: /Import Options/i }).first().click({ timeout: 15_000 });
          await p.waitForTimeout(1200);
          // The FAB and the sheet's third row carry the same label, so the
          // sheet's copy is the *last* match, not the first.
          await p.getByRole('button', { name: /Import Options/i }).last().click({ timeout: 15_000 });
          await p.waitForTimeout(2000);
        },
      },
    ]);
  });

  test('trainee: food, templates and premium', async ({ traineePage }) => {
    test.setTimeout(600_000);
    const page = traineePage;
    await waitForSync(page);

    await walk(page, [
      {
        name: 'trainee-FoodDetail',
        open: async (p) => {
          await navDestination(p, 'Food').click();
          await p.waitForTimeout(1800);
          await p.getByRole('button', { name: /Rolled Oats|Chicken Breast|Banana/i }).first().click({ timeout: 15_000 });
          await p.waitForTimeout(2000);
        },
      },
      {
        name: 'trainee-CreateMealTemplate',
        url: '/meal-templates',
        open: async (p) => {
          await p.getByRole('button', { name: /Create template|New template/i }).first().click({ timeout: 15_000 });
          await p.waitForTimeout(2000);
        },
      },
      {
        name: 'trainee-EditMealTemplate',
        url: '/meal-templates',
        open: async (p) => {
          await p.getByRole('button', { name: /Pre-session oats/i }).first().click({ timeout: 15_000 });
          await p.waitForTimeout(1200);
          await p.getByRole('button', { name: /^Edit$/i }).first().click({ timeout: 15_000 });
          await p.waitForTimeout(2000);
        },
      },
      {
        // The one route the app itself offers a non-premium trainee: the
        // workout list's create action, gated once they hold a plan.
        name: 'trainee-Paywall',
        open: async (p) => {
          await workoutsList(p);
          await p.getByRole('button', { name: /Import Options/i }).first().click({ timeout: 15_000 });
          await p.waitForTimeout(1200);
          await p.getByRole('button', { name: /Create your first workout/i }).first().click({ timeout: 15_000 });
          await p.waitForTimeout(3000);
        },
      },
    ]);
  });

  test('trainee: coach chat, now that the seed links the accounts', async ({ traineePage }) => {
    test.setTimeout(300_000);
    const page = traineePage;
    await waitForSync(page);

    await walk(page, [
      {
        // `CoachChatEntry` resolves the conversation and builds
        // `CoachChatScreen` inside its own Scaffold, so one journey renders
        // both files. §13 recorded this as "did not respond within 15s" and
        // wondered whether it was an app defect; the card is rendered under
        // `if (isTrainerClient)` and the seeded trainee was on nobody's
        // roster, so there was nothing to click.
        name: 'trainee-CoachChat',
        open: async (p) => {
          await navDestination(p, 'Profile').click();
          await p.waitForTimeout(1800);
          await p.getByRole('button', { name: /Your coach/i }).first().click({ timeout: 20_000 });
          await p.waitForTimeout(3000);
        },
      },
    ]);
  });

  test('trainee without a trainer: joining one', async ({ unlinkedTraineePage }) => {
    test.setTimeout(300_000);
    const page = unlinkedTraineePage;

    // Deliberately no waitForSync: this account has no seeded data, so the
    // marker that sync uses ("2900") never appears and waiting for it only
    // burns the timeout. An empty Profile tab is the correct state here.
    await walk(page, [
      {
        name: 'trainee-JoinTrainer',
        open: async (p) => {
          await navDestination(p, 'Profile').click();
          await p.waitForTimeout(1800);
          await p.getByRole('button', { name: /Join a trainer/i }).first().click({ timeout: 20_000 });
          await p.waitForTimeout(2000);
        },
      },
    ]);
  });

  test('trainee: the profile questionnaire itself', async ({ appPage }) => {
    test.setTimeout(300_000);
    const page = appPage;
    const viewport = String(page.viewportSize()?.width ?? 0);

    // `signIn` dismisses this screen, which is right for every other test and
    // wrong for this one -- it is the reason ProfileSetupScreen had never been
    // measured. So the sign-in is done by hand here and stops one step early.
    try {
      const loginButton = page.getByRole('button', { name: 'Login' });
      await loginButton.waitFor({ state: 'attached', timeout: 60_000 });
      await typeReliably(page.getByRole('textbox', { name: 'Username' }), TRAINEE_CREDENTIALS.username);
      await typeReliably(page.getByLabel('Password'), TRAINEE_CREDENTIALS.password);
      await loginButton.click();
      await page.getByRole('button', { name: 'Set up later' }).waitFor({
        state: 'attached',
        timeout: 60_000,
      });
      await page.waitForTimeout(2000);
      results.push(await auditScreen(page, 'trainee-ProfileSetup', viewport));
    } catch (err) {
      skipped.push({
        name: 'trainee-ProfileSetup',
        kind: 'by fixture',
        reason: String(err).split('\n')[0].slice(0, 120),
      });
    }
  });

  test('console: the client behind the roster', async ({ trainerPage }) => {
    test.setTimeout(300_000);
    const page = trainerPage;
    const viewport = String(page.viewportSize()?.width ?? 0);

    try {
      await land(page, '/console/dashboard');
      await page.waitForTimeout(2000);
      await page.getByRole('button', { name: /Robert Meyer/i }).first().click({ timeout: 20_000 });
      await page.waitForTimeout(3000);
      results.push(await auditScreen(page, 'console-ClientDetail', viewport));
    } catch (err) {
      skipped.push({
        name: 'console-ClientDetail',
        kind: 'by fixture',
        reason: String(err).split('\n')[0].slice(0, 120),
      });
    }
  });

  /**
   * The screens a browser cannot reach, recorded rather than omitted.
   *
   * None of these is a defect and none of them is clean either — they are
   * simply outside what a web audit can see, and the honest place for that
   * fact is the same table as everything else.
   */
  test('the unreachable, by kind', async () => {
    skipped.push({
      name: 'trainee-ScheduleView',
      kind: 'by definition',
      reason: 'nothing constructs ScheduleView — its only three references are inside its own file',
    });
    skipped.push({
      name: 'trainee-BarcodeScanner',
      kind: 'by platform',
      reason: 'needs a camera stream; the scanner never mounts in a headless browser',
    });
    skipped.push({
      name: 'auth-Welcome',
      kind: 'by platform',
      reason: 'AppRouter renders LoginScreen when kIsWeb — WelcomeScreen is mobile-only by design',
    });
    expect(skipped.length).toBeGreaterThan(0);
  });
});
