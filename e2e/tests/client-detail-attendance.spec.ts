import type { Page } from '@playwright/test';
import { test, expect } from '../fixtures/flutter';

/**
 * The Attendance by week chart on the console's Client Detail screen.
 *
 * On a phone, twelve weeks leave each column narrower than a label like
 * "20/7". Those labels used to wrap at the slash onto a second line, and the
 * extra line came out of their own bar, so single bars stepped up off the
 * baseline. See docs/trainer-console-attendance-chart.md.
 *
 * The widget test pins the layout under the test font. This one checks the
 * real bundle with the real Exo 2 font, at every project width, from rendered
 * pixels -- the bug was purely visual, and the accessibility tree reports a
 * column's box, not where its bar ends.
 *
 * It runs at 1.0x and 1.3x text. The bug needed both a narrow screen and a
 * phone's enlarged system font -- at 390px and 1.0x the old 8px labels fit,
 * so a single-scale run passed against the broken build. Flutter web takes
 * its text scale from the root element's font size, which is what a browser's
 * own "font size" setting changes, so that is what the test sets.
 *
 * Needs a live API seeded with tools/seed-review-data.mjs, so it is gated like
 * the other signed-in specs.
 */
const AUDIT_ENABLED = !!process.env.AUDIT;

type Week = { label: string | null; box: { x: number; y: number; width: number; height: number } };

async function openClientDetail(page: Page): Promise<void> {
  // The roster defaults to Grid view, whose cards do not mirror into the
  // semantics tree (see audit-flows.spec.ts). In Table view the row is a
  // button at desktop width and a progressbar at phone width.
  await page.getByRole('button', { name: /Table view/i }).first().click({ timeout: 20_000 });
  await page
    .getByRole('button', { name: /Robert Meyer/i })
    .or(page.getByRole('progressbar', { name: /Robert Meyer/i }))
    .first()
    .click({ timeout: 20_000 });
  const title = page.getByText('Attendance by week');
  await title.waitFor({ timeout: 30_000 });
  await title.scrollIntoViewIfNeeded();
}

/** One entry per week column, oldest first, with its visible label if any. */
async function readWeeks(page: Page): Promise<Week[]> {
  const nodes = page.locator('flt-semantics').filter({ hasText: /^Week of / });
  await expect(nodes).toHaveCount(12);
  const weeks: Week[] = [];
  for (let i = 0; i < 12; i++) {
    const text = (await nodes.nth(i).textContent()) ?? '';
    // "Week of 20 Jul: 2 of 3 sessions" then, when labelled, "\n20/7".
    expect(text).toMatch(/^Week of \d{1,2} \w{3}: \d+ of \d+ sessions/);
    const [, label] = text.split('\n');
    const box = await nodes.nth(i).boundingBox();
    expect(box).not.toBeNull();
    weeks.push({ label: label ?? null, box: box! });
  }
  return weeks;
}

/**
 * Rows and columns of "ink" (anything not the card background) in the chart,
 * decoded in the browser so the suite needs no PNG dependency.
 */
async function inkMap(page: Page, weeks: Week[]) {
  const pad = 4;
  const clip = {
    x: Math.floor(weeks[0].box.x),
    y: Math.floor(weeks[0].box.y) - pad,
    width: Math.ceil(weeks[11].box.x + weeks[11].box.width - weeks[0].box.x),
    height: Math.ceil(weeks[0].box.height) + pad,
  };
  const png = (await page.screenshot({ clip })).toString('base64');
  const ink: boolean[][] = await page.evaluate(async (b64) => {
    const img = new Image();
    img.src = `data:image/png;base64,${b64}`;
    await img.decode();
    const canvas = new OffscreenCanvas(img.width, img.height);
    const ctx = canvas.getContext('2d')!;
    ctx.drawImage(img, 0, 0);
    const { data, width, height } = ctx.getImageData(0, 0, img.width, img.height);
    // Row 0 sits in the gap between the title and the chart: card background.
    const bg = [data[0], data[1], data[2]];
    const rows: boolean[][] = [];
    for (let y = 0; y < height; y++) {
      const row: boolean[] = [];
      for (let x = 0; x < width; x++) {
        const i = (y * width + x) * 4;
        row.push(
          Math.abs(data[i] - bg[0]) + Math.abs(data[i + 1] - bg[1]) + Math.abs(data[i + 2] - bg[2]) > 30,
        );
      }
      rows.push(row);
    }
    return rows;
  }, png);
  return { ink, clip };
}

