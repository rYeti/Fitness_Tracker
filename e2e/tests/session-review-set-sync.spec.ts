import {
  test,
  expect,
  navDestination,
  typeReliably,
  waitForFlutterBoot,
  enableFlutterSemantics,
  signIn,
  TRAINEE_CREDENTIALS,
  TRAINER_CREDENTIALS,
} from '../fixtures/flutter';
import type { Page } from '@playwright/test';

/**
 * RPE, set type and side on logged sets, end to end: what the trainee logs
 * is what the trainer reads in Session Review. See docs/logged-set-sync.md.
 *
 * Two tests, one per half of the path:
 *
 * - **Seeded through the API** checks the server and the console: the sets
 *   are written through the same batch endpoint the app's sync uses, and
 *   Session Review must show each set's tags and leave the warm-up out of
 *   the session's volume and Avg RPE.
 * - **Logged in the trainee app** checks the device: the sets are typed into
 *   the real active workout, pushed by the real SyncService, and read back by
 *   the trainer in a separate browser context — the path that carried none of
 *   the three fields before this work.
 *
 * Both sessions are built so the same numbers come out: a 12 × 40 kg warm-up,
 * a left-side 5 × 100 kg at RPE 9 and a 5 × 100 kg at RPE 8. Volume is
 * 1,000 kg (1,480 if the warm-up counted) and Avg RPE is 8.5.
 *
 * Gated like chat-attachments.spec.ts: needs a bundle built with
 * FORGE_API_URL pointing at a running API seeded by
 * tools/seed-review-data.mjs. Run with
 * `E2E_API=1 npx playwright test session-review-set-sync.spec.ts --project=chromium-desktop`.
 *
 * The API allows five logins per minute per IP (`auth` rate limiter); each
 * test signs in at most twice through the UI plus once through the API, so
 * run the two tests one after the other rather than as a sweep of projects.
 */
const API_ENABLED = !!process.env.E2E_API;
const API = (process.env.E2E_API_URL ?? 'http://127.0.0.1:5080').replace(/\/$/, '');

async function call(path: string, init: { method?: string; body?: unknown; token?: string } = {}) {
  const res = await fetch(`${API}${path}`, {
    method: init.method ?? 'GET',
    headers: {
      'Content-Type': 'application/json',
      ...(init.token ? { Authorization: `Bearer ${init.token}` } : {}),
    },
    body: init.body === undefined ? undefined : JSON.stringify(init.body),
  });
  const text = await res.text();
  if (!res.ok) throw new Error(`${init.method ?? 'GET'} ${path} -> ${res.status} ${text.slice(0, 300)}`);
  return text ? JSON.parse(text) : null;
}

const todayUtc = () => new Date().toISOString().slice(0, 10);

/**
 * Replaces the trainee's session of [workoutName] for today with a fresh one
 * and returns it. Recreated rather than reused so the test runs the same way
 * every time: a completed session can't be started again in the app, and two
 * sessions of one workout on one day are folded into one by the console
 * (docs/trainer-console-duplicate-rows.md), so a leftover would decide which
 * one the trainer sees.
 */
async function freshSessionToday(token: string, workoutName: string, isCompleted: boolean) {
  const workouts = await call('/api/Workout', { token });
  const workout = workouts.find((w: { name: string }) => w.name === workoutName);
  if (!workout) throw new Error(`seeded workout "${workoutName}" not found — run tools/seed-review-data.mjs`);

  const sessions = await call('/api/ScheduledWorkout', { token });
  for (const s of sessions) {
    if (s.workoutId === workout.id && String(s.scheduledDate).startsWith(todayUtc())) {
      await call(`/api/ScheduledWorkout/${s.id}`, { method: 'DELETE', token });
    }
  }
  return call('/api/ScheduledWorkout', {
    method: 'POST',
    token,
    body: {
      workoutId: workout.id,
      scheduledDate: `${todayUtc()}T12:00:00.000Z`,
      isCompleted,
      isSkipped: false,
    },
  });
}

async function traineeApiToken(): Promise<string> {
  const login = await call('/api/auth/login', { method: 'POST', body: TRAINEE_CREDENTIALS });
  return login.token;
}

/** Opens a session in Session Review by its list entry, e.g. "Upper A Today · …". */
async function openSessionToday(trainer: Page, workoutName: string): Promise<void> {
  await navDestination(trainer, 'Session Review').click();
  await trainer
    // A PR badge sits between the name and the date when the session has one.
    .getByRole('button', { name: new RegExp(`^${workoutName} (PR )?Today`) })
    .first()
    .click();
}

