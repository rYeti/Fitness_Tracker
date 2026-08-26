# End-to-end tests for the web bundle: how they work and why

A walkthrough of the Playwright suite in `e2e/`, written to be read on its own.
It covers why the web target is the one that needed E2E, the single fact about
Flutter web that determines how every test in this repo must be written, and
the defect the first green run turned up — one that had been in the shipped
bundle the whole time without a build or a test ever noticing.

Line references are to the commit that introduced this document.

---

## 1. The target that had no tests was the one that ships to strangers

`fittnes_tracker/test/` holds Flutter widget and unit tests, and
`FitTracker.Api.Tests/` holds backend tests. Both run in CI. Neither runs the
application.

For the trainee app that gap is tolerable — an Android build is exercised by
hand before a release goes to the internal track, and `docs/android-release.md`
describes a pipeline that assumes a human looks at the result. The Trainer
Console is different. Per CLAUDE.md, *the browser is the trainer's workstation*:
the console is delivered as a Flutter web bundle, `.github/workflows/web.yml`
builds and uploads that bundle on every push, and nothing between `flutter build
web` and a trainer's browser ever loaded the thing.

`flutter build web` succeeding proves that Dart compiled. It proves nothing at
all about whether the resulting bundle starts. Section 4 is what that gap was
hiding.

---

## 2. The whole app is a `<canvas>`, and that decides everything else

This is the fact that shapes the entire suite, so it goes first.

Flutter web does not render widgets to HTML. Since the HTML renderer was
removed, there is exactly one output: CanvasKit paints every pixel — text,
buttons, icons, the lot — into a canvas surface. Open the built app and read
`document.body`:

```html
<flutter-view flt-view-id="0">
  <flt-glass-pane></flt-glass-pane>
  <flt-text-editing-host></flt-text-editing-host>
  <flt-semantics-host></flt-semantics-host>
</flutter-view>
```

That is the app. All of it. There is no `<button>`, no heading, no text node.
`page.getByText('Login')` matches nothing, not because the button is missing but
because the word "Login" is a shape drawn on a bitmap. Every habit carried over
from testing a DOM application — CSS selectors, test ids, text matching —
is simply unavailable.

Nor is `<canvas>` itself a useful anchor. `page.locator('flutter-view canvas')`
returns **zero** on a fully painted app; the engine keeps its rendering surface
out of reach of a document query. `waitForFlutterBoot`
(`e2e/fixtures/flutter.ts:48`) waits on `<flutter-view>` and the semantics
placeholder instead, which is the earliest pair that reliably means the engine
came up. An earlier draft waited on a canvas and hung for the full 60-second
timeout against an app that was, visibly, working.

### The one seam: the accessibility tree

Flutter mirrors its `Semantics` tree into real DOM elements — but only when
accessibility is switched on, because building it costs memory and frame time.
Once on, the login screen materialises:

```html
<flt-semantics role="group">
  <flt-semantics role="img"></flt-semantics>
  <flt-semantics><span>ForgeForm</span></flt-semantics>
  <flt-semantics><span>Welcome back</span></flt-semantics>
  <flt-semantics><input aria-label="Username" type="text" inputmode="email"></flt-semantics>
  <flt-semantics><input aria-label="Password" type="password">
    <flt-semantics role="button" tabindex="0"></flt-semantics>
  </flt-semantics>
  <flt-semantics role="button">Forgot password?</flt-semantics>
  <flt-semantics role="button">Login</flt-semantics>
  <flt-semantics><span>Don't have an account?</span></flt-semantics>
  <flt-semantics role="button">Register</flt-semantics>
</flt-semantics>
```

Roles and accessible names, and nothing else. So every assertion in this suite
is `getByRole` / `getByLabel` / `getByText` against that tree — not as a style
preference, but because it is the only surface that exists.

