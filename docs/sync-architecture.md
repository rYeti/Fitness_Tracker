# Sync: how it works, why it kept breaking, and the rules it leaves behind

A walkthrough of the device ↔ server sync, written to be read on its own. It
starts with why the same kinds of bug kept coming back after seven separate
post-mortems had each fixed one, then goes through what changed, the decisions
behind it that aren't obvious from the diff, and the rules to keep.

This is part one of a staged rework. Part one changes only the app. Later parts
change the API as well: the device mints every row's id, the pull fetches only
what changed, and each side is told when the other changes something. Those
parts will be added here as they land.

Line references are to the commit that introduces this document.

---

## 1. Four symptoms, four causes

Users reported four things, "every now and then":

| Symptom | What was actually happening |
|---|---|
| **Duplicates** — workouts, exercises, sets or meals shown twice | A create is a POST, and the device learns the new row's id only from the response. A lost response, a retry or two sync runs at once makes a second row. The code compensated by *guessing* identity — by workout name, by `(exercise, position)`, by `(workout, day)` — and eleven "dedup" passes ran on every sync, some of them deleting data. |
| **Edits revert** | "This row needs pushing" was a flag every writer had to remember to set, and "the server has this" was stamped without checking. Forgetting the first loses the edit. Doing the second while the user edits mid-request loses it too. Then the pull, which trusts a clean row to match the server, puts the old value back. |
| **Data missing or late** | One crash (§2) stopped every pull after the workouts step, for good, on any device where an exercise with history had been removed. Separately, the whole launch/resume sync — the push included — was throttled to once every six hours, so a finished session reached the trainer hours later. |
| **Deleted things come back** | The device inferred "deleted elsewhere" from a row's absence in a full list, and handled it by *pushing the row again*. Seven screens also hard-deleted synced rows without leaving any record the push could act on, so the server kept them and the next pull restored them. |

The seven existing post-mortems (`docs/sync-*.md`, `docs/workout-exercise-order.md`,
`docs/trainer-exercise-notes.md`, `docs/logged-set-sync.md`) each fixed one
instance of these, and each was right. What none of them could change is that
the *structure* made the next instance likely: a rule that every call site must
follow, enforced by nothing, is a rule that the next call site breaks. Part one
moves those rules to places that can't forget them — the database, the enum,
the type of a thrown exception — and removes the code that guessed.

---

## 2. The crash that stopped the pull

### What happened

`WorkoutExerciseTable` rows use a fifth status, `4` ("retired"), for an
exercise that has left a workout but that logged sets still point at
(`docs/sync-dangling-references.md`). It was deliberately kept *outside* the
`SyncStatus` enum. `_reconcileWorkoutFromServer` then read every local
exercise's status like this:

```dart
if (SyncStatus.values[local.syncStatus] != SyncStatus.synced) continue;
```

`SyncStatus.values` has four entries. `values[4]` throws `RangeError`.

The sequence that reached it is ordinary:

| Step | Device | Server |
|---|---|---|
| Trainee removes an exercise they have history for | row → `pendingDelete` | live |
| Push | DELETE sent, then the local row is **hard-deleted** | kept, `RemovedAt` set |
| Pull 1 | server lists the exercise as retired; no local row has its id, so a new one is inserted with status `4` | — |
| Pull 2 | `_reconcileWorkoutFromServer` reaches the `4` → `RangeError` | — |

Nothing caught it. `_pullWorkouts` had no try/catch, and neither did `_pullAll`.
So every step after workouts — plans, sessions, food, meals, weights, meal
templates — stopped running on that device. `main.dart` stamps the pull
timestamp only after `pullAll` returns, so it was never stamped. That meant
every launch and every resume ran a full push and a full pull, downloaded the
account's whole history, and crashed at the same line.

### Why nothing caught it

- **The compiler couldn't.** `syncStatus` is an `int` column. `values[i]` is a
  legal expression for any `int`. The enum's doc comment explained that `4`
  existed and was not a member, but nothing checks a comment.
- **The tests couldn't.** Every test that involved a retired exercise pulled
  once. The crash needs two pulls, because the first one is what creates the
  row the second one trips on.
