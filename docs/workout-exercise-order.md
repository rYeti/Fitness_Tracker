# The reorder that never left the phone: why a workout's exercise order changed on its own

A trainee opened *OK B* at the gym and found the exercises in a different order
from the one they had set. Nobody had edited the workout. From the gym floor it
looked random: the app had shuffled the list.

It hadn't. It had **put back an order the trainee had changed**, because the
change had only ever existed on the phone, and the server — which still held the
old order — was treated as the truth the next time the app synced.

Line references are to the commit that introduces this document.

---

## 1. What actually happened

Reordering a workout goes through the edit screen
(`edit_single_view.dart`, the drag handle), which renumbers every exercise
`index + 1` and hands the whole workout to `WorkoutDao.saveCompleteWorkout`.
That method updates each existing `WorkoutExerciseTable` row in place — same
row id, new `orderPosition` — so history logged against those rows stays
linked.

It updated the position. It did not update `syncStatus`.

That one omission is the whole bug, but it only became visible when a second,
unrelated change landed. Here is the sequence on a device that already has the
workout synced:

| Step | Local row (Bench / Row) | `syncStatus` | Server |
|---|---|---|---|
| Pulled from server | 1 / 2 | synced / synced | 1 / 2 |
| Trainee drags Row above Bench | 2 / 1 | **synced / synced** | 1 / 2 |
| Push runs | 2 / 1 | synced / synced | 1 / 2 — nothing sent |
| Pull runs, workout is clean → reconcile | **1 / 2** | synced / synced | 1 / 2 |

The push (`SyncService._syncUpdateWorkout`) does look at the exercises of an
edited workout, but it only sends the ones whose own status is
`pendingUpdate` (`syncStatus == 2`). The workout row itself was correctly
promoted to `pendingUpdate` — that was fixed in
`docs/sync-account-switch-duplication.md` — so the push ran, sent the workout's
name and description, found no dirty exercises, and marked the workout synced
again.

