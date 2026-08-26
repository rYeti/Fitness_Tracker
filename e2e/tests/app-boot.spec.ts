import { test, expect, consoleErrorsOf } from '../fixtures/flutter';

// The web bundle is how the Trainer Console ships. These tests assert the two
// things that have to be true before any console test is worth writing: the
// engine boots, and a signed-out visitor lands on login rather than the
// consumer welcome pitch.
//
// Everything is queried by ARIA role and accessible name, because that is the
// only surface a canvas-rendered Flutter app exposes to a browser. See
// ../fixtures/flutter.ts.

test.describe('web bundle boot', () => {
  test('renders the sign-in screen with a usable semantics tree', async ({ appPage }) => {
    await expect(appPage.getByText('ForgeForm').first()).toBeVisible();
    await expect(appPage.getByText('Welcome back')).toBeVisible();

    await expect(appPage.getByRole('textbox', { name: 'Username' })).toBeVisible();
    // Not getByRole('textbox') — Flutter renders an obscured field as
    // <input type="password">, which has no implicit ARIA role at all. The
    // accessible name is the only handle it has.
    await expect(appPage.getByLabel('Password')).toBeVisible();

    await expect(appPage.getByRole('button', { name: 'Login' })).toBeVisible();
    await expect(appPage.getByRole('button', { name: 'Register' })).toBeVisible();
    await expect(appPage.getByRole('button', { name: 'Forgot password?' })).toBeVisible();
  });

  test('sends a signed-out visitor to login, not the welcome screen', async ({ appPage }) => {
    // CLAUDE.md, "Web support": pre-auth collects nothing — WelcomeScreen on
    // mobile, straight to login on web. The rule is a platform check
    // (`kIsWeb`), not a viewport check, so it must hold at 390px too; both
    // Playwright projects run this.
    await expect(appPage.getByRole('textbox', { name: 'Username' })).toBeVisible();
    await expect(appPage.getByText('Your personal fitness companion')).toHaveCount(0);
    await expect(appPage.getByRole('button', { name: 'Create account' })).toHaveCount(0);
  });

  test('boots without throwing', async ({ appPage }) => {
    // Failed network calls to the API are expected here — nothing is signed in
    // and no backend is running — so only genuine JS/Dart exceptions count.
    const fatal = consoleErrorsOf(appPage).filter((line) => {
      // purchases_flutter fetches its JS mapping from a CDN at runtime and
      // always fails on web. Documented as non-fatal in CLAUDE.md ("Known web
      // constraints") — the app boots regardless, only premium paths are dead.
      if (/purchases-js-hybrid-mappings|cdn\.jsdelivr\.net/.test(line)) return false;
      // Google Fonts is fetched for the Roboto fallback; a miss degrades
      // typography, it does not stop the engine.
      if (/fonts\.gstatic\.com/.test(line)) return false;
      return /Uncaught|Unhandled|Assertion failed|TypeError|RangeError/i.test(line);
    });
    expect(fatal, `Unexpected errors during boot:\n${fatal.join('\n')}`).toEqual([]);
  });
});

test.describe('hosting contract', () => {
  test('rewrites an unknown deep link to the app shell', async ({ page }) => {
    // Whatever host serves this bundle has to rewrite unknown paths to
    // /index.html or a refresh on a deep link 404s. tools/serve-web.mjs
    // implements that rule; this test is what keeps it honest.
    const response = await page.goto('/trainer/clients/42');
    expect(response?.status()).toBe(200);
    await expect(page.locator('flutter-view')).toBeAttached({ timeout: 60_000 });
  });

  test('still 404s a missing asset', async ({ page }) => {
    // The rewrite must not swallow asset misses — a font URL that silently
    // returns HTML fails somewhere far from the cause.
    const response = await page.goto('/assets/does-not-exist.png');
    expect(response?.status()).toBe(404);
  });
});
