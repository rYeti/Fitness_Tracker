import { test as base, expect, type Locator, type Page } from '@playwright/test';

/**
 * Flutter web draws the entire app into a `<canvas>`. There are no divs, no
 * buttons, no text nodes — `page.getByText('Login')` finds nothing, because
 * "Login" is pixels.
 *
 * The one exception is the accessibility tree. When accessibility is switched
 * on, Flutter mirrors its `Semantics` tree into real DOM elements
 * (`<flt-semantics role="button" aria-label="Login">`), and those *are*
 * queryable — by role and accessible name, exactly like any other page.
 *
 * That is why these tests are written entirely against roles and names, and
 * why the accessibility rules in CLAUDE.md are load-bearing here: an element
 * with no semantic label is not merely hard for a screen reader to announce,
 * it is invisible to this suite.
 *
 * Flutter does not build that tree by default (it costs memory and frame
 * time). It exposes a hidden button to turn it on, which is what
 * `enableFlutterSemantics` clicks.
 */
export async function enableFlutterSemantics(page: Page): Promise<void> {
  const placeholder = page.locator('flt-semantics-placeholder[role="button"]');
  await placeholder.waitFor({ state: 'attached', timeout: 60_000 });

  // The placeholder is positioned off-screen with zero opacity so sighted
  // users never see it, which means Playwright's actionability checks would
  // refuse a normal .click(). Dispatching directly is the point, not a
  // workaround.
  await placeholder.evaluate((el: HTMLElement) => el.click());

  // Semantics are built on the next frame; wait for the tree to actually
  // appear rather than assuming the click took.
  await page.locator('flt-semantics[role], flt-semantics[aria-label]').first().waitFor({
    state: 'attached',
    timeout: 30_000,
  });
}

/**
 * Wait for the Flutter engine to have mounted its view.
 *
 * Deliberately not a wait on `<canvas>`: CanvasKit renders into a surface the
 * engine keeps out of reach of a document query, so counting canvases returns
 * zero even on a fully painted app. `<flutter-view>` plus the semantics
 * placeholder is the earliest pair that reliably means "the engine is up".
 */
export async function waitForFlutterBoot(page: Page): Promise<void> {
  await page.locator('flutter-view').waitFor({ state: 'attached', timeout: 60_000 });
  await page.locator('flt-semantics-placeholder').waitFor({ state: 'attached', timeout: 60_000 });
}


/**
 * Type into a Flutter text field, then read it back and retype on mismatch.
 *
 * Flutter web routes keystrokes through a hidden input that it repositions and
 * re-creates as focus moves, and characters get dropped when a frame lands
 * mid-sequence. In a password field that is not a cosmetic problem: a dropped
 * character and a wrong password both surface as a 401, so a flaky login looks
 * exactly like a broken one.
 *
 * `fill()` alone is not enough either — it sets the DOM value without the
 * input events Flutter's engine listens for, so the framework never sees it.
 */
export async function typeReliably(
  field: Locator,
  value: string,
  { attempts = 4 }: { attempts?: number } = {},
): Promise<void> {
  for (let attempt = 1; attempt <= attempts; attempt++) {
    await field.click();
    await field.press('ControlOrMeta+a');
    await field.press('Delete');
    // Slow enough that the engine sees each key. Faster is measurably lossy.
    await field.pressSequentially(value, { delay: 30 });

    const actual = await field.inputValue();
    if (actual === value) return;
    if (attempt === attempts) {
      throw new Error(
        `field did not accept the value after ${attempts} attempts ` +
          `(got ${actual.length} of ${value.length} characters)`,
      );
    }
  }
}

/** The account `tools/seed-review-data.mjs` creates. */
export const TRAINEE_CREDENTIALS = {
  username: 'robert.meyer',
  password: 'ReviewPass!2026',
};

/** The trainer account, for the console. */
export const TRAINER_CREDENTIALS = {
  username: 'nina.brandt',
  password: 'ReviewPass!2026',
};

/**
 * The seeded trainee who is deliberately *not* on anyone's roster.
 *
 * `robert.meyer` is linked to `nina.brandt`, which is what makes coach chat and
 * the console's Client Detail reachable — and which, in the same move, removes
 * the only route to `JoinTrainerScreen`, since Profile renders "Your coach" and
 * "Join a trainer" on opposite arms of the same `if`. This account is the other
 * arm. See the comment on `UNLINKED_TRAINEE` in tools/seed-review-data.mjs.
 */
export const UNLINKED_TRAINEE_CREDENTIALS = {
  username: 'lena.fischer',
  password: 'ReviewPass!2026',
};

/**
 * Sign in through the real login screen.
 *
 * Deliberately not a token injected into storage: the thing most worth
 * exercising here is what a sign-in actually triggers — PostAuthHome deciding
 * between the console and the trainee app, ProfileSetupGate waiting on
 * `roleResolved`, and SyncService.pullAll() filling the local database that
 * every trainee screen reads from. A planted token skips all three and lands
 * on screens that would be empty for the wrong reason.
 */
