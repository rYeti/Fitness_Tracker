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

## 6. The query was in the wrong layer, and the layer was hiding an N+1

Review comment on the first version of this feature, against
`active_workout_view.dart`:

> why is here a db.select and not a repository or dio like the other access to
> the database

Worth being precise about what was actually wrong, because the surrounding
code looks like a defence. Views in `gym_tracking` query the database
inline constantly — roughly 32 `db.select(...)`/`db.into(...)` sites across
that view directory against ~18 `db.someDao.method()` calls, five of them in
`active_workout_view` alone. By volume, an inline query in a view *is* the
house style, and there is no repository layer in `gym_tracking` at all
(`grep -rn "Repository" lib/feature/gym_tracking/` returns nothing) — the
"repository or dio" of the review is, concretely, a drift DAO.

The distinction that makes the comment right is not inline-vs-DAO, it is
typed-vs-raw. A `db.select(db.workoutSetTable)..where(...)` in a view is a
query the analyser type-checks against the schema: rename a column and it
goes red. A `customSelect` with a SQL string is a second, untyped copy of
the schema that no build step reads, and there were exactly **three** of
those in all of `lib/` outside the data layer. Two of them are gone in this
change and the third was deleted outright (§6b).

### 6a. What the move actually bought

`WorkoutDao.getAllTimeBestSets({List<int>? exerciseIds})` replaced
`_loadAllTimeBestSet(db, exerciseId)`. Three things changed that a
straight cut-and-paste into the DAO would not have:

**One definition of "best" for two screens.** The dashboard needed the same
number (§7). Had the query stayed in the workout view, the dashboard would
have grown its own — and "heaviest non-warmup set from a completed session"
is a definition with four independent ways to drift. There is now one place
where warmups are excluded and one place where the tie-break lives.

**The N+1 disappeared.** The old method took a single `exerciseId` and was
called *inside* the per-exercise loop of `_loadWorkoutData`, so a six-exercise
workout ran six round trips before the first set could be typed. The batch
method is called once, before the loop, and the loop reads
`allTimeBests[exerciseId]` out of a map. Nothing about the review comment was
about performance, and fixing the layering is what made the N+1 visible: a
per-exercise query buried in a view reads as ordinary, and the same query in a
DAO signature asks to be given all the ids at once.

**`SetType.warmup.index` instead of `1`.** The dashboard's copy of this filter
was written `AND ws.set_type != 1  -- exclude warmup sets`, a magic number with
an apology attached. `workout_dao.dart` already imports the enum, so both
queries now bind `SetType.warmup.index` as a variable and the comment is
unnecessary.

The tie-break needed one deliberate choice. Picking the best row per exercise
in SQL wants `ROW_NUMBER() OVER (PARTITION BY ...)`, and window functions
require SQLite 3.25+ — which not every Android system library ships. Instead
the query orders by `we.exercise_id, ws.weight DESC, ws.reps DESC` and Dart
keeps the first row it sees per id. Same semantics, no version floor. It reads
more rows than it returns, which is the actual cost, and is bounded by the
handful of exercises a caller asks about.

### 6b. The third raw query was not a query

`edit_view.dart` held this, inside a `try` that swallowed everything:

```dart
final links = await db.customSelect(
  'SELECT * FROM workout_plan_workout_table WHERE plan_id = ?', …).get();
```

`links` was never read. It was a diagnostic dump — "if the plan has no
workouts, dump the junction table to help diagnose missing/stale links" — from
some earlier debugging session, still running on every load of a plan with no
workouts and still discarding its result. The fix for a query nobody reads is
not to relocate it into a DAO; it is to delete it, which is what happened.
Worth noticing that the analyser never said a word: the variable *is* assigned,
and the lint that would have caught it (`unused_local_variable`) fires only for
variables that are never used at all — which this one technically is, but the
warning had been sitting in a file with two other unused declarations for long
enough to blend in.

## 7. The same PB, on the progress dashboard

The second half of this change puts the all-time PB on each exercise card in
`progress_dashboard_view.dart`. The interesting part is what was already
there and why it could not be reused.

That screen already renders a **"Max weight"** stat under every chart, which
looks exactly like the feature being asked for and is not:

| | Max weight (existing) | All-time PB (new) |
| --- | --- | --- |
| Scope | the selected time range | every completed session, ever |
| Reps | none | the reps of that set |
| Free? | yes | premium |