- **The users couldn't tell.** The app works fine from local data. Nothing
  says "your plans haven't synced for three weeks"; things just quietly stop
  arriving.

### What changed

- `retired` is now the fifth member of `SyncStatus` (`workout_tables.dart`).
  Every stored status is read with `SyncStatus.fromDb(int)`, which never throws.
  A value only a newer build could write reads as `synced`: it is neither pushed
  nor deleted, and the next pull reconciles it. Being a member means every
  exhaustive `switch` must now say what it does with a retired row. The
  compiler enforces what the comment only asked for.
- The four identical enums (`SyncStatus`, `FoodItemSyncStatus`,
  `MealSyncStatus`, `WeightSyncStatus`) are now one.
- `pullAll` runs every step even when an earlier one fails, and each server
  record is applied in its own savepoint (`_applyEach`), so one bad record costs
  that record, not the step. If any step failed, `pullAll` throws
  `SyncIncompleteException` *after* all of them have run. The caller (`main.dart`)
  doesn't stamp the pull, so the failed steps are retried next launch rather
  than in six hours.
- The push no longer hard-deletes an exercise that sessions point at; it
  retires it (§6). The pull reattaches sessions that an older build had already
  orphaned (`_relinkOrphanedScheduledExercise`).

`sync_rework_test.dart` › *a workout holding a retired exercise* reproduces the
original `RangeError` against the old code.

---

## 3. The database records every change the sync engine needs

### The bug class

Every one of these was found by reading the code; the tables are from that
survey.

| Where | What it wrote | What it forgot |
|---|---|---|
| `workouts_list_view.dart` | plan rename | to mark the plan dirty |
| `edit_view.dart` | workout colour, plan `isFreeChoice` | the same |
| `create_view.dart` | colour on an existing "Rest Day" | the same |
| `FoodItemDao.hideFromRecent` | `hidden_from_recent` | the same |
| `MealDao.addFoodToMeal` | a food added to an already-synced meal | to mark the *meal* dirty — entries were only pushed from the meal's own push |
| `edit_view.dart` | a new plan link | to mark the *plan* dirty |
| `removeScheduled`, `removeWorkoutFromPlan`, `deleteExercise`, `deleteFoodFromMeal`, … (seven in all) | a hard delete of a row the server has | to leave any record the push could act on |
| `ExerciseDao.saveExercise` | `INSERT OR REPLACE` of an edited custom exercise | that REPLACE deletes the row — its server id went, and the next push created it on the server again |

`docs/sync-account-switch-duplication.md`, `docs/workout-exercise-order.md`,
`docs/trainer-exercise-notes.md` and `docs/logged-set-sync.md` each fixed one
of these by hand, at one call site. They all end on the same rule: *a write
that changes a synced row's pushed columns must dirty that row*. That rule was
correct, but a rule like that is only as good as the next person's memory.

### Why nothing caught it

A drift companion makes every column optional. Leaving `syncStatus` out of a
write is not an error; it is the normal way to say "don't touch this column".
So a write that forgets to dirty a row looks, to the type system, exactly like
one that deliberately doesn't. The tests couldn't catch it either, because each
half is correct alone. The DAO test sees the new value read back, and the
reconcile test sees a clean row overwritten from the server, which is what
reconcile is for. The failure is in the contract *between* them.

### The design

`lib/core/sync/sync_triggers.dart` lists every synced table once, with the
columns the push sends. From that list, SQLite gets three kinds of trigger:

| Trigger | Fires when | Does |
|---|---|---|
| `sync_<t>_update` | a column the push sends **actually changes** (`NEW.c IS NOT OLD.c`) | `local_rev + 1`; `synced → pendingUpdate` |
| `sync_<t>_owner_*` | a row of an *owned list* is added, changed or deleted — a workout exercise's set templates, a session exercise's logged sets, a meal's foods, a plan's workouts | the same, to the owner |
| `sync_<t>_delete` | a row with a server id is deleted | a row in `sync_deletion_table` (kind, server id, and the route ids the DELETE needs) |

The push reads the dirty rows as before. It also drains `sync_deletion_table`
first, before any create or update, so a food removed from a meal and then
added back reaches the server as a delete followed by an add. A 404 means the
row is already gone, and a 409 means the server refused. Either way retrying
won't change the answer, so the entry is dropped.

