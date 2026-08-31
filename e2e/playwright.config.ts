import { defineConfig, devices } from '@playwright/test';

const PORT = Number(process.env.E2E_PORT ?? 4173);

// Some environments ship a Chromium that Playwright did not download itself
// (a preinstalled one in a container image, for instance). Playwright refuses
// to launch anything but the exact build its version pins, so point it at the
// binary explicitly rather than re-downloading one. Unset elsewhere, this is
// undefined and the bundled browser is used as normal.
const executablePath = process.env.PLAYWRIGHT_CHROMIUM_PATH || undefined;

export default defineConfig({
  testDir: './tests',
  // seed.spec.ts is the template the Playwright generator agent copies when it
  // writes a new spec. It is deliberately empty, so it is never run.
  testIgnore: '**/seed.spec.ts',

  // Flutter web boots an engine, a CanvasKit wasm module and a sqlite wasm
  // module before it paints anything, so first contentful paint is slow by the
  // standards of a DOM app. These are generous on purpose.
  timeout: 90_000,
  expect: { timeout: 20_000 },

  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: process.env.CI ? [['list'], ['html', { open: 'never' }]] : [['list']],

  use: {
    baseURL: `http://localhost:${PORT}`,
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    // The app follows the browser locale and ships en + de. Pinning it keeps
    // assertions on visible copy meaningful.
    locale: 'en-US',
    timezoneId: 'UTC',
  },

  projects: [
    {
      name: 'chromium-desktop',
      use: {
        ...devices['Desktop Chrome'],
        viewport: { width: 1440, height: 900 },
        launchOptions: { executablePath },
      },
    },
    {
      // The 600-1024 band. `Breakpoints.isDesktop` is `> 1024`, so everything
      // in here gets the phone layout -- a sidebar-less console with a bottom
      // tab bar on a 1024px-wide window. That is the band the design review
      // flagged and the one the suite could not see, because it had only 1440
      // and 390.
      name: 'chromium-tablet',
      use: {
        ...devices['Desktop Chrome'],
        viewport: { width: 800, height: 1000 },
        launchOptions: { executablePath },
      },
    },
    {
      name: 'chromium-mobile',
      use: {
        ...devices['Desktop Chrome'],
        viewport: { width: 390, height: 844 },
        launchOptions: { executablePath },
      },
    },
  ],

  webServer: {
    command: `node tools/serve-web.mjs --port ${PORT}`,
    url: `http://localhost:${PORT}/index.html`,
    reuseExistingServer: !process.env.CI,
    timeout: 30_000,
    stdout: 'pipe',
    stderr: 'pipe',
  },
});
