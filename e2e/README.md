# ForgeForm E2E

Playwright tests that run against the built Flutter web bundle — the same
bundle `.github/workflows/web.yml` uploads, and the surface the Trainer
Console ships on.

## Running them

```bash
cd fittnes_tracker
flutter build web --release --no-web-resources-cdn   # the flag is required, see below

cd ../e2e
npm install
npx playwright install chromium                      # first run only
npm test
```

`npm test` starts `tools/serve-web.mjs` on port 4173 itself; there is nothing
to leave running in another terminal. `npm run test:headed` watches it happen,
`npm run report` opens the HTML report after a failure.

No backend is needed. Nothing here signs in.

## The two things worth knowing before writing a test

**Everything is queried by role and accessible name.** Flutter web paints the
whole app into a canvas, so there is no DOM to select — `getByText('Login')`
finds nothing, because "Login" is pixels. The only queryable surface is the
accessibility tree, which Flutter builds *on request* and mirrors into real
elements. `fixtures/flutter.ts` turns it on; use the `appPage` fixture and it
is already done. A widget with no semantic label is invisible to this suite,
which makes CLAUDE.md's accessibility rules load-bearing rather than aspirational.

**Build with `--no-web-resources-cdn`.** Without it the bundle fetches
CanvasKit from `gstatic.com` at boot and the app never starts on a machine that
cannot reach it. See `docs/e2e-playwright.md`.

## Granting the RevenueCat entitlement to a seeded account

`tests/self-managed-nutrient-pins.spec.ts` needs `UNLINKED_TRAINEE_CREDENTIALS`
(`lena.fischer`) to hold the RevenueCat premium entitlement — something neither
`tools/seed-review-data.mjs` nor the app itself can grant, since it only ever
arrives over the RevenueCat webhook (see `docs/revenuecat-self-managed-pins.md`).
Grant it by POSTing a fabricated webhook event against a running API with
`RevenueCat:WebhookAuthHeader` configured, using that account's user id (from
`GET api/auth/login`'s response or the database) and matching the `entitlement_ids`
this app grants premium for (`ForgeForm Pro`, the constant in
`RevenueCatService.EntitlementId`):

```bash
curl -X POST http://127.0.0.1:5080/api/revenuecat/webhook \
  -H "Authorization: $REVENUECAT_WEBHOOK_SECRET" \
  -H "Content-Type: application/json" \
  -d '{"event":{"type":"INITIAL_PURCHASE","app_user_id":"<lena.fischer user id>","entitlement_ids":["ForgeForm Pro"],"expiration_at_ms":<30-days-from-now-ms>,"event_timestamp_ms":<now-ms>}}'
```

This grant lives only in the API's database, not in this suite's fixtures —
re-run it after reseeding against a fresh database.

## Layout

| Path | What it is |
| --- | --- |
| `playwright.config.ts` | Two projects: `chromium-desktop` (1440px) and `chromium-mobile` (390px). |
| `fixtures/flutter.ts` | The `appPage` fixture — boots the app and enables semantics. |
| `tests/` | Specs. |
| `tests/seed.spec.ts` | Empty template the Playwright generator agent copies. Never runs. |
| `tools/serve-web.mjs` | Static server with the SPA rewrite production hosting also has to implement. |

## Agents

`.claude/agents/playwright-test-{planner,generator,healer}.md` drive this suite
through the `playwright-test` MCP server declared in the repo root `.mcp.json`.
The planner explores a running app and writes a plan, the generator turns a plan
into a spec against a live browser, the healer debugs failures.