Some details that matter:

- **"Actually changes".** `saveCompleteWorkout` rewrites every exercise row on
  every save. A trigger that fired on *any* write would PUT every exercise of a
  workout because the user renamed it. `workout-exercise-order.md` rejected
  exactly that, since it races a trainer's edit. The `WHEN NEW.c IS NOT OLD.c`
  clause keeps the push proportional to the edit.
- **Only `synced` is promoted.** `pending` (never pushed), `pendingDelete` and
  `retired` are each a stronger statement than "edited". Several DAO methods
  used to write `pendingUpdate` outright. On a row being deleted, that un-deleted
  it.
- **Owned lists dirty their owner.** The server replaces a set-template list or
  a session exercise's log as a whole. So the question the push needs answered
  is "did this *list* change", and a deleted set leaves no row behind to ask.
  The owner is where that answer lives.
- **Built-in exercises don't count.** The exercise table's trigger only fires
  for `is_custom = 1`; the built-in ones are the server's, not the user's.

### How the sync engine writes without triggering itself

The pull writes server data into synced tables, the push marks rows synced, and
dedup folds duplicates. None of that is a local edit.
`AppDatabase.untracked(body)` runs `body` inside a transaction that sets a
single flag, `sync_apply_guard_table.active`. Every trigger checks that flag
and does nothing while it's set.

Three properties make that safe, and they are worth knowing before touching it:

