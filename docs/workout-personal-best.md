# Personal bests on the active workout screen: two numbers that must never merge

Adds a personal-best (PB) display to `ActiveWorkoutScreen`
(`lib/feature/gym_tracking/presentation/view/workouts/active_workout_view.dart`).
There are two PBs, deliberately kept apart, and the interesting part of this
change is why collapsing them into one would have been wrong rather than
merely less useful.

Line references are to the commit that introduces this document.

---

## 1. Two things both called "personal best," computed from different data

The request was: show a PB "right next to the last weight and reps," and a
separate, overall PB next to the exercise name. Those turn out to be two
different queries over two different data sources, not one number shown
twice:

- **All-time PB** (`_loadAllTimeBestSet`, active_workout_view.dart:544) — the
  heaviest completed set ever logged for this *exercise*, across every
  workout it has ever appeared in, read from the database. It only knows
  about sets that were already saved before this screen opened.
- **This-workout PB** (`_currentWorkoutBestSet`, active_workout_view.dart:582)
  — the heaviest set typed into this *workout session* for this exercise so
  far, read live from the in-memory `TextEditingController`s. It knows
  nothing the database doesn't, except the one thing that matters: what the
  user just typed and hasn't saved yet.

Nothing in the type system forces these apart. Both are `PersonalBestSet?`
(a `({double weight, int reps})` record — active_workout_view.dart:17), and a
version of this feature that read both from `WorkoutSetTable` would compile
and pass a cursory smoke test, because during normal use they *usually*
agree: the session's best set is often also the lifetime best, so a screen
that quietly showed the same value under both labels would look correct
until the day a user beat an old PB.

That day is exactly when it matters. The person who just outlifted their own
history is the one who most wants to see "this workout: 105 kg" next to
"all-time: 100 kg" and know the number on the left just took the number on
the right. Backing both off the same query erases the moment the feature
exists to surface.

## 2. Why the in-session PB can't be a database query

`_saveCurrentExercise` (active_workout_view.dart:558, pre-existing) does not
append rows as sets are logged — on every debounced save it deletes and
reinserts every `WorkoutSetTable` row for the exercise currently being
edited (see the method body a few lines down). So even if the this-workout
PB *were* a query, it would only ever reflect the last flushed save, not the
value in the field the user is currently looking at, and it would flicker
between the entered value and the previous one for the 800ms of the debounce
in `_scheduleSave` (active_workout_view.dart:121).

`_currentWorkoutBestSet` reads `_setControllers` directly instead, which is
why `onChanged` on the weight and reps fields (active_workout_view.dart, the
two `TextField`s inside `_buildSetFocusedView`) now calls `setState(() {})`
in addition to `_scheduleSave()`. The debounce is still right for the
network/DB write — nobody needs a row persisted on every keystroke — but the
on-screen PB has to move on every keystroke, because that is the whole
point: it is showing the user, as they type, whether they're about to beat
their own session.

## 3. Why "all-time" ignores which workout the sets came from

The all-time query joins `workout_exercise_table` on `exercise_id`, not on
`workout_id`:

```sql
SELECT ws.weight, ws.reps
FROM workout_set_table ws
JOIN scheduled_workout_exercise_table swe ON swe.id = ws.scheduled_workout_exercise_id
JOIN scheduled_workout_table sw ON sw.id = swe.scheduled_workout_id
JOIN workout_exercise_table we ON we.id = swe.workout_exercise_id
WHERE we.exercise_id = ?
  AND sw.is_completed = 1
  AND ws.set_type != ?   -- SetType.warmup
  AND ws.weight IS NOT NULL
ORDER BY ws.weight DESC, ws.reps DESC
LIMIT 1
```

A PB scoped to "this template workout" would under-report: a trainee who
benches on both "Push Day A" and a one-off "Push Day A (edited)" copy — which
happens after any trainer edit, per `docs/trainer-workout-builder.md` — would
see their PB reset every time the template changed shape, even though it's
still the same barbell exercise. Scoping by `exercise_id` is also what
`_loadExerciseProgress` in `progress_dashboard_view.dart:160` already does
for the same reason (its `MAX(weight)` is per-day-per-exercise, not
per-workout); this query reuses that precedent rather than inventing a new
scope.

