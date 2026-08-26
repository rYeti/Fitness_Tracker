import { test as base, expect, type Page } from '@playwright/test';

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

type Fixtures = {
  /** A page with the app loaded, booted, and its semantics tree live. */
  appPage: Page;
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
});

export { expect };

/** Console/page errors collected for `appPage` since navigation. */
export function consoleErrorsOf(page: Page): string[] {
  return (page as Page & { consoleErrors?: string[] }).consoleErrors ?? [];
}
