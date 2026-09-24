# Set 1, set 1, set 2, set 2: two ways a set ended up logged twice

A trainee opened an active workout and every exercise listed each set twice.
Typing a weight into the first "set 1" filled the second one too. The same week, a
trainer opening Session Review for that client saw one exercise's "set 1"
eight times, in pairs: 5, 5, 8, 8, 5, 5, 5, 5.

These look like one bug but are two, with a common pattern. Each is a
**delete-then-insert that assumed nothing else would touch the rows in between,
or afterwards.** Neither is a type error. Neither throws. Every test in the suite
ran one sync at a time against a server that did whatever the test told it,
so every test was green.

Line references are to the commit that introduces this document.

---

## 1. Why typing into one set fills the other

`active_workout_view.dart` keys every text field on the set number:

```dart
return '${scheduledId}_${workoutExerciseId}_${setNumber}_$field';
```

Two set templates numbered 1 therefore get *the same* `TextEditingController`.
The screen isn't wrong; it faithfully draws a table that holds two rows claiming
to be set 1. The question is how the table came to hold them.

## 2. The first cause: two pulls at once

`_runInitialSync` (`main.dart`) runs from `initState` **and** from every
`AppLifecycleState.resumed`. Its six-hour throttle is stamped only once
`syncAll()` and `pullAll()` have *finished*. The notification-permission dialog at
sign-in, pulling down the shade, or switching apps for a moment all fire
`resumed`. If that happens while the first sync is still running, the throttle
hasn't been stamped yet, so a second, complete sync starts alongside the first.

Nothing stopped it. Every caller (main.dart twice, Settings twice, sign-out)
builds its own `SyncService`, and the service had no notion of a run in progress.

Most of what the pull does survives running twice. One step didn't.
`_reconcileWorkoutFromServer`, added so a trainer's edits reach a device that
already has the workout (`docs/trainer-workout-builder.md`), refreshes each
exercise's set templates in `_replaceLocalSetTemplates`:

```
read local rows → all clean? → delete them all → insert the server's
```

Run twice, interleaved at every `await`:

| Pull A                | Pull B                | Table         |
|-----------------------|-----------------------|---------------|
| read: 1, 2 (clean)    |                       | 1, 2          |
|                       | read: 1, 2 (clean)    | 1, 2          |
| delete all            |                       | —             |
|                       | delete all            | —             |
| insert 1, 2           |                       | 1, 2          |
|                       | insert 1, 2           | 1, 2, 1, 2    |

Ordered by set number, that's the screen the trainee saw.

**The fix has two halves because there are two kinds of "at once".**
`syncAll` and `pullAll` now hold their in-flight run in a *static* field and hand
it to any caller who arrives while it runs (`sync_service.dart`, top of the
class). Static, because no instance lives long enough for an instance field to
guard anything. That covers one isolate. The background WorkManager task runs in
another isolate, with its own `SyncService` and its own database connection,
which no Dart field can see. So `_replaceLocalSetTemplates` is now a single
`transaction`, and SQLite's own locking serialises it against everyone.

> A delete-then-insert "replace" is only a replace if nothing can run between
> the delete and the insert. Otherwise it is two operations, and two of them
> interleaved is an append.

## 3. The second cause: a save that forgets what it already sent

This is the one Session Review showed, and it doesn't need twin templates at all.

`_saveCurrentExercise` (the active workout's debounced save, and the full pass
`_completeWorkout` makes at the end) does this for the current exercise:

```dart
await (db.delete(db.workoutSetTable)..where(...)).go();
for (final template in exerciseData.templates) { ... insert ... }
```

The fresh rows have no `serverId`. That's deliberate. They are new rows.
But consider a background sync that runs mid-workout:

1. The trainee logs set 1 (5 reps). Save: one local row, unsynced.
2. A sync pushes it. The server now has copy **A**; the local row is stamped `A`.
3. The trainee touches any field. Save: delete the row stamped `A`, insert a new
   unsynced one. Nothing tells the server; the id `A` has just been discarded.
4. The next sync pushes the new row. `POST …/sets/batch` **appended**, so the
   server now holds **A** and **B**.

Every save that follows a push adds another full copy of the exercise. The
values differ between copies because the trainee was typing between them, which
is why the console's pairs weren't all the same number. It sorts by set number,
so every copy of set 1 came first and the set 2 copies were further down the
list.

