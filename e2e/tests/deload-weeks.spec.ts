import type { Page } from '@playwright/test';

import {
  test,
  expect,
  navDestination,
  waitForFlutterBoot,
  enableFlutterSemantics,
  signIn,
  UNLINKED_TRAINEE_CREDENTIALS,
} from '../fixtures/flutter';

/**
 * Deload weeks, end to end through the real UI — see `docs/deload-weeks.md`.
 *
 * Uses the unlinked trainee (`lena.fischer`) for the same reason
 * `self-managed-nutrient-pins.spec.ts` does, and it matters more here: deload
 * authority keys on the *plan*, and a plan with `AssignedByTrainerId` set is
 * read-only to its owner however entitled they are (§6). An account on
 * somebody's roster is the wrong side of that rule to test the trainee-owned
 * path from.
 *
 * Premium is seeded into local storage rather than granted live, exactly as
 * the pins spec does and for the same documented reason: CLAUDE.md's "Known
 * web constraints" says `purchases_flutter` cannot be relied on in a browser,
 * and `AccessProvider._checkRevenueCat` is a no-op under `kIsWeb`, so
 * `_isPremium` only ever comes from the SharedPreferences cache of a previous
 * check. Seeding that cache stands in for a real paying user's browser.
 *
 * Needs a live API seeded with `tools/seed-review-data.mjs`, which CI's
 * `web.yml` does not provide — so, like the audit and pins specs, it is gated
 * behind AUDIT=1 rather than left to hang on a login that cannot succeed.
 */
const AUDIT_ENABLED = !!process.env.AUDIT;
const API_BASE = 'http://127.0.0.1:5080';

/** The strip renders one of these per week; the accessible name carries the state. */
const weekChip = (page: Page, week: number) =>
  page.getByRole('button', { name: new RegExp(`^Week ${week}\\b`) }).first();

/**
 * Walk to the plan screen.
 *
 * Gym → "Manage Workouts" → the plan's row → "Edit Details". Four hops,
 * because `EditWorkoutView` is only reachable with a `planId` and nothing
 * links to it directly. A helper so a change to that path is one edit rather
 * than one per test.
 */
async function openPlanScreen(page: Page) {
  await navDestination(page, 'Gym').click();
  await page.getByRole('button', { name: 'Manage Workouts' }).click();

  const editDetails = page.getByRole('button', { name: 'Edit Details' }).first();
  await editDetails.waitFor({ state: 'attached', timeout: 30_000 });
  await editDetails.click();
}

test.describe('deload weeks', () => {
  test.skip(!AUDIT_ENABLED, 'set AUDIT=1 and run tools/seed-review-data.mjs first');

  test('a premium user marks one week, and only that week, and it persists', async ({
    page,
  }) => {
    test.setTimeout(180_000);

    const loginResponse = await page.request.post(`${API_BASE}/api/auth/login`, {
      data: UNLINKED_TRAINEE_CREDENTIALS,
    });
    const { token, id } = await loginResponse.json();

    // Clear any deload left by a previous run, so what this asserts is the
    // toggle it performs rather than whatever state the account was left in.
    const plansResponse = await page.request.get(`${API_BASE}/api/WorkoutPlan`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    const plans = (await plansResponse.json()) as Array<{ id: string; isActive: boolean }>;
    const plan = plans.find((p) => p.isActive) ?? plans[0];
    expect(plan, 'the seed must leave this account at least one plan').toBeTruthy();
    await page.request.put(`${API_BASE}/api/WorkoutPlan/${plan.id}/deload-weeks`, {
      headers: { Authorization: `Bearer ${token}` },
      data: [],
    });

    // shared_preferences_web prefixes keys with "flutter." and JSON-encodes
    // values. Must run before first paint, hence an init script.
    await page.addInitScript(
      ({ userId }) => {
        window.localStorage.setItem('flutter.access_is_premium', 'true');
        window.localStorage.setItem('flutter.access_cached_user_id', JSON.stringify(userId));
      },
      { userId: id },
    );

    await page.goto('/');
    await waitForFlutterBoot(page);
    await enableFlutterSemantics(page);
    await signIn(page, UNLINKED_TRAINEE_CREDENTIALS);
    await openPlanScreen(page);

    const week5 = weekChip(page, 5);
    await expect(week5).toBeVisible({ timeout: 20_000 });
    // Not a deload yet: the accessible name is bare, with no volume in it.
    await expect(week5).toHaveAccessibleName('Week 5');

    // The write is a local drift update plus a sync push, so a fixed delay
    // would race the push. Wait for the request itself.
    const [putResponse] = await Promise.all([
      page.waitForResponse(
        (r) => r.url().includes('/deload-weeks') && r.request().method() === 'PUT',
        { timeout: 60_000 },
      ),
      week5.click(),
    ]);
    expect(putResponse.ok()).toBe(true);

    // The default volume, and the direction of the number, both surface in the
    // accessible name — 50 means *perform* 50%, and getting that backwards
    // would invert the feature.
    await expect(week5).toHaveAccessibleName('Week 5, deload at 50 percent volume');

    // The one-off rule: tapping one week must not opt the user into a cadence.
    // Week 10 is where an "every 5" generator would have put the next one.
    await expect(weekChip(page, 10)).toHaveAccessibleName('Week 10');
    await expect(weekChip(page, 1)).toHaveAccessibleName('Week 1');

    // Round-trip. A fresh boot re-pulls the plan, so this is what proves the
    // toggle reached the server rather than only local state — and it is the
    // assertion that would have failed before `_pullWorkoutPlans` learned to
    // reconcile a plan it already holds.
    await page.reload();
    await waitForFlutterBoot(page);
    await enableFlutterSemantics(page);
    const loginButton = page.getByRole('button', { name: 'Login' });
    await Promise.race([
      loginButton.waitFor({ state: 'attached', timeout: 30_000 }).catch(() => {}),
      navDestination(page, 'Gym').waitFor({ state: 'attached', timeout: 30_000 }).catch(() => {}),
    ]);
    if (await loginButton.count()) {
      await signIn(page, UNLINKED_TRAINEE_CREDENTIALS);
    }
    await openPlanScreen(page);

    await expect(weekChip(page, 5)).toHaveAccessibleName(
      'Week 5, deload at 50 percent volume',
      { timeout: 30_000 },
    );
  });

  test('a non-premium user sees the strip locked rather than absent', async ({ page }) => {
    test.setTimeout(120_000);

    // No premium seeded. The strip must still render — hiding a control makes
    // a user think the feature does not exist, so it is shown with a lock and
    // routes to the paywall (§10).
    await page.goto('/');
    await waitForFlutterBoot(page);
    await enableFlutterSemantics(page);
    await signIn(page, UNLINKED_TRAINEE_CREDENTIALS);
    await openPlanScreen(page);

    const week5 = weekChip(page, 5);
    await expect(week5).toBeVisible({ timeout: 20_000 });

    // Tapping opens the paywall instead of marking the week. Asserting the
    // week did *not* change is the half that matters: a gate that shows a
    // paywall and writes anyway is not a gate.
    await week5.click();
    await expect(week5).toHaveAccessibleName('Week 5');
  });
});
