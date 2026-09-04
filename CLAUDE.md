# ForgeForm — Project Memory

## Project overview
ForgeForm is a Flutter fitness app with an ASP.NET Core backend (JWT/OAuth/RBAC already in place). Two client surfaces: the trainee-facing tracker, and the **Trainer Console** — a trainer-facing companion for managing a client roster (chat, workout building, attendance/adherence, nutrition monitoring).

## Stack
- Backend: ASP.NET Core (C#), JWT/OAuth/RBAC, SignalR for real-time chat + notifications.
- Client: Flutter, targeting mobile (iOS/Android), desktop (Windows/macOS/Linux) **and web** from one codebase. Web is how the Trainer Console is delivered — see "Web support" below.

## Key reference docs (read before implementing related features)
- `trainer-console-spec.md` — full Trainer Console feature spec, phasing, and competitive positioning.
- `docs/trainer-licensing.md` — trainer plans, seat limits, and where premium comes from. **Read before touching anything premium, invite- or seat-related.**
- `design/trainer_console/design_handoff_trainer_console/README.md` — design handoff for the Trainer Console mockup. **Read this before touching any Trainer Console UI.**
- `docs/trainer-nutrition-duplicate-meals.md` — why the console showed a client two of every meal, and the rule it leaves behind. **Read before touching meals, meal categories or the nutrition summary on either side of the API** — a meal is one row per user, per day, per category, and only code enforces that: the date column is an instant, not a day, and the category has been spelled two ways.
- `docs/push-notifications.md` — how chat push and the app's local notifications are set up, and why. **Read before touching Firebase config, the notification permission, or anything that sends a notification** — Google's own Gradle instructions are wrong for this repo, the google-services plugin is applied conditionally on purpose, and the permission is asked at sign-in rather than at startup for a reason.
- `docs/sync-account-switch-duplication.md` — why switching accounts brought workouts back with duplicated exercises and sets and with deleted exercises restored, and the rule it leaves behind. **Read before touching `SyncService`, `saveCompleteWorkout`, or anything that decides whether a row needs pushing** — the pull skips any workout it already holds locally, so it cannot see drift, and an account switch is the only thing that empties the cache and makes the server's copy visible. A `syncStatus` left unchanged is an edit that never leaves the device.
- `docs/sync-dangling-references.md` — why a reinstall or a second device could permanently lose logged sets for a swapped-out exercise, and whole meals for a deleted food, and the rule it leaves behind. **Read before touching any `SyncService` pull that gates a row's existence on resolving another table's id** — a `continue` on a reference that's stale, retired, or merely vestigial drops everything downstream of it too, including content that never depended on that reference. A retired `WorkoutExerciseTable` row is kept (`syncStatus` 4, unique to that table) specifically so historic sets can still link to it, and is invisible to every listing and diff that would otherwise delete it back out.
- `docs/e2e-playwright.md` — the Playwright suite in `e2e/` that runs a real browser against the built web bundle, the CDN dependency it uncovered, and the signed-in fixture that drives both clients against a seeded local API. **Read before touching `.github/workflows/web.yml`, the web build flags, or anything under `e2e/`** — point a review build at a local API with `--dart-define=FORGE_API_URL=`, never by editing `serverUrlDefault`; a `waitFor` on a locator that matches nothing succeeds instantly, which is how the fixture once passed without ever signing in; — Flutter web paints the whole app into a canvas, so the accessibility tree is the only thing a test (or a screen reader) can see, and `--no-web-resources-cdn` is what stops the bundle fetching its engine from `gstatic.com` at startup.
- `docs/trainer-session-review.md` — why the console showed a client more training than they had, and the rule it leaves behind. **Read before touching scheduled workouts, workout exercises or set templates on either side of the API** — those tables record what was true at a point in time, and reading them as the present broke Session Review three separate ways.
- `docs/trainer-console-duplicate-rows.md` — why the console kept showing duplicate meals, sessions and exercises after the two docs above had already fixed those tables once, and the rule it leaves behind. **Read before adding a de-duplication fold anywhere in the Trainer Console, or trusting that an idempotent write closed the matching read-side fold** — an idempotent outer call doesn't make its side effects idempotent, a guard keyed on an identity the real caller never supplies guards nothing, and a read-side fold needs the write path's own idempotency key or the two can silently disagree about what a duplicate is.
- `docs/chat-timestamps.md` — why a chat thread showed a day divider reading `01/01/0001`, why every message time was one timezone offset out, and the rule it leaves behind. **Read before touching anything that parses or formats a chat time** — a timestamp crossing the API boundary is an instant, `DateTime.parse` silently guesses its zone when the payload has no `Z`, a pre-epoch date is missing data rather than history, and the only place that converts to wall-clock time is the widget drawing it.
- `docs/app-chrome-and-insets.md` — why the two clients wore different chrome, why a `SafeArea` around a `Scaffold` breaks the inset it looks like it is handling, and the rule it leaves behind. **Read before adding an `AppBar`, a bottom bar or a `SafeArea` to any screen** — the `Scaffold` already owns the insets for the bars it holds, one wrapped around it takes them away, and one built as a sibling of the content charges them twice; app bars and bottom bars come from `ForgeAppBar`/`ForgeNavBar` and set no colour and no size of their own, because the theme declares both. It also records why a `finally` that restores a loading flag turns a failed load into an empty state.
- `docs/chat-encryption.md` — how chat messages became end-to-end encrypted, and what that cost. **Read before touching anything that handles a message body, a chat key, or a chat push** — the server stores an opaque blob and must never be given a way to read one, `decrypt` returns null rather than throwing so one unreadable message costs one bubble instead of the thread, replay re-encrypts from the outbox plaintext because an IV must never be reused, push is data-only and the *device* writes the notification, and the private key deliberately survives sign-out. The client has no user id of its own, which is why the key is stored under a fixed name with its owner recorded beside it.
- `docs/trainer-console-loading.md` — why the console made a trainer wait, and the rules it leaves behind. **Read before adding a query to any Trainer Console read path, or a section to the console shell** — a trainer-facing aggregate reads a bounded window and returns one row per client, the current-programme predicate exists in exactly one place, and `IndexedStack` builds every child whether or not anyone is looking at it.
- `docs/trainer-workout-builder.md` — how a trainer creates and edits a client's workouts, and the rules it leaves behind. **Read before touching trainer-facing workout/exercise endpoints, the Workout Builder screen, or `SyncService._pullWorkouts`/`_pullWorkoutPlans`** — a trainer's own exercise is only ever *given* to a client (copied, never referenced) because the client's app can only resolve exercises it owns; editing an existing day matches by both the `WorkoutExercise` id and the exercise id so a swap retires the old entry instead of disowning its logged history; and the sync pull's "already have this workout" check now reconciles a clean local copy instead of skipping it outright, which is the only reason a trainer's edit ever reaches a device that already pulled the workout once.
- `docs/chat-attachments.md` — how chat gained photo, video, voice-note, audio-file and document attachments, and the rules it leaves behind. **Read before touching `IChatAttachmentStore`, `ChatBodyCodec`, `ChatAttachmentProvider`/`AttachmentStore`, the R2 config, or the attachment-related migrations on either side of the API** — the server never writes `MediaType`/`Url`/`ThumbnailUrl` on a `ChatMessage`, because a shipped client indexes `MediaType.values` by ordinal and a value it doesn't recognise crashes the whole thread; the per-attachment key travels inside the same encrypted envelope as the caption, not derived from the conversation key, which is what makes a replay re-encrypt 400 bytes instead of re-uploading the file; `SendMessage` grew a `V2` sibling rather than a new parameter, because SignalR hub methods bind by arity and fail closed on a mismatch; and "45-day retention" is only half of what it copies from WhatsApp — the other half is the permanent on-device `AttachmentStore`, without which the server-side expiry is just data loss with a familiar number attached.

## Design mockup handling — IMPORTANT
`design/trainer_console/design_handoff_trainer_console/Trainer Console.dc.html` is a **high-fidelity reference prototype, not production code**:
- It's built in a bespoke design-tool syntax (`<x-dc>` component, `DCLogic` class) that does not exist in this codebase — never copy/embed this markup directly.
- **Rebuild each screen using this repo's real Flutter widgets and state management**, following `lib/core/providers/theme_provider.dart` for design tokens (or the target framework's own conventions if building a separate web dashboard).
- Treat it as authoritative on layout, spacing, states, and interaction intent — but adapt freely to Flutter's actual constraints and whatever components/patterns already exist in this codebase. It is a reference, not a pixel-exact spec.
- Client names, numbers, and message content in the prototype are placeholder data — wire everything to real API responses.

