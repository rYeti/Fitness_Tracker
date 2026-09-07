# Deload weeks: how to calculate one, show one, and decide who gets to set one

A design walkthrough for adding deload weeks to ForgeForm, written to be read on
its own. It covers where a "week" actually comes from in this codebase, why the
obvious storage choice is the wrong one, the three places the plumbing is
already broken in ways that would silently swallow the feature, and the
authority rule that makes "the user sets it, unless their trainer does" fall out
of data we already have instead of a new permission system.

No code has been written yet. This is the plan and the reasoning behind it.

Line references are to the commit that introduces this document.

---

## 1. What the feature has to answer

A deload is a planned week of reduced training stress inside a programme —
lighter loads, fewer working sets, or both — so accumulated fatigue can clear
without the trainee stopping. Three questions have to be answerable, and they
are more separable than they look:

1. **Which week of the programme is today?** — arithmetic.
2. **Is that week a deload?** — a stored declaration.
3. **Who is allowed to make that declaration?** — authority.

Almost every mistake available here comes from collapsing two of the three. The
most tempting collapse is answering (2) by writing a flag onto every session in
the week, which quietly makes (1) and (2) the same thing and then makes (3)
impossible to enforce. Section 4 is about why not.

---

## 2. Where a "week" comes from — and the two different weeks already in the app

ForgeForm already counts weeks in two incompatible ways, and neither one is
labelled as a choice.

**The trainee's programme counts weeks from the plan's start date.**
`create_view.dart` asks for a duration in weeks and writes
`durationDays = _durationWeeks * 7` onto `WorkoutPlanTable`, then materialises
one `ScheduledWorkoutTable` row per day for `_durationWeeks * 7` days starting at
`_startDate`. The cycle pattern itself is *not* seven days long — it can be any
length, and `day % _cyclePattern.length` walks it. So the plan's weeks are
7-day blocks anchored on `startDate`, entirely unrelated to the cycle, and
"week 5" means days 28–34 of the plan.

**The Trainer Console counts Monday-anchored calendar weeks.**
`TrainerConsoleService.WeekStartFor` snaps to Monday, and the twelve attendance
bars on Client Detail are Monday-to-Sunday.

These agree only when a plan happens to start on a Monday. A plan starting on a
Wednesday puts every programme week across two attendance bars.

**Recommendation: anchor deloads to the plan, not the calendar.** Three
reasons, in order of weight:

- The plan is *already authored in plan-weeks*. `SchedulePlanRequestDto` takes
  `DurationWeeks`; `create_view` takes `_durationWeeks`. Marking "week 5" in the
  same units the programme was written in needs no translation and no explaining.
- A deload is a periodisation concept. It belongs to the block, not to the
  calendar. "Week 5 of 8" survives the plan being started on any weekday;
  "the week of the 14th" does not survive being asked about a different plan.
- `startDate` is not editable after creation — `edit_view.dart` sets it once at
  `DateTime.now()` and never offers a picker. So plan-relative week numbers are
  stable. (If start-date editing is ever added, it must renumber or clear the
  deload set; see §11.)

The cost is honest and should be stated in the UI rather than engineered away:
the trainer's attendance bars will not line up with the deload week when the
plan didn't start on a Monday. The fix for that is to put the deload marker on
the *day/session*, where it is unambiguous, and not to try to tint an attendance
bar that only half-overlaps.

### 2a. The arithmetic, and the three ways to get it wrong

```
weekNumber(date) = floor(daysBetween(planStartDay, day(date)) / 7) + 1
```

One-based, deliberately: the UI says "Week 5", and storing zero-based numbers
behind a one-based label is the single most reliable way to ship an off-by-one.
Name the accessor `weekNumberFor`, never `weekIndexFor`, so the type's name
carries the convention.

It returns `null` outside the plan — before `startDate`, or at or beyond
`durationDays` when the plan has one. A null week number is "no deload
question to ask", not "week 0".

Three traps, all of which this repo has already been bitten by in other forms:

**Do not subtract instants.** `startDate` is a `DateTime` column on both sides,
and `docs/trainer-nutrition-duplicate-meals.md` already records the general
version of this: *the date column is an instant, not a day*. `DateTime.now()
.difference(plan.startDate).inDays` is wrong twice over — the start instant
carries a time-of-day, so the boundary moves; and DST makes a local day 23 or 25
hours, so `.inDays` truncates to the wrong day roughly twice a year. Normalise
both ends to a date first, then subtract:

```dart
int _daysBetween(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day)
        .difference(DateTime.utc(a.year, a.month, a.day))
        .inDays;
```

The `DateTime.utc` is a normalisation trick, not a timezone conversion — both
operands get the same fictional zone, so the difference is exactly the number of
calendar days between them, DST included.

**Do not `DateTime.parse` the start date off the wire without checking for a
`Z`.** `WorkoutPlanSummary.fromJson` currently does exactly that
(`trainer_console_models.dart:158`), which is the trap
`docs/chat-timestamps.md` was written about. For a *time* that silently shifts
the clock by an offset. For a *date* it is worse, because the shift can move the
whole plan across a day boundary and renumber every week. Whatever the payload
says, the week arithmetic must run on the plan's start **day**, and the
serialisation should be date-only (`yyyy-MM-dd`) the way
`TrainerConsoleApi._dateParam` already sends dates.

**Do not compute "today" twice.** `GetRosterAggregateAsync` already carries the
comment for this: *"Read the clock once. Two reads either side of midnight
disagree."* A screen that resolves the current week for a header and again for a
badge can disagree with itself at midnight. Resolve once per read and pass it
down.

### 2b. One rule, two languages

Both sides need this arithmetic. The trainee app is offline-first — the drift
database is the source of truth for a device with no connection, so it must be
able to decide "today is a deload" with no server. The server needs it to stamp
completed sessions (§7) and to answer trainer-facing reads.

That is two implementations of one rule, which will drift. There is no way to
avoid the duplication, so the mitigation is to make the drift visible:

