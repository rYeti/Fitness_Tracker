import { test, expect, navDestination } from '../fixtures/flutter';
import { auditScreen, waitForSync, type ScreenAudit } from '../tools/audit';
import { mkdir, writeFile } from 'node:fs/promises';
import { AUDIT_DIR } from '../tools/audit';
import { join } from 'node:path';

/**
 * The design-review sweep. Not a pass/fail suite — its output is evidence.
 *
 * `docs/frontend-design-review.md` §9 drove every screen once, by hand, and
 * the trainee half came out as a single number per screen ("Food 20, Gym 2,
 * Dashboard 1, Progress 1") that nobody has been able to reproduce since. This
 * makes that pass repeatable: one command, every screen, both surfaces, three
 * widths, and a JSON + PNG per screen written to `audit-out/`.
 *
 * Run with `AUDIT=1 npx playwright test audit.spec.ts`. It is skipped
 * otherwise, because it needs a seeded API behind it and the rest of the suite
 * deliberately does not.
 */
const AUDIT_ENABLED = !!process.env.AUDIT;

test.describe('design audit', () => {
  test.skip(!AUDIT_ENABLED, 'set AUDIT=1 and run tools/seed-review-data.mjs first');
  test.describe.configure({ mode: 'serial' });

  const results: ScreenAudit[] = [];

  test.afterAll(async () => {
    if (!results.length) return;
    // Each viewport project runs in its own worker, so a single summary path
    // means the last writer wins and the other widths vanish.
    const width = results[0].viewport;
    await mkdir(AUDIT_DIR, { recursive: true });
    await writeFile(join(AUDIT_DIR, `summary-${width}.json`), JSON.stringify(results, null, 2));

    const rows = results.map((r) =>
      `| ${r.screen} | ${r.viewport} | ${r.theme} | ${r.nodes.length} | ${r.unnamed.length} | ` +
      `${r.belowTapTarget.length} | ${r.adjacent.length} | ${r.widest?.fraction ?? '-'} |`
    );
    await writeFile(
      join(AUDIT_DIR, `summary-${width}.md`),
      [
        '| Screen | Width | Theme | Controls | Unnamed | Below target | <8px gap | Widest |',
        '|---|---|---|---:|---:|---:|---:|---:|',
        ...rows,
      ].join('\n') + '\n',
    );
  });

  test('trainee app: every tab', async ({ traineePage }, testInfo) => {
    const page = traineePage;
    const viewport = String(page.viewportSize()?.width ?? 0);
    // Every trainee screen reads a local database the first sync fills.
    await waitForSync(page);

    // The bottom bar labels only the selected destination, so the others are
    // reachable by their tooltip -- which is what ForgeNavBar puts the
    // accessible name in.
    const tabs = ['Dashboard', 'Food', 'Gym', 'Progress', 'Profile'];

    for (const tab of tabs) {
      const destination = navDestination(page, tab);
      if (await destination.count()) {
        await destination.click();
        await page.waitForTimeout(1200);
      }
      results.push(await auditScreen(page, `trainee-${tab}`, viewport));
    }

    await testInfo.attach('trainee-summary', {
      body: JSON.stringify(results.map((r) => [r.screen, r.unnamed.length]), null, 2),
      contentType: 'application/json',
    });
    expect(results.length).toBeGreaterThan(0);
  });

  test('trainer console: every section', async ({ trainerPage }) => {
    const page = trainerPage;
    const viewport = String(page.viewportSize()?.width ?? 0);

    // The sidebar uses the full label, the bottom bar the short one. Both are
    // tried per section rather than picking by width, so this keeps working if
    // the breakpoint moves.
    const sections: Array<[string, string]> = [
      ['Dashboard', 'Home'],
      ['Messages', 'Chat'],
      ['Workout Builder', 'Workouts'],
      ['Nutrition', 'Nutrition'],
      ['Session Review', 'Review'],
    ];
    for (const [section, short] of sections) {
      const destination = navDestination(page, section).or(navDestination(page, short)).first();
      if (await destination.count()) {
        await destination.click();
        await page.waitForTimeout(1200);
      }
      results.push(await auditScreen(page, `console-${section}`, viewport));
    }
    expect(results.length).toBeGreaterThan(0);
  });

  test('pre-auth screens', async ({ appPage }) => {
    const page = appPage;
    const viewport = String(page.viewportSize()?.width ?? 0);
    results.push(await auditScreen(page, 'auth-Login', viewport));

    await page.getByRole('button', { name: 'Register' }).click();
    await page.waitForTimeout(900);
    results.push(await auditScreen(page, 'auth-Register', viewport));
  });
});