export async function signIn(
  page: Page,
  credentials: { username: string; password: string },
): Promise<void> {
  const loginButton = page.getByRole('button', { name: 'Login' });
  // Asserted, not assumed. `waitFor({ state: 'detached' })` on a locator that
  // matches nothing resolves immediately, so waiting for the login button to
  // disappear "succeeds" instantly when the screen never rendered -- and every
  // downstream screenshot is then of the login screen, silently. That is the
  // shape of false pass this fixture exists to avoid, so the button has to be
  // there before it can meaningfully go away.
  await loginButton.waitFor({ state: 'attached', timeout: 60_000 });

  await typeReliably(page.getByRole('textbox', { name: 'Username' }), credentials.username);
  await typeReliably(page.getByLabel('Password'), credentials.password);
  await loginButton.click();

  await loginButton.waitFor({ state: 'detached', timeout: 60_000 });

  // A trainee lands on ProfileSetupGate first. Completion is stored per
  // account in local prefs (ProfileSetupPrefs), so a fresh browser profile
  // always sees the questionnaire however many times the account has signed in
  // elsewhere -- which makes it part of the sign-in path here, not an
  // occasional interruption. Trainers skip it entirely; the gate is
  // trainees-only.
  const setUpLater = page.getByRole('button', { name: 'Set up later' });
  // Race them rather than testing `count()` once: the gate resolves a frame or
  // two after the login screen tears down, so an immediate count is 0 and the
  // questionnaire is then never dismissed.
  await Promise.race([
    setUpLater.waitFor({ state: 'attached', timeout: 60_000 }).catch(() => {}),
    page.getByRole('tablist').first().waitFor({ state: 'attached', timeout: 60_000 }).catch(() => {}),
  ]);
  if (await setUpLater.count()) {
    await setUpLater.click();
  }

  // And positively confirm we arrived. Without this a failed login that merely
  // re-renders would read as success.
  //
  // The signal is the nav itself, not a named destination: the console's first
  // section is "Dashboard" in the desktop sidebar and "Home" in the narrow
  // bottom bar (consoleNavDashboardShort), so any single name is wrong at one
  // width or the other.
  await page
    .getByRole('tablist')
    .or(page.getByRole('button', { name: 'Dashboard', exact: true }))
    .first()
    .waitFor({ state: 'attached', timeout: 60_000 });
}

/**
 * A navigation destination, on whichever nav the current layout is using.
 *
 * Material 3's NavigationBar emits `role=tablist` / `role=tab`, and every
 * destination carries an `aria-label` even though only the selected one shows
 * a visible label -- the tooltip ForgeNavBar sets is what feeds it. The
 * console's desktop sidebar is a column of buttons instead, so both are tried.
 */
export function navDestination(page: Page, name: string): Locator {
  return page
    .getByRole('tab', { name, exact: true })
    .or(page.getByRole('button', { name, exact: true }))
    .first();
}

type Fixtures = {
  /** A page with the app loaded, booted, and its semantics tree live. */
  appPage: Page;
  /** A page signed in as the seeded trainee, on the trainee app. */
  traineePage: Page;
  /** A page signed in as the seeded trainer, on the Trainer Console. */
  trainerPage: Page;
  /** A page signed in as the seeded trainee who has no trainer. */
  unlinkedTraineePage: Page;
};

export const test = base.extend<Fixtures>({
  appPage: async ({ page }, use) => {
    const consoleErrors: string[] = [];
    page.on('console', (msg) => {
      if (msg.type() === 'error') consoleErrors.push(msg.text());
    });
    page.on('pageerror', (err) => consoleErrors.push(String(err)));

    await page.goto('/');
    await waitForFlutterBoot(page);
    await enableFlutterSemantics(page);

    // Surfaced on the page object so a test can assert on them without
    // re-registering listeners. See app-boot.spec.ts.
    Object.defineProperty(page, 'consoleErrors', { value: consoleErrors, configurable: true });

    await use(page);
  },

  traineePage: async ({ appPage }, use) => {
    await signIn(appPage, TRAINEE_CREDENTIALS);
    await use(appPage);
  },

  trainerPage: async ({ appPage }, use) => {
    await signIn(appPage, TRAINER_CREDENTIALS);
    await use(appPage);
  },

  unlinkedTraineePage: async ({ appPage }, use) => {
    await signIn(appPage, UNLINKED_TRAINEE_CREDENTIALS);
    await use(appPage);
  },
});

export { expect };

/** Console/page errors collected for `appPage` since navigation. */
export function consoleErrorsOf(page: Page): string[] {
  return (page as Page & { consoleErrors?: string[] }).consoleErrors ?? [];
}