1. **Nothing else runs while the flag is up.** Drift blocks every statement
   outside a transaction until it finishes (`engines.dart`,
   `_StatementBasedTransactionExecutor`: "blocks the main database for the
   duration of the transaction"). The WorkManager isolate has its own
   connection, but SQLite allows one writer at a time, and the flag is only
   visible to other connections once committed. The flag is cleared before
   commit, so another connection never sees it set. So no user edit can land
   while the flag is up and be missed.
2. **It can't be left set.** It is cleared before the transaction commits, and
   a transaction that throws rolls the flag back with everything else. As a
   belt-and-braces measure, `beforeOpen` clears it again on every open. If it
   were ever stuck on, every trigger would go silent forever, so it is not
   trusted.
3. **It holds the write lock.** Nothing inside `untracked` may await the
   network, or every save in the app waits for the request. That is why the
   pull fetches a list first and then applies it in chunks of 40 records per
   transaction (`_applyEach`). One transaction for the whole pull would freeze
   the app's writes for its duration. One per record would pay for a disk sync
   per record on a first pull of years of history.

It is a table rather than a Dart flag because the triggers live in SQLite and
can only read SQLite. It is not a `TEMP` table because a trigger in the main
schema cannot see one.

### Installed from code, not migrated

`installSyncTriggers` runs in `beforeOpen`. It reads the existing trigger SQL
from `sqlite_master` and rewrites only the triggers that differ. So **adding a
column the push sends is one line in the map**. No migration, no schema bump,
nothing to remember elsewhere. An unchanged launch costs a single read of
`sqlite_master` (`sync_tracking_migration_test.dart` › *opening again leaves the
triggers as they are*).

### What was rejected

- **Keep fixing call sites.** That is what had been happening, and it's how
  this list grew.
- **A helper every write must go through** (`markDirty(companion)`). This is
  the same discipline in a new place, and it doesn't cover a raw `update()` or
  `replace()` in a screen, which is where most of the bugs above were.
- **A revision counter the DAOs increment.** Same problem.

### Consequences in the DAOs

The hand-written promotions in `saveCompleteWorkout`, the scheduled-workout
skip, unskip and postpone, the session notes, `updateFoodItem` and the active
workout are gone; the triggers do it. `saveCompleteWorkout` now rebuilds an
exercise's set templates only when the prescription actually differs. Under the
owned-list rule, rewriting an unchanged list would mark the exercise dirty on
every save. `saveExercise` and `saveWorkoutPlan` update in place instead of
`INSERT OR REPLACE`.

---

## 4. "Clean" is a claim, now checked: `local_rev`

Every synced entity table has `local_rev`, which the triggers increment on
every local change. Before a request, the push reads a row. After it, the row
is marked with `_markSent`:

```sql
UPDATE t SET server_id = ?, sync_status = CASE
  WHEN sync_status IN (0, 2) AND local_rev = ? THEN 1   -- nothing changed meanwhile
  WHEN sync_status = 0 THEN 2                           -- a create edited in flight
  ELSE sync_status END                                  -- e.g. deleted in flight
WHERE id = ?
```

This is what it guards against:

| Time | Device | Server |
|---|---|---|
| t0 | weight 81 (`pendingUpdate`, rev 1); push sends 81 | — |
| t1 | user corrects it to 82 (rev 2) | receives 81 |
| t2 | *before:* marked `synced` — 82 is never sent | 81 |
| t3 | *before:* next pull sees a clean row and writes the server's 81 back | 81 |

Now at t2 the revs differ (2 ≠ 1), so the row stays `pendingUpdate` and 82 goes
out on the next push. A create edited while its POST was in flight becomes
`pendingUpdate` with its new server id, rather than staying `pending` and being
POSTed a second time.

Meal templates live in SharedPreferences, where no trigger can reach.
`MealTemplateDao` keeps the same two facts by hand: `dirty` and `rev`. An edit
used to drop the template's server id, so the push created a copy and the pull
brought the original back beside it. It also records deletions, and the push
now sends the template PUT and DELETE calls it never made before.

---

## 5. Deleted elsewhere means deleted here

The old `_reconcileAll` fetched seven full lists on every push. Any synced local
row missing from its list was reset to `pending` with its server id cleared, and
pushed again. That was written for one situation: rows removed from the server
by hand, when the device was the only writer. Once a second device or a trainer
could delete things, it put back everything they deleted. It also reset a
workout's `retired` and `pendingDelete` exercises, which then re-created
exercises the user had removed.

`_removeDeletedElsewhere` now runs at the end of each pull step, on the list
that step already fetched:

| A local row the server no longer lists that… | Is |
|---|---|
| is clean | deleted here, with its dependents |
| holds an unsent change | left for the push |
| is a workout a session logged sets against | kept, the same way the server keeps (409s) one |
| is a custom exercise a workout uses, or a food a meal logged | kept |
| is in a list that came back **empty** while this device holds synced rows for it | not touched this run |

The last row is a guard, not a rule. An empty answer is far likelier to be a
server fault than a user who deleted everything, and this is not an operation
to get wrong on a guess. It is also the admission that "absent from a list" is
still an inference; part three replaces it with explicit tombstones.

The reverse race is also closed. A row deleted here but not yet reported to the
server is skipped by the pull (`_deletedHere`), rather than being restored until
the DELETE goes out.

---

## 6. Foreign keys are not enforced, and the code was written as if they were

Nothing in the app runs `PRAGMA foreign_keys = ON`, and SQLite's default is off.
Every `onDelete: KeyAction.cascade` in `workout_tables.dart` is declarative
only. A delete never cascades; it orphans. Several pieces of code, and
`docs/sync-dangling-references.md` §3, assumed otherwise:

- **`WorkoutDao.deleteWorkout`** deleted logged sets `where
  scheduledWorkoutExerciseId == <workout exercise id>`. That compares an id from
  one table with the id column of another. Both tables count from 1, so it
  removed the sets of whichever *unrelated* sessions happened to hold those
  numbers, and left the deleted workout's own templates and sessions behind. It
  now deletes the workout's templates, exercise entries, plan links and
  unlogged placeholder sessions, and refuses (returns `false`) when a session
  of it holds logged sets.
- **`_syncDeleteWorkoutExercise`** hard-deleted the exercise entry after the
  server's DELETE. The session entries pointing at it survived as orphans, and
  `watchForScheduledWorkout` (an inner join) stopped showing them. So the
  history for that lift vanished from the very device that logged it. It now
  retires the row when anything references it.
- **Session and meal deletes** removed the parent row only. They now remove
  exercises and sets, or a meal's foods, explicitly.
- **Every dedup fold** now *moves* what hangs on a duplicate to the row it keeps
  — sessions, logged sets, exercise entries, a meal's foods — before removing
  it (`_deduplicateAll`, `_merge*`).

**Why not turn foreign keys on?** Because existing installs already hold
orphans. Enforcement would also turn every remaining hard delete of a parent
into a *cascade*, silently deleting history instead of orphaning it. A missing
cascade shows up as rows that vanish from one screen; an unexpected one
destroys them. Deleting dependents explicitly keeps each deletion visible at
its call site.

---

## 7. Guessing identity

Two guesses caused real damage, and both are gone:

- **`_deduplicateWorkoutsByContent`** treated any two workouts with the same
  name as duplicates. A trainer assigning "Upper A" to a client who already had
  an "Upper A" produced two same-named workouts. One was deleted on the device
  (never on the server), the next pull restored it, and the next dedup deleted
  it again. The deleted one's exercise entries went with it, orphaning the
  sessions that pointed at them. **A name is not an identity.** The pull's
  matching step, which linked a never-synced local workout to a server workout
  of the same name, went too.
- **The session-exercises batch** (`POST api/ScheduledWorkout/{id}/exercises/batch`)
  returns *every* entry the session has, in no promised order. The client
  paired the response to its request by index, so an entry could be linked to
  the wrong exercise, and its sets then pushed under it. It now matches on the
  workout exercise each entry performs.

Part two removes the reason these guesses existed: once the device mints the
id, there is nothing to match.

---

## 8. Runs that overlapped: the lease

`SyncService` joins a caller to a run already in flight
(`docs/sync-concurrent-runs.md`), but through static fields, which exist once
per isolate. The WorkManager task runs in another isolate, with its own
`SyncService` and its own connection to the same file. Two pushes at once POST
the same pending rows, and most creates on the server can't tell a retry from
a new row.

`SyncLease` (`lib/core/sync/sync_lease.dart`) is a single row in the database,
which every isolate sees. It is taken with a conditional `UPDATE`:

- the holder is a token per *run*, not per isolate, so a push and a pull in the
  same isolate don't overlap either;
- it expires after five minutes, and is renewed between steps, so a run killed
  mid-sync stops blocking the next one;
- a run that can't get it within 30 seconds doesn't run. A sync that didn't run
  is retried on the next trigger; a sync that ran alongside another is how
  duplicates got onto the server.

Sign-out waits for it before clearing the database. The background isolate now
closes its connection when it's done. The native connection sets
`PRAGMA busy_timeout = 5000`: SQLite's default is to fail a write that finds the
file locked rather than wait, so a save made while the background sync held a
transaction threw "database is locked".

---

## 9. Pushing when something changes

The six-hour throttle in `_runInitialSync` returned before the push as well as
the pull. A session finished at the gym reached the server — and the trainer —
on the next launch after six hours, or from the daily background task.

`SyncScheduler` (`lib/core/sync/sync_scheduler.dart`) now pushes:

- ten seconds after the synced tables go quiet, so a set logged mid-workout is
  on the server within seconds of the last keystroke;
- immediately when the app goes to the background, which is when a trainee
  finishes and locks the phone;
- on launch and resume;
- again after a failure, backing off from 30 seconds to 10 minutes, while in
  the foreground.

Frequent pushes are affordable because a push now only does work proportional
to what changed:

- reconcile moved into the pull;
- the two sweeps that walked every workout and session each push now find
  their candidates with one query (`_syncWorkoutExercises`,
  `_syncMissingScheduledExerciseSets`);
- the legacy dedup folds run at most every ten minutes;
- settings are only PUT when they differ from what this process last sent;
- a push with nothing pending is one `COUNT`.

The pull keeps its six-hour throttle until part three makes it cheap.

The logged-set push changed shape along the way. Any change to an exercise's
log sends the **whole log** to the replace endpoint. The per-set PUT is gone,
because a deleted set leaves nothing to PUT, and the owner being dirty is how
it is now noticed.

---

## 10. What the tests pin

In `test/sync/sync_rework_test.dart` unless noted. Each was run against the old
code first, or against the old code restored for that one behaviour, and failed
there.

| Test | Pins |
|---|---|
| *a workout holding a retired exercise* | §2: the `RangeError`, and that the pull goes on |
| *a pull step that fails* | §2: later steps run; `SyncIncompleteException` names the failed one |
| *two workouts with the same name* (2 tests) | §7: both survive a sync; no link by name |
| *deleting a workout* (2 tests) | §6: other sessions' sets survive; refused while logged |
| *removing an exercise that has logged history* (2 tests) | §6: retired, still shown, pulled twice without duplicating; orphans reattached |
| *a row deleted elsewhere* (4 tests) | §5: deleted, not re-pushed; unsent change kept; empty list trusted for nothing; a session goes with its sets |
| *a synced row deleted on this device* (6 tests) | §3: one DELETE; not restored by a pull first; 404 dropped; 500 kept; a meal's food; sign-out is not a deletion |
| *the database marks a synced row changed* (9 tests) | §3: a real change dirties; an unchanged write, an engine write and a pending delete don't; plan rename, `hideFromRecent`, custom vs built-in exercise; a meal's new food and a plan's new workout dirty the owner, and are pushed |
| *an edit made while its push is in flight* | §4 |
| *a meal template the server has* | §4: an edit is a PUT, not a copy; a delete is sent and not undone by a pull first |
| *a session's exercises created on the server* | §7: linked by exercise, not position |
| *the sync lease* (2 tests) | §8: excludes a second run; an expired one is taken over |
| *the push scheduler* (2 tests) | §9: pushes after an edit; a no-op when nothing's pending |
| `sync_tracking_migration_test.dart` (2 tests) | §3: a v40 install upgrades, its existing rows are tracked; reopening rewrites nothing |

Existing tests changed in two ways. The ones that seed "already synced" data now
seed it through `db.untracked` — the way the sync engine would have written it.
And the two RPE tests expect an edited set to go out in the whole-log batch
rather than as a single PUT. One `FoodItemDao` test asserted that editing a
never-pushed food made it `pendingUpdate`. It now stays `pending` so it is still
created, and both cases are pinned.

---

## 11. The rules this leaves behind

- **A new column the push sends goes in `sync_triggers.dart`.** Nothing else.
  If it isn't in the map, the database won't notice an edit to it — and the
  push won't send it, because the push map is the other half
  (`docs/logged-set-sync.md` §7).
- **The sync engine writes inside `db.untracked`, and nothing else does.** A
  pull, a mark-synced, a dedup fold, a wipe. A screen that wraps its own write
  in it has just made an edit that will never leave the device.
- **Nothing inside `untracked` awaits the network.** It holds the write lock.
- **Don't set `syncStatus` in a DAO to mean "edited".** The database does it,
  and does it correctly for `pending` and `pendingDelete`. Setting `pending` on
  a new row (the column default) and `pendingDelete` on a row being deleted are
  still yours to do.
- **Deleting a synced row locally is enough to delete it on the server.** Any
  delete outside `untracked` is recorded. The flip side: a local-only cleanup
  of synced rows must run inside `untracked`, or it becomes a server DELETE.
- **Foreign keys are off.** Delete dependents explicitly, and never delete a
  row that history references; retire it or move what hangs on it.
- **Read a status with `SyncStatus.fromDb`.** Never index `values`.
- **Absence from a list is not proof of deletion,** and resetting a row to
  `pending` to "recover" it creates a duplicate. Until part three, only a clean
  row with nothing hanging on it is deleted on absence.
- **A name, a position or a response index is not an identity.**

---

## What is deliberately not here yet

- **Client-minted ids and idempotent creates** (part two). Until then the
  server-side matching fallbacks (`_stampWorkoutExercisesFromServer`,
  `_stampMealFoodEntriesFromServer`, the unlinked-row stamps in the pull) stay.
  They are guesses, but guesses that prevent duplicates rather than cause them.
- **An incremental pull with tombstones** (part three). The pull still
  downloads everything, which is why it keeps its throttle.
- **Live updates to the Trainer Console and to the trainee's phone** (part
  four).
- **Foreign-key enforcement** — see §6 for why not.
- Deleting a plan from the workouts list marks *every* session of it
  `pendingDelete`, including ones with logged sets, which the server then
  hard-deletes. The trainer console's plan delete keeps history. That is a
  product decision, not a sync defect, and it is left for the owner.