The consequence worth internalising: **CLAUDE.md's accessibility rules are now
load-bearing.** "Every interactive element needs a semantic label for screen
readers" reads like a courtesy until you notice that an unlabelled widget is
also untestable. A screen built without `Semantics` is a screen this suite
cannot see.

### Turning it on

Flutter exposes the switch as a hidden button:

```html
<flt-semantics-placeholder role="button" aria-label="Enable accessibility"
  style="position: absolute; left: -1px; top: -1px; width: 1px; height: 1px;">
```

`enableFlutterSemantics` (`e2e/fixtures/flutter.ts:22`) clicks it —
via `el.evaluate(e => e.click())`, not Playwright's `.click()`. Playwright's
actionability checks would refuse a 1×1 element parked off-screen, and rightly
so; dispatching the event directly is the correct move for an element
deliberately hidden from sighted users, not a workaround.

The rejected alternative was to call `SemanticsBinding.instance.ensureSemantics()`
from `main()` behind a `--dart-define`. It is more deterministic and does not
depend on an element name Flutter could rename. It was dropped because it costs
a second CI build — the tested bundle would no longer be the uploaded bundle —
and because touching `main.dart` to make tests pass is how a test suite starts
diverging from the thing it tests. Clicking the placeholder means the suite runs
against the exact artifact `web.yml` hands to a host.

---

## 3. `input[type="password"]` has no role at all

A small trap, recorded because it costs twenty minutes each time.

The username field is `<input type="text" aria-label="Username">`, so
`getByRole('textbox', { name: 'Username' })` works. The password field looks
identical in the markup and does not work: `<input type="password">` has **no
implicit ARIA role**, by specification. It is not a `textbox`. It is nothing.

`getByLabel('Password')` (`e2e/tests/app-boot.spec.ts:21`) is the handle. The
accessible name is the only thing an obscured field exposes.

---

## 4. The bundle could not boot without Google's CDN, and nothing caught it

The first real run failed on every test with the app never mounting. The
browser console:

```
[reqfail] https://www.gstatic.com/flutter-canvaskit/…/canvaskit.wasm
          net::ERR_TUNNEL_CONNECTION_FAILED
[pageerror] Error: TypeError: Failed to fetch dynamically imported module:
          https://www.gstatic.com/flutter-canvaskit/…/canvaskit.js
```

By default `flutter build web` emits a bootstrap that fetches the CanvasKit
engine from `gstatic.com` **at runtime**. The `canvaskit/` directory sitting in
`build/web` is not used. So the artifact `web.yml` has been uploading all along
— the one described as "a complete static bundle — point Netlify, Firebase
Hosting, a GCS bucket, or Cloud Run at it" — is not complete and does not run
without a live third-party CDN.

`flutter build web --release --no-web-resources-cdn`
(`.github/workflows/web.yml:37`) bundles the engine into the output instead.

### Why nothing caught it

Every check the repo had asks a question one layer below the failure.
`flutter analyze` reads source. `flutter test` runs widgets in a Dart VM with no
bootstrap, no browser and no network. `flutter build web` produces files and
exits zero — the fetch it configures is a URL in a JavaScript file, and no
compiler validates a URL. The bundle had never been loaded by a browser inside
CI, so the first moment anything could have noticed was the first moment
something did.

This is the recurring shape in this repo's `docs/`, in a new costume: **the
artifact is not the thing.** `docs/trainer-session-review.md` records rows read
as the present when they were a point-in-time record;
`docs/sync-account-switch-duplication.md` records a pull that could not see
drift because it skipped what it already had. Here, a build that succeeds is
read as an app that runs. In each case the mistake is trusting a proxy for the
property you actually care about, and in each case the type system is content
because the proxy is well-typed.

The general rule: *if a pipeline's output is meant to be executed, the pipeline
must execute it.* Producing bytes is not evidence.

### What this changes about deployment