> The week arithmetic exists in exactly two places — `PlanWeek` (Dart) and
> `PlanWeeks` (C#) — and both are pinned by the *same table of cases*: plan
> starting Mon/Wed/Sun, day 0, day 6, day 7, a DST boundary, a date before the
> start, a date past `durationDays`. A case added to one table is added to both.

This is the same discipline `docs/trainer-console-loading.md` imposed on the
current-programme predicate ("two copies of it will drift"), applied to a
duplication that cannot be collapsed to one copy.

---

## 3. Where the declaration lives

**Recommendation: one column on the plan, holding a JSON array of week numbers.**

```
WorkoutPlanTable.deloadWeeksJson   TEXT NOT NULL DEFAULT '[]'   (drift, schema 40)
WorkoutPlan.DeloadWeeksJson        text not null default '[]'   (EF, new migration)
```

Sorted, de-duplicated, one-based. `[]` for a plan with no deloads.

The plan already carries `cyclePatternJson` as a JSON blob, so this is idiomatic
here rather than novel. More importantly, the column shape forces the write
semantics you want: **a deload write always replaces the whole set.** That is
the same rule `docs/trainer-console-micronutrients.md` landed on for nutrient
pins — "a pin write always replaces the whole set, never edits one row" — and it
exists for the same reason. A replace is idempotent by construction. An
add/remove pair is two operations that can interleave, and
`docs/trainer-console-duplicate-rows.md` is 100% about what happens when a write
path's idempotency is assumed rather than built.

### 3a. What was rejected, and what it would have cost

**A boolean on every `ScheduledWorkout` row.** The obvious one. Rejected:

- Setting "week 5 is a deload" becomes a fan-out write over ~7 rows, each of
  which is a separate sync push, and each of which can half-apply. A
  half-applied deload week is a week where Monday is a deload and Thursday
  isn't, which is worse than no feature.
- It cannot express a deload for a week whose sessions don't exist yet. A
  free-choice plan (`isFreeChoice`) generates *no* `ScheduledWorkout` rows at
  all — the user picks each day. A trainer marking next month's deload on a
  free-choice client would have nothing to write to.
- Rows created later don't get the flag. `postponeWorkout` moves a session to a
  new date; ad-hoc scheduling inserts one. Both would land in a deload week
  carrying a `false` nobody set.
- Authority becomes unenforceable. §5's rule is "whoever owns the plan owns the
  deload". Spread across N session rows, that check has to be repeated N times
  on every write path that touches a session, including the trainee's own sync
  push.

**A `deloadEveryNWeeks` rule instead of an explicit set.** Tempting, because
"every 4th week" is how most programmes are written. Rejected: changing `N`
retroactively rewrites which past weeks were deloads, and a single-week override
then needs *both* a rule and an exception list — two sources of truth for one
answer. Keep the generator in the UI: "repeat every 4 weeks" is a button that
**expands** to `[4, 8, 12]` at save time and stores the expansion. The rule is
authoring convenience; the set is the truth.

**A separate `WorkoutPlanDeloadWeek` table.** Correct in the abstract, and
against YAGNI here: the set is bounded at 52 entries by `DurationWeeks`'s own
range, it is always read whole with its plan, and it is always written whole.
A table buys nothing and costs a join, a repository, a sync path and a
migration.

**A single `isCurrentWeekDeload` boolean on the plan.** Rejected outright: it
cannot answer "was last week a deload", it silently becomes wrong the moment the
week rolls over, and nothing in the system would ever clear it.

---

## 4. Three things already broken that would swallow this feature

These are pre-existing, none of them are visible to the compiler or to the
current test suite, and each one would make the feature appear to work in
development and fail in the hands of a real pair of users.

### 4a. `_pullWorkoutPlans` never updates a plan it already has

`sync_service.dart:2650`:

```dart
if (existingPlan != null) {
  await _addMissingPlanWorkoutLinks(existingPlan.id, p);
  continue;                 // <-- every column of the plan is skipped
}
```

The plan's own fields are written on the insert path only. A device that has
already pulled a plan will **never** pick up a change to any column on it — not
the name, not `durationDays`, and not `deloadWeeksJson`. So a trainer marking
week 5 as a deload would save it, see it in the console, and the client's phone
would never show it. Forever.

This is the exact failure `docs/trainer-workout-builder.md` describes for
workouts, and records having fixed there:

> the sync pull's "already have this workout" check now reconciles a clean local
> copy instead of skipping it outright, which is the only reason a trainer's
> edit ever reaches a device that already pulled the workout once.

The plan pull never got the same treatment. The `continue` is even commented as
deliberate — but read the comment: it is arguing that *membership* removals are
unsafe to reconcile, which is true and unrelated. It says nothing about the
plan's own columns, and skipping them is collateral damage.

**This must be fixed before, or as part of, the deload work**, and it is worth
noting that it is not a deload bug — it is a plan-sync bug that the deload
feature happens to be the first thing to depend on. Reconcile the scalar
columns of a plan whose local copy is clean (`syncStatus == synced`), leaving
the membership logic exactly as it is. The `syncStatus` guard matters:
`docs/sync-account-switch-duplication.md`'s rule is that a locally-edited row
must not be overwritten by a pull, and a plan the user just edited offline is
precisely that case.

### 4b. The trainee's plan push is a full-document PUT

`_syncUpdatePlan` sends `name`, `description`, `startDate`, `cyclePatternJson`,
`isFreeChoice`, `durationDays` as one document to `PUT api/WorkoutPlan/{id}`,
and `WorkoutPlanRepository.UpdatePlanAsync` applies it. Add `deloadWeeksJson`
to that document naively and a trainee's device that hasn't pulled the trainer's
change yet will push a stale `[]` over it — last writer wins, and the loser is
the trainer.

The fix is not to add a dedicated endpoint and a second sync path. It is to make
the server the boundary, which §5 requires anyway: **the trainee's plan update
ignores `deloadWeeksJson` when the plan is trainer-assigned.** The field is
dropped, the response echoes the authoritative value, and 4a's reconcile puts
the device right on the next pull. Failing the whole PUT instead would stall
every unrelated plan edit behind one field the client didn't mean to send.

### 4c. The Flutter client cannot tell a trainer-assigned plan from its own

`WorkoutPlanResponseDto.AssignedByTrainer` and
`WorkoutResponseDto.AssignedByTrainer` both exist and are both populated
server-side. Grep the Flutter app for `assignedByTrainer` and there are **zero**
hits. The field crosses the wire and is thrown away; `WorkoutPlanTable` has no
column for it.

So the trainee app currently has no way to know whether it should offer the
deload toggle. Carrying it needs a `boolean assignedByTrainer` column on
`WorkoutPlanTable`, read in `_pullWorkoutPlans` from a field already in the
payload. Small, but it is a prerequisite, not a nice-to-have — without it the
trainee UI has to guess, and the guess is the difference between "your trainer
sets your deloads" and a toggle that appears to work and is silently discarded
by the server on every sync.

---

## 5. Who may set it — authority falls out of plan ownership

The requirement is "the user sets their own deload if they have no trainer; the
trainer sets it for their clients". Resist turning that into a permission
concept. It already exists in the schema:

> **The deload declaration is owned by whoever owns the plan.**
> `WorkoutPlan.AssignedByTrainerId == null` → the trainee sets it.
> `AssignedByTrainerId == <trainer>` → that trainer sets it, and only that trainer.

This is the same field that already decides who may delete a plan
(`PlanDeleteResult.AssignedByTrainer`), so it needs no new invariant and no new
tests of its own beyond the two below. It also gets the awkward cases right for
free:

| Situation | Who sets the deload |
|---|---|
| No trainer, own plan | Trainee |
| Has a trainer, training on a plan they built themselves | Trainee |
| Has a trainer, on a trainer-assigned plan | The assigning trainer |
| Trainer relationship ends | Plan keeps `AssignedByTrainerId`; nobody can set it until the trainee makes their own plan |

That last row is the one worth arguing about. It is the right behaviour: the
plan is still the trainer's prescription, and silently handing the trainee the
pen when a relationship lapses is exactly the kind of quiet authority transfer
the licensing doc refuses elsewhere ("lapsing gives 14 days of grace, then
read-only — never deletion"). If it proves annoying in practice, the answer is a
"make this plan mine" action with a confirmation, not an implicit rule.

**Enforce it server-side, on both endpoints.** CLAUDE.md is explicit that the
console gate is a UX guard and every trainer endpoint re-checks the caller
against an Active relationship; the same applies here in both directions:

- `PUT api/TrainerConsole/{clientId}/workout-plans/{planId}/deload-weeks` —
  body is the replacement list, mirroring the existing
  `PUT .../nutrient-pins` shape exactly. Refuses unless the caller is an active
  trainer of the client **and** `AssignedByTrainerId == callerId`.
- The trainee's own path goes through the existing sync push, with the server
  dropping the field for a trainer-assigned plan (§4b).

Two regression tests, in the spirit of `TrainerProvisioningTests`: a trainee's
PUT cannot change the deload set on a trainer-assigned plan; a trainer who did
not assign the plan cannot change it either.

---

## 6. What a deload actually does to the prescription

Look at what a prescription contains before deciding. `WorkoutSetTemplate` has
`SetNumber`, `TargetReps` (a string, so `"8-12"` is legal) and `OrderPosition`.
**There is no prescribed weight anywhere in the schema.** Load is something the
trainee logs, not something the plan states.

That settles it: a deload cannot mechanically reduce a prescribed load, because
there isn't one. Two options remain.

**Rewriting the set templates for the week** — dropping a set, widening the rep
range. Rejected. `WorkoutSetTemplate` rows belong to the `WorkoutExercise`, not
to a date, so a week-scoped rewrite would have to mutate the template and put it
back afterwards. `docs/trainer-session-review.md` describes what happens when
prescriptions are mutated on a schedule ("prescriptions that grew every time you
saved"), and a deload that permanently deletes a working set from someone's
programme because the restore didn't run is a bad trade for a feature whose
whole point is to be temporary.

**An advisory target beside the existing "previous" hint** — recommended.
`active_workout_view.dart:1518` already renders `100 kg × 8` from the previous
session for each set. That line is the natural home:

```
Previous   100 kg × 8
Deload     ~65 kg × 8          ← derived, never stored
```

Derived at render time from the previous *non-deload* session's logged weight
times a factor. Nothing is written, nothing needs restoring, and a trainee who
ignores it has simply ignored a hint.

Start with a single constant factor (60% is the common prescription) and a
short line of guidance in the week banner. Do **not** add a per-plan
`deloadLoadPercent` column until a trainer asks for one — YAGNI, and the number
is guidance, not a target the app should pretend to enforce.

One detail that matters: the previous-session lookup must skip deload sessions
when finding "last time", or the week *after* a deload will anchor its hints to
the deload's reduced loads and the trainee will spend two weeks light. This is
the sort of thing that is obvious once stated and invisible in review.

---

## 7. History needs a stamp, not a re-derivation

`docs/trainer-session-review.md` states the rule this feature has to obey:

> A row that records what was true at a point in time cannot answer a question
> about what is true now.

The deload feature needs the mirror image of it. `WorkoutPlan.DeloadWeeksJson`
records what is true **now**. It cannot answer what was true when a session was
performed. Render a past session's deload badge by re-deriving from the plan and
every one of these is wrong:

- The trainer removes week 5 from the deload set in October. Every session the
  client did in week 5 back in June stops being a deload, retroactively.
- The client finishes the plan and starts a new one. `weekNumberFor` now returns
  null for every old session, or worse, a week number belonging to a different
  programme.
- The plan is deleted. Its history survives (sessions are kept); its deload
  weeks don't.

**Recommendation: `ScheduledWorkout.WasDeload` (`bool?`), stamped at
completion.** Null everywhere else. Readers use the stamp when it is non-null
and derive from the plan when it is null — which is exactly right, because null
means "not performed yet", and for a future session the plan *is* the current
truth.

Stamp it at completion rather than at generation, because generating the sessions
happens weeks or months before anyone decides where the deloads go. The edge
case this leaves is honest and should be left alone: mark the current week as a
deload on Thursday, and Monday's already-completed session stays un-stamped. It
was not performed as a deload. Saying it was would be a lie the trainer would
then read on Session Review.

---

## 8. Showing it

One shared widget, per CLAUDE.md's "one shared widget per repeated pattern —
never re-implement the same visual pattern inline". Call it `DeloadChip` and use
it on every surface below.

**Do not reuse `StatusBadge`.** Its tone enum is `ok / warn / bad`, and a deload
is none of the three — it is information, not a judgement. Shoehorning it into
`warn` tells a trainee their planned recovery week is a problem.
`ForgeColors.statusInfoFor(brightness)` already exists with a contrast-checked
light variant (`statusInfoOnLight`), which is the right token. Add the new
foreground/background pair to `test/core/contrast_test.dart` — that file exists
because a tone shipped at 4.34:1 and no other test could see it.

Colour is never the only signal (CLAUDE.md, non-negotiable): the chip carries
the word "Deload" and an icon, and the icon alone is never used.

**Trainee surfaces**

| Where | What |
|---|---|
| `scheduled_workouts_view.dart` day cards | Chip on each day in a deload week |
| The calendar grid (`_weekdays`, ~line 877) | A subtle band behind the deload week's row — with the chip in the day card as the non-colour signal |
| `active_workout_view.dart` header | Chip + one line of guidance ("Reduced load — stop 3–4 reps short") |
| Per-set rows (~line 1492) | The derived deload target beside "previous" (§6) |
| Plan screen | The week strip with toggles — see below |

**Trainer surfaces**

| Where | What |
|---|---|
| Workout Builder plan section | The week strip, `1..durationWeeks`, tap to toggle |
| Client Detail | "This week is a deload" chip in the header |
| Session Review | Chip on past sessions, from `WasDeload` (§7) |
| Dashboard roster | Optional: chip per client currently in a deload week |

The roster one is cheap but not free, and it has a rule attached.
`GetActivePlanNamesAsync` currently projects `{ UserId, Name }`. Answering "is
this client in a deload week" needs `StartDate` and `DeloadWeeksJson` in the
same projection — two more columns on a query that already runs, no new round
trip. `docs/trainer-console-loading.md`'s rule holds: a trainer-facing aggregate
reads a bounded window and returns one row per client. Adding two columns to an
existing projection respects that; adding a per-client query does not.

**The week strip** is the primary control on both sides, and it is the same
widget:

```
 1   2   3   4●  5   6   7   8●
             ▲ deload          ▲ deload
```

One-tap toggle on a week; "repeat every N weeks" as a secondary action that
expands into explicit toggles (§3a) so the user can immediately see and override
what it did. Weeks before the current one are shown but not editable — editing
the past is the retroactive-rewrite problem from §7 wearing a friendlier hat.

**States.** Every data-bound surface needs the four (CLAUDE.md): the week strip
has no meaningful loading state of its own if the plan is already loaded, but
"no active plan" is a real empty state and must say so ("Deloads are set per
plan — create one first"), not render an empty strip. And on the trainee's side,
a trainer-assigned plan renders the strip **read-only with an explanation** —
"Your trainer sets the deload weeks for this plan" — rather than hiding it.
Hiding a control makes a user think the feature doesn't exist; disabling it with
a reason tells them where to ask.

---

## 9. Telling the client their trainer set a deload

The obvious answer — have the server post a chat message — is impossible here,
and it is worth writing down why so nobody tries.

`docs/chat-encryption.md`: the server stores an opaque blob and **must never be
given a way to read or write one**. It cannot compose "Week 5 is a deload"
because it cannot encrypt. Push is data-only and the *device* writes the
notification.

Two workable options:

**Pragmatic, zero new infrastructure (recommended for v1):** the trainer's own
console, at the moment it saves the deload set, offers to send an ordinary
encrypted chat message alongside it. Composed on the trainer's device, sent
through the path that already exists, end-to-end encrypted like everything else.
It is also better product: a trainer's own words about why this week is lighter
beat a system notice.

**A data-only push with a new type**, rendered locally by the device, mirroring
how chat push already works. Correct, and more machinery than the first release
needs. If it happens, it goes through the existing path in
`docs/push-notifications.md` — data-only, device composes.

Either way, the badge itself arrives with the next sync, and after §4a is fixed
that is a real guarantee rather than a hope.

---

## 10. Things that will be got wrong

A checklist for review, and for the tests:

- [ ] Week arithmetic on **days**, not instants (§2a). Test a DST boundary.
- [ ] `weekNumberFor` is one-based and returns null outside the plan.
- [ ] Clock read once per render pass.
- [ ] Both language implementations pinned by the same case table (§2b).
- [ ] `_pullWorkoutPlans` reconciles a clean plan's columns (§4a) — without
      which nothing else in this feature works between two people.
- [ ] Reconcile is guarded on `syncStatus == synced` so it can't eat an offline
      edit (`docs/sync-account-switch-duplication.md`).
- [ ] Server drops `deloadWeeksJson` from a trainee push on a trainer-assigned
      plan, and echoes the authoritative value (§4b).
- [ ] `assignedByTrainer` is actually carried into the local plan table (§4c).
- [ ] Deload writes replace the whole set; never add/remove (§3).
- [ ] "Every N weeks" expands at save time; the rule is not stored (§3a).
- [ ] The previous-session hint skips deload sessions when looking back (§6).
- [ ] Past sessions read `WasDeload`, never re-derive (§7).
- [ ] `DeloadChip` is not `StatusBadge`; contrast pair added to
      `test/core/contrast_test.dart` (§8).
- [ ] Trainee UI on a trainer-assigned plan is read-only **with a reason**, not
      hidden (§8).
- [ ] A free-choice plan still resolves a week number (it has a `startDate`), and
      a user with no active plan gets a clean "nothing to mark" state.

---

## 11. Suggested phasing

**Phase 0 — the plumbing, shippable on its own.** Fix `_pullWorkoutPlans` to
reconcile a clean plan's columns; carry `assignedByTrainer` into
`WorkoutPlanTable`. Both are bug fixes with value independent of deloads, and
both are prerequisites. Landing them separately means the deload PR is about
deloads.

**Phase 1 — trainee-owned deloads.** `deloadWeeksJson` on both schemas, the
`PlanWeek`/`PlanWeeks` helpers with their shared case table, the week strip on
the trainee's plan screen, `DeloadChip` on the schedule and active-workout
screens. No trainer involvement, no stamp — everything derives from the plan,
which is correct while nothing but the current programme is being shown.

**Phase 2 — trainer-set deloads.** The console endpoint and its two authority
tests, the week strip in the Workout Builder, the read-only strip with its
explanation on the trainee side, the optional chat message on save.

**Phase 3 — history.** `ScheduledWorkout.WasDeload`, stamped at completion; the
chip on Session Review and on the trainee's own history. Worth splitting out
because it is the only part that touches the completion path, and the completion
path is where logged sets live.

**Deliberately not planned:** automatic deload *detection* — suggesting a week
based on RPE trend, adherence, or volume drop. The signals exist
(`WorkoutSetTable.rpe`, the attendance aggregate, `setType` for excluding
warmups) and it is a genuinely interesting feature. It is also a different
feature: it is a recommendation engine, and it must never auto-apply. An app
that silently decides someone's week is now a deload is worse than one that
never mentions it. If it is built, it is a suggestion chip on the week strip
that the user or trainer taps to accept — which is to say, it is a UI on top of
everything above, and nothing above has to change to accommodate it.

---

## 12. The general lesson

The interesting part of this design was not the deload. It was that three
separate pieces of existing plumbing would have swallowed it silently:

- A pull that skips rows it already has, so a remote edit never lands.
- A full-document PUT, so a stale client overwrites a field it never edited.
- A DTO field that crosses the wire and is discarded, so the client can't tell
  whose data it is holding.

None of the three is a bug in isolation. Each one is fine until something new
depends on a plan column changing after the plan was created — and *nothing had,
until now*. `durationDays` is set at creation. `cyclePatternJson` is set at
creation. `startDate` isn't editable. The deload set is the first field on
`WorkoutPlan` that is meant to change during the plan's life, and it lands on
plumbing built, reasonably, for fields that never do.

> Before adding a mutable field to an entity, check whether any field on that
> entity has ever changed after creation. If none has, the sync path, the write
> path and the client model have almost certainly never been tested for it —
> and none of them will say so.