Now the workout *and* its exercises are clean, and a clean row is a promise
that the local copy matches the server. The pull's reconcile pass
(`_reconcileWorkoutFromServer`, added in `docs/trainer-workout-builder.md` so a
trainer's edit reaches a device that already has the workout) takes that
promise at face value and writes the server's `orderPosition` onto every clean
exercise. The old order comes back.

Sync runs on launch and on every resume. Switch to Spotify between sets, come
back, and the order you set last week can quietly revert.

### Why it looked random rather than "reverted"

Two things blur the pattern:

- An exercise **added** since the last push is a new row (`pending`), so it is
  pushed with its new position while its neighbours are not. After the next
  reconcile, old positions and new positions sit side by side, and two rows can
  end up sharing a slot.
- Both listing queries (`getWorkoutExercisesWithTemplates`, used by the active
  workout screen, and `getCompleteWorkoutById`) ordered by `orderPosition`
  alone. SQLite makes no promise about the order of tied rows, so a tie could
  come back one way today and the other way tomorrow.

"Some of my reorder stuck, some didn't, and two exercises swap back and forth"
is exactly what randomness looks like from the outside.

---

## 2. Why nothing caught it

**The compiler couldn't.** `WorkoutExerciseTableCompanion` makes every column
optional. Leaving `syncStatus` out of a write is not an error — it is the normal
way to say "don't touch this column" — so an update that forgets to dirty the
row is indistinguishable, in the type system, from one that deliberately
doesn't.

**The tests couldn't.** Each half was correct in isolation and tested that way:

- `saveCompleteWorkout` writes the new positions — true, and a local read-back
  shows them.
- Reconcile overwrites a clean row with the server's values — true, and that is
  exactly what it is for.

The failure is in the *contract between them*: reconcile assumes "clean" means
"the server already has this", and the save path broke that assumption. No
single-unit test exercises that seam, and the local UI looks right right up to
the next sync.

**It was latent for months.** Before the trainer Workout Builder shipped, the
pull skipped any workout it already held. The unsent reorder was never pushed,
but nothing ever read the server's copy back either, so the phone's order
survived — wrong on the server, right on the phone, and invisible. Reconcile
didn't create the bug; it made the server's stale copy *matter*.

---

## 3. The fix

### 3.1 Dirty the exercise row when it actually changes

`saveCompleteWorkout` now compares the incoming `orderPosition`, `notes` and
`supersetGroupId` against the stored row, and if any differ **and** the row is
currently `synced`, stamps it `pendingUpdate`
(`fittnes_tracker/lib/core/database/daos/workout_dao.dart:447-461`). This is
the same rule the method already applied to the workout row a few lines above,
applied one level down:

- Only `synced` is promoted. `pending` (never pushed) and `pendingDelete`
  outrank an update and must not be overwritten by it.
- Only a *changed* row is promoted. `saveCompleteWorkout` is called for every
  small edit — adding a set, renaming the workout — and rewrites every exercise
  row each time. Promoting unconditionally would PUT every exercise of the
  workout on every save. The comparison keeps the push proportional to the
  edit.

Once the row is `pendingUpdate`, the existing push path does the rest:
`_syncUpdateWorkoutExercise` sends `PUT api/Workout/exercises/{id}` with the new
position, the server (`WorkoutRepository.UpdateWorkoutExerciseAsync`) stores it, and the next
reconcile agrees with the phone instead of overruling it. Reconcile also
already skips a dirty exercise row, so a pull that happens to run *before* the
push leaves the reorder alone.

### 3.2 A deterministic order for tied positions

Both listing queries now order by `orderPosition`, then by row `id`
(`workout_dao.dart:213-216`, `:295-298`). This doesn't make a collision correct,
but it makes it *stable*: two rows sharing a slot show in the same order every
time, instead of trading places between loads. Accounts that already carry a
tie from the bug stop flickering, and the next reorder the trainee saves
renumbers everything contiguously and pushes it.

### 3.3 Edits in the legacy edit view no longer drop supersets

`edit_view.dart` rebuilt an exercise by hand when adding, deleting or editing a
set, listing every field except `supersetGroupId`. The rebuilt exercise went
through `saveCompleteWorkout` with a null group, silently un-pairing a
superset. Before this change that loss stayed local (and was then undone by
reconcile, which is its own kind of confusing). With 3.1 in place, the null
would have been a *change* — promoted and pushed — making the loss permanent on
the server. Those three call sites now use `e.copyWith(sets: …)`, which carries
every field the exercise already had.

This is the same shape as the `FoodItemModel.fromData` rule in
`docs/trainer-console-micronutrients.md`: a model rebuilt field-by-field at a
call site is correct only until someone adds a field.

### What was rejected

- **Never reconcile exercise positions from the server.** That would hide this
  bug and break the trainer Workout Builder, whose reorders reach the trainee
  only through reconcile.
- **Always promote on save.** Correct, but turns every set edit into a PUT per
  exercise, and a PUT that races a trainer's edit overwrites it with values the
  trainee never changed.
- **Renumber positions inside `saveCompleteWorkout`.** Callers disagree on the
  base (the create screen is 0-based, the edit screens 1-based, the trainer
  console 0-based), so normalising here would dirty every exercise of every
  older workout on its first save. The id tiebreak makes a collision harmless
  without rewriting anyone's data.

### Tests

`test/sync/sync_service_test.dart`, group *reordering the exercises of a synced
workout*:

- a reorder leaves both rows `pendingUpdate`, and `syncAll` PUTs each with its
  new position — this fails against the old save path with every row still
  `synced`;
- a save that doesn't touch an exercise (a rename) leaves it `synced`, so the
  promotion stays proportional.

---

## 4. The rule it leaves behind

> **A write that changes a synced row's pushed columns must dirty that row.
> "Clean" is a promise that the server already has it, and reconcile will cash
> that promise.**

This is the rule from `docs/sync-account-switch-duplication.md` — *a
`syncStatus` left unchanged is an edit that never leaves the device* — showing
up one table further down. That document fixed it for the workout row; this
one fixes it for the exercise rows beneath it. The general form is worth
checking every time a DAO method gains an `update(...)`:

1. Which of the columns I'm writing does the push send?
2. If any, does this write promote `synced` → `pendingUpdate` (and leave
   `pending` / `pendingDelete` alone)?
3. Is there a pull path that overwrites clean rows? If so, a missing promotion
   isn't a lost edit that might one day sync — it's an edit that *will* be
   reverted.

Adding a reconcile pass anywhere turns every missing promotion upstream of it
from invisible into user-visible. Before adding one, grep for every write to
the table it reconciles.