## Design tokens (from the handoff — do not deviate)
- Brand accent: Forge Orange `#FF6B3E` (buttons, active states, progress fill, FAB)
- Neutrals: charcoal `#333` (app bar, both themes); light bg `#F5F5F5`/white cards; dark bg `#121212`, surface `#1E1E1E`, cards `#2C2C2C`
- Macro colors (fixed everywhere): protein red `#E53935`, carbs blue `#1E88E5`, fat green `#43A047`
- Status tones: ok = green, warn = amber, bad = red
- Radii: 8px buttons/inputs/tiles · 12px cards · 16px hero/summary cards · pill (999px) for progress bars/chips/FAB
- Typography: Montserrat (Bold/ExtraBold) for headings/stat numbers; Exo 2 for UI labels/body
- Icons: Material Symbols Rounded, outlined default, filled + orange when active

## UI/UX Conventions

These conventions apply to every screen built for the Trainer Console (and should be extended to the trainee-facing app where reasonable). They exist so multiple agents/sessions produce consistent, production-grade UI rather than each screen reinventing spacing, states, and interactions.

### Layout & spacing
- Base unit: **4px grid**, spacing scale `4 / 8 / 12 / 16 / 24 / 32 / 48px`. No arbitrary one-off values (e.g. `13px`, `21px`).
- Card padding: 16px (compact) or 24px (hero/summary cards).
- Section gaps: 24px between major blocks, 32px page-level padding on desktop, 16px on mobile.
- Responsive breakpoints: mobile `<600px`, tablet `600–1024px`, desktop `>1024px`. Design for mobile and desktop explicitly; tablet inherits the nearer breakpoint rather than getting a bespoke layout unless a screen visibly breaks.

