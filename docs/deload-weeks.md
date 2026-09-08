# Deload weeks: how to calculate one, show one, and decide who gets to set one

A design walkthrough for adding deload weeks to ForgeForm, written to be read on
its own. It covers where a "week" actually comes from in this codebase, what the
training-science literature says a deload is (and what it says the app must not
claim), why the obvious storage choice is the wrong one, the three places the
plumbing is already broken in ways that would silently swallow the feature, and
the authority rule that makes "the user sets it, unless their trainer does" fall
out of data we already have instead of a new permission system.

No code has been written yet. This is the plan and the reasoning behind it.

Line references are to the commit that introduces this document.

---

## 1. What the feature has to answer

A deload is a planned week of reduced training stress inside a programme, so
accumulated fatigue can clear without the trainee stopping. Four questions have
to be answerable, and they are more separable than they look:

1. **Which week of the programme is today?** — arithmetic.
2. **Is that week a deload?** — a stored declaration.
3. **Who is allowed to make that declaration?** — authority.
4. **Who is allowed to see it?** — entitlement.

Almost every mistake available here comes from collapsing two of the first
three. The most tempting collapse is answering (2) by writing a flag onto every
session in the week, which quietly makes (1) and (2) the same thing and then
makes (3) impossible to enforce. §4a is about why not.

The fourth question is new to this feature relative to the rest of the workout
domain — plans, workouts and sessions are not entitlement-gated at the row
level, and deload weeks are (§7). That asymmetry is the source of the one rule
in this document most likely to be got wrong: **an absent field means "not
provided", never "clear it".**

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
  deload set; see §13.)

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
completed sessions (§9) and to answer trainer-facing reads.

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

## 3. What the evidence actually says

The first draft of this design invented its numbers — "every 4 weeks", "60% of
normal load" — and got the main lever backwards. The literature is worth reading
before building this, because it disagrees with the intuitive design in one
specific and load-bearing way.

### 3a. The parameters

| Variable | Finding | Source |
|---|---|---|
| Duration | 6.4 ± 1.7 days — one week | Bell et al. 2024 survey (n = 246 competitive strength/physique athletes) |
| Cadence | every 5.6 ± 2.3 weeks; pre-planned every 4–8 weeks | Bell et al. 2024; Bell et al. 2025 |
| Volume | **the primary lever.** −25–45% (low recovery need), −40–60% (moderate), −60–90% (high), via fewer reps per set, fewer sets, or both | Bell et al. 2025 |
| Load | reduced, but *secondary* to volume | Bell et al. 2024 |
| Effort | reduced by **increasing reps-in-reserve** | Bell et al. 2024 |
| Frequency | **unchanged** | Bell et al. 2024; Bosquet et al. 2007 |
| Exercise selection | generally unchanged | Bell et al. 2024 |
| Trigger | pre-planned, often combined with autoregulation: stalled performance, elevated soreness, joint aches | Bell et al. 2024; Rogerson et al. 2023 (coach interviews) |
| Training age | novices accumulate fatigue more slowly, so tolerate longer blocks | practitioner consensus; weakly evidenced, and must be labelled as such wherever the app repeats it |

Sources: Bell et al., *Deloading Practices in Strength and Physique Sports: A
Cross-sectional Survey*, Sports Medicine – Open (2024); Bell et al., *A
Practical Approach to Deloading*, Strength & Conditioning Journal (2025);
Rogerson et al., *"You can't shoot another bullet until you've reloaded the
gun"*, Frontiers in Sports and Active Living (2023); Bosquet et al., *Effects of
Tapering on Performance: a Meta-Analysis*, MSSE (2007).

**Volume first, frequency held.** That is the finding that changes the design.
The intuitive implementation — "make the weights lighter this week" — is the
*secondary* lever, and cutting sessions out of the week is not a lever at all:
every source holds training frequency constant. §8 is rewritten around it.

### 3b. What the evidence does *not* say

Direct trials are few and they do not show a benefit.

- **Coleman et al. 2024** (*PeerJ*; 39 resistance-trained men and women, 9-week
  programme): a midpoint deload week produced **worse** lower-body strength than
  continuous training, with no difference in hypertrophy, power or local
  endurance, and no psychological benefit on a readiness-to-train questionnaire.
  The important caveat: that study's "deload" was one week of **complete
  cessation**, so it is evidence about a rest week, not about a reduced-volume
  one.
- **Scientific Reports 2026** (19 untrained men, within-subject, 8 weeks; deload
  = one session of 2 sets replacing two sessions of 6–8): **no difference** in
  muscle thickness or 10RM strength-endurance either way.

The best-evidenced adjacent result is the taper literature. Bosquet et al.'s
meta-analysis found volume reduced 41–60% with **intensity and frequency
maintained** produced ~2.2% performance improvement — in endurance athletes, so
it is a mechanistic analogue rather than direct evidence, and it is the
strongest support there is for "cut volume, hold frequency".