The uploaded artifact is now self-contained: larger by the CanvasKit payload,
cacheable, and with no runtime dependency on a Google domain. For a trainer
console — a tool people use at work, sometimes behind a corporate proxy that
does not have `gstatic.com` on an allowlist — that is the behaviour you want
regardless of testing. If the size ever matters more than the independence,
reverting is one flag; the E2E job would then need its own build, and the
comment at `.github/workflows/web.yml:33` says so.

---

## 5. The static server is hand-written on purpose

`e2e/tools/serve-web.mjs` is about seventy lines where `npx serve --single`
would have been a dependency and a flag.

The reason is that one rule in this repo's hosting contract is stated in prose
in three places and enforced nowhere: *whatever host serves this bundle must
rewrite unknown paths to `/index.html`, or a refresh on a deep link 404s.*
Prose does not fail. Writing the server means the rule is executable, and
`tests/app-boot.spec.ts:56` exercises it — `/trainer/clients/42` must return 200
and mount the app.

The paired test at `:65` matters as much: a missing asset must still 404. A
rewrite implemented as "serve index.html for anything not found" turns a typo'd
font URL into a 200 response containing HTML, and the failure then surfaces
somewhere unrecognisably far from its cause. `serve-web.mjs:77` only falls back
for paths with no file extension.

The server also sets `Cross-Origin-Opener-Policy` and
`Cross-Origin-Embedder-Policy`, which the engine expects when fetching its wasm
modules. A host that omits them will fail in ways this suite would not have
predicted — worth checking against whichever host is eventually chosen.

---

## 6. What the suite deliberately does not do

Per YAGNI, the current suite has no authentication, no backend, no fixtures, no
page objects and no test database. It boots the bundle and asserts on the
signed-out screen. Ten tests, about eighteen seconds.

Two of those tests earn their place beyond smoke coverage:

| Test | The rule it pins |
| --- | --- |
| `sends a signed-out visitor to login, not the welcome screen` | CLAUDE.md, "Web support": pre-auth collects nothing — `WelcomeScreen` on mobile, straight to login on web. The check in `main.dart:474` is `kIsWeb`, a *platform* test, so it must hold at 390px as well; both Playwright projects run it. |
| `boots without throwing` | Distinguishes real exceptions from the two known-benign network failures (`purchases_flutter`'s CDN mapping, the Google Fonts Roboto fallback), so a genuinely new one is visible rather than lost in noise. |

`purchases_flutter` failing on web is documented in CLAUDE.md as expected and
non-fatal; `app-boot.spec.ts:45` filters it by name rather than by loosening the
assertion, so if it ever starts failing differently the test still speaks up.

The natural next step, when the console has screens worth driving, is a signed-in
fixture. That needs a decision this change does not make: a seeded test account
against a running API, or an intercepted network layer. Both are real work and
neither is needed to assert that the app starts.

---

## 7. Working with the agents

`playwright init-agents` installed three subagents at
`.claude/agents/playwright-test-{planner,generator,healer}.md`, wired to the
`playwright-test` MCP server declared in the repo root `.mcp.json` and pointed
at `--config e2e`.

The planner explores a running app and writes a test plan; the generator turns a
plan into a spec while driving a live browser; the healer debugs failures. They
copy `e2e/tests/seed.spec.ts` as the template for new specs, which is why that
file exists and why `playwright.config.ts:9` excludes it from runs — it is a
template, not a test.

One caveat carries over from section 2: these agents were written for DOM
applications and will reach for CSS selectors and text matching by default.
Against this app that produces specs that find nothing. Point them at
`e2e/fixtures/flutter.ts` and the `appPage` fixture, and review generated
locators for role-and-name form before keeping them.

---

## 8. The short version

- Flutter web is a canvas. Roles and accessible names are the only queryable
  surface, so accessibility work is test infrastructure.
- `<input type="password">` has no ARIA role. Use the label.
- Build with `--no-web-resources-cdn` or the app fetches its engine from
  `gstatic.com` and dies without it.
- A build that succeeds is not an app that runs. If CI produces something meant
  to be executed, make CI execute it.
