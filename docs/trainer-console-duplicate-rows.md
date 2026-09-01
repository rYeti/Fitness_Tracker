# Duplicate rows, round two: what idempotency doesn't fix

Two prior documents in this repo — `docs/trainer-nutrition-duplicate-meals.md` and
`docs/trainer-session-review.md` — each fixed a table where the Trainer Console
showed a client more than they had, by making the write idempotent and folding
the read. Both fixes shipped. Both tables kept producing duplicates.

The report this time: a lunch listing ten foods a client had logged five of,
each one twice; two identical session chips in Session Review for the same
workout on the same day; an exercise reported *Skipped* with a full
prescription that the client's own workout no longer carries, at a set count
the client's own workout no longer prescribes. The owner's first instinct was
the account switch mentioned in the report — reasonable, since
`docs/sync-account-switch-duplication.md` documents exactly that mechanism for
workouts. It wasn't the cause here either, for the same reason it wasn't the
cause there: the switch only empties the local cache. Every duplicated row
below had already been on the server, in most cases for months.

Read together, the two prior fixes and this one describe a pattern worth
naming on its own: **the client that heals a defect on read is the reason
nobody sees it, and the next reader inherits everything that ever happened,
all at once.** The trainee app has never shown any of these rows twice. It
has instead been quietly correct in three unrelated ways, for three unrelated
reasons, none of which touch the server.

Line references are to the commit that introduces this document.

---

## 1. Three tables, three mechanisms, one shape

| Symptom | Server residue | Why the trainee app never showed it |
|---|---|---|
| ten-food lunch | a second `Meals` row for one day+category — sometimes holding a second copy of the *same* `MealFoodEntry` rows the first already had | reads the first row of each category by construction |
| duplicate session chip | a second `ScheduledWorkouts` row for one workout+date | `_deduplicateScheduledWorkoutsByContent` merges local twins by content |
| phantom skipped exercise, wrong set count | a second `WorkoutExercises` row in one `(WorkoutId, ExerciseId, OrderPosition)` slot | `_pullWorkouts`' own dedup pass folds duplicate exercises as it pulls |

None of these are new categories of bug. Each is a table this codebase has
already named as append-only and already fixed once. What changed between
"fixed" and "still duplicating" is worth going through per table, because it's
a different mistake each time — the common thread is only visible once you
see all three.

---

## 2. Meals: an idempotent create that created a new hole

`MealService.CreateMealAsync` (`trainer-nutrition-duplicate-meals.md` §4) already
returns the existing row instead of inserting a second one, for the same day and
category. That should have ended it. What it actually did was move the
duplication one level down.

The sync client's `_syncNewMeal` posts a meal, then — unconditionally — posts
every locally unsynced food entry against whatever id the response carried:

```dart
final response = await _apiClient.post('api/Meal', data: {...});
final mealServerId = response.data['id'] as String;
await _db.mealDao.markMealSynced(localId: meal.id, serverId: mealServerId);

final entries = await _db.mealDao.getAllFoodEntriesForMeal(meal.id);
await _syncMealFoodEntriesBatch(
  entries.where((e) => e.serverId == null).toList(),
  mealServerId,
);
```

Before the idempotent create, that `id` always named a fresh, empty meal, so
posting the local entries onto it was correct. After it, the id can just as
well name a meal that already exists — one a second device wrote, or one this
device wrote on an earlier attempt whose response never arrived — and that
meal can already hold the very food entries this device is about to post
again. The idempotent `POST api/Meal` fixed the row count. It did nothing
about what got attached to the row once found, because nothing on the client
side changed its assumption that a returned id names an empty meal.

This is the same failure mode `_syncMissingWorkoutExercises` was already fixed
for, one call away: a write whose *outer* effect became idempotent, while an
*inner* effect it triggers unconditionally kept assuming the outer call always
starts from nothing.

### The fix

`_syncNewMeal` now asks what the returned meal already holds and links its own
entries to matches before creating anything —
`_stampMealFoodEntriesFromServer`, structurally identical to
`_stampWorkoutExercisesFromServer` (`sync_service.dart`, introduced for
exactly this reason on the workout side, `docs/sync-account-switch-duplication.md`
§3). Matching is on `foodItemId`, and each server entry is claimed at most
once — so a client that genuinely logged two portions of the same food still
gets its second entry created. `LoggedMealDto.Foods` already documents that
repeats inside one meal are real; a fix that collapsed them would silently
under-report what somebody ate, which is worse than showing an extra row.