The honest reading is that over 8–9 week horizons a deload neither clearly helps
nor clearly hurts. The case for it is long-horizon fatigue, joint health and
adherence — exactly the things a two-month trial cannot measure. That is a real
case, and it is not the case a marketing screen wants to make. Hence:

> A deload is fatigue management, not an optimisation. Nothing this feature says
> — in the app, in a notification, or on the paywall — may imply that taking a
> deload produces better results than not taking one. The evidence does not
> support it, and a fitness app that overclaims is indistinguishable from every
> other fitness app.

That rule binds the copy in §7, §8 and §10, and it is the reason the paywall
bullet added for this feature names a capability ("plan recovery weeks into your
programme") rather than an outcome.

### 3c. What the numbers become in the product

- **Default cadence: every 5 weeks.** Closest single value to the survey's
  5.6 ± 2.3. Offer 4, 5, 6.
- **Duration: one week, always.** 6.4 ± 1.7 days is a week, which is why the
  whole model in §4 is week-shaped and there is no "deload for N days".
- **Volume reduction: set per deload, not fixed.** Whoever owns the plan
  dictates it — a trainer prescribing 40% for a beaten-up client and 70% for a
  fresh one is the normal case, not an edge case, and a single global constant
  cannot express it. Stored as `volumePercent`: the share of normal volume to
  **perform**, so 50 means "do half your sets", a 50% reduction. Default 50
  (the middle of the moderate band). The evidence bands become, in retained
  terms: 55–75% (low recovery need), 40–60% (moderate), 10–40% (high).
- **Range 10–90, and the ends are excluded deliberately.** 100% retained is not
  a deload, and 0% is total cessation — which is a *different intervention*
  with its own evidence (§3b: the one trial that studied cessation found it
  slightly worse than training through). The app should not let a slider
  quietly turn a deload into the thing the research says didn't work.
- **Frequency: untouched.** A deload week keeps every session and every rest day
  the cycle pattern laid out. This costs nothing to honour, because the sessions
  already exist — but it does mean "deload" must never be implemented as
  auto-skipping sessions, which is the obvious shortcut.

---

## 4. Where the declaration lives

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
`docs/trainer-console-duplicate-rows.md` is entirely about what happens when a
write path's idempotency is assumed rather than built.

**Each entry carries its own volume**, because §3c makes that the prescription
rather than a constant:

```json
[{"week": 5, "volumePercent": 50}, {"week": 10, "volumePercent": 40}]
```

Sorted by `week`, one entry per week, `[]` for none. `volumePercent` is the
share of normal volume to **perform** — not the reduction. That distinction is
worth a name and a doc comment on every declaration of it, because "50% deload"
is used in the wild to mean both, and the two readings differ by the entire
point of the feature.

Nothing has shipped with the bare-integer form this document originally
proposed (`[5, 10]`), so there is no legacy payload to parse and no compat shim
to write — the object form is simply the shape, from the first migration.

### 4a. What was rejected, and what it would have cost

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
- Authority becomes unenforceable. §6's rule is "whoever owns the plan owns the
  deload". Spread across N session rows, that check has to be repeated N times
  on every write path that touches a session — and §7's entitlement check with
  it.

**A `deloadEveryNWeeks` rule instead of an explicit set.** Tempting, because
"every 5th week" is how most programmes are written. Rejected: changing `N`
retroactively rewrites which past weeks were deloads, and a single-week override
then needs *both* a rule and an exception list — two sources of truth for one
answer.

**One-off or a repeating cadence is the user's choice, and both are
first-class.** Some people want a single week marked because this athlete is
beaten up *now*; others run 3-on-1-off and want the whole block laid out at
once. Neither is the "real" way to use the feature, so the UI offers both and
picks neither by default:

- **Just this week** — one tap on a week, and nothing else in the plan changes.
- **Repeat every N weeks** — expands the cadence across the plan in one action.

The one rule that constrains the choice: a one-off tap must never silently opt
someone into a cadence, and applying a cadence must never silently overwrite
weeks already set by hand. Choosing is the user's; inferring is not the app's.

The generator **expands** to explicit entries at save time and stores the
expansion — the cadence is an authoring action, the resulting set is the truth,
which is why changing your mind about N later cannot retroactively rewrite
weeks already trained (the rejected `deloadEveryNWeeks` rule above). Applying it
into a set that already holds entries **merges**: an existing week keeps the
volume it was given, and the generator only fills weeks that had none. Three
details it needs:

- Offer N ∈ {4, 5, 6} and default to **5** (§3c). Generated entries take the
  default `volumePercent`; the user can then retune any individual week.
- It is opt-in and reversible in one action. A generator that cannot be undone
  in one tap is a generator people are right to distrust.
- `generate(N, durationWeeks) = [N, 2N, 3N, …]` filtered to `< durationWeeks`,
  **strictly**. A block that ends on its easiest week is a bug, not a taper.
  Without that filter "every 4 weeks" on a 12-week plan yields `[4, 8, 12]` and
  week 12 is the plan's last.
- Plan durations are a fixed set: `create_view.dart:701` offers 4, 8 and 12
  weeks free, 26 and 52 premium, defaulting to 12. A 4-week plan therefore
  generates nothing, and the generator must *say so* rather than silently
  producing `[]`. Manual toggles still work on it.

**A separate `WorkoutPlanDeloadWeek` table.** Correct in the abstract, and
against YAGNI here: the set is bounded at 52 entries by `DurationWeeks`'s own
range, it is always read whole with its plan, and it is always written whole.
A table buys nothing and costs a join, a repository, a sync path and a
migration.

**A single `isCurrentWeekDeload` boolean on the plan.** Rejected outright: it
cannot answer "was last week a deload", it silently becomes wrong the moment the
week rolls over, and nothing in the system would ever clear it.

---

## 5. Three things already broken that would swallow this feature

These are pre-existing, none of them are visible to the compiler or to the
current test suite, and each one would make the feature appear to work in
development and fail in the hands of a real pair of users.

### 5a. `_pullWorkoutPlans` never updates a plan it already has

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

One extra rule the reconcile needs because of §7, and only because of §7:

> An absent `deloadWeeks` in a plan payload means "not provided", never "clear
> it". The field is omitted when the reader isn't entitled to see it, so a
> reconcile that treats absence as `[]` will wipe a user's deload weeks the
> first time they sync after a subscription lapses — and re-subscribing will not
> bring them back.

### 5b. The trainee's plan push is a full-document PUT

`_syncUpdatePlan` sends `name`, `description`, `startDate`, `cyclePatternJson`,
`isFreeChoice`, `durationDays` as one document to `PUT api/WorkoutPlan/{id}`,
and `WorkoutPlanRepository.UpdatePlanAsync` applies it. Add `deloadWeeksJson`
to that document and a trainee's device that hasn't pulled the trainer's change
yet will push a stale `[]` over it — last writer wins, and the loser is the
trainer.

**So don't put it in the document.** `deloadWeeksJson` is not a plan-document
field; it has its own endpoint (§6), exactly as nutrient pins do. That is one
write path, not two, and the bulk PUT can never clobber a deload set because it
never carries one. The alternative — carrying the field and having the server
selectively ignore it — leaves a payload whose meaning depends on who is sending
it, and a client that cannot tell whether its write took effect.

The same reasoning applies to the entitlement gate. Refusing the whole plan PUT
because one field wasn't allowed would stall every unrelated plan edit behind
it; a separate endpoint refuses precisely the thing that wasn't allowed, and
says why (§7).

### 5c. The Flutter client cannot tell a trainer-assigned plan from its own

`WorkoutPlanResponseDto.AssignedByTrainer` and
`WorkoutResponseDto.AssignedByTrainer` both exist and are both populated
server-side. Grep the Flutter app for `assignedByTrainer` and there are **zero**
hits. The field crosses the wire and is thrown away; `WorkoutPlanTable` has no
column for it.

So the trainee app currently has no way to know whether it should offer the
deload toggle. Carrying it needs a `boolean assignedByTrainer` column on
`WorkoutPlanTable`, read in `_pullWorkoutPlans` from a field already in the
payload.

Under §7 this stops being merely a prerequisite for the toggle and becomes a
prerequisite for the **gate**: the entitlement rule turns on whether a plan is
the trainee's own or their trainer's, so without this column a free user's own
deload weeks and their trainer's are indistinguishable and the gate cannot be
implemented at all.

### 5d. `saveWorkoutPlan` silently drops most of the plan

Found while implementing, and the worst of the four.
`workout_plan_dao.dart:64-78` writes a `WorkoutPlanTableCompanion` with exactly
five columns — `id`, `name`, `description`, `startDate`, `isActive` — and
inserts it with `InsertMode.insertOrReplace`.

`insertOrReplace` on an existing primary key is a **delete and re-insert**, not
an update. Every column absent from the companion goes back to its default. So
any call to `saveWorkoutPlan` on a plan that already exists silently discards
`cyclePatternJson`, `isFreeChoice`, `durationDays`, `serverId` and `syncStatus`
— today, before deload weeks exist. A plan round-tripped through this method
loses its cycle, its duration, and its link to the server copy.

This is pre-existing and out of scope to fix properly here, but it dictates one
rule for this feature:

> Deload weeks are never written through `saveWorkoutPlan`. The toggle issues a
> targeted `update(workoutPlanTable)` against the one column, the way
> `_toggleFreeChoice` (`edit_view.dart:388-440`) already does for its own.

Worth noting *why* nothing has caught this: the plan screen only ever calls
`saveWorkoutPlan` for a **new** plan, where insert and replace are the same
thing. The bug is latent, waiting for the first caller that saves an edit.

---

## 6. Who may set it — authority falls out of plan ownership

The requirement is "the user sets their own deload if they have no trainer; the
trainer sets it for their clients". Resist turning that into a permission
concept. It already exists in the schema:

> **The deload declaration is owned by whoever owns the plan.**
> `WorkoutPlan.AssignedByTrainerId == null` → the trainee sets it.
> `AssignedByTrainerId == <trainer>` → that trainer sets it, and only that trainer.

This is the same field that already decides who may delete a plan
(`PlanDeleteResult.AssignedByTrainer`), so it needs no new invariant. It also
gets the awkward cases right for free:

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

Note this is a *narrower* question than the one nutrient pins ask.
`SetMyNutrientPinsStatus.HasActiveTrainer` refuses any linked client, on the
grounds that a coached client's pins are their coach's. Deloads key on the plan
instead, because a client can legitimately have a trainer *and* be running a
programme they wrote themselves — and on that programme the deloads are theirs.

### 6a. The two endpoints

Both replace the whole set; neither adds or removes individual weeks.

- **`PUT api/WorkoutPlan/{planId}/deload-weeks`** — the trainee's own write,
  mirroring `PUT api/TrainerClient/my-nutrient-pins`. Returns
  `SetMyDeloadWeeksResult { Status, DeloadWeeks }` with

  ```csharp
  enum SetMyDeloadWeeksStatus { Ok, PlanNotFound, AssignedByTrainer, NotEntitled, InvalidWeek }
  ```

  `AssignedByTrainer` and `NotEntitled` are deliberately distinct, for the reason
  `SetMyNutrientPinsStatus` already records: "your coach manages this" and "you
  need Premium" point the user at two completely different next steps, and
  collapsing them into one refusal makes the app unable to say which.
  `InvalidWeek` covers a week number outside `1..durationWeeks`.

- **`PUT api/TrainerConsole/{clientId}/workout-plans/{planId}/deload-weeks`** —
  the trainer's write, mirroring `PUT api/TrainerConsole/{clientId}/nutrient-pins`.
  Refuses unless the caller is an active trainer of the client **and**
  `AssignedByTrainerId == callerId`. Opts into `RequireEntitledLicenceFilter`
  like every other mutating console endpoint, so the trainer's own licence is
  the entitlement gate on that side and no new check is invented.

Two regression tests, in the spirit of `TrainerProvisioningTests`: a trainee's
PUT cannot change the deload set on a trainer-assigned plan; a trainer who did
not assign the plan cannot change it either.

---

## 7. What premium unlocks, and what it must never take away

Deload weeks are a premium feature. `PremiumFeatures` already lists plan
structure as the premium column — free choice mode, extended plan durations —
and periodisation belongs with them.

**Setting is premium. A trainer-set deload is always visible.** Three reader
states, decided by two facts: whether the plan is trainer-assigned (§5c), and
`AccessProvider.hasPremiumAccess`.

| Plan | Entitled | Behaviour |
|---|---|---|
| Trainer-assigned | either | Deload weeks **always shown**, read-only, with "Your trainer sets the deload weeks for this plan" |
| Own plan | yes | Full week strip: toggle any week, plus the "every N weeks" generator |
| Own plan | no | Strip locked — lock chip, tap opens the paywall; self-set deload weeks are not rendered |

There is no fourth case. A plan is either trainer-assigned or it isn't, and a
user is either entitled or isn't.

The middle row is the one that matters most and the one a naive gate gets wrong.
A client whose trainer's licence lapses loses derived Pro
(`AccessProvider.hasPremiumAccess` is `_isPremium || _proFromLicence`), and if
the gate were "premium or nothing" they would stop seeing the deload weeks their
own programme still contains. That is not a locked control, it is information
loss from a programme they are actively training against — and
`docs/trainer-licensing.md` is explicit that lapsing means read-only, never
deletion.

### 7a. Absent, not hidden — and absent means unchanged

`docs/trainer-console-micronutrients.md`'s rule applies unchanged: when a value
is locked it is **absent from the payload**, not merely hidden by the client.
This feature adds one corollary, because unlike micronutrients the deload set is
also stored locally on an offline-first device:

> The server keeps storing the deload set while it is locked, and omits it from
> the read payload. An omitted field means "not provided", never "clear it". A
> lapse must not delete a programme's deload weeks, and re-subscribing must find
> them intact.

That is the rule §5a's reconcile has to implement. Get it wrong and the failure
is silent, permanent, and only reachable by a user who cancelled — which is to
say, by nobody who is going to file a bug.

Because the client caches the plan locally, the client also has to gate
*rendering* on `hasPremiumAccess` — a device that was premium yesterday still
holds the values. Both halves are needed and each has its own job, which is the
same split `docs/revenuecat-self-managed-pins.md` records for the nutrient
picker:

> the client decides what to *show*, `PUT api/TrainerClient/my-nutrient-pins`
> decides what's *allowed*.

### 7b. Which entitlement the server checks

This is the one judgement call in the design rather than a derivation, so it is
recorded as such.

`docs/revenuecat-self-managed-pins.md` argues — correctly — against merging
`IRevenueCatService.IsEntitledAsync` (a user's own app-store purchase) and
`ITrainerClientService.DerivesProAsync` (licence-derived Pro) into a single
"is premium" helper, because every gate already built on `DerivesProAsync` would
silently start accepting RevenueCat entitlement too.

But the client's `hasPremiumAccess` ORs both (`access_provider.dart:139`). Check
only RevenueCat server-side and a derived-Pro user sees an unlocked strip and
gets a refusal when they use it — the client/server disagreement the
micronutrients doc calls "the defect" ("Neither side was wrong on its own — the
disagreement was the defect").

**So call both, explicitly, at this one call site, and introduce no shared
helper.** That honours the actual concern in the RevenueCat doc — no
platform-wide widening — without shipping a gate the UI disagrees with. The
comment at the call site should say that client parity is the reason, so the
next person doesn't "simplify" it back to one call.

### 7c. Where it appears in the offer

- `PremiumFeatures` — under *Planning & Scheduling*, and in the free/premium
  split table.
- The paywall's `_features()` list (`paywall_screen.dart:291`), via a new
  `paywallFeatureDeloads` key in both ARBs.

The copy names a capability, not a result, per §3b: *"Deload weeks — plan
recovery weeks into your programme"*. It sits next to `paywallFeatureFreeChoice`
and `paywallFeatureLongPlans`, which are the other plan-structure bullets.

---

## 8. What a deload actually does to the prescription

Look at what a prescription contains before deciding. `WorkoutSetTemplate` has
`SetNumber`, `TargetReps` (a string, so `"8-12"` is legal) and `OrderPosition`.
**There is no prescribed weight anywhere in the schema.** Load is something the
trainee logs, not something the plan states.

That is convenient, because §3a says load is the *secondary* lever anyway. The
primary lever is volume, and volume is exactly what the schema does describe:
a count of set-template rows per exercise.

**Rewriting the set templates for the week** — deleting rows, widening the rep
range. Rejected. `WorkoutSetTemplate` rows belong to the `WorkoutExercise`, not
to a date, so a week-scoped rewrite would have to mutate the template and put it
back afterwards. `docs/trainer-session-review.md` describes what happens when
prescriptions are mutated on a schedule ("prescriptions that grew every time you
saved"), and a deload that permanently deletes a working set from someone's
programme because the restore didn't run is a bad trade for a feature whose
whole point is to be temporary.

**Marking the surplus sets optional at render time** — recommended, with a
correction to how it renders. The first draft of this section assumed the active
workout screen shows a *list* of set rows to dim. It does not:
`active_workout_view.dart:1415` (`_buildSetFocusedView`) shows **one set at a
time**, indexed by `_currentSetIndex` out of `exerciseData.templates`. There is
no column of rows to grey out.

So the effect is expressed on the one set in front of the user, plus the
progress line that already says where they are:

```
   Set 4 of 5                       ← existing progress text
   ┌───────────────────────────┐
   │  4    Optional — deload    │   ← the set circle, plus the marker
   │       week (50% volume)    │
   └───────────────────────────┘
   Previous   100 kg × 8            ← existing hint, unchanged
```

The kept-set count is `max(1, (templates.length * volumePercent / 100).round())`
— from *this deload's own* `volumePercent` (§4), not a constant. Sets at index
`>= keptCount` carry the marker. The `max(1, …)` matters: at 10% volume on a
two-set exercise the arithmetic rounds to zero, and an exercise where every set
is optional is an exercise the UI has quietly told you to skip — which is
cessation again (§3c), reached by rounding rather than by choice.

Derived at build time from `weekNumberFor(today)` — nothing is written, nothing
needs restoring, and a trainee who logs all five sets has simply logged all five.
The set stays fully loggable: this is guidance, not enforcement, and marking a
set optional while still accepting the log is the honest version of both.

**Frequency is untouched.** The deload week keeps every scheduled session and
every rest day exactly as the cycle pattern laid them out (§3c). Auto-skipping
sessions is the obvious shortcut and it is the one thing every source in §3a
agrees you should not do.

**Effort guidance goes in the session header, not per set** — one line, "Reduced
volume this week — stay 3–4 reps short", covering the RIR half of the
prescription. Per-set repetition of it is noise.

**No derived load number.** The first draft proposed rendering "~65 kg × 8"
beside the existing previous-session hint at `active_workout_view.dart:1518`.
Dropped: load is the weaker-evidenced lever, and a specific kilo figure claims a
precision that a survey range of "reduced, secondarily" does not support. If a
trainer wants to prescribe a load for a deload week, that is a conversation in
chat, which they already have.

One detail that survives from the first draft and matters more now: **the
previous-session lookup must skip deload sessions** when finding "last time"
(`active_workout_view.dart:387–521`), or the week after a deload anchors its
hints to the deload's reduced work. Under optional-set marking this is worse
than it was under a load hint, because a deload session may hold half as many
logged sets — so the comparison is missing rows, not merely light.

---

## 9. History needs a stamp, not a re-derivation

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
- The client's subscription lapses. Under §7 the plan's deload set stops being
  readable — and a past session's badge would vanish with it, rewriting history
  as a side effect of billing.

**Recommendation: `ScheduledWorkout.WasDeload` (`bool?`), stamped at
completion.** Null everywhere else. Readers use the stamp when it is non-null
and derive from the plan when it is null — which is exactly right, because null
means "not performed yet", and for a future session the plan *is* the current
truth. The stamp is a record of what the trainee did, so it is readable
regardless of entitlement; §7 gates the *declaration*, not the history.

Stamp it at completion rather than at generation, because generating the sessions
happens weeks or months before anyone decides where the deloads go. The edge
case this leaves is honest and should be left alone: mark the current week as a
deload on Thursday, and Monday's already-completed session stays un-stamped. It
was not performed as a deload. Saying it was would be a lie the trainer would
then read on Session Review.

---

## 10. Showing it

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
| `active_workout_view.dart` header (between :1081 and :1083) | Chip + the effort line ("Reduced volume this week — stay 3–4 reps short") |
| The current set (`_buildSetFocusedView`, :1415) | Sets past the kept count marked optional for this week (§8) — one set at a time, not a dimmed list |
| Plan screen | The week strip, same widget and same volume control as the trainer's — see below |

**Trainer surfaces**

| Where | What |
|---|---|
| Workout Builder plan section | The week strip, `1..durationWeeks`. Tap toggles one week on/off; a long-press or the week's own row opens the volume control for that week |
| Client Detail | "This week is a deload" chip in the header |
| Session Review | Chip on past sessions, from `WasDeload` (§9) |
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
 1   2   3   4   5●  6   7   8   9   10●  11  12
                 │                       │
                 └ deload · 50% volume    └ deload · 40% volume
```

Tapping a week marks it. Two things are then the user's to choose, and the
strip has to make both reachable without making either the default:

- **How much volume**, per week — a stepper or a short row of presets keyed to
  the §3a bands, defaulting to 50% and adjustable week by week, so a trainer
  can prescribe 40% in one block and 70% in another. Reached from the marked
  week itself (its row, or a long-press), so the common one-tap path never has
  to walk through it.
- **One week or a cadence** — "just this week" is the tap; "repeat every N
  weeks" is an equally visible action beside the strip that expands into
  explicit entries (§4a), so the user immediately sees what it did and can
  retune or clear any individual week afterwards. Neither is pre-selected. Its copy carries the evidence rather than a bare number: *"Most
lifters deload every 4–6 weeks. Newer lifters can usually go longer."* Weeks
before the current one are shown but not editable — editing the past is the
retroactive-rewrite problem from §9 wearing a friendlier hat.

**The locked state** reuses the pattern already in `create_view.dart:722–742`
for the premium plan durations — a lock icon on the chip, `openPaywall(context)`
on tap — rather than the `PremiumGate` overlay widget, which dims and covers a
whole card and is the wrong shape for a row of chips.

**Free-choice plans have no `durationDays`**, so the strip has no end and the
generator has nothing to bound. For `isFreeChoice`, offer "mark this week" and
"mark next week" only, not an unbounded strip.

**States.** Every data-bound surface needs the four (CLAUDE.md). The week strip
has no meaningful loading state of its own if the plan is already loaded, but
"no active plan" is a real empty state and must say so ("Deloads are set per
plan — create one first"), not render an empty strip. And on the trainee's side,
a trainer-assigned plan renders the strip **read-only with an explanation** —
"Your trainer sets the deload weeks for this plan" — rather than hiding it.
Hiding a control makes a user think the feature doesn't exist; disabling it with
a reason tells them where to ask. The same applies to the locked state: it says
what it is, it does not pretend to be absent.

---

## 11. Telling the client their trainer set a deload

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

Either way, the badge itself arrives with the next sync, and after §5a is fixed
that is a real guarantee rather than a hope.

---

## 12. Things that will be got wrong

A checklist for review, and for the tests:

- [ ] Week arithmetic on **days**, not instants (§2a). Test a DST boundary.
- [ ] `weekNumberFor` is one-based and returns null outside the plan.
- [ ] Clock read once per render pass.
- [ ] Both language implementations pinned by the same case table (§2b).
- [ ] `_pullWorkoutPlans` reconciles a clean plan's columns (§5a) — without
      which nothing else in this feature works between two people.
- [ ] Reconcile is guarded on `syncStatus == synced` so it can't eat an offline
      edit (`docs/sync-account-switch-duplication.md`).
- [ ] **An absent `deloadWeeks` is "unchanged", never "clear"** (§5a, §7a). The
      test is: entitled user sets weeks, entitlement lapses, sync runs, the
      server's copy is intact and re-entitlement shows it again.
- [ ] `deloadWeeksJson` is **not** in the plan-document PUT (§5b).
- [ ] `assignedByTrainer` is carried into the local plan table (§5c) — the gate
      as well as the toggle depends on it.
- [ ] The server checks both entitlement sources at the one call site, and no
      shared "is premium" helper is introduced (§7b).
- [ ] Trainer-set deload weeks render for a non-entitled client (§7). This is
      the row a naive gate gets wrong.
- [ ] Deload writes replace the whole set; never add/remove (§4).
- [ ] "Every N weeks" expands at save time; the rule is not stored (§4a).
- [ ] The generator filters the final week strictly, and says something rather
      than returning `[]` on a 4-week plan (§4a).
- [ ] A deload week keeps every scheduled session — nothing auto-skips (§3c, §8).
- [ ] The previous-session lookup skips deload sessions (§8).
- [ ] Past sessions read `WasDeload`, never re-derive, and stay readable when
      entitlement lapses (§9).
- [ ] `DeloadChip` is not `StatusBadge`; contrast pair added to
      `test/core/contrast_test.dart` (§10).
- [ ] Locked and trainer-assigned states are *explained*, not hidden (§10).
- [ ] No string anywhere claims a deload improves results (§3b).
- [ ] A free-choice plan resolves a week number (it has a `startDate`) but gets
      the two-button control, not the strip (§10).

---

## 13. Suggested phasing

**Phase 0 — the plumbing, shippable on its own.** Fix `_pullWorkoutPlans` to
reconcile a clean plan's columns; carry `assignedByTrainer` into
`WorkoutPlanTable`. Both are bug fixes with value independent of deloads, and
both are prerequisites. Landing them separately means the deload PR is about
deloads.

**Phase 1 — trainee-owned deloads, gated.** `deloadWeeksJson` on both schemas,
the `PlanWeek`/`PlanWeeks` helpers with their shared case table,
`PUT api/WorkoutPlan/{planId}/deload-weeks` with its status enum and both
entitlement checks, the week strip on the trainee's plan screen with its locked
state, `DeloadChip` and optional-set marking on the schedule and active-workout
screens, and the paywall bullet. No trainer involvement, no stamp — everything
derives from the plan, which is correct while nothing but the current programme
is being shown.

**Phase 2 — trainer-set deloads.** The console endpoint and its two authority
tests, the week strip in the Workout Builder, the read-only strip with its
explanation on the trainee side, and the always-visible rule from §7 — which is
only testable once a trainer can set one. The optional chat message on save.

**Phase 3 — history.** `ScheduledWorkout.WasDeload`, stamped at completion; the
chip on Session Review and on the trainee's own history. Worth splitting out
because it is the only part that touches the completion path, and the completion
path is where logged sets live.

**Phase 4 — recovery-need tiers, if asked for.** The three bands from §3a as a
per-week choice, widening `deloadWeeksJson` behind a parser that accepts both
shapes (§4). Not speculative work now; recorded so the shape is known.

**Phase 5 — deload suggestion.** A recommendation, never an application.

What this schema can actually see: `WorkoutSetTable.rpe` (nullable, 6–10) gives
RPE drift at matched load — "the same weight felt harder" — which is the single
best signal available and the one the coach interviews describe most often.
`isCompleted`/`isSkipped` on `ScheduledWorkoutTable` gives adherence. Logged
weight gives a stalled top set. `setType` excludes warmups from any volume fold.

What it cannot see, and which is most of what coaches actually cite: soreness,
sleep, joint aches, motivation. The app collects none of them. Say that plainly
rather than pretending the available signals are the right ones — a suggestion
built on RPE drift alone is a suggestion built on the one signal that happens to
be in the database, and the literature's own advice is to look for several
indicators converging rather than to trust one.

Output is a suggestion chip on the week strip that the user or trainer taps to
accept. It never writes `deloadWeeksJson` on its own. An app that silently
decides someone's week is now a deload is worse than one that never mentions it.

---

## 14. The Trainer Console side, and the two things it changed

Sections 1–13 were written before any of this existed. Building the console
half changed two of the decisions they record, which is worth setting down
next to the originals rather than quietly editing them.

### 14a. A bypass flag is not an authority check

`SetDeloadWeeksAsync` was built with a `bool actingAsTrainer` that skipped the
ownership and entitlement checks wholesale. That is the shape
`DeleteClientWorkoutPlanAsync` already uses one layer up: check
`IsActiveTrainerOfAsync`, then pass the bypass.

It is the wrong shape, and the reason is not stylistic. A flag says *trust me*.
Nothing downstream can tell whether the caller had the right to set it, so the
only thing standing between any active trainer and any of their client's plans
is the caller remembering to check first. Add a second call site later — a bulk
action, a template apply, an admin path — and the check is one forgotten line
away from being absent, with nothing to notice.

The fix is to pass the trainer's **identity** rather than their claim:

```csharp
Task<SetDeloadWeeksResult> SetDeloadWeeksAsync(
    Guid planId, Guid userId, IEnumerable<DeloadWeek> weeks, Guid? actingTrainerId = null);
```

and check it where the plan is already loaded:

```csharp
if (actingTrainerId != null)
{
    return plan.AssignedByTrainerId == actingTrainerId
        ? await ApplyDeloadWeeksAsync(plan, planId, userId, weeks)
        : new SetDeloadWeeksResult { Status = SetDeloadWeeksStatus.NotPermitted };
}
```

This is not a theoretical improvement. It is what makes §6's ownership table
true. A client who has a coach but is running a programme they wrote for
themselves owns its deloads — and under the bypass, their trainer could have
rewritten them, because `AssignedByTrainerId` was never consulted on that path.
Delete still behaves the looser way; deloads deliberately do not, and a test
names the divergence so the next person doesn't "fix" the inconsistency in the
wrong direction.

> An authority parameter should carry an identity that can be verified, not a
> boolean that can only be trusted. If the callee cannot check the claim, the
> check does not exist — it has merely moved somewhere nobody is looking.

### 14b. A widget that reads a provider has decided which question it answers

`DeloadWeekStrip` read `AccessProvider.hasPremiumAccess` internally to decide
whether to show its lock. That was correct on the trainee's plan screen and
made the widget unusable on the console, because the two surfaces are gated on
entirely different questions:

| Surface | The gate | On a locked tap |
| --- | --- | --- |
| Trainee plan screen | *Their own* Premium (`hasPremiumAccess`) | Open the paywall |
| Trainer Console builder | The *trainer's licence*, server-side (`RequireEntitledLicenceFilter`, 402) | Nothing — the server refuses |

A trainer is not short of Premium; a lapsed trainer is short of a licence, which
the client can't see and shouldn't. Reading the provider inside the widget baked
the trainee's question into a component whose whole value was being shared.

So the gate is lifted out — `locked` and `onLockedTap` are parameters. The
trainee screen passes its premium state and `openPaywall`; the console passes
neither and lets the endpoint refuse. The widget got simpler by learning less.

> A shared widget must not read the ambient state that decides *whether* it may
> be used. Take the answer as a parameter: the second caller is where you find
> out that the question was never as universal as it looked.

### 14c. What the console needed that was already there

Worth recording because it is the pleasant kind of surprise.
`ClientWorkoutSummaryDto.CurrentPlan` is a `WorkoutPlanResponseDto` — the same
type the trainee's own reads return — so adding `DeloadWeeks` to that DTO in
Phase 1 had *already* delivered deload weeks, the plan's duration, its start
date and `AssignedByTrainer` to every console read. No DTO change, no new query,
no new round trip. The console work was an endpoint, a provider method and three
render sites.

That is what putting a field on the shared response type buys, versus minting a
console-specific summary DTO that would have had to be widened separately.

### 14d. The stamp, and why the server writes it

The Session Review chip is the reason `ScheduledWorkout.WasDeload` exists now
rather than in a later phase: §9 forbids deriving a past session's deload state
from the current plan, so the chip could not be built without the stamp.

It is written **server-side, on the transition into completed, once**. Each
clause is load-bearing:

- *Server-side*, because everything needed is already there — the session's
  date, its plan's start date and deload set — and a stamp written by the device
  would simply be missing from anything an older build saved. History that
  disagrees with itself depending on which client version logged it is worse
  than history that is uniformly absent.
- *On the transition*, because generating sessions happens months before anyone
  decides where the deloads go.
- *Once*, because re-saving a completed session must never restamp it. A trainer
  clearing the deload set afterwards must not relabel training the client has
  already done.

And `false` is not `null`. False means "settled, and it was a normal week";
null means "nobody has settled this". That is why the drift column is nullable
with no default: `NOT NULL DEFAULT 0` would have asserted that every session
predating the column was performed in a normal week — a claim nothing checked,
and one the server would then contradict for any of them that weren't.

---

## 15. The general lesson

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

There is a second lesson, cheaper to state and easier to skip. The first draft
of this document was written from the codebase alone, and it got the domain
backwards: it proposed reducing *load* as the primary effect of a deload, when
every source says volume is the lever and frequency is held constant. Nothing in
the repository could have told me that. The schema is equally happy to express
either, the compiler has no opinion, and a reviewer who trains would have caught
it in a sentence.

> A design that is internally consistent can still be wrong about the world it
> models. For a feature that encodes domain practice — training, nutrition,
> medicine, finance — read the domain before designing the schema, not after.
> The codebase can only tell you what is *representable*, never what is *right*.