### Component & naming conventions
- Flutter widget names mirror the design-system component names in the handoff (`StatTile`, `ProgressBar`, `MacroSummary`, `Button`) — don't invent parallel names for the same concept.
- One shared widget per repeated pattern (e.g. a single `ClientAvatar` widget for initials-in-colored-circle, reused in Roster, Chat, Client Detail) — never re-implement the same visual pattern inline in multiple screens.
- Status badges (`ok` / `warn` / `bad`) are a single reusable widget with a tone enum, not per-screen colored containers.

### States every screen must handle
Every data-bound screen (Roster, Client Detail, Chat, Builder, Nutrition) needs explicit, designed handling for:
- **Loading** — skeleton/shimmer placeholders matching the final layout's shape, not a bare spinner, for anything above ~300ms of expected latency.
- **Empty** — a real empty state (icon + short message + action where applicable), e.g. "No clients yet — invite your first client" rather than a blank screen.
- **Error** — inline, recoverable error messaging with a retry action; never a silent failure or a raw exception surfaced to the trainer.
- **Populated** — the default/happy-path state shown in the mockup.

### Interaction & motion
- Press/hover feedback: subtle darken (~8–10%) or scale to `0.97`, consistent with the handoff — no bespoke transitions per screen.
- Standard transition duration: **150–250ms, ease-out** for state changes (opening a sheet, switching tabs, expanding a card). Avoid anything longer than 300ms for UI chrome.
- Respect the OS-level reduced-motion setting — fall back to instant/cross-fade transitions rather than skipping the state change entirely.
- Hover states are desktop/web only; never rely on hover to reveal functionality that mobile users would then have no way to trigger (use always-visible affordances or long-press instead).

### Accessibility (non-negotiable, not a later pass)
- Minimum tap target: 44×44px on mobile, 32×32px acceptable for dense desktop tables.
- Text contrast: WCAG AA minimum (4.5:1 body text, 3:1 large text/icons) in both light and dark themes — verify Forge Orange on white/charcoal combinations specifically, since brand orange on light backgrounds is a common contrast failure point.
- Every interactive element needs a semantic label for screen readers (Flutter `Semantics`/`tooltip`), not just a visual icon.
- Color is never the only signal — status badges/tones pair a color with a label or icon, since color-only status (ok/warn/bad) fails for colorblind users.
- Focus states are visible and keyboard-navigable on desktop (tab order follows visual/logical order).

### Forms & input
- Inline validation on blur, not only on submit; error copy is specific ("Weight must be greater than 0", not "Invalid input").
- Destructive actions (removing a client, deleting a workout) require a confirmation step — never a single tap with no undo path.
- Numeric inputs relevant to training (reps/weight/RPE) use appropriate keyboard types and sane min/max/step constraints matching real-world values.

### Copy & tone
- UI copy is short, direct, and trainer-facing (not consumer-marketing tone) — e.g. "Assign to client" not "Share this awesome plan!"
- Placeholder/example data in any new screen should look like realistic trainer data (real-sounding names, plausible adherence %, realistic set/rep/kcal numbers), not "Lorem ipsum" or "Test Client 1."

## Shared state — client-switcher
A single **active client** selection must live at the app-shell level and be shared across Roster, Chat, Workout Builder, and Nutrition — not re-selected per screen. Switching the active client re-derives all client-specific data in already-visible panes; it should not trigger a full navigation reload. See the design handoff README's "State Management" section for the exact state shape to replicate (`route`, `client`, `chatView`, `picker`, `layout`, builder new/edit mode, per-client data shape).