test.describe('Client Detail: Attendance by week', () => {
  test.skip(!AUDIT_ENABLED, 'set AUDIT=1 and run tools/seed-review-data.mjs first');

  for (const scale of [1, 1.3]) {
    test(`${scale}x text: bars share one baseline and labels sit on one line`, async ({ trainerPage: page }, info) => {
      test.setTimeout(180_000);
      await page.evaluate((px) => {
        document.documentElement.style.fontSize = `${px}px`;
      }, 16 * scale);
      await openClientDetail(page);
      // Let the scroll settle before reading pixels.
      await page.waitForTimeout(1000);

      const weeks = await readWeeks(page);
      const labelled = weeks.filter((w) => w.label);

      // The current week is always named, and every label is a d/M date.
      expect(weeks[11].label).toMatch(/^\d{1,2}\/\d{1,2}$/);
      for (const w of labelled) expect(w.label).toMatch(/^\d{1,2}\/\d{1,2}$/);
      // Labels are spaced evenly, counting back from the newest week.
      const labelledIdx = weeks.flatMap((w, i) => (w.label ? [i] : []));
      const stride = labelledIdx.length > 1 ? labelledIdx[1] - labelledIdx[0] : 12;
      expect(weeks.every((w, i) => !!w.label === ((11 - i) % stride === 0))).toBe(true);
      // A desktop column has room for every week.
      if ((page.viewportSize()?.width ?? 0) > 1024) expect(labelled).toHaveLength(12);

      const { ink, clip } = await inkMap(page, weeks);
      const columnRange = (w: Week) => {
        const from = Math.round(w.box.x - clip.x);
        return [from + 3, Math.round(from + w.box.width) - 3] as const;
      };

      // Each bar is the first run of ink from the top of its column. Its last
      // row is the baseline, and a label that wrapped used to move it.
      const baselines = weeks.map((w) => {
        const [x0, x1] = columnRange(w);
        const hasInk = (y: number) => ink[y].slice(x0, x1).some(Boolean);
        let y = 0;
        while (y < ink.length && !hasInk(y)) y++;
        while (y < ink.length && hasInk(y)) y++;
        return y - 1;
      });
      expect(new Set(baselines).size, `bar bottoms: ${baselines.join(', ')}`).toBe(1);

      // Everything below the baseline is labels: one band, one line tall.
      const labelRows = ink
        .map((row, y) => (y > baselines[0] && row.some(Boolean) ? y : -1))
        .filter((y) => y >= 0);
      expect(labelRows.length).toBeGreaterThan(0);
      const bandHeight = labelRows[labelRows.length - 1] - labelRows[0] + 1;
      expect(labelRows.length, 'label band has a gap in it: a second line').toBe(bandHeight);
      expect(bandHeight, 'label band is taller than one line').toBeLessThanOrEqual(Math.ceil(14 * scale));

      // Labels do not run into each other: separate ink clusters, one per label.
      const inkColumns = Array.from({ length: clip.width }, (_, x) =>
        labelRows.some((y) => ink[y][x]),
      );
      let clusters = 0;
      let gap = Infinity;
      for (const on of inkColumns) {
        if (on) {
          if (gap >= 5) clusters++;
          gap = 0;
        } else {
          gap++;
        }
      }
      expect(clusters, 'label ink clusters vs labels shown').toBe(labelled.length);

      await page.screenshot({
        path: info.outputPath(`attendance-${scale}x.png`),
        clip: { x: 0, y: clip.y - 48, width: page.viewportSize()!.width, height: clip.height + 72 },
      });
    });
  }
});