Then the pull made it worse on the device. It inserted every server set whose
id the device didn't recognise, and it didn't recognise **A**, because step 3
threw that id away. So the stale copies came back onto the trainee's phone beside
the real rows. It also "helpfully" stamped an unsynced local row with a server id
from the same exercise and set number. That marked the trainee's newest values
as synced with the id of an *older* copy, so they were never pushed at all.

### What changed

The same shape as the set-template fix in `docs/trainer-session-review.md` §4,
one table over:

- **The server replaces.** `AddSetsBatchAsync` now calls
  `ScheduledWorkoutRepository.ReplaceSetsAsync`. It deletes the exercise's logged
  sets and inserts the batch in one transaction. An empty batch changes nothing.
- **The client always sends the whole log.** Once any set in an exercise is new,
  `_syncSetsForScheduledWorkout` sends every set in that exercise. A partial list
  would now delete the sets that already made it across. Local `pendingDelete`
  rows are simply dropped afterwards, because the replace already removed them.
- **The pull decides per exercise, not per set** (`_reconcileLoggedSets`):

  | Local log                                   | What the pull does                 |
  |---------------------------------------------|------------------------------------|
  | holds an unpushed set                       | leaves it; the push will replace   |
  | empty                                       | inserts the server's               |
  | every id still on the server, plus extras   | re-queues it to overwrite them     |
  | an id the server no longer has              | takes the server's                 |

  The third row does the healing. On the trainee's own phone the local rows
  are the ones they typed, and the server's extras are the stale copies. Rather
  than pulling the copies down, the pull marks the local log unsynced, and the
  next push *replaces* the server's copy with the device's. That cleans up the
  trainer's view with the right numbers, not a guess. The fourth row can only
  mean another device replaced the log, because a replace always mints fresh ids.
- **Local copies are folded before any push.** `_deduplicateLoggedSets` and
  `_deduplicateSetTemplates` run in `_deduplicateAll`. Logged sets keep the
  lowest local id: a save rewrites the whole exercise, so any copy the old pull
  inserted came *after* the rows the device wrote itself. Templates keep the row
  linked to the server. Either way, an exercise that lost a row is re-queued
  whole, and the replace push clears the same twins from the server.
- **The readers fold too.** `getWorkoutExercisesWithTemplates` and
  `getCompleteWorkoutById` return one template per set number. Sync is throttled
  to six hours, so without this a device holding twins would keep drawing them,
  and the builder would save them straight back as pending rows until then.

## 4. What is still true, and why

A session held only on the server (the trainee reinstalled, or it was logged on a
phone that no longer syncs) has no device-side copy to overwrite its stale rows.
`WorkoutSet` has no creation timestamp, so the server can't tell which copy was
last. The pull folds these to one per set number when it brings them down, but
which copy survives there is an accident of row order. Session Review still
shows every copy of such a session. That's honest, if ugly: hiding all but one
would mean silently choosing numbers for the trainer.

Logged sets still don't carry RPE through the sync (the batch DTO has no field
for it; see the TODO on `WorkoutSet.Rpe`). That's why the console's RPE column
reads "—". It's a separate gap, unrelated to the duplication.

## 5. What to take from this

- **"Replace" is two operations until something makes it one.** Delete-then-insert
  is only a replace under mutual exclusion. Two of them interleaved produce a
  union. Put them in a transaction, or be certain nothing else can run.
- **A throttle stamped on completion doesn't throttle anything concurrent.** It
  only spaces out runs that have already finished. The window in which a second
  caller can start is the whole duration of the first run.
- **Look at who constructs the thing you're guarding.** An instance field on a
  service that every caller news up is a lock nobody shares.
- **Rewriting rows locally discards their server identity.** If the local save
  deletes and re-inserts, the server endpoint has to replace. An append endpoint
  plus a rewriting client is a duplicate generator, one copy per save after each
  push.
- **Tests that run one thing at a time can't see this class of bug.** The new test
  in `sync_service_test.dart` fires two `pullAll()`s with `Future.wait`. Before
  the fix it reproduces the user's `[1, 1, 2, 2]` exactly.
- **Heal from the side that knows.** The server couldn't tell which copy was
  current; the trainee's device could. Re-queuing the device's log so it
  overwrites the server repairs the data with real values. A server-side fold
  would only have picked one.