### The read side still needed its own fix, twice

Idempotent writes stop new duplicates. They do nothing for the ones already
on the server, which is the whole reason `trainer-nutrition-duplicate-meals.md`
folded the read in the first place — but that fold only handled the *first*
shape of duplicate, where two rows hold different foods:

```csharp
var loggedMeals = todaysMeals
    .GroupBy(meal => MealCategory.Key(meal.Category))
    .Select(sameCategory =>
    {
        var meal = sameCategory.First();
        var foods = sameCategory
            .OrderBy(m => m.Date)
            .SelectMany(m => m.FoodEntries)   // ← concatenates, unconditionally
            ...
```

That's correct when the two rows genuinely split one meal's foods across
themselves — the shape a reconcile pass produces (§2 of the earlier document).
It is wrong for the shape *this* bug produces: two rows holding the *same*
foods, where concatenating doubles the count and the totals right back up.
Grouping by category had already solved the row-count symptom the trainer
first reported; it took a second, harder look to notice the food-count symptom
riding along inside the surviving group.

`CollapseRepushedMeals` (`TrainerConsoleService.cs`) runs inside that group and
drops a row only when its food-item multiset, as a set, exactly matches a row
already kept — a repush is byte-identical, so this needs no fuzz. Rows that
differ in any item are still concatenated exactly as before. And because the
day's calorie trend bar sums the same `FoodEntries` through a separate code
path (`TotalCalories`, used by `SevenDayTrend`), that path needed the identical
fold — otherwise the ring on the summary card and the bar for that exact day,
six centimetres apart on the same screen, would disagree by the duplicate's
worth of calories. The earlier document's own postscript said as much about
the reconcile-path duplication it left unfixed: *"the day's calories are
inflated... that half of the problem is still there."* This is that half,
for a different cause.

---

## 3. Sessions: idempotent everywhere except the one place that mattered

`ScheduledWorkoutRepository.CreateScheduledWorkoutAsync` already guards against
creating the same session twice — but only for the case of the exact same
client-supplied `Id`:

```csharp
var existing = await _context.ScheduledWorkouts...FirstOrDefaultAsync(s => s.Id == sw.Id);
if (existing != null) return existing;
```

The sync client's `_syncNewScheduledWorkout` never supplies one. It sends a
`POST` with no id, the server mints a fresh `Guid` every time, and the id
check above can, structurally, never fire for a sync push — it exists for a
caller this endpoint doesn't have. A push whose response never made it back,
or a second device that scheduled its own local copy of the same day's
workout, each committed a genuinely new row. The workout and set sync paths
were fixed for exactly this shape of loss two documents ago
(`docs/sync-account-switch-duplication.md` §3, `_syncMissingWorkoutExercises`);
scheduled workouts never got the equivalent guard, because their duplication
was invisible everywhere it had ever been looked at.

Invisible on the device, because `_deduplicateScheduledWorkoutsByContent`
treats two local rows for the same workout and date as duplicates by
definition and merges them — the trainee app was never going to show this.
Invisible on the server side of Session Review too, until now: the twin
without any logged sets reads as a session where the client turned up to
nothing and skipped every exercise in it, next to the real session showing
what they actually did.

### The fix, both halves again

