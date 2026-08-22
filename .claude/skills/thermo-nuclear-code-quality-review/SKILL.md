---
name: thermo-nuclear-code-quality-review
description: Exhaustive multi-pass quality review of the ForgeForm codebase — correctness, repo invariants, trust boundaries, state handling, screen states, accessibility, tests and dead weight. Use when the user wants a deep, total, "nuclear" quality pass rather than the bounded diff review /code-review gives. Reports findings; edits only when explicitly asked.
argument-hint: "[path | --diff | --full] [--fix]"
metadata:
  author: ForgeForm
  version: "1.0.0"
---

# Thermo-Nuclear Code Quality Review

`/code-review` is the scalpel: a bounded set of high-confidence findings on a diff.
This is the full sweep. Every pass below runs, every finding is verified against the
source before it is reported, and nothing is skipped because it "looked fine."

The point is not volume. A hundred nitpicks is a failed review — it buries the three
findings that matter. The point is **coverage with a verification gate**: look
everywhere, then report only what you can prove.

## Scope

Resolve scope before reading anything:

| Argument | Scope |
|---|---|
| *(none)* or `--diff` | `git diff origin/main...HEAD` — the branch's own delta |
| a path | that file or directory, in full |
| `--full` | the whole repo, subsystem by subsystem |

State the resolved scope and the file count in your first message. If `--full` on a
codebase this size (~121k lines across `FitTracker.Api/` and `fittnes_tracker/`),
work subsystem by subsystem and report incrementally — do not disappear for twenty
minutes and return with a wall of text.

## The passes

Run all of them. Note explicitly which passes found nothing — a silent pass is
indistinguishable from a skipped one.