The range is the point. It is premium-clamped (`rangeStart(..., hasPremium:)`),
so a free user's "Max weight" is the heaviest lift *of the last few weeks*.
Presenting that as a personal best would have been wrong for the user who set
their PB in January, and it would have made the paywall's promise false.

Reps were the other blocker, and this one is a trap worth writing down.
`ExerciseSessionData` carries a `reps` field, so `(maxWeight, reps)` looks
like a set. It isn't: the SQL populates `reps` from `first_set_reps` — the
reps of that day's *first* set, used to label chart points — while `maxWeight`
is a `MAX()` across the day. On any day whose first set was a lighter one,
pairing them describes a set that never happened, and both fields are
`double`/`int` so nothing anywhere would object. `getAllTimeBestSets` returns
a real set instead; `getExerciseProgressRows` now says so in a doc comment.

Two smaller decisions:

- **`ExerciseProgressData` gained an `exerciseId`.** It carried only
  `exerciseName`, because nothing had needed to join it to anything before —
  the id existed as a map key during loading and was dropped on the way out.
  Keying PBs by name would have worked right up until two exercises shared one.
- **The PB sits in the `ExpansionTile` subtitle**, not above the chart inside
  the expanded body. Each exercise is a collapsed tile, so the body version is
  invisible until you tap — and "the overall PB for each exercise" is a thing
  you want to read down a list, not open one at a time. In the header it is
  above the diagram anyway, which is where it was asked for.

Premium gating follows §5 exactly: `hasPremiumAccess` is read once per build
of the gym tab (not once per card) and passed down, and a free user gets the
card they have always had, with no lock, no placeholder, and no layout shift.
`PremiumGate` is deliberately not used here — it paints a tappable lock over
its child, which is the behaviour §5a rejected.

## 8. Four defects a code review found, and why nothing else would have

All four survived a green suite and a clean `flutter analyze`, and three of
them were introduced by the very change that centralised this logic. They are
worth recording as a set, because they share a shape: each one is a place where
two pieces of code answered the same question differently and nothing forced
them to agree.

**The decimal comma.** `_saveCurrentExercise` parses a weight as
`double.tryParse(text.replaceAll(',', '.'))`. `_currentWorkoutBestSet` parsed
it as `double.tryParse(text)`. On a German keyboard `102,5` therefore *saved*
correctly and was silently skipped by the session-best card — the app agreed
with itself about what you lifted and disagreed about whether it was your best
set. Both paths read the same `TextEditingController`; only one of them knew
the app ships in a locale that types commas.

**Two clocks on the exercise identity.** `_loadWorkoutData` renders
`resolvedExercise` — which is the *override* when the trainee swapped the
exercise for that day — but looked the PB up under
`workoutExercise.exerciseId`, the exercise the plan originally named. Swap
Bench Press for Dumbbell Press and the card offered you the bench PB while you
were doing dumbbells. The fix is `_attachAllTimeBests`, which keys off
`exercise.id` (what is on screen) and, being a post-loop pass, is the only
point where those ids are known.

**The same split in SQL.** `getAllTimeBestSets` attributed sets by
`we.exercise_id`, so the swapped day's sets counted toward the exercise that
was *replaced* — 40 kg dumbbell presses landing in the bench press's history
forever, not just for the session. Both queries now attribute through
`_performedExerciseId` (`COALESCE(swe.override_exercise_id, we.exercise_id)`),
so a set counts toward the lift that was actually done. This also corrected
`getExerciseProgressRows`, which had inherited the same assumption from the
original dashboard SQL.

**The PB that vanished.** `_replaceCurrentExercise` and the superset-partner
picker both rebuild `_ExerciseWithSets` from scratch. Neither passed
`allTimeBest`, so it defaulted to null and the card disappeared for the rest of
the session — indistinguishable, on screen, from an exercise that has no PB at
all. This is the failure mode of adding a field to a class with more than one
construction site: the analyser is perfectly happy, because the parameter is
optional and null is a legal value that already means something else. Making
the field mutable and assigning it through one method removes the chance to
forget, and the constructor parameter was deleted so there is nothing left to
pass inconsistently.

A fifth, smaller one: reps defaulted to `0` when the field was empty, so typing
a weight before its reps promoted "100 kg × 0 reps" to the best of the session
for as long as it took to type the next number. A PB now requires both a weight
and a rep count, in the widget *and* in SQL — `AND ws.reps IS NOT NULL AND
ws.reps > 0` — because a stored weight-only row would otherwise render the same
sentence permanently.

