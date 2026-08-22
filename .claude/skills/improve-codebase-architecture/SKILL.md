---
name: improve-codebase-architecture
description: Structural assessment and sequenced refactor plan for the ForgeForm codebase — layering and dependency direction, module cohesion, state ownership, duplicated concepts, API surface consistency, over- and under-abstraction. Use when the user wants the shape of the code improved rather than individual bugs found. Produces a map, ranked findings and a migration plan; proposes rather than performs unless asked.
argument-hint: "[subsystem | --api | --flutter | --full] [--apply]"
metadata:
  author: ForgeForm
  version: "1.0.0"
---

# Improve Codebase Architecture

Quality review asks "is this code correct?" This asks "is this the right code in the
right place, and what does it cost to move it?"

The trap is opinion without evidence — arriving with a preferred architecture and
grading the repo against it. Every finding here starts from something measured in
the codebase, and every recommendation carries its blast radius. A refactor nobody
can afford is not a recommendation.

## Scope

| Argument | Scope |
|---|---|
| *(none)* or `--full` | both surfaces, plus the seam between them |
| `--api` | `FitTracker.Api/` |
| `--flutter` | `fittnes_tracker/lib/` |
| a subsystem name | e.g. `chat`, `trainer_console`, `nutrition`, `licensing` — trace it end to end, controller through provider to widget |

## Phase 1 — Measure before you opine

Gather evidence first. Report the numbers; they are half the deliverable.

- **Size distribution.** Largest files by line count, excluding generated code —
  `*.g.dart`, `lib/l10n/*`, `Migrations/`. A 2,800-line view file is a finding on
  its own.
- **Dependency direction.** In the API, does anything flow backwards —
  `Repositories/` importing from `Controllers/`, `Models/` knowing about `DTOs/`? In
  Flutter, does `lib/core/` ever import from `lib/feature/`? Core depending on a
  feature is a layering inversion, always.
- **Cohesion of the feature tree.** `lib/feature/` mixes two shapes: nested
  (`gym_tracking/presentation/view/…`) and flat (`progress_dashboard_view.dart`
  sitting directly in `feature/`). Map which features follow which, and whether the
  nesting earns itself where it exists.
- **Duplicated concepts.** Shared behaviour that drifted apart is worth more attention
  than any abstraction you could invent — but similar *names* are a hypothesis, not
  evidence. Find candidate pairs (a `create_`/`edit_` pair, two screens with the same
  suffix), then diff them whitespace-insensitively and compare method-name sets before
  concluding anything. A pair that shares only `build()` is two different screens with
  similar titles, and merging them makes the tree worse. Report the measurement either
  way: a rejected duplication is a finding too, because it stops the same refactor
  being proposed again next quarter.
- **State ownership.** Where does each piece of state actually live, and who can
  mutate it? The **active client** selection must live once at app-shell level and be
  shared across Roster, Chat, Workout Builder and Nutrition — every place it is
  re-derived or re-selected per screen is a finding.
- **Naming drift.** Widget names must mirror the design-system component names in the
  handoff (`StatTile`, `ProgressBar`, `MacroSummary`, `Button`). Parallel names for
  one concept, and one name meaning two things, both count.

## Phase 2 — Assess along these axes

**Layering and dependency direction.** Are Controllers thin? Is business logic in
`Services/` or has it leaked into controllers and repositories? Does the repository
layer return domain models or leak `IQueryable`/EF types upward?

**Module cohesion and coupling.** Does a feature folder contain everything that
changes together, or does a single behaviour change require edits in five folders?
Count the folders touched by recent feature commits — `git log --name-only` over the
last few merges answers this factually.

**State ownership and flow.** One owner per piece of state. Derived state computed
once, not recomputed per rebuild. Cross-cutting selections at the shell, not
duplicated per screen. On wide viewports, switching the active client must re-derive
*all simultaneously visible panes* — an architecture that only updates the focused
screen fails the desktop requirement structurally, not cosmetically.

**Trust boundary placement.** Authorization belongs server-side, per endpoint,
against an Active `TrainerClientRelationship`. `TrainerConsoleGate` is a UX guard.
Any design where the client is the only thing between a user and someone else's data
is an architectural defect, not a bug.

**API surface consistency.** Do endpoints agree on naming, pluralization, error
shape, and status codes? Is `not_a_trainer` (or whatever the convention is) used
uniformly, or does each controller invent its own refusal format? Inconsistency here
taxes every client change forever.

**Error strategy.** One coherent story from exception to user-visible message, or
several competing ones? `lib/core/errors/` exists — is it actually the single path,
or do features catch and format independently?

**Test seams.** Can the thing be tested without standing up the world? Untestable
code is usually badly-factored code; the seam that is missing tells you which
dependency should have been inverted.

**Abstraction, both directions.** Over: unused generalized layers, config hooks and
indirection built "just in case" — YAGNI violations, per CLAUDE.md, and they are
findings. Under: the same logic pasted into four screens. Say which you are seeing;
they need opposite fixes, and "add an abstraction" is the wrong instinct roughly half
the time.

## Phase 3 — Report

**A current-state map.** How the system is actually layered today, in prose plus one
diagram or table. Describe what is there, not what should be.

**Ranked findings**, worst structural debt first:

| # | Finding | Evidence | Cost of leaving it | Blast radius to fix |
|---|---|---|---|---|

"Evidence" is a measurement or a file reference, never an impression. "Blast radius"
is concrete: files touched, whether it forces a migration, whether it breaks the
public API surface, whether tests exist to catch a regression.

**A sequenced plan.** Ordered so each step is independently shippable and leaves the
tree green. Explicitly separate:
- *Now* — cheap, contained, unblocks later steps.
- *Next* — worth doing, needs a dedicated change.
- *Not worth it* — real problems whose fix costs more than the problem. Naming these
  is as valuable as the recommendations; it stops the same debate recurring.

**What you are deliberately not changing, and why.** A structure that looks unusual
but works, and has tests pinning it, stays.

## Phase 4 — The teaching document (required)

CLAUDE.md requires it and it is part of the deliverable, not a follow-up. A
standalone document in `docs/`, or a new section on the existing document for that
subsystem, committed alongside any code.

It covers: what was actually wrong and **why the compiler and the tests had nothing
to say about it** — architectural defects are invisible to both, which is the whole
reason they accumulate; the decisions that are not obvious from the diff and what the
rejected alternatives would have cost; and the general lesson that outlives this
change — the shape of the mistake, not the instance.

Narrative prose, readable on its own, tables and diagrams where they earn their
place. Match `docs/chat-architecture.md` for depth, tone and structure — it is the
model. `CHANGELOG.md` records *what changed* and still gets written; this explains
*why it was wrong and how not to write it again*.

## Rules

- **Propose, do not perform.** The owner writes implementation code himself and reads
  these to learn the codebase. Produce the map, the findings and the plan. Refactor
  only when `--apply` is passed or the owner asks.
- With `--apply`: one step at a time, tree green after each, tests run and reported
  between steps. Never bundle unrelated structural changes into one commit.
- **No speculative architecture.** YAGNI is a project rule. Do not recommend an
  abstraction for a requirement that does not exist yet, however likely it looks.
- **Never trade a documented invariant for elegance.** The licensing, routing and
  authorization rules in `docs/trainer-licensing.md`, `docs/onboarding-and-roles.md`
  and CLAUDE.md are pinned by regression tests because each was a real incident. A
  cleaner design that relaxes one of them is not cleaner.
- Preserve behaviour unless a change of behaviour is the point and is called out.
