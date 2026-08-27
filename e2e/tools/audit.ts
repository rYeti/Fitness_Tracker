import { type Page } from '@playwright/test';
import { mkdir, writeFile } from 'node:fs/promises';
import { join } from 'node:path';

export const AUDIT_DIR = process.env.AUDIT_DIR ?? 'audit-out';

/** One interactive node in Flutter's mirrored accessibility tree. */
export type Node = {
  role: string;
  name: string;
  tag: string;
  x: number;
  y: number;
  w: number;
  h: number;
};

export type ScreenAudit = {
  screen: string;
  viewport: string;
  theme: string;
  nodes: Node[];
  unnamed: Node[];
  belowTapTarget: Node[];
  adjacent: Array<{ a: string; b: string; gap: number }>;
  widest: { name: string; w: number; fraction: number } | null;
};

/**
 * Flutter mirrors its Semantics tree into `<flt-semantics>` elements when
 * accessibility is on. Anything interactive that reaches this list with an
 * empty name is, to a screen reader, the word "button" and nothing else — and
 * it is also invisible to every Playwright query, since the suite addresses
 * everything by role and name.
 */
export async function collect(page: Page): Promise<Node[]> {
  return page.evaluate(() => {
    // How Flutter names things in the mirrored tree, established by reading it
    // rather than by assuming: a button's accessible name is the element's own
    // text content, and a text field's is `aria-label` on the `<input>` child.
    // `aria-label` on the `flt-semantics` element itself is almost never set,
    // so keying off it alone reports every control as unnamed -- which is what
    // the first version of this did, and it was wrong in the same direction
    // for every screen, which is exactly how a measurement flatters you.
    const interactive = new Set([
      'button', 'link', 'checkbox', 'radio', 'switch', 'tab',
      'textbox', 'slider', 'menuitem', 'combobox',
    ]);
    const out: Node[] = [];
    for (const el of Array.from(document.querySelectorAll('flt-semantics'))) {
      const role = el.getAttribute('role') ?? '';
      const input = el.querySelector(':scope > input, :scope > textarea');
      if (!interactive.has(role) && !input) continue;

      const r = el.getBoundingClientRect();
      if (r.width === 0 && r.height === 0) continue;

      const ownText = Array.from(el.childNodes)
        .filter((n) => n.nodeType === Node.TEXT_NODE)
        .map((n) => n.textContent ?? '')
        .join('')
        .trim();
      const name = (
        el.getAttribute('aria-label') ??
        input?.getAttribute('aria-label') ??
        ownText
      ).trim();

      out.push({
        role: role || (input ? 'textbox' : ''),
        name,
        tag: el.tagName.toLowerCase(),
        x: Math.round(r.x), y: Math.round(r.y),
        w: Math.round(r.width), h: Math.round(r.height),
      });
    }
    return out;
  }) as Promise<Node[]>;
}

/** Minimum tap target from CLAUDE.md: 44x44 on mobile, 32x32 dense desktop. */
function minTarget(viewport: string): number {
  return viewport === '390' ? 44 : 32;
}

/**
 * The rendered background, sampled from the canvas rather than assumed.
 *
 * The app's theme comes from the local database, which `SyncService` fills
 * from the server *after* the first frame — so a build seeded with
 * `themeMode: 'dark'` still paints light until the pull lands, and a capture
 * labelled from the seed is simply mislabelled. `docs/frontend-design-review.md`
 * §10 retracted three findings for inferring behaviour rather than reading it;
 * a theme label is the cheapest possible instance of that mistake, so it is
 * measured.
 */
export async function detectTheme(page: Page): Promise<'light' | 'dark'> {
  // Sampled from the middle of the content area, not the left edge: the
  // console's desktop sidebar is charcoal in *both* themes by design, so an
  // x=2 sample reported every desktop console screen as dark.
  const size = page.viewportSize() ?? { width: 800, height: 600 };
  const shot = await page.screenshot({
    clip: {
      x: Math.round(size.width * 0.65),
      y: Math.round(size.height * 0.75),
      width: 4,
      height: 4,
    },
  });
  // PNG bytes -> just ask the browser instead: draw and read back.
  const luminance = await page.evaluate(async (b64: string) => {
    const img = new Image();
    img.src = `data:image/png;base64,${b64}`;
    await img.decode();
    const c = document.createElement('canvas');
    c.width = img.width; c.height = img.height;
    const ctx = c.getContext('2d')!;
    ctx.drawImage(img, 0, 0);
    const d = ctx.getImageData(0, 0, img.width, img.height).data;
    return (0.299 * d[0] + 0.587 * d[1] + 0.114 * d[2]) / 255;
  }, shot.toString('base64'));
  return luminance > 0.5 ? 'light' : 'dark';
}

/**
 * Wait for the first sync to land.
 *
 * Every trainee screen reads a local drift database that starts empty in a
 * fresh browser profile; `SyncService.pullAll()` fills it after sign-in.
 * Capturing before that finishes photographs the *default* state -- a 2,000
 * kcal goal, 0 workouts, an 85kg placeholder weight -- and reads as a data bug
 * that is really a stopwatch bug. Screens captured this way is how a review
 * ends up retracting findings.
 */
export async function waitForSync(page: Page, timeoutMs = 30_000): Promise<void> {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const settled = await page.evaluate(() => {
      const text = document.body.innerText;
      // The seeded goal, which only exists once user settings have pulled.
      return text.includes('2900') || text.includes('96.1');
    });
    if (settled) return;
    await page.waitForTimeout(1000);
  }
}

export async function auditScreen(
  page: Page,
  screen: string,
  viewport: string,
  themeOverride?: string,
): Promise<ScreenAudit> {
  const theme = themeOverride ?? (await detectTheme(page));
  const nodes = await collect(page);
  const min = minTarget(viewport);

  const unnamed = nodes.filter((n) => n.name === '');
  const belowTapTarget = nodes.filter((n) => n.w < min || n.h < min);

  // Controls sitting side by side with less than the 8px minimum between them.
  const adjacent: ScreenAudit['adjacent'] = [];
  const sorted = [...nodes].sort((a, b) => a.y - b.y || a.x - b.x);
  for (let i = 0; i < sorted.length - 1; i++) {
    const a = sorted[i];
    const b = sorted[i + 1];
    if (Math.abs(a.y - b.y) > 4) continue;
    const gap = b.x - (a.x + a.w);
    if (gap >= 0 && gap < 8) {
      adjacent.push({ a: a.name || `<unnamed ${a.role}>`, b: b.name || `<unnamed ${b.role}>`, gap });
    }
  }

  const width = page.viewportSize()?.width ?? 0;
  const widest = nodes.length
    ? nodes.reduce((m, n) => (n.w > m.w ? n : m))
    : null;

  const audit: ScreenAudit = {
    screen, viewport, theme, nodes, unnamed, belowTapTarget, adjacent,
    widest: widest ? { name: widest.name, w: widest.w, fraction: +(widest.w / width).toFixed(3) } : null,
  };

  const dir = join(AUDIT_DIR, `${viewport}-${theme}`);
  await mkdir(dir, { recursive: true });
  const slug = screen.toLowerCase().replace(/[^a-z0-9]+/g, '-');
  await writeFile(join(dir, `${slug}.json`), JSON.stringify(audit, null, 2));
  await page.screenshot({ path: join(dir, `${slug}.png`), fullPage: false });
  return audit;
}
