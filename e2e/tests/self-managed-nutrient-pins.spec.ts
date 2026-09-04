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
 * An unlinked premium user (`lena.fischer` — deliberately not on anyone's
 * roster, see `UNLINKED_TRAINEE_CREDENTIALS`) has nobody to curate the
 * "Tracked nutrients" picker for them. Since PR #83 made the picker
 * coach-driven, this account had no way to reach it at all until the
 * RevenueCat-verified self-service pins feature — see
 * `docs/revenuecat-self-managed-pins.md`.
 *
 * This account is granted the RevenueCat entitlement out of band (a fabricated
 * webhook POST, the same one RevenueCat itself would send) before this suite
 * runs — see the project README for the exact command — since neither the
 * seed script nor the app itself can grant it.
 *
 * The server-side grant alone does not unlock the card on web: CLAUDE.md's
 * "Known web constraints" says `purchases_flutter` cannot be relied on in a
 * browser, and `AccessProvider._checkRevenueCat` (`access_provider.dart:258`)
 * is in fact a no-op under `kIsWeb` — so `_isPremium` never gets set from a
 * live check here, only from `SharedPreferences`' cache of a *previous*
 * check (real hardware, in production). This test seeds that cache directly
 * before the app boots, standing in for a device that already knows it is
 * premium — exactly the state a real paying user's browser would be in — so
 * `hasPremiumAccess` unlocks the card the same way it would off a genuine
 * cold-start cache hit. `LENA_FISCHER_USER_ID` must match the account the
 * README's webhook command was run against.
 */
const LENA_FISCHER_USER_ID = 'a158d657-db33-4bcc-96d2-daa4641b4ddb';

test.describe('self-managed nutrient pins', () => {
  test('an unlinked premium user can choose and persist their own tracked nutrients', async ({
    page,
  }) => {
    test.setTimeout(120_000);

    // shared_preferences_web prefixes every key with "flutter." and stores a
    // bool or a plain String verbatim (no JSON-quoting) — only List<String>
    // gets JSON-encoded. Must run before the app's first paint, so it's an
    // init script rather than a post-navigation page.evaluate.
    await page.addInitScript(
      ({ userId }) => {
        window.localStorage.setItem('flutter.access_is_premium', 'true');
        window.localStorage.setItem('flutter.access_cached_user_id', userId);
      },
      { userId: LENA_FISCHER_USER_ID },
    );

    await page.goto('/');
    await waitForFlutterBoot(page);
    await enableFlutterSemantics(page);
    await signIn(page, UNLINKED_TRAINEE_CREDENTIALS);

    await navDestination(page, 'Food').click();
    await page.waitForTimeout(1500);

    // Read-only for a linked client, this account has no trainer and holds
    // the entitlement, so the picker must be reachable.
    // exact: true matters here — the date nav's own button is accessibly
    // named "Choose a date" (pickDate), a substring match away from
    // colliding with this card's "Choose" (chooseNutrients).
    const chooseButton = page.getByRole('button', { name: 'Choose', exact: true });
    await expect(chooseButton).toBeVisible({ timeout: 20_000 });

    await chooseButton.click();
    await page.waitForTimeout(500);

    const ironChip = page.getByRole('button', { name: 'Iron', exact: true });
    await expect(ironChip).toBeVisible({ timeout: 10_000 });
    const wasPinned = (await ironChip.getAttribute('aria-selected')) === 'true';
    await ironChip.click();
    await page.waitForTimeout(500);

    // Close the picker sheet.
    await page.keyboard.press('Escape');
    await page.waitForTimeout(500);

    // Reload the whole app — a fresh boot re-fetches
    // `GET api/TrainerClient/my-nutrient-pins`, so this is the round-trip
    // check that the toggle actually reached the server, not just local state.
    // Whether the JWT survives a reload is not this test's concern, so handle
    // either outcome: sign in again only if the login screen is what comes back.
    await page.reload();
    await waitForFlutterBoot(page);
    await enableFlutterSemantics(page);
    const loginButton = page.getByRole('button', { name: 'Login' });
    await Promise.race([
      loginButton.waitFor({ state: 'attached', timeout: 30_000 }).catch(() => {}),
      navDestination(page, 'Food').waitFor({ state: 'attached', timeout: 30_000 }).catch(() => {}),
    ]);
    if (await loginButton.count()) {
      await signIn(page, UNLINKED_TRAINEE_CREDENTIALS);
    }

    await navDestination(page, 'Food').click();
    await page.waitForTimeout(1500);
    const chooseButtonAfterReload = page.getByRole('button', { name: 'Choose', exact: true });
    await expect(chooseButtonAfterReload).toBeVisible({ timeout: 20_000 });
    await chooseButtonAfterReload.click();
    await page.waitForTimeout(500);

    const ironChipAfterReload = page.getByRole('button', { name: 'Iron', exact: true });
    await expect(ironChipAfterReload).toBeVisible({ timeout: 10_000 });
    const isPinnedNow = (await ironChipAfterReload.getAttribute('aria-selected')) === 'true';
    expect(isPinnedNow).toBe(!wasPinned);
  });
});
