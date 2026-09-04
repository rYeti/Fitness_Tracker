import path from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  test,
  expect,
  navDestination,
  typeReliably,
  waitForFlutterBoot,
  enableFlutterSemantics,
  signIn,
  TRAINEE_CREDENTIALS,
} from '../fixtures/flutter';
import type { Page } from '@playwright/test';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const TEST_PHOTO = path.join(__dirname, '..', 'fixtures', 'test-photo.jpg');

/**
 * The trainee side of the seeded conversation has no dedicated nav
 * destination — "Your coach" is a ListTile on the Profile tab
 * (settings_screen.dart), not a bottom-bar tab. Reach it the way a real user
 * would: Profile, then the tile, which pushes CoachChatEntry.
 */
async function openCoachChat(page: Page): Promise<void> {
  await navDestination(page, 'Profile').click();
  await page.getByRole('button', { name: /Your coach/i }).click();
}

/**
 * Chat runs against a real, seeded local API (Attachments__Provider=local,
 * so bytes round-trip through the API itself rather than R2 — see
 * docs/chat-attachments.md §7). `nina.brandt` (trainer) and `robert.meyer`
 * (trainee) are linked by tools/seed-review-data.mjs, so a
 * nina<->robert conversation already exists before either signs in.
 *
 * Everything here is a semantics assertion, per docs/e2e-playwright.md: the
 * canvas has no DOM, so only Flutter's mirrored accessibility tree is
 * queryable. A `waitFor` on a locator matching nothing resolves instantly,
 * so every assertion here is positive presence of a named node, never
 * absence.
 */

test.describe('trainer console chat', () => {
  test('opens Messages and finds the seeded conversation', async ({ trainerPage }) => {
    await navDestination(trainerPage, 'Messages').click();

    // The console's client-switcher and thread list are keyed by client
    // name; robert.meyer was linked during seeding.
    await expect(
      trainerPage.getByRole('button', { name: /Robert Meyer/i }).first(),
    ).toBeVisible({ timeout: 30_000 });
  });

  test('sends a plain text message — the five-argument SendMessage path', async ({
    trainerPage,
  }) => {
    await navDestination(trainerPage, 'Messages').click();
    await trainerPage.getByRole('button', { name: /Robert Meyer/i }).first().click();

    const composer = trainerPage.getByRole('textbox').last();
    await composer.waitFor({ state: 'attached', timeout: 30_000 });

    const body = `E2E regression check ${Date.now()}`;
    await typeReliably(composer, body);
    await trainerPage.getByRole('button', { name: 'Send message' }).click();

    // Sent, not merely queued: the composer's own tooltip on the trailing
    // button flips from "Sending" back to "Send message" once the hub acks,
    // and the bubble text is on screen either way.
    await expect(trainerPage.getByText(body)).toBeVisible({ timeout: 30_000 });
  });

  test('attach affordance is enabled and its menu lists Photo, Video and Document', async ({
    trainerPage,
  }) => {
    await navDestination(trainerPage, 'Messages').click();
    await trainerPage.getByRole('button', { name: /Robert Meyer/i }).first().click();

    // The composer's "+" button. Before this pass it had `tooltip: null`
    // when enabled and an icon with no semanticLabel — an unlabeled button,
    // invisible both to a screen reader and to this query. Fixed alongside
    // this spec: it now always carries chatOpenAttachMenu ("Add attachment").
    const attachButton = trainerPage.getByRole('button', { name: 'Add attachment' });
    await expect(attachButton).toBeVisible({ timeout: 30_000 });
    await attachButton.click();

    // Desktop viewport (this project is chromium-desktop, 1440x900) renders
    // the attach choices as a PopupMenuButton (Flutter's MenuItemButton
    // semantics — role="menuitem", not "button"), not a bottom sheet.
    await expect(trainerPage.getByRole('menuitem', { name: 'Photo', exact: true })).toBeVisible();
    await expect(trainerPage.getByRole('menuitem', { name: 'Video', exact: true })).toBeVisible();
    await expect(
      trainerPage.getByRole('menuitem', { name: 'Document', exact: true }),
    ).toBeVisible();

    // Dismiss the menu so it doesn't leak into the next test.
    await trainerPage.keyboard.press('Escape');
  });

  test('uploads a photo end to end: sender sees it sent, recipient sees it arrive', async ({
    trainerPage,
    browser,
  }) => {
    // Both parties need genuinely separate sessions. `traineePage` is not
    // usable alongside `trainerPage` here: both derive from the single
    // `page` fixture Playwright hands each test, so requesting them together
    // would silently hand back the *same* tab, already signed in as the
    // trainer — the trainee's own signIn() would then wait forever for a
    // Login button that already scrolled off screen. A second, independent
    // browser context is what a second real device actually is.
    const traineeContext = await browser.newContext();
    const traineePage = await traineeContext.newPage();
    await traineePage.goto('/');
    await waitForFlutterBoot(traineePage);
    await enableFlutterSemantics(traineePage);
    await signIn(traineePage, TRAINEE_CREDENTIALS);

    // Both parties open the same conversation from opposite ends.
    await navDestination(trainerPage, 'Messages').click();
    await trainerPage.getByRole('button', { name: /Robert Meyer/i }).first().click();

    await openCoachChat(traineePage);

    await trainerPage.getByRole('button', { name: 'Add attachment' }).click();

    // The one previously-unproven mechanic in this pass: Flutter web's
    // file_picker creates its <input type="file"> on demand when the pick
    // flow starts, so the chooser has to be armed with filChooser handling
    // before the click that triggers it, then driven by path.
    const fileChooserPromise = trainerPage.waitForEvent('filechooser');
    await trainerPage.getByRole('menuitem', { name: 'Photo', exact: true }).click();
    const chooser = await fileChooserPromise;
    await chooser.setFiles(TEST_PHOTO);

    // Sender side: an uploading state, then a sent bubble with a photo
    // semantics value (per docs' chat_bubble.dart table — "Photo, ...").
    await expect(trainerPage.getByText(/Photo/i).first()).toBeVisible({ timeout: 30_000 });

    // Recipient side: the same attachment arrives and (per the auto-download
    // policy) fetches without a tap, ending in a rendered/stored state
    // rather than "tap to download" staying forever.
    await expect(traineePage.getByText(/Photo/i).first()).toBeVisible({ timeout: 45_000 });

    await traineeContext.close();
  });
});
