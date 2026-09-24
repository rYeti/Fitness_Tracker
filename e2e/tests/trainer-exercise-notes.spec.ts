import {
  test,
  expect,
  navDestination,
  waitForFlutterBoot,
  enableFlutterSemantics,
  signIn,
  TRAINEE_CREDENTIALS,
  TRAINER_CREDENTIALS,
} from '../fixtures/flutter';
import type { Page } from '@playwright/test';

/**
 * A trainee's note on an exercise, typed during an active workout, has to
 * reach their trainer's Session Review. See docs/trainer-exercise-notes.md.
 *
 * The widget and API tests each cover one side. This drives the whole path in
 * two real browsers, because the defect it guards against lived *between* the
 * sides: every layer had a notes field, and nothing ever sent it.
 *
 *   trainee browser: Start Workout → type a note → finish → Settings → Sync now
 *   API:             the note is on the server's copy of the session
 *   trainer browser: Session Review → the note is under the exercise
 *
 * Needs a running API behind the bundle and a seed, like chat-attachments.spec.ts:
 *
 *   flutter build web --release --no-web-resources-cdn \
 *     --dart-define=FORGE_API_URL=http://127.0.0.1:5080/
 *   node tools/seed-review-data.mjs
 *   E2E_API=1 npx playwright test trainer-exercise-notes.spec.ts
 *
 * Desktop project only. The API allows 5 auth requests per minute per IP and
 * this test makes three (the API precheck and two sign-ins); running it in all
 * three projects at once would be rejected with 429s that look like a wrong
 * password. It also writes to the one seeded session scheduled for today,
 * which the three projects would otherwise race over.
 */
const API_ENABLED = !!process.env.E2E_API;
const API = (process.env.E2E_API_URL ?? 'http://127.0.0.1:5080').replace(/\/$/, '');

type ScheduledExercise = { id: string; notes: string | null };
type ScheduledWorkout = {
  id: string;
  workoutId: string;
  workoutPlanId: string | null;
  templateWorkoutId: string | null;
  scheduledDate: string;
  notes: string | null;
  isCompleted: boolean;
  isSkipped: boolean;
  exercises: ScheduledExercise[];
};

async function api<T>(path: string, init: { method?: string; token?: string; body?: unknown } = {}): Promise<T> {
  const res = await fetch(`${API}${path}`, {
    method: init.method ?? 'GET',
    headers: {
      'Content-Type': 'application/json',
      ...(init.token ? { Authorization: `Bearer ${init.token}` } : {}),
    },
    body: init.body === undefined ? undefined : JSON.stringify(init.body),
  });
  const text = await res.text();
  if (!res.ok) throw new Error(`${init.method ?? 'GET'} ${path} -> ${res.status} ${text.slice(0, 200)}`);
  return (text ? JSON.parse(text) : null) as T;
}

/** The seed schedules exactly one session for today (Upper A). */
function todaysSession(sessions: ScheduledWorkout[]): ScheduledWorkout | undefined {
  const today = new Date().toISOString().slice(0, 10);
  return sessions.find((s) => s.scheduledDate.slice(0, 10) === today);
}

type Field = { label: string; value: string; hintedName?: boolean };

/**
 * Fill the active workout's text fields, in on-screen order.
 *
 * Not `typeReliably`, and not a click per field. Clicking a field's semantics
 * node moves the *browser's* focus onto that node's `<input>` but not
 * Flutter's: after the first field, every click left Flutter focused on
 * Weight while `document.activeElement` — and `typeReliably`'s readback, which
 * reads the clicked node's own input — reported the new field. The keys landed
 * in a box the framework was not listening to, the screenshot showed Reps and
 * the note still empty, and an empty note is what got saved. Tab moves
 * Flutter's focus and the browser's together, so only the first field is
 * clicked and every later one is reached by tabbing until it is the focused
 * element.
 *
 * `hintedName` marks a field whose hint is part of its accessible name. Once
 * the framework's controller holds text the hint leaves the name ("Exercise
 * Notes How did it feel?" becomes "Exercise Notes"), which is the only
 * evidence available here that Flutter, not just the DOM, has the value.
 */
async function fillFields(page: Page, fields: Field[]): Promise<void> {
  // First line only: a field's accessible name can carry its hint or value
  // after a line break ("Weight\n0.0").
  const focusedLabel = () =>
    page.evaluate(() => document.activeElement?.getAttribute('aria-label')?.split('\n')[0] ?? null);
  const focusedValue = () =>
    page.evaluate(
      () => (document.activeElement as HTMLInputElement | HTMLTextAreaElement | null)?.value ?? '',
    );

  await page.getByRole('textbox', { name: new RegExp(`^${fields[0].label}`) }).click();
  await page.waitForTimeout(300);

  for (const { label, value, hintedName } of fields) {
    for (let tabs = 0; (await focusedLabel()) !== label; tabs++) {
      if (tabs === 20) throw new Error(`could not focus "${label}" (focus is on "${await focusedLabel()}")`);
      await page.keyboard.press('Tab');
      await page.waitForTimeout(200);
    }

    // A value pulled from an earlier session is replaced, not appended to.
    if ((await focusedValue()) !== '') {
      await page.keyboard.press('ControlOrMeta+a');
      await page.keyboard.press('Delete');
    }
    await page.keyboard.type(value, { delay: 30 });
    expect(await focusedValue(), `value of the focused "${label}" field`).toBe(value);
    if (hintedName) {
      await expect(page.getByRole('textbox', { name: label, exact: true })).toBeAttached();
    }
  }
}