What connects them: a green test suite proves the code does what its tests say,
and every one of these is a disagreement *between* two pieces of code that were
never tested against each other. The DAO tests were right about the DAO. The
save path was right about commas. Nothing owned the question "do these two
agree", which is exactly the question a reviewer asks first.

## 9. The lessons

A feature described as "show X" that turns out to have two legitimate
readings of X is a scoping decision, not a display decision — and the two
readings can look identical in every manual test until the one moment
(a new PB) that the feature exists for. When two numbers share a name,
check what happens when they *disagree* before deciding whether one query
can serve both; if the disagreement is the interesting case, it needs to
survive as two code paths, not get collapsed by whichever one was easier to
wire up first.

The second lesson is about where a query lives. A method signature is a
statement about how often it is meant to run, and moving a query one layer
down forces you to write that statement: `_loadAllTimeBestSet(db, exerciseId)`
sitting in a view among other per-exercise work looked fine and ran six times;
the same logic behind `getAllTimeBestSets({exerciseIds})` could only be
written once. Neither the compiler nor a test can see the difference between
one query and six — they can only see the shape you gave the caller.

---

# 10. The second number was the wrong "best" — one session, not one programme

Line references in this section are to the commit that introduces it.

The feature shipped in §1–§9 put two cards on the active-workout screen: an
all-time PB for the exercise, and a second card labelled "This Workout's Best."
The second one was wrong, and it was wrong in a way that no test, type or
review caught, because it was *exactly what the original request asked for*
under a reading nobody noticed was a reading.

## 10.1 What "this workout" meant to the code, and what it meant to the user

`workout` is used for two different things in this codebase, one line apart:

| The word | What it denotes | Where |
| --- | --- | --- |
| a workout | a template — "Upper A" — a named list of exercises | `WorkoutTable` |
| a scheduled workout | one performance of a template on one date | `ScheduledWorkoutTable` |
| the active workout | the *screen* the trainee is standing in | `ActiveWorkoutScreen` |

`_currentWorkoutBestSet` picked the third. It read the text controllers of the
session on screen and returned the heaviest set typed into them so far, so the
card answered: **of the sets you have logged in the last forty minutes, which
was heaviest?**

A trainee training a plan — Upper A, Upper B, Lower A, rotating — reads "this
workout" as the fourth thing the word can mean, which the table above does not
even contain: *the programme*. The collection of workouts they are currently
working through. Their question is **on this block, how heavy have I gone on
this lift?**, and it is a genuinely useful question, because it is the one the
all-time PB cannot answer. An all-time best can be four years old and set at a
bodyweight they no longer have; a programme best is the thing they are actually
trying to beat this month.

The session-scoped number is, by contrast, almost content-free. Sets within a
session are usually a ramp followed by working sets at one weight, so "the best
of this session" is the top of the ramp — a number the trainee chose before
starting and can see two inches away in the field they just typed it into. It
is a restatement of the screen, presented as a statistic.

Nothing about that is visible from the code. The method was named for what it
computed, the tests asserted what it computed, and the doc in §1 defended the
distinction between the two cards at length — correctly, as far as it went. The
question it never asked was whether *the smaller of the two scopes was worth a
card at all*. "These two numbers must not be merged" and "one of these two
numbers is the wrong number" are compatible statements, and only the first one
had been argued.

## 10.2 The scope that replaced it

The card now shows the best set for the exercise across **every completed
session scheduled under the same plan as the session on screen**, plus whatever
the trainee has typed into the session in progress.

```
all-time      ⊇      this plan      ⊇      this session
(every         (Upper A + Upper B +      (what is on
 session ever)  Lower A + … of the        screen right
                current block)            now)
```

The middle scope is new; the innermost one did not survive as a card, but it
did survive as an input, which §10.4 is about.

`WorkoutDao.getPlanBestSets` (workout_dao.dart) is the query. It shares its
body with `getAllTimeBestSets` through a private `_bestSets`, which takes the
scope as an extra `WHERE` fragment plus its bound variables and is otherwise
identical. That sharing is not tidiness: the two numbers are stacked on the
same screen and the user will subtract one from the other, so every rule about
what counts as a personal best — warmups excluded, both a weight and a rep
count required, the set credited to `_performedExerciseId` rather than to the
exercise the plan named — has to be the same rule, not the same rule typed
twice. §8 of this document is an inventory of what happens when two pieces of
code answer the same question separately; a copy-pasted second query with a
different `WHERE` would have been the next entry in it.

## 10.3 Scoping by the session's plan id, not by the plan's workouts