`CreateScheduledWorkoutAsync` now also checks for an existing row by
`(WorkoutId, UTC day)`, returning it — with its exercise entries — before
creating anything. `ScheduledDate` is a client's local midnight stored as an
instant (the same representation `MealDayWindow` exists to undo, per
`trainer-nutrition-duplicate-meals.md` §4's closing section), so this is a
day-window match, not equality; it catches what one device sends for one day,
and can still miss two devices in different timezones landing on either side
of the UTC boundary. That residual gap is what the read-side fold exists for.

`GetClientSessionHistoryAsync` folds duplicate sessions by `(WorkoutId,
ScheduledDate.Date)` before building anything else. The survivor is chosen by
most logged sets, then completed, then earliest created — deterministic
between requests — but the fold does **not** discard the losing rows' exercise
entries. They're carried forward into the merged session and handed to the
exercise-level fold below. Discarding them outright would have been simpler
and would have been wrong: which twin a set landed on is an artifact of which
local row happened to be linked on the device that logged it, not a signal
about which twin is "real."

Because the fold removes rows, the page has to be pulled deeper than it's
displayed — `count * 2` sessions in, `count` out — or a client with duplicates
would see a shorter history than one without. The doubling is a heuristic
sized to the failure mode actually observed (one twin per lost push, one per
extra device); it does not need to be exact, because the fold is stable and a
short page just means one extra call on the next screen the trainer opens.

---

## 4. Exercises: the fold that already existed, applied one level too late

Adding an exercise to a workout has been idempotent per
`(WorkoutId, ExerciseId, OrderPosition)` since `trainer-session-review.md`
§2. Every duplicate `WorkoutExercises` row in production predates that fix and
will outlive it — this is, again, a training log, not something a migration
gets to tidy by deleting rows. The sync client already knows how to live with
that: `_pullWorkouts`' `_collapseDuplicateServerExercises` folds duplicate
exercises to one per slot as it builds the local workout, which is exactly why
the client app has never shown this to anyone.

`GetClientSessionHistoryAsync` doesn't read the workout, though — it reads
`ScheduledWorkoutExercises`, the rows stamped onto a session at the moment it
was created, from *all* of the workout's exercises with `RemovedAt == null` —
duplicates included, because nothing before this fix filtered on anything but
removal:

```csharp
var workoutExercises = await _context.WorkoutExercises
    .Where(we => we.WorkoutId == sw.WorkoutId && we.RemovedAt == null)
    ...
foreach (var we in workoutExercises)
    sw.Exercises.Add(new ScheduledWorkoutExercise { WorkoutExerciseId = we.Id, ... });
```

Every session generated after a duplicate `WorkoutExercise` row existed for a
slot got stamped with both. The client only ever logs against one — the one
its local, already-collapsed workout points at — so the twin sits there
unlogged, and Session Review read that absence as the client skipping an
exercise the workout, as the client can actually see it, doesn't even list.
Where the twin also carried its own frozen generation of `WorkoutSetTemplates`
(the shape `trainer-session-review.md` §4 fixed *within* one exercise row),
the prescription shown for it could disagree with the live row's, too.

### The fix

`CollapseDuplicateEntries` runs per session, keyed on the same
`(WorkoutId, ExerciseId, OrderPosition)` triple the write path is now
idempotent on — reusing the write path's own key rather than inventing a
read-side heuristic, so the two can never disagree about what counts as a
duplicate. Within one slot: if any entry carries logged sets, every entry that
does is kept and every entry that doesn't is dropped; if none do, one
arbitrary — but stable — entry survives so an unlogged prescribed exercise
still shows up as unlogged rather than vanishing. Two entries in one slot both
carrying logged sets are both kept, unconditionally: that shape means the
client actually logged against both twins on different occasions, and there
is no way to merge two independent sets of real history without either
inventing reps that weren't done or discarding some that were. `OrderPosition`
stays part of the key for the reason it's part of the write path's own key: a
real superset pairs a movement with itself, and two entries at different
positions are not a duplicate no matter how identical the exercise.

---

## 5. What to take from this

- **Fixing the write does not retire the read-side fold — it just changes what
  the fold has to look for.** `trainer-nutrition-duplicate-meals.md` predicted
  this in its own words: *"idempotent writes beat cleanup, but only for the
  future."* What it didn't anticipate is that the *fold itself* can be
  incomplete in a way the row-count symptom hides — the meal fold solved
  "two rows" and quietly mishandled "two rows with the same contents" for
  months, because both cases produce one merged row and only one of them
  produces the right calorie count.
- **An idempotent outer call does not make its side effects idempotent.**
  `_syncNewMeal` became safe to retry at the meal level and stayed unsafe at
  the food-entry level, because the code attached to the food entries never
  stopped assuming the meal it just heard about was new.
- **A guard keyed on the wrong identity guards nothing.** Matching
  `CreateScheduledWorkoutAsync` on `sw.Id` protected against a caller that
  supplies one. The only caller that exists supplies none. The check had been
  dead for every request it would ever receive.
- **The client that can't see a defect is not evidence there isn't one — even
  after you've already fixed a defect in the same table.** Three separate
  local de-duplication passes (meals, scheduled workouts, workout exercises)
  each made a different table look clean on the device where the bug was
  first noticed. None of them touched the server. Each was, independently,
  the reason the corresponding server-side duplication went unnoticed for as
  long as it did.
- **Reuse the write path's own idempotency key as the read path's fold key.**
  Both exercise-duplication fixes — the create-time guard and the
  read-time fold — key on `(WorkoutId, ExerciseId, OrderPosition)`. That's not
  a coincidence to note in passing; it's why the two can't quietly disagree
  about what a duplicate is. A fold with its own separate notion of identity
  is a second place for that definition to drift from the first.