## Screens in scope
Dashboard (roster + KPIs), Client Detail, Messages/Chat (SignalR-backed), Workout Builder (create/edit modes, templates, day tabs, per-set tables), Nutrition (macro tracking, calorie ring, 7-day trend).

## Release pipelines
- `.github/workflows/deploy.yml` — API to Cloud Run on every push to `main`.
- `.github/workflows/web.yml` — builds/tests the Flutter web bundle on push and PR, uploads it as an artifact. No deploy step; host not chosen yet.
- `.github/workflows/android-release.yml` — signed app bundle to Google Play, triggered by a `v*` tag or run manually. See `docs/android-release.md` for the required secrets. Three things to respect: **the build number is CI's, not yours** — the workflow releases one above the highest `play/*` tag, then commits the version and the stamped note headings back, so never hand-edit the `+N` in `pubspec.yaml` (it records what last published; a `v*` tag still has to match the version *name*, which is yours to bump); notes for the next release go under **`## Unreleased`** in both `CHANGELOG.md` and `PLAY_NOTES.md`, and publishing renames that heading to the version it went out as, so a `## <version>` section is frozen history — never add to one; and `PLAY_NOTES.md` is capped at Play's 500-character per-locale limit while `CHANGELOG.md` has no limit. All of it is checked by the workflow's preflight step before anything is installed. `docs/android-release.md` ends with why this was automated — a versionCode reused across three runs, and two days of work written into an already-published section. **Read it before changing anything about how a release is versioned or how its notes are keyed.** The signing secrets are named `KEYSTORE_BASE64` / `KEYSTORE_PASSWORD` / `KEY_ALIAS` / `KEY_PASSWORD` (no `ANDROID_` prefix), plus `PLAY_SERVICE_ACCOUNT_JSON`. A tag publishes to the **internal** track only — nothing auto-ships to production. `PLAY_SERVICE_ACCOUNT_JSON` is optional: without it the workflow builds and signs the bundle and attaches it for manual upload instead of publishing. The app has already had a manual Console upload, so Play's first-upload-by-hand rule is satisfied and adding that secret is all that's needed to publish automatically.

## Web support — the Trainer Console ships as a web app
The browser is the trainer's workstation, so **web is a supported target**, not just mobile + desktop:
- Entry points: `PostAuthHome` (`main.dart`) is the **single** place deciding where an authenticated user lands — on web a trainer gets the console, everyone else the trainee app; other platforms reach the console from Settings → Trainer Console. Both go through `TrainerConsoleGate`, which checks `AccessProvider.isTrainer`. Never push `HomeScreen` directly after auth; that bug dropped web trainers into the trainee app.
- Profile setup runs **post-auth and trainees only**, via `ProfileSetupGate`. It must wait for `AccessProvider.roleResolved` — not `initialized`, which flips on cached flags and would flash the trainee questionnaire at a trainer on first sign-in. Completion is per account (`ProfileSetupPrefs`). Pre-auth collects nothing: `WelcomeScreen` on mobile, straight to login on web. See `docs/onboarding-and-roles.md`.
- The gate is a **UX guard, not a security boundary** — every Trainer Console endpoint independently re-checks the caller against an Active TrainerClient relationship. Keep it that way; never let the client be the only thing standing between a user and someone else's data.
- A trainer is also a ForgeForm user: leaving the console for the trainee app must stay possible without signing out (`onExitConsole`).
- Build/CI: `.github/workflows/web.yml` builds and uploads the static bundle. No deploy step yet — the host hasn't been chosen. Whatever host is used must rewrite unknown paths to `/index.html`.
- Known web constraints:
  - **WASM compilation is unavailable** — `flutter_secure_storage_web` still uses legacy `dart:html`. Standard JS compilation is fine; don't add `--wasm` until that's resolved.
  - **`purchases_flutter` fetches its JS mapping from a CDN at runtime** and errors on web. Non-fatal (the app boots), but premium/paywall paths shouldn't be relied on in a browser.
  - **CORS is origin-explicit and credentialed**, driven by `Cors:AllowedOrigins` (production: the `WEB_ORIGIN` / `WEB_ORIGIN_ALT` repository variables). This is what SignalR requires — `AllowAnyOrigin` cannot be combined with `AllowCredentials`. With nothing configured it falls back to the old any-origin-without-credentials behaviour and logs a warning, so a missing setting degrades browser SignalR rather than taking the API down. See `docs/cors-and-signalr.md`.

