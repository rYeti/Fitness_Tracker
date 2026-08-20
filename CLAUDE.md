# ForgeForm — Project Memory

## Project overview
ForgeForm is a Flutter fitness app with an ASP.NET Core backend (JWT/OAuth/RBAC already in place). Two client surfaces: the trainee-facing tracker, and the **Trainer Console** — a trainer-facing companion for managing a client roster (chat, workout building, attendance/adherence, nutrition monitoring).

## Stack
- Backend: ASP.NET Core (C#), JWT/OAuth/RBAC, SignalR for real-time chat + notifications.
- Client: Flutter, targeting mobile (iOS/Android), desktop (Windows/macOS/Linux) **and web** from one codebase. Web is how the Trainer Console is delivered — see "Web support" below.

## Key reference docs (read before implementing related features)
- `trainer-console-spec.md` — full Trainer Console feature spec, phasing, and competitive positioning.
- `design/trainer_console/design_handoff_trainer_console/README.md` — design handoff for the Trainer Console mockup. **Read this before touching any Trainer Console UI.**

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
- `.github/workflows/android-release.yml` — signed app bundle to Google Play, triggered by a `v*` tag or run manually. See `docs/android-release.md` for the required secrets. Two things to respect: the tag must match `pubspec.yaml`'s `version:`, and the `+N` build number must increase on every upload because Play burns `versionCode`s permanently. A tag publishes to the **internal** track only — nothing auto-ships to production.

## Web support — the Trainer Console ships as a web app
The browser is the trainer's workstation, so **web is a supported target**, not just mobile + desktop:
- Entry points: on web a signed-in trainer lands directly in the console (`_WebLanding` in `main.dart`); on every other platform it's reached from Settings → Trainer Console. Both go through `TrainerConsoleGate`, which checks `AccessProvider.isTrainer`.
- The gate is a **UX guard, not a security boundary** — every Trainer Console endpoint independently re-checks the caller against an Active TrainerClient relationship. Keep it that way; never let the client be the only thing standing between a user and someone else's data.
- A trainer is also a ForgeForm user: leaving the console for the trainee app must stay possible without signing out (`onExitConsole`).
- Build/CI: `.github/workflows/web.yml` builds and uploads the static bundle. No deploy step yet — the host hasn't been chosen. Whatever host is used must rewrite unknown paths to `/index.html`.
- Known web constraints:
  - **WASM compilation is unavailable** — `flutter_secure_storage_web` still uses legacy `dart:html`. Standard JS compilation is fine; don't add `--wasm` until that's resolved.
  - **`purchases_flutter` fetches its JS mapping from a CDN at runtime** and errors on web. Non-fatal (the app boots), but premium/paywall paths shouldn't be relied on in a browser.
  - **CORS is currently `AllowAnyOrigin`**, which works because auth is Bearer-token, not cookies. Note that SignalR needs `AllowCredentials` with explicit origins — the chat feature will require changing this policy.

## Desktop support
The Trainer Console must run natively on desktop via Flutter's desktop targets, not just scale up from mobile:
- Responsive, breakpoint-driven layouts (e.g. a 3-pane desktop layout for Messages, collapsing to single-pane + bottom tabs on mobile).
- Shared active-client state must update all *simultaneously visible* panes on wide viewports, not just the current screen.
- Keyboard shortcuts and hover states are desktop-only affordances — gate behind platform checks, don't skip them.

## Working conventions
- Owner prefers to write implementation code himself — act as reviewer/guide, not code-provider, unless a skeleton is explicitly requested.
- Auth stack (JWT/OAuth/RBAC) already exists — reuse it for SignalR hub auth (token passed as `?access_token=` query param for the hub path, since WebSocket transport can't set headers).
- Tie SignalR group membership and any trainer-facing data access to `TrainerTraineeRelationship.Status == Active`, not role membership alone.
- Follow YAGNI principles — build for the current requirement, not speculative future needs; no unused abstractions, config hooks, or generalized layers "just in case."