There are two defensible ways to express "the sets belonging to this plan," and
they are not equivalent:

```sql
-- what this change does
AND sw.workout_plan_id = ?

-- the other candidate
AND sw.workout_id IN (SELECT workout_id FROM workout_plan_workout_table WHERE plan_id = ?)
```

The first asks which plan a session *was scheduled under* — a fact recorded on
the session row at the moment it was created, and never revised. The second
asks which workouts the plan contains *right now*, and then finds sessions of
those.

They diverge whenever the plan's shape changes underneath a history that
already exists, which is not an exotic case: it is what a trainer edit does
(`docs/trainer-workout-builder.md`), and it is what any workout removed from a
plan, renamed into a new row, or rebuilt after a sync reconciliation does. Under
the second predicate, the trainee's programme best silently resets when their
coach reorganises the block — the sets are still in the database, still
attributed to the right exercise, and simply stop being counted because the
workout they were performed under is no longer in the plan's list. §3 of this
document rejected workout-scoped PBs for this exact failure mode; scoping by
the plan id on the session is the same argument applied one level up.

The cost of the choice is that a session can carry a plan id for a plan that
has since been deleted — `SyncService` nulls the column rather than orphaning
the row (sync_service.dart), so those sessions fall out of the scope rather
than poisoning it. That is the right trade: a plan that no longer exists has no
programme best to report.

### The null-plan case is a scope, not an error

`workout_plan_id` is nullable and genuinely null in the field: a session pulled
from the server whose plan did not resolve locally, a session whose plan was
deleted, anything predating plans. Three things could happen there, and two of
them are bugs:

- **Bind null and let SQL compare.** `sw.workout_plan_id = NULL` is never true
  in SQLite, so the card would vanish for those trainees with no explanation.
- **Drop the filter.** The scope silently widens to all-time, and the screen
  shows the same number twice under two different labels — the §1 failure mode,
  reintroduced through a null check that looked like defensive coding.
- **Fall back to the workout.** With no plan there is no collection of workouts
  to span, so the collection degenerates to the sessions of *this* workout —
  every Upper A ever performed. Still a real, useful scope; still not the
  session.

`getPlanBestSets` takes `planId` **and** `workoutId` for this reason, and swaps
the `WHERE` fragment rather than the binding, so the placeholder count never
depends on the data. The screen labels the result for the scope it actually
got: `_hasPlan ? l10n.planBest : l10n.workoutBest` (active_workout_view.dart) —
"Best in This Plan" or "Best in This Workout". A card whose number and whose
noun are chosen in two different places will eventually disagree; here they are
chosen off the same nullable field, one line apart.

## 10.4 Why the live text controllers are still read

The query only sees `sw.is_completed = 1`. The session the trainee is standing
in is, by definition, not completed — and beyond that, §2 of this document
explains why it could not be read from the database even if it were: the save
path deletes and reinserts every set row for the exercise on each debounced
flush, so a query would lag the keyboard by up to 800ms and flicker between the
old value and the new one.

So the programme best is **two sources folded together**:

```dart
PersonalBestSet? _planBestSet(_ExerciseWithSets exerciseData) {
  var best = bestOf(exerciseData.planBest, _currentSessionBestSet(exerciseData));
  for (final slot in _exercises) { … }
  return best;
}
```

`planBest` is the plan's completed history, fetched once when the screen loads.
`_currentSessionBestSet` — the old `_currentWorkoutBestSet`, renamed to say what
it actually computes — covers the gap live from the text fields.

The fold is the whole feature. The moment a trainee's working set passes what
they have done all block is the moment this card exists for, and it happens
between two keystrokes, in a session that will not be marked complete for
another half hour. Without the live half, the card would announce the new
programme best some time after the trainee had left the gym.

That is also why the session number survived as an input after being rejected
as a display: it was never useless, it was mis-framed. As a card it answered a
question nobody asked. As one of two terms in a fold it is the only thing that
makes the card current.

## 10.5 One comparison, three places, previously zero of them shared

