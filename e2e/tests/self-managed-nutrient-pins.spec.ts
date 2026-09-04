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
 * cold-start cache hit. The cache key is this account's *username*, not its
 * server id — `main.dart` calls `accessProvider.initialize(userId:
 * restoredAuth.user!.username, ...)`, despite the parameter's name — so the
 * seed below must match `UNLINKED_TRAINEE_CREDENTIALS.username` for
 * `cacheIsOurs` (`access_provider.dart:158`) to accept it.
 */
test.describe('self-managed nutrient pins', () => {
  test('an unlinked premium user can choose and persist their own tracked nutrients', async ({
    page,
  }) => {
    test.setTimeout(120_000);

    // shared_preferences_web prefixes every key with "flutter." and
    // JSON-encodes every value, strings included — a bare `true` for the
    // bool, but a quoted `"lena.fischer"` for the string. Must run before the
    // app's first paint, so it's an init script rather than a
    // post-navigation page.evaluate.
    await page.addInitScript(
      ({ username }) => {
        window.localStorage.setItem('flutter.access_is_premium', 'true');
        window.localStorage.setItem('flutter.access_cached_user_id', JSON.stringify(username));
      },
      { username: UNLINKED_TRAINEE_CREDENTIALS.username },
    );

    await page.goto('/');
    await waitForFlutterBoot(page);
    await enableFlutterSemantics(page);

    // Sign in through the real form once just to get a token, then reset this
    // account's pins to the defaults over the API directly. Without this, a
    // leftover pin set from a previous run (or from manually exercising the
    // endpoint, as this feature's own backend verification did) makes
    // `wasPinned` below depend on whatever state the account happened to be
    // in rather than on the toggle this test performs.
    await signIn(page, UNLINKED_TRAINEE_CREDENTIALS);
    const apiBase = 'http://127.0.0.1:5080';
    const loginResponse = await page.request.post(`${apiBase}/api/auth/login`, {
      data: UNLINKED_TRAINEE_CREDENTIALS,
    });
    const { token } = await loginResponse.json();
    await page.request.put(`${apiBase}/api/TrainerClient/my-nutrient-pins`, {
      headers: { Authorization: `Bearer ${token}` },
      data: ['fibre', 'sugar', 'sodium'],
    });

    await navDestination(page, 'Food').click();
    // The card's pinned-nutrients GET is fired from initState and raced
    // against the picker sheet's own pinnedKeys snapshot — opening the sheet
    // before this resolves shows (and toggles from) stale, possibly-empty
    // state. Wait for the response itself rather than a guessed delay.
    await page.waitForResponse(
      (r) => r.url().includes('/api/TrainerClient/my-nutrient-pins') && r.request().method() === 'GET',
    );

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
    // _NutrientChip's Semantics(selected: pinned, ...) surfaces as
    // aria-current on a role=button element, not aria-selected -- the ARIA
    // spec doesn't permit aria-selected on a plain button, so the engine
    // picks the nearest valid analogue instead.
    const wasPinned = (await ironChip.getAttribute('aria-current')) === 'true';
    expect(wasPinned).toBe(false); // seeded to the defaults above, which don't include iron

    // The toggle is a fire-and-forget PUT behind an optimistic local update
    // (_toggleMyPin) — a plain click + fixed wait races a page reload against
    // that request, and a reload cancels any XHR still in flight, so the
    // toggle can silently never reach the server. Wait for the response
    // itself instead of a guessed delay.
    const [putResponse] = await Promise.all([
      page.waitForResponse((r) => r.url().includes('/api/TrainerClient/my-nutrient-pins') && r.request().method() === 'PUT'),
      ironChip.click(),
    ]);
    expect(putResponse.ok()).toBe(true);

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
    // Same race as the first load: wait for the pins GET this reload fires,
    // not a guessed delay, before trusting what the picker shows.
    await page.waitForResponse(
      (r) => r.url().includes('/api/TrainerClient/my-nutrient-pins') && r.request().method() === 'GET',
    );
    const chooseButtonAfterReload = page.getByRole('button', { name: 'Choose', exact: true });
    await expect(chooseButtonAfterReload).toBeVisible({ timeout: 20_000 });
    await chooseButtonAfterReload.click();
    await page.waitForTimeout(500);

    const ironChipAfterReload = page.getByRole('button', { name: 'Iron', exact: true });
    await expect(ironChipAfterReload).toBeVisible({ timeout: 10_000 });
    const isPinnedNow = (await ironChipAfterReload.getAttribute('aria-current')) === 'true';
    expect(isPinnedNow).toBe(!wasPinned);
  });
});
