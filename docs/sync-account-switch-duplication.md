# The pull that never ran: how switching accounts exposed a year of sync drift

Switching accounts on one device and switching back brought a workout back
wrong. Exercises appeared twice. Sets appeared twice. Exercises the user had
deleted weeks earlier were back in the plan. And the right data took a long time
to arrive, sometimes most of a day.

Four complaints, and the tempting reading is that the account switch broke
something. It didn't. **Every one of those rows was already on the server, and
had been for a long time.** The switch is simply the only thing in this app that
empties the local database, and emptying the local database is the only thing
that makes the sync client read the server's copy of a workout back.

The bug was never in the switch. The bug was that nothing had ever looked.

Line references are to the commit that introduces this document.

---

## 1. The shape of the mistake

`SyncService._pullWorkouts` opens its loop like this:

```dart
final workoutServerId = w['id'] as String;
if (await _db.workoutDao.getWorkoutByServerId(workoutServerId) != null)
  continue;
```

Read it as what it is: *if I already have a row with this id, I know what this
workout contains.* That is a cache-validity claim, and nothing anywhere
establishes it. The local row and the server row share an id and nothing else.

This is a reconciliation loop that reconciles only the rows it does not have. It
cannot detect drift; it can only detect absence. And it runs on every launch and
every resume, which is what makes it feel trustworthy — a sync that runs
constantly and never reports a problem looks like a sync that is working.

> A pull that short-circuits on what it already holds is not a reconciliation.
> It is a cache fill. It will hide any amount of divergence for as long as the
> cache survives, and hand you all of it at once when the cache is dropped.

The account switch drops the cache. `clearAllUserData` (`app_database.dart`)
empties fourteen tables, the next pull takes the full-insert path for every
workout, and a year of accumulated server-side garbage lands in one go.

Everything below is about how the garbage got there.

---

## 2. The edit that was never pushed

`saveCompleteWorkout` (`workout_dao.dart`) builds its companion like this — this
is the version that shipped:

```dart
final workoutCompanion = WorkoutTableCompanion(
  id: ..., name: ..., description: ..., difficulty: ...,
  estimatedDurationMinutes: ..., isTemplate: ...,
  scheduledDate: ..., completedDate: ...,
);
```

No `syncStatus`. On an insert that is correct — the column defaults to `0`,
`pending`, and the workout gets pushed. On an **update** it is silently fatal,
because a drift companion omitting a field leaves that field alone. A workout
that had synced stayed at `1`, `synced`.

And the only query that finds work to push is:

```dart
Future<List<WorkoutTableData>> getUnsyncedTemplates() =>
    (select(workoutTable)..where(
      (w) => w.isTemplate.equals(true) & w.syncStatus.isNotValue(1),
    )).get();
```

So: **once a workout had synced, no edit to it was ever pushed again.** Not the
name, not the difficulty, not the set counts. `markWorkoutPendingUpdate` existed,
three lines below that query, with zero callers — written by someone who saw the
gap, and never wired up.

The reason this was not obvious is that the workout mostly *looked* synced,
because a second mechanism papered over the common case. `_syncMissingWorkoutExercises`
sweeps every workout that has a `serverId` and pushes any exercise lacking one.
Adding an exercise therefore worked. Changing a prescription worked, because the
set-template batch is keyed off the exercise. Only the operations that need the
workout row itself to re-enter the queue were lost — and the important one is
deletion.

### Why deletion was the one that hurt

Removing an exercise does the careful thing. From `saveCompleteWorkout`:

```dart
if (ex.serverId != null) {
  // don't hard-delete yet — mark it pendingDelete so SyncService can
  // issue the DELETE call first
  ... syncStatus: Value(3)
} else {
  ... hard delete ...
}
```

That comment is correct and the code implementing it is correct. The row is kept
precisely so that sync can tell the server about it. But the only code that
drains `pendingDelete` rows lives inside `_syncUpdateWorkout`:

```dart
for (final we in exercises.where((e) => e.syncStatus == 3)) {
  await _syncDeleteWorkoutExercise(we);
}
```

and `_syncUpdateWorkout` is reached only from `syncWorkoutTemplates`, which
iterates `getUnsyncedTemplates()`, which the workout was no longer in. There is
a `getUnsyncedWorkoutExercises()` that would have found these rows directly. It
also had zero callers.