Merging two `PersonalBestSet?`s needs the same ordering the query's `ORDER BY
ws.weight DESC, ws.reps DESC` encodes and the same ordering
`_currentWorkoutBestSet` had open-coded as
`weight > best.weight || (weight == best.weight && reps > best.reps)`. That is
three statements of one rule, and by §8's standard, two of them were already a
latent disagreement waiting for someone to edit one and not the other.

`beatsPersonalBest` and `bestOf` (workout_dao.dart, beside the `PersonalBestSet`
typedef) are now the single Dart statement of it, used by the per-set scan and
by the fold. The SQL still spells it a fourth time, and no compiler can check
that against the Dart — so the Dart version carries a comment saying where its
twin lives, and the tests assert the two boundary cases the rule turns on
(heavier always wins however few the reps; reps break a tie on weight and
nothing else).

`bestOf` returning null only when *both* sides are null matters more than it
looks. The natural one-liner —
`a != null && b != null ? (better one) : (a ?? b)` — is correct, but the
equally natural `if (a == null || b == null) return null;` is a shape that
compiles, reads as a null guard, and quietly deletes the programme best for
every exercise the trainee has not yet typed a set for. Null here means "no such
set," not "unknown," and the two behave differently under a fold.

## 10.6 The same exercise, twice in one session

`_currentSessionBestSet` reads the controllers of **one slot** — one
`WorkoutExercise` row. A workout can hold the same lift twice: the overview
sheet's "add exercise" will happily add one already in the session, and a swap
can land on an exercise that is already elsewhere in the day.

Scoped to a session, reading one slot was defensible. Scoped to a plan it is
not: the card would claim a programme best the trainee had already beaten,
sixty seconds ago, two exercises further down the same screen. `_planBestSet`
therefore folds every slot in `_exercises` whose `exercise.id` matches, not just
the one being rendered. The `identical(slot, exerciseData)` skip is only there
to avoid scanning the same controllers twice; the result would be the same
without it.

This is the widening a scope change tends to bring with it and which is easy to
miss: the *implementation* of the inner term did not change, but the claim the
card makes about that term did, and a narrower implementation that was true
under the old claim is false under the new one.

## 10.7 What the labels had to change into

`workoutBest` read "This Workout's Best" / "Bestleistung dieses Trainings" —
which was ambiguous in exactly the way §10.1 describes, and is the phrasing that
let the wrong reading ship. Both locales are now explicit about which collection
they mean:

| key | en | de | shown when |
| --- | --- | --- | --- |
| `planBest` | Best in This Plan | Bestleistung in diesem Plan | the session has a plan |
| `workoutBest` | Best in This Workout | Bestleistung in diesem Training | it does not |

`workoutBest` was repurposed rather than deleted, and its meaning shifted from
"this session" to "this workout across all its sessions" — the degenerate scope
of §10.3. Repurposing a translation key is normally a way to ship a wrong
string in the locale nobody on the team reads; it is safe here only because
both locales are hand-updated in the same change, and it is recorded here so
that a future translator pass knows the English changed meaning rather than
merely wording.

`paywallFeaturePersonalBest` changed too — it promised "all-time and
per-workout", and per CLAUDE.md the paywall bullet is the only route a free
user has back to a feature they cannot see. A bullet that describes a scope the
app no longer has is the same defect as no bullet at all, one step later.

## 10.8 Both cards still render when they agree

For a trainee whose all-time PB on a lift was set during the current block, the
two cards show the same set under two labels. That is deliberate, and it is a
change from the old behaviour, where the session card simply did not exist until
the trainee typed something.

Suppressing the duplicate was considered and rejected on layout grounds: the
plan card is the hero-styled one directly above the set being entered, so a rule
like "hide it when it equals the all-time best" makes the card appear and
disappear *mid-set*, exactly as the trainee beats it — a layout jump at the one
moment the screen has something to say. Two cards reading the same number is not
misinformation; it is the true statement "your best ever on this lift is from
this block", rendered twice.

## 10.9 The lesson

§9 ended on: when a feature description has two readings of "X", the difference
between them can be invisible in every manual test until the case the feature
exists for. This change is the sequel, and its lesson is narrower and less
comfortable.

Both readings had been identified. §1 of this document names them, defends
keeping them apart, and ships them as two cards. What was never asked is whether
each scope was *worth showing* — whether a user would ever act on it. A scope
is not justified by being computable, nor by being distinct from the scope next
to it, and "these are two different numbers" is not an argument that both are
answers to a question somebody has. The session-scoped best passed every test
of internal consistency and failed the only external one: a trainee glancing at
it learned nothing they could not read off the field under their thumb.

The tell, in hindsight, was that the card's value was almost always a number the
user had typed themselves, minutes earlier, on the same screen. A statistic
whose input is entirely within the user's current field of view is a restatement,
not a statistic. That is a question worth asking of any derived number before
giving it a card: *where does this come from that the user cannot already see,
and what would they do differently on learning it?*