The warmup exclusion (`ws.set_type != ?`, bound to `SetType.warmup.index`)
mirrors the same rule already encoded as a magic-number comment in that SQL
string (`ws.set_type != 1 -- exclude warmup sets from volume/PR stats`).
Both `_loadAllTimeBestSet` and `_currentWorkoutBestSet` now express it as
`SetType.warmup.index`/`SetType.warmup` instead of a bare `1`, since the
enum (`lib/feature/workout_planning/data/models/workout_set.dart`) is
already imported into this file for `SetType`/`SetSide`.

## 4. What ties a weight to its reps, and why that's not two separate `MAX()`s

`ORDER BY ws.weight DESC, ws.reps DESC LIMIT 1` — not
`MAX(weight)` and `MAX(reps)` as two independent aggregates — because a PB is
a *set* (one weight–reps pair that actually happened together), not the best
weight ever combined with the best rep count ever, which could come from two
different sets on two different days and describe a lift the person never
performed. The same reasoning applies to `_currentWorkoutBestSet`'s
comparison (`weight > best.weight || (weight == best.weight && reps >
best.reps)`): reps only break a tie on equal weight, they never outrank a
heavier set with fewer reps, because "best" here means heaviest, not
highest-volume.

## 5. Both displays are premium-only, and free users see nothing at all

Both cards went through two earlier shapes before landing here, and both
are worth recording because they're the two ways a "premium feature" can go
wrong.

**First shape:** no gate at all — every trainee saw both PBs.

**Second shape:** gated with the existing `PremiumGate` widget
(`lib/feature/premium/premium_gate.dart`), the same one
`progress_dashboard_view.dart` uses for the adaptive-TDEE card. `PremiumGate`
with no explicit `placeholder` dims the *real* child at `Colors.black
.withValues(alpha: 0.38)` and lays a lock icon over it — a stylistic darken,
tuned for a card like a chart where the gate is selling interpretation, not
hiding the axis labels. A PB is nothing but the numbers, so `PremiumGate(
child: card)` painted the real "105 kg × 3 reps" at ~62% opacity: trivially
legible, gate defeated. Passing an explicit masked `placeholder` (a second
`_PersonalBestCard` built with `'-- kg × -- reps'` instead of the real
`valueText`) fixed the leak, but kept the free user staring at a locked card
promising a number they'd never see without paying — a teaser for a stat,
not a feature.

**Current shape:** the PB cards simply don't build for a free user.
`hasPremiumAccess` (`context.watch<AccessProvider>().hasPremiumAccess`,
active_workout_view.dart, `_buildSetFocusedView`) gates both `if`s directly —
`if (hasPremiumAccess && exerciseData.allTimeBest != null)` for the all-time
card, `if (_currentWorkoutBestSet(exerciseData) case final currentBest?
when hasPremiumAccess)` for the this-workout card. No `PremiumGate`, no
placeholder, no lock icon: a free user's screen looks exactly like it did
before this feature existed. `_PersonalBestCard` lost the masking role it
was built for and is now just the one real layout, built once, for
premium users only.

`hasPremiumAccess` is `_isPremium || _proFromLicence` — the trainee's own
RevenueCat entitlement OR-ed with pro-via-trainer-licence. That's a
different flag from `TrainerLicence` itself: nothing here mints, checks, or
touches a trainer's seat count or licence tier.

### 5a. A gate a free user can't see is a gate that never sells anything

Hiding the cards outright (§5) solves the leak, but it creates a second
problem on its own: `PaywallScreen._features()`
(`lib/feature/premium/paywall_screen.dart`) is the trainee's only listing of
what premium actually buys — the bullet list under "Unlock your potential"
that a user reads before paying. A feature nobody can see for free and
nobody is told about on the paywall doesn't just fail to advertise itself;
there's no path back to it at all for someone who didn't already know it
existed. `paywallFeaturePersonalBest` closes that: one line
("Personal bests — all-time and per-workout, for every exercise") added to
`_features()` alongside the existing progress/plans/nutrition bullets, so
the feature a free user's workout screen now says nothing about is still
something they were told they'd get.

## 6. The lesson

A feature described as "show X" that turns out to have two legitimate
readings of X is a scoping decision, not a display decision — and the two
readings can look identical in every manual test until the one moment
(a new PB) that the feature exists for. When two numbers share a name,
check what happens when they *disagree* before deciding whether one query
can serve both; if the disagreement is the interesting case, it needs to
survive as two code paths, not get collapsed by whichever one was easier to
wire up first.
