# The exercise that vanished twice: why a swapped-out lift lost its history on every other device

A trainee swaps an exercise out of a workout — leg press for hack squat, say —
and keeps training. Weeks later they reinstall, or sign in on a second phone.
Every set they ever logged against the *retired* exercise is gone: Exercise
Progress shows nothing for it, and starting that lift again shows no
"previous set" reference. Sets logged against exercises still in the workout
came back fine. Only the ones tied to an exercise the user had since removed
were missing.

The set was never lost server-side. It was never even attempted, because the
one row a fresh device needed to hang it on was never created.

Line references are to the commit that introduces this document.

---

## 1. What actually happens on pull

`SyncService.pullAll` hydrates a new device in a fixed order: workouts, then
scheduled workouts (the calendar of sessions), then the sets logged inside
each one. `_pullScheduledWorkouts` resolves a logged set's exercise like this:

```dart
final localWe = await _db.workoutDao.getWorkoutExerciseByServerId(
  se['workoutExerciseId'] as String,
);
if (localWe == null) {
  _logger.w('... skipping exercise ... — no local workout exercise for ...');
  continue;
}
```

`workoutExerciseId` here doesn't point at "leg press" the exercise — it
points at *this workout's leg-press slot*, a `WorkoutExerciseTable` row. Find
that row locally, and the scheduled exercise (and every set under it) gets
created. Don't find it, and the `continue` drops the exercise, its
`ScheduledWorkoutExerciseTable` row, and every `WorkoutSetTable` row it would
have held — silently, with nothing left in the payload to retry from.

The row that resolution depends on is created earlier, in `_pullWorkouts`,
one exercise at a time:

```dart
if (ex['removedAt'] != null) continue;
```

The API deliberately keeps returning a workout exercise after it's removed
(`WorkoutExercise.RemovedAt`, soft delete — see
`FitTracker.Api/Repositories/WorkoutRepository.cs`), specifically so that
sessions logged against it can still resolve what was performed. `_pullWorkouts`
read half of that intent — "still returned" — and missed the other half:
*resolve* requires a local row to resolve *into*, and this line made sure one
never existed. The comment above it even said so: "still returned so that
logged sessions can resolve what was performed" — describing a guarantee the
next two lines didn't keep.

## 2. Why this only showed up on a second device

On the device where the set was originally logged, none of this ran. The
`WorkoutExerciseTable` row for leg press was created locally when the
exercise was *added*, synced normally, and stayed on disk after being removed
from the workout — removal only stops it being shown (workout-builder and
active-workout queries already filter `syncStatus.isNotValue(3)`, the
`pendingDelete` marker `saveCompleteWorkout` stamps on a removed exercise
that has a `serverId`). The row a scheduled exercise needs to link against
was sitting right there the whole time.

A pull is the only code path that has to build that row from nothing. It ran
into exactly the gap `docs/sync-account-switch-duplication.md` describes for
workouts and set templates: a pull that only fills in what's *absent*
locally can't see a resolution failure until something empties the local
tables and forces it to try. A reinstall, a second device, or (less
obviously) any workout containing a since-retired exercise pulled for the
first time — all hit the same missing row.

## 3. The fix

`_pullWorkouts` now creates the `WorkoutExerciseTable` row for a retired
exercise instead of skipping it — with one difference from a normal row: its
`syncStatus` is stamped `4`, a value with no member in the shared `SyncStatus`
enum (`pending` / `synced` / `pendingUpdate` / `pendingDelete` — see
`workout_tables.dart`). It needed a state that:

- is **invisible** to every workout-builder and active-workout query, same as
  `pendingDelete` (`3`) — both are now excluded everywhere the other was;
- is **never swept for a DELETE push** — unlike `pendingDelete`, there is
  nothing left to delete; the server already dropped this row on its own;
  and
- **survives editing the workout it belongs to.**

That third one was the one bug reusing `pendingDelete` (`3`) would have
reintroduced immediately. `saveCompleteWorkout` diffs "what's in the workout
now" against "every `WorkoutExerciseTable` row for this `workoutId`" to find
exercises the user removed, and anything not in the current set gets marked
`pendingDelete` and eventually hard-deleted — a delete that cascades through
`ScheduledWorkoutExerciseTable` straight into `WorkoutSetTable`
(`onDelete: cascade`, `workout_tables.dart`). A retired placeholder is
never in "what's in the workout now" — the builder doesn't show it — so the
very first edit to that workout after a pull would have deleted the
placeholder and, with it, the logged sets it exists to protect. The fix
excludes `syncStatus == 4` from that diff explicitly, so the placeholder is
invisible to the diff the same way it's invisible to the UI.

Nothing else needed to be taught about the new value: `_syncMissingWorkoutExercises`
already skips rows with a `serverId` (a retired placeholder always has one —
it's stamped straight from the server payload), and every push sweep in
`SyncService` filters by raw `== 3`, not "anything not synced," so a stray
`4` never enters a code path built for the other three states.

## 4. What to take from this

- **"Still returned" is not the same as "still resolvable."** The API kept
  its half of the contract — the retired exercise never disappeared from the
  response. The client dropped its half by deciding "no longer part of the
  workout" and "not worth storing" were the same thing. They're different
  questions with different answers: it isn't part of the *plan*, but it is
  part of the *history*.
- **A `continue` that skips a row skips everything downstream of it too.**
  This one skipped a `WorkoutExerciseTable` insert, but the actual loss —
  sets — happened three sync passes later, in code that had no idea the row
  it depended on had been deliberately never created.
- **A shared status column needs headroom before you write into it.** Reusing
  `pendingDelete` for "hide this" would have been one field, zero new code —
  and it would have deleted the very rows this fix exists to keep, the next
  time the workout was edited. The new value earned its keep specifically by
  being checked against the one thing (`saveCompleteWorkout`'s diff) that a
  reused value would have gotten wrong silently.
- **The device that removed the exercise is the one device that can never see
  this bug.** Every other device only discovers it by pulling from scratch —
  the same shape of blind spot `docs/sync-account-switch-duplication.md`
  found for workouts and set templates: a pull that fills gaps can't see a
  gap it never had a reason to open.