## Desktop support
The Trainer Console must run natively on desktop via Flutter's desktop targets, not just scale up from mobile:
- Responsive, breakpoint-driven layouts (e.g. a 3-pane desktop layout for Messages, collapsing to single-pane + bottom tabs on mobile).
- Shared active-client state must update all *simultaneously visible* panes on wide viewports, not just the current screen.
- Keyboard shortcuts and hover states are desktop-only affordances — gate behind platform checks, don't skip them.

## Trainer licensing — where premium comes from
Trainers hold a `TrainerLicence`: a tier, a seat limit, and a Stripe subscription. Full detail in `docs/trainer-licensing.md`; the load-bearing parts:
- **Premium derives from a *paid, current* licence and nothing else.** `AccessProvider.hasPremiumAccess` is `_isPremium || _proFromLicence`, where `proFromLicence` is computed server-side. It is deliberately **not** `|| isTrainerClient` — invite codes are free to mint, so a relationship-based grant made Pro free to anyone with a spare email. `TrainerLicence.GrantsPro` requires a non-Free tier for the same reason. Three regression tests pin this; don't relax any of them without an equivalent replacement.
- **Holding a licence is what makes someone a trainer**, not having clients. `IsTrainer = licence != null`. The old roster-based check locked a new trainer out of the console — the only place they could invite their first client from.
- **A licence is only ever created at registration.** Trainer is an account type (`accountType` on `POST api/auth/register`), and `ITrainerLicenceRepository.CreateFreeAsync` is called from `AuthService.RegisterAsync` and nowhere else. Existing accounts can't convert and the trainee app offers no route to one. Every licence endpoint is a pure read that refuses a non-trainer with `not_a_trainer`; the repository deliberately has no `GetOrCreateAsync`, because `GET api/TrainerLicence/me` used to be one — so merely opening the plan screen turned an ordinary user into a permanent trainer. Pinned by `TrainerProvisioningTests`; don't reintroduce provisioning on any read path.
- **A seat is an Active relationship *or* an unexpired Pending invite**, and the limit is enforced at both mint *and* redemption. Checking only at mint time makes it advisory: a code redeemed days later can land on a trainer who has since filled up or downgraded.
- **Over the limit blocks new invites and never revokes clients.** A trainer can legitimately sit above their seat limit; say so plainly in UI rather than implying anyone is about to be removed.
- **Lapsing gives 14 days of grace, then read-only** — never deletion. Clients are warned during grace (`proEndsAt`) and offered their own Pro, because they didn't do anything wrong. Writes are blocked by `RequireEntitledLicenceFilter`, applied per-action so a new mutating endpoint opts in deliberately.
- **Free is never a downgrade target and the trial always requires a card.** Both are loophole guards, one enforced in Stripe portal configuration rather than code — see the doc before changing either.
- Seat counts live only in `LicencePlanCatalog`. **Prices live in Stripe**, keyed by price id, so the ladder retunes without a deploy.

## Working conventions
- Owner prefers to write implementation code himself — act as reviewer/guide, not code-provider, unless a skeleton is explicitly requested.
- Auth stack (JWT/OAuth/RBAC) already exists — reuse it for SignalR hub auth (token passed as `?access_token=` query param for the hub path, since WebSocket transport can't set headers).
- Tie SignalR group membership and any trainer-facing data access to `TrainerTraineeRelationship.Status == Active`, not role membership alone.
- Follow YAGNI principles — build for the current requirement, not speculative future needs; no unused abstractions, config hooks, or generalized layers "just in case."

### Explain the implementation after every planning phase
Every planning phase ends with a **detailed written explanation of the implementation, written to teach** — the owner reads these to learn the codebase, not to review a changelog. It is part of the deliverable, not a follow-up.

- **Where it goes:** a standalone document in `docs/`, or a new section appended to the existing document for that feature. Committed alongside the code it describes.
- **What it covers:**
  - What was actually wrong or actually needed, and **why the compiler and the tests had nothing to say about it** — the failure modes that type systems and green suites don't catch are the ones worth writing down.
  - The decisions that aren't obvious from reading the diff, and what the rejected alternatives would have cost.
  - The general lesson that outlives this particular change — the shape of mistake, not just the instance.
- **How it reads:** narrative prose that can be read on its own, with tables and diagrams where they earn their place. Not a bullet-point restatement of the diff. Line references point at the commit that introduces the document.
- **The model to follow:** `docs/chat-architecture.md` — match its depth, tone and structure.
- **Not a substitute:** `CHANGELOG.md` records *what changed*; this explains *why it was wrong and how not to write it again*. Both get written.