/** Every next-set / next-exercise press until the finish button replaces it. */
async function finishWorkout(page: Page): Promise<void> {
  const finish = page.getByRole('button', { name: 'Workout completed!' });
  const next = page.getByRole('button', { name: /^Next (Set|Exercise)$/ });
  // A control only the sheet has: the app bar also carries a "Rest Timer"
  // button, so that name never goes away.
  const restTimer = page.getByRole('button', { name: '-30s', exact: true });
  for (let press = 0; press < 40; press++) {
    if (await finish.count()) break;
    await next.first().click();
    // Every set but the last opens the rest timer, a modal bottom sheet;
    // tapping the scrim above it is how a user closes it.
    await restTimer.waitFor({ state: 'visible', timeout: 3000 }).catch(() => {});
    if (await restTimer.count()) {
      await page.mouse.click(page.viewportSize()!.width / 2, 120);
      await restTimer.waitFor({ state: 'detached', timeout: 10_000 });
    }
  }
  await finish.click();
  // The summary dialog. Its Done pops the workout screen.
  await page.getByRole('button', { name: 'Done', exact: true }).click();
}

test.describe('exercise notes reach the trainer', () => {
  test.skip(!API_ENABLED, 'set E2E_API=1 and run tools/seed-review-data.mjs against a running API first');

  // Signs in inside the test rather than through the `traineePage` fixture:
  // a fixture signs in before this skip runs, so the two skipped projects
  // would each still spend an auth request.
  test('a note typed in an active workout shows up in Session Review', async ({ page, browser }) => {
    test.skip(test.info().project.name !== 'chromium-desktop', 'desktop only: see the file comment');
    test.setTimeout(300_000);

    // Unique per run, so a note left by an earlier run can never satisfy the
    // final assertion. Realistic otherwise, per CLAUDE.md's copy rules.
    const note = `Left elbow ached at lockout on the top set (${Date.now().toString(36)})`;

    // Put today's session back to not-started if an earlier run finished it;
    // the Gym tab only offers Start Workout for a session that isn't done.
    const { token } = await api<{ token: string }>('/api/auth/login', {
      method: 'POST',
      body: TRAINEE_CREDENTIALS,
    });
    const before = todaysSession(await api<ScheduledWorkout[]>('/api/ScheduledWorkout', { token }));
    expect(before, 'the seed schedules one session for today').toBeDefined();
    if (before!.isCompleted) {
      await api(`/api/ScheduledWorkout/${before!.id}`, {
        method: 'PUT',
        token,
        body: { ...before!, isCompleted: false, exercises: undefined },
      });
    }
    // And clear an earlier run's note, so the field starts empty the way it
    // does for a first entry.
    for (const exercise of before!.exercises.filter((e) => e.notes)) {
      await api(`/api/ScheduledWorkout/exercises/${exercise.id}/notes`, {
        method: 'PUT',
        token,
        body: { notes: null },
      });
    }

    // ── Trainee: log a set and write the note ──────────────────────────────
    const trainee = page;
    await trainee.goto('/');
    await waitForFlutterBoot(trainee);
    await enableFlutterSemantics(trainee);
    await signIn(trainee, TRAINEE_CREDENTIALS);
    // Let the sign-in pull land before opening the Gym tab.
    await trainee.waitForTimeout(6000);
    await navDestination(trainee, 'Gym').click();
    await trainee.getByRole('button', { name: /Start Workout/i }).first().click({ timeout: 30_000 });

    await fillFields(trainee, [
      { label: 'Weight', value: '82.5' },
      { label: 'Reps', value: '8' },
      { label: 'Exercise Notes', value: note, hintedName: true },
    ]);

    await finishWorkout(trainee);

    // Push now rather than waiting on the app's throttled background sync.
    await navDestination(trainee, 'Profile').click();
    await trainee.getByRole('button', { name: /Sync now/i }).click({ timeout: 30_000 });
    await expect(trainee.getByText('Sync complete').first()).toBeVisible({ timeout: 60_000 });

    // ── API: the note left the device ──────────────────────────────────────
    // Checked on its own so a failure says which half broke: a missing note
    // here is the push, a missing note below is the console.
    const after = todaysSession(await api<ScheduledWorkout[]>('/api/ScheduledWorkout', { token }));
    expect(after!.isCompleted).toBe(true);
    expect(after!.exercises.map((e) => e.notes)).toContain(note);

    // ── Trainer: Session Review shows it ───────────────────────────────────
    const trainerContext = await browser.newContext();
    const trainer = await trainerContext.newPage();
    await trainer.goto('/');
    await waitForFlutterBoot(trainer);
    await enableFlutterSemantics(trainer);
    await signIn(trainer, TRAINER_CREDENTIALS);

    await navDestination(trainer, 'Session Review').click();
    // The newest session is selected by default, and today's is the newest
    // one that isn't in the future.
    await expect(trainer.getByText(note)).toBeVisible({ timeout: 30_000 });
    await expect(trainer.getByText('CLIENT NOTE').first()).toBeVisible();
    await trainer.screenshot({ path: test.info().outputPath('session-review.png') });

    await trainerContext.close();
  });
});