/**
 * The per-set assertions both tests share. Each set row in Session Review is
 * one semantics node whose label reads the whole row, tags included, so a
 * screen reader hears the warm-up with its set (session_review_screen.dart,
 * `_semanticsLabel`). Matched by prefix because "under target" is appended
 * when reps miss the prescription, which is the prescription's business.
 */
async function expectLoggedSets(trainer: Page, { warmUpRpe }: { warmUpRpe?: number }) {
  const warmUp = warmUpRpe === undefined
    ? /^Set 1, 12 reps, 40 kg, Warm-up/
    : new RegExp(`^Set 1, 12 reps, 40 kg, RPE ${warmUpRpe}, Warm-up`);
  await expect(trainer.getByText(warmUp)).toBeVisible();
  await expect(trainer.getByText(/^Set 2, 5 reps, 100 kg, RPE 9, Left/)).toBeVisible();
  await expect(trainer.getByText(/^Set 3, 5 reps, 100 kg, RPE 8(,|$)/)).toBeVisible();

  // The session hero: the warm-up counts toward neither figure.
  await expect(trainer.getByText('1,000 kg', { exact: true })).toBeVisible();
  await expect(trainer.getByText('8.5', { exact: true })).toBeVisible();
}

test.describe('RPE, set type and side reach Session Review', () => {
  test.skip(!API_ENABLED, 'set E2E_API=1 and run tools/seed-review-data.mjs against a running API first');
  test.describe.configure({ mode: 'serial' });

  test('sets written through the sync endpoint are tagged, and a warm-up counts toward nothing', async ({
    trainerPage,
  }) => {
    const token = await traineeApiToken();
    const session = await freshSessionToday(token, 'Lower B', true);
    await call(
      `/api/ScheduledWorkout/${session.id}/exercises/${session.exercises[0].id}/sets/batch`,
      {
        method: 'POST',
        token,
        body: [
          { setNumber: 1, reps: 12, weight: 40, weightUnit: 'kg', rpe: 4, setType: 1, side: 0, isCompleted: true },
          { setNumber: 2, reps: 5, weight: 100, weightUnit: 'kg', rpe: 9, setType: 0, side: 1, isCompleted: true },
          { setNumber: 3, reps: 5, weight: 100, weightUnit: 'kg', rpe: 8, setType: 0, side: 0, isCompleted: true },
        ],
      },
    );

    await openSessionToday(trainerPage, 'Lower B');
    // The warm-up's RPE 4 is still shown on its row — it is only left out of
    // the average, which is why the average reads 8.5 and not 7.
    await expectLoggedSets(trainerPage, { warmUpRpe: 4 });
  });

  test('sets logged in the trainee app reach the trainer', async ({ page, browser }) => {
    test.setTimeout(300_000);
    await freshSessionToday(await traineeApiToken(), 'Upper A', false);

    // ── Trainee: log the three sets in the real active workout ────────────
    await page.goto('/');
    await waitForFlutterBoot(page);
    await enableFlutterSemantics(page);
    await signIn(page, TRAINEE_CREDENTIALS);

    // RPE input is opt-in (off by default, per settings_screen.dart).
    await navDestination(page, 'Profile').click();
    await page.getByRole('switch', { name: /Track RPE/ }).click();

    await navDestination(page, 'Gym').click();
    await page.getByRole('button', { name: 'Start Workout' }).click();

    await logSet(page, { setNumber: 1, setType: 'Warm-up', weight: '40', reps: '12' });
    await nextSet(page);
    await logSet(page, { setNumber: 2, side: 'Left', weight: '100', reps: '5', rpe: '9' });
    await nextSet(page);
    await logSet(page, { setNumber: 3, weight: '100', reps: '5', rpe: '8' });

    // Walk the remaining exercises unlogged to the finish button; Session
    // Review lists them as skipped, which is what they were.
    for (let i = 0; i < 20; i++) {
      const finish = page.getByRole('button', { name: 'Workout completed!' });
      if (await finish.count()) {
        await finish.click();
        // The "Workout Complete!" summary.
        await page.getByRole('button', { name: 'Done', exact: true }).click();
        break;
      }
      const next = page
        .getByRole('button', { name: 'Next Exercise', exact: true })
        .or(page.getByRole('button', { name: 'Next Set', exact: true }))
        .first();
      await next.click();
      await dismissRestTimer(page);
    }

    // Push now rather than waiting for the next launch or resume sync.
    await navDestination(page, 'Profile').click();
    await page.getByRole('button', { name: /^Sync now/ }).click();
    await expect.poll(async () => loggedSetCountToday('Upper A'), {
      message: 'the trainee app never pushed the logged sets',
      timeout: 60_000,
    }).toBeGreaterThanOrEqual(3);

    // ── Trainer: a separate device, reading what arrived ──────────────────
    const trainerContext = await browser.newContext();
    const trainer = await trainerContext.newPage();
    await trainer.goto('/');
    await waitForFlutterBoot(trainer);
    await enableFlutterSemantics(trainer);
    await signIn(trainer, TRAINER_CREDENTIALS);

    await openSessionToday(trainer, 'Upper A');
    await expectLoggedSets(trainer, {});

    await trainerContext.close();
  });
});