So the flag was set, correctly, on a row that nothing would ever read. The
exercise vanished from the user's screen — the UI queries filter
`syncStatus.isNotValue(3)` — and stayed in the workout on the server forever.

**Three pieces of code, each individually right, arranged so that the intent
never travelled between them.** The delete marker was written by code that
assumed someone would drain it; the drain existed but sat behind a gate that a
third piece of code had quietly stopped opening. No type error, no exception, no
failing request. The DELETE was simply never attempted.

---

## 3. The duplicates

Two independent sources, both long-standing.

**Exercises.** `_syncNewWorkoutExercisesBatch` POSTs a batch and stamps the
returned ids onto the local rows:

```dart
for (var i = 0; i < valid.length && i < serverList.length; i++) {
```

If the response is lost — the app is killed, the connection drops, the array
comes back short — the server has committed the rows and the client does not
know their ids. Those rows still have `serverId == null`, so on the next run
`_syncMissingWorkoutExercises` posts them again. `POST api/Workout/{id}/exercises/batch`
had no idempotency (`WorkoutService.cs`), so the workout grew a second copy.

**Set templates.** Saving a workout deletes every local set template and
re-inserts the lot ("ALWAYS rebuild template sets", `workout_dao.dart`). The
rebuilt rows have no `serverId`, so they are pushed as new. Until 1.0.2+12 the
batch endpoint *appended* rather than replaced (see
`docs/trainer-session-review.md` §4), so each save left another complete copy of
the prescription on the server. That endpoint is fixed; the rows it created are
still there.

Neither was visible in the app. `_pullWorkouts` never re-read those workouts,
and the trainee UI builds a workout from local rows. Session Review saw the set
duplicates from the other side and was taught to collapse them — server-side,
for the trainer. The sync client, the other reader of the same data, was not.

---

## 4. Why the delay was a separate bug

The startup sync is throttled:

```dart
final lastSyncMs = prefs.getInt('last_sync_timestamp');
if (DateTime.now().difference(lastSync) < const Duration(hours: 6)) return;
```

and the WorkManager background task stamps that same key:

```dart
await syncService.syncAll();
await prefs.setInt('last_sync_timestamp', ...);
```

`syncAll` is the **push**. The background task never calls `pullAll` at all. So a
background run that downloaded nothing still convinced the foreground that
everything was fresh, and the pull that would have fetched the account's real
data was skipped for the next six hours.

One key was being used to answer two different questions. The fix is two keys:
`last_pull_timestamp` (`auth_provider.dart`) now gates the pull, and only a run
that actually pulled sets it.

---

## 5. What changed

### The push path stops creating drift

- `saveCompleteWorkout` promotes an edited workout from `synced` to
  `pendingUpdate`. Only from `synced`: `pending` and `pendingDelete` both
  outrank an update and must not be overwritten by one.
- `_syncUpdateWorkout` marks the workout synced **after** draining its
  exercises, not before. It did the mark first, so a throw part-way through the
  loops left the rest stranded behind a row that already looked done — and for
  the `pendingDelete` rows, which have no other push path, permanently.
- `_syncMissingWorkoutExercises` now asks the server what the workout holds
  before creating anything, via `_stampWorkoutExercisesFromServer`, and links
  local rows to what is already there. Matching is on
  `(exercise serverId, orderPosition)`, and each server row is claimed at most
  once. When the GET fails it creates nothing and retries next run: a missed
  push costs one cycle, a duplicate costs the user a cleanup they cannot
  perform.
- `AddExerciseToWorkoutAsync` (`WorkoutRepository.cs`) returns the row already
  occupying `(WorkoutId, ExerciseId, OrderPosition)` instead of inserting a
  second. Every caller is a sync push, so a repeat POST is always a retry.

`OrderPosition` is in both keys deliberately. A workout may legitimately contain
the same movement twice — a superset pairing it with itself, which
`saveCompleteWorkout` has its own comment about — and those instances differ only
by slot. Keying on the exercise alone would have merged real supersets. Two
entries sharing the exercise *and* the slot cannot be anything but a duplicate.

### The pull path heals what is already stored

