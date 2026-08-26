import { defineConfig, devices } from '@playwright/test';

const PORT = Number(process.env.E2E_PORT ?? 4173);

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
      use: { ...devices['Desktop Chrome'], viewport: { width: 1440, height: 900 } },
    },
    {
      // The console collapses to a single pane below 600px (CLAUDE.md,
      // "Layout & spacing"), so the narrow layout is its own project rather
      // than an afterthought.
      name: 'chromium-mobile',
      use: { ...devices['Desktop Chrome'], viewport: { width: 390, height: 844 } },
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