/**
 * Logs one set on the current exercise. Set type and side live in a sheet
 * opened from the set's number circle in the set list.
 */
async function logSet(
  page: Page,
  set: { setNumber: number; setType?: string; side?: string; weight: string; reps: string; rpe?: string },
): Promise<void> {
  if (set.setType || set.side) {
    await page.getByRole('button', { name: String(set.setNumber), exact: true }).click();
    if (set.setType) await page.getByRole('button', { name: set.setType, exact: true }).click();
    if (set.side) await page.getByRole('button', { name: set.side, exact: true }).click();
    await page.getByRole('button', { name: 'Dismiss' }).click();
  }

  await typeIntoField(page, /^Weight/, set.weight);
  await typeIntoField(page, /^Reps/, set.reps);
  if (set.rpe) await typeIntoField(page, /^RPE/, set.rpe);
}

/**
 * Scrolls a field to the middle of the screen, then types into it.
 *
 * The fields live inside Flutter's own scroll view, which Playwright can't
 * scroll into view — it scrolls the page, and the page doesn't move. Worse, a
 * field left clipped at the bottom edge (just above the fixed Next Set bar)
 * *looks* typeable: the semantics <input> accepts the keys and reads them
 * back, so `typeReliably` passes, while Flutter's own editor never receives
 * them and the field still shows its hint. The first version of this spec
 * logged every set with no reps that way. Centring the field first is what
 * makes the keystrokes land.
 */
async function typeIntoField(page: Page, name: RegExp, value: string): Promise<void> {
  const field = page.getByRole('textbox', { name });
  const viewport = page.viewportSize()!;
  for (let i = 0; i < 8; i++) {
    const box = await field.boundingBox();
    const centre = box ? box.y + box.height / 2 : 0;
    if (box && centre > viewport.height * 0.25 && centre < viewport.height * 0.6) break;
    await page.mouse.move(viewport.width / 2, viewport.height / 2);
    await page.mouse.wheel(0, box ? centre - viewport.height * 0.4 : -3000);
    await page.waitForTimeout(300);
  }
  await typeReliably(field, value);
}

async function nextSet(page: Page): Promise<void> {
  await page.getByRole('button', { name: 'Next Set', exact: true }).click();
  await dismissRestTimer(page);
}

/**
 * The rest timer opens as a modal after each set. It has no labelled close
 * control and ignores Escape, so the only way out is its barrier — tapped by
 * position, the one place this spec has to. Recorded as an accessibility gap
 * in docs/logged-set-sync.md.
 */
async function dismissRestTimer(page: Page): Promise<void> {
  // Keyed on a control only the dialog has: "Rest Timer" is also the app
  // bar's button, which never goes away.
  const timer = page.getByRole('button', { name: '+30s', exact: true });
  await timer.waitFor({ state: 'attached', timeout: 3_000 }).catch(() => {});
  if (await timer.count()) {
    await page.mouse.click(40, 300);
    await timer.waitFor({ state: 'detached', timeout: 10_000 });
  }
}

/** How many sets the server holds on today's session of [workoutName]. */
async function loggedSetCountToday(workoutName: string): Promise<number> {
  // Read through the trainer-independent owner endpoint; one extra login is
  // within the rate limit this spec budgets for.
  const token = cachedToken ??= await traineeApiToken();
  const workouts = await call('/api/Workout', { token });
  const workout = workouts.find((w: { name: string }) => w.name === workoutName);
  const sessions = await call('/api/ScheduledWorkout', { token });
  const today = sessions.find(
    (s: { workoutId: string; scheduledDate: string }) =>
      s.workoutId === workout.id && String(s.scheduledDate).startsWith(todayUtc()),
  );
  if (!today) return 0;
  return today.exercises.reduce((n: number, e: { sets: unknown[] }) => n + e.sets.length, 0);
}
let cachedToken: string | undefined;