**1 · Correctness and failure modes.** Null/empty/boundary inputs, off-by-one,
unhandled `Future` rejections, swallowed exceptions, `async void`, disposal of
controllers/subscriptions/`HttpClient`, race conditions between a rebuild and an
in-flight request, timezone and date-boundary handling (the nutrition day-window bugs
in this repo's history all lived here).

**2 · Repo invariants.** See the ledger below. These are the failures a green test
suite and a happy compiler will not catch, because they are policy encoded in code.

**3 · Trust boundaries.** Every Trainer Console endpoint must independently re-check
the caller against an **Active** `TrainerClientRelationship` — `TrainerConsoleGate` is
a UX guard, never a security boundary. Any endpoint that trusts a client-supplied id
for authorization is a finding regardless of what the UI does. SignalR group
membership is tied to `Status == Active`, not role membership.

**4 · State, lifecycle, async.** Provider notification storms, state derived in
`build()` that should be memoized, the single app-shell **active client** selection
being re-derived or re-selected per screen instead of shared, navigation that
reloads rather than re-deriving visible panes.

**5 · Error handling and the four screen states.** Every data-bound screen owes
**loading / empty / error / populated** (CLAUDE.md, "States every screen must
handle"). A bare `CircularProgressIndicator` where a skeleton is required, a blank
screen where an empty state is required, a raw exception surfaced to a trainer, or a
retry-less error are each findings.

**6 · Accessibility and token conformance.** Tap targets (44×44 mobile / 32×32 dense
desktop), semantic labels on every interactive element, colour never the only signal
on ok/warn/bad, WCAG AA contrast — check Forge Orange `#FF6B3E` on light backgrounds
specifically. Flag hard-coded colours, radii and spacing that bypass
`lib/core/providers/theme_provider.dart`, and any spacing off the 4px scale.

**7 · Duplication, dead weight, YAGNI.** The same visual pattern re-implemented
inline in two screens instead of one shared widget; parallel names for one concept;
unused abstractions, config hooks and generalized layers built "just in case";
commented-out code; unreachable branches.

**8 · Tests.** Not coverage percentage — coverage of *consequence*. Which of the
invariants below has no test pinning it? Which bug fixed in this branch has no
regression test? Tests asserting mock interactions instead of behaviour are findings.

**9 · Release and config hygiene.** `pubspec.yaml` is the single source of the
version; `build.gradle.kts` derives from it and is never hand-edited. The `+N` build
number must increase on every upload. `CHANGELOG.md` and `PLAY_NOTES.md` both need a
`## <version>` section matching the full version, `+N` included; `PLAY_NOTES.md` is
capped at 500 characters per locale. Secrets are `KEYSTORE_BASE64` /
`KEYSTORE_PASSWORD` / `KEY_ALIAS` / `KEY_PASSWORD` — no `ANDROID_` prefix.

## The invariant ledger

Each of these was a real bug once. Check the code against every line in scope.

**Licensing and premium** (`docs/trainer-licensing.md`)
- `AccessProvider.hasPremiumAccess` is `_isPremium || _proFromLicence` — **never**
  `|| isTrainerClient`. Invite codes are free to mint; a relationship-based grant
  makes Pro free to anyone with a spare email.
- `TrainerLicence.GrantsPro` requires a non-Free tier, for the same reason.
- A licence is created **only** in `AuthService.RegisterAsync` via
  `ITrainerLicenceRepository.CreateFreeAsync`. Every licence endpoint is a pure read
  that refuses a non-trainer with `not_a_trainer`. No `GetOrCreateAsync`, no
  provisioning on any read path — `GET api/TrainerLicence/me` used to be one, and
  opening the plan screen turned ordinary users into permanent trainers.
- `IsTrainer = licence != null`. Not roster-based: a roster check locks a new trainer
  out of the only screen they could invite their first client from.
- A seat is an Active relationship **or** an unexpired Pending invite, enforced at
  both mint **and** redemption. Mint-only is advisory.
- Over the limit blocks new invites and **never** revokes clients.
- Lapsing gives 14 days of grace (`proEndsAt`), then read-only — never deletion.
  Writes are blocked by `RequireEntitledLicenceFilter`, applied per-action.
- Free is never a downgrade target; the trial always requires a card.
- Seat counts live only in `LicencePlanCatalog`; prices live in Stripe, keyed by
  price id.

**Routing and roles** (`docs/onboarding-and-roles.md`)
- `PostAuthHome` in `main.dart` is the **single** place deciding where an
  authenticated user lands. Never push `HomeScreen` directly after auth — that
  dropped web trainers into the trainee app.
- `ProfileSetupGate` waits for `AccessProvider.roleResolved`, not `initialized`.
  `initialized` flips on cached flags and flashes the trainee questionnaire at a
  trainer on first sign-in.
- Leaving the console for the trainee app must stay possible without signing out
  (`onExitConsole`).

**Web** (`docs/cors-and-signalr.md`)
- CORS is origin-explicit and credentialed, driven by `Cors:AllowedOrigins`.
  `AllowAnyOrigin` cannot be combined with `AllowCredentials` — SignalR needs the
  credentialed form.
- No `--wasm` until `flutter_secure_storage_web` stops using `dart:html`.
- `purchases_flutter` fetches its JS mapping from a CDN and errors on web; premium
  paths must not be relied on in a browser.

## Verification gate

Before a finding is reported it must clear all four:

1. **Read the actual code**, not the diff hunk around it. A hunk that looks wrong is
   frequently right in context, and vice versa.
2. **Name the concrete failure**: specific inputs or state → specific wrong output,
   crash, or policy breach. "Could be a problem" is not a finding.
3. **Rule out the existing guard.** Search for the validation, filter, or test that
   already covers it. This repo has regression tests pinning most of the ledger —
   find them before claiming a violation.
4. **Judge whether it matters.** Style preferences, hypothetical futures, and
   "consider extracting this" are not findings unless they violate a documented
   convention in CLAUDE.md.

Anything that fails a gate is dropped silently. Do not report it as a "minor note."

## Output

Lead with a verdict line: how many files reviewed, how many findings survived, and
whether the branch is shippable as-is.

Then a ranked table — most severe first:

| # | Severity | File:line | Finding |
|---|---|---|---|

Then one short section per finding: the failure scenario, why the compiler and the
tests had nothing to say about it, and the smallest fix that resolves it. Reference
code as `path/to/file.dart:42` so it is clickable.

Close with **what you checked and found clean**, pass by pass. That list is how the
owner knows the review was total rather than lucky.

## Rules

- **Report, do not rewrite.** The owner writes implementation code himself and reads
  reviews to learn the codebase. Describe the fix; write it only when `--fix` is
  passed or the owner asks.
- With `--fix`: apply only findings that cleared the gate, smallest change each, run
  the repo's own checks, and report what you changed versus what you left.
- Never skip, disable, or weaken a test to make something pass.
- If a pass cannot run (tooling missing, subsystem out of scope), say so plainly
  rather than reporting it as clean.