Idempotency does nothing for the rows already on the server, and this is a
training log — we are not writing a migration that deletes someone's history to
make a list look tidier. So the reader folds them, the same two-halves shape as
`docs/trainer-nutrition-duplicate-meals.md` §4:

- `_collapseDuplicateServerExercises` — one entry per `(exerciseId, orderPosition)`.
- `_collapseDuplicateSetTemplates` — one row per `setNumber`. Set numbers are
  ordinals within an exercise, so two templates numbered 2 *are* the same set.
  Not a heuristic; the same reasoning Session Review already uses.
- `_pullScheduledWorkouts` gained the stamp-instead-of-insert fallback that the
  scheduled-workout row and the set rows around it already had.

### The de-duplication passes stopped eating the wrong row

`_deduplicateScheduledExercisesByContent` kept the lowest local id. The lowest id
is generally the stale unstamped row, so the pass deleted the row that had just
been linked to the server and left the group unlinked — ready for the next pull
to re-create the twin and the next dedup to delete it again. It now prefers the
linked row, matching `_deduplicateWorkoutsByContent` and
`MealDao.deduplicateMeals`, which both already did.

It also **moves logged sets to the survivor** instead of deleting them
(`_moveLoggedSets`), and the scheduled-workout pass refuses outright to delete a
session that has logged sets. A de-duplication pass that can destroy training
history is worse than the duplicate it removes.

### Sign-out clears the device, and says what that costs

`clearAllUserData` used to run at the *next* login, and only when the username
differed from `last_logged_in_user`. That left one account's rows on disk under
the next account's bearer token — a sync firing in that window pushes the wrong
person's workouts into the wrong person's account.

`confirmAndSignOut` (`feature/auth/presentation/sign_out.dart`) now clears on the
way out, from both sign-out entry points. It pushes what it can first, and if
anything is still pending it says how many and lets the user cancel. That matters
more than it looks: for a `pendingDelete` row the row is the *only* record that
the user deleted something, so discarding it silently resurrects whatever they
removed. The login-time check stays as a backstop for the paths that never reach
this function — a refresh token expiring mid-session, or a crash mid-sign-out.

### `DELETE api/Workout/{id}` stopped returning 500

`ScheduledWorkout → Workout` is `Restrict` (`AppDbContext.cs`), so deleting any
workout the user had ever scheduled raised a foreign-key violation. This is the
same bug `DeleteWorkoutExerciseAsync` was fixed for one level down, and it was
never applied one level up. Sessions with nothing logged are placeholders and are
deleted with the workout; if any session has logged sets the workout is kept and
the API returns **409**, not 500. A `bool` could not express that — "not deleted"
had to mean both "no such workout" and "this one never can be" — hence
`WorkoutDeleteResult`.

---

## 6. What to take from this

- **Ask what makes a cache valid.** `if (I have this id) continue;` is a claim
  that the local copy is current. Sharing an id is not evidence of that. If you
  cannot point at what keeps the two in step, you are not syncing, you are
  filling a cache.
- **A flag is not an action.** The delete marker was set correctly by code that
  assumed something would drain it. The drain existed. The gate in front of the
  drain had quietly closed. Three correct pieces, no working whole — and nothing
  in between them was typed, so nothing complained.
- **Zero callers is a finding, not a curiosity.** `markWorkoutPendingUpdate` and
  `getUnsyncedWorkoutExercises` were both dead, and both were dead *because* of
  the bug. An unused helper on a critical path is usually the fix somebody
  started.
- **The device that causes the divergence is the one that cannot see it.**
  Every reader here was local, and every local reader agreed with the local
  write. It took emptying the database to get an honest look at the server.
- **Idempotent writes beat cleanup, but only for the future.** Making the batch
  endpoint idempotent stops new duplicates and does nothing for the ones already
  stored. Both halves are needed, every time.
- **A de-duplication pass needs a rule for which row survives.** "Lowest id" is
  not a rule, it is an accident of iteration order — and here it was exactly
  backwards, which turned a cleanup into a loop that regenerated its own input.
- **One key cannot answer two questions.** `last_sync_timestamp` meant "we
  pushed" to one caller and "we're up to date" to another, and the disagreement
  cost users six hours of stale data at a time.
