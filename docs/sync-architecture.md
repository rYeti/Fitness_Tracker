# Sync: how it works, why it kept breaking, and the rules it leaves behind

A walkthrough of the device ↔ server sync, written to be read on its own. It
starts with why the same kinds of bug kept coming back after seven separate
post-mortems had each fixed one, then goes through what changed, the decisions
behind it that aren't obvious from the diff, and the rules to keep.

The rework is staged. Part one (§1–§13) changes only the app. Part two
(§14–§25) changes the API as well: the device mints every row's id, and a
create can tell a repeat from a new request. Part three (§26–§44) makes the
pull fetch only what changed, and tells a device about deletes instead of
leaving it to infer them. Part four (§45 onwards) tells each side when the
other changes something, so neither has to wait for its next sync to see it.

Line references are to the commit that introduces each part.

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

  The push checks for logged sessions *before* it sends the DELETE, and keeps
  the workout when there are any. It shows the workout again: `pendingUpdate`
  if the server has it, `pending` if the server never did. Checking only
  afterwards, as an early version did, left the workout stuck. Sessions push
  after workouts, so the server often doesn't know about the sets yet and
  accepts the DELETE, but the local delete then refuses. The row stayed hidden
  and `pendingDelete` for good, re-sending the DELETE on every push and keeping
  the sign-out warning up. That is the rule from
  `docs/sync-account-switch-duplication.md` — a status left unchanged is an
  edit that never leaves the device — in its delete form. Caught in review.
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
- it expires after five minutes unless renewed. A heartbeat renews it every 30
  seconds while the run is alive, however long any one step takes. So it only
  runs out when the process can't run at all — killed, or suspended in the
  background mid-sync — and a dead run stops blocking the next one within
  minutes;
- a run whose lease was taken while it was suspended finds out the next time it
  checks and stops, with `SyncLeaseLostException`. The checks are between steps,
  every 40 records within a pull step, and per workout or session in the push's
  long loops. What it hadn't finished is still pending and goes on the next
  run;
- a run that can't get the lease within 30 seconds doesn't run, and says so:
  `syncAll` and `pullAll` throw `SyncBusyException`. A sync that didn't run is
  retried on the next trigger. A sync that ran alongside another is how
  duplicates got onto the server.

An early version of this returned quietly when it couldn't get the lease, and
`pullAll` then completed as if it had run. `main.dart` recorded the pull time
and skipped pulling for six hours, and Settings reported "Restore complete".
The realistic trigger was a slow background push still holding the lease when
the app resumed. It was caught in review, and it is the general shape of every
"skipped" path: **a caller acts on "it finished", so "it didn't run" has to be
something it can't mistake for that.**

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
| *deleting a plan* | §12: trained sessions and their sets stay, placeholders go, nothing trained is deleted on the server, kept sessions end up detached |
| *a deleted workout that sessions logged sets against* (2 tests) | §6: kept and shown again, never left pending; one never pushed is created instead |
| *a session's exercises created on the server* | §7: linked by exercise, not position |
| *the sync lease* (4 tests) | §8: excludes a second run; a run that lost it stops; a push or pull that couldn't get it throws `SyncBusyException`; an expired one is taken over |
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

## 12. Deleting a plan keeps what was trained

The workouts list deleted a plan by marking *every* session it had scheduled
`pendingDelete` — trained ones included. The push then sent each DELETE, and
the server removed the sessions and their logged sets for good. The plan
editor had the opposite problem: it marked only the plan and left every
session behind, including future ones nobody would ever train, on the
calendar under a plan that no longer existed. The Trainer Console's plan
delete was a third rule, keeping all of a plan's days.

Asked which one is right, the owner's answer was that deleting a plan keeps
the history of the workouts trained under it. Both screens now call
`WorkoutPlanDao.deletePlanKeepingHistory`:

| A session of the plan that… | Is |
|---|---|
| has any logged set, or was marked complete | kept |
| was never trained (a future or missed placeholder) | deleted — off the calendar at once; the database records its server DELETE |

The plan is marked `pendingDelete`, and once the server has deleted it,
`deleteWorkoutPlan` detaches the kept sessions (`workout_plan_id = NULL`) — the
local half of the server's `ON DELETE SET NULL`, which nothing else would do
here with foreign keys off. A session's workout is untouched, so its history
still shows under Progress and Session Review.

This is the first place the deletion outbox (§3) paid for itself outside a
bug fix: deleting the placeholders is a plain delete, and reaching the server
takes no code of its own.

---

## 13. Where the code lives

`SyncService` was one 3,500-line file. It is now one library in `lib/core/sync/`,
split by what it syncs. The split was a separate commit that moves code and
changes nothing else.

| File | Holds |
|---|---|
| `sync_service.dart` | the class: entry points (`syncAll`, `pullAll`), the lease and step isolation, `_markSent`, the deletion outbox drain, `_applyEach`, and since part three the changes cursor, `_applyTombstones` and `_goneElsewhere` (which replaced `_removeDeletedElsewhere`) |
| `exercise_sync.dart` | custom exercises; linking built-in exercises to their server ids |
| `workout_sync.dart` | workouts, their exercise entries, set templates |
| `plan_sync.dart` | plans and the workouts in them |
| `session_sync.dart` | scheduled workouts, their exercises, logged sets |
| `nutrition_sync.dart` | food items, meals and their foods, meal templates |
| `body_sync.dart` | settings and weight records |
| `sync_dedup.dart` | the folds that heal legacy duplicates |
| `sync_triggers.dart` | the pushed-column map and the triggers made from it |
| `sync_lease.dart` | `SyncLease` |
| `sync_scheduler.dart` | `SyncScheduler` |

The domain files are `part`s of `sync_service.dart`, each an extension on
`SyncService`, so they share its private members. A *static* member of the
class has to be written `SyncService._name` inside an extension, because an
extension doesn't see its target type's statics unqualified.

---

# Part two: the phone mints every id

Part one made the device honest about what it had changed. It left one thing
exactly as it was: who decides what a new row is called. The server did, and
the device found out from the response to its POST. Part two moves that
decision to the device, where the row is created, and changes the API so a
create can be told apart from a repeat of one.

It is the one part of the rework that changes both sides at once, so it is
built to be deployed in the order CI deploys it: the API goes out on merge,
ahead of any app release, and every change to it keeps shipped apps working.

---

## 14. Why a retry made a second row

### The shape of the problem

A push that creates a row is a POST. Under server-minted ids, the row's
identity is born on the server, travels back in the response, and only then
reaches the device, which writes it into `server_id`. Until that last step the
device has no way to refer to the row, and no way to ask about it.

Now lose the response. Nothing exotic is needed: the client gives up after 15
seconds (`receiveTimeout` in `api_client.dart`), and a Cloud Run instance
starting cold can take longer than that while it still finishes the request.
Or the phone goes into a tunnel. Either way:

| What actually happened | What the device observes |
|---|---|
| The server never got the POST | the call throws; `server_id` stays null |
| The server stored the row; the answer was lost | the call throws; `server_id` stays null |

This is `docs/chat-architecture.md` §2 in a different costume: the two cases
look identical from the device, and guessing is wrong in both directions.
Chat solved it by generating the message id on the client, so a retry carries
the same identity as the original. Sync never did. Its retry was a brand-new
POST with no identity at all, and the server, which had no way to tell a
repeat from a new request, stored a second row. Two sync runs at once (part
one §8) did the same thing without any network fault.

### Why nothing caught it

- **The compiler couldn't.** `serverId` was a `String?`, and "null means the
  server doesn't have it" was a convention written in doc comments
  ("UUID assigned by the remote API after first successful sync"). Nothing
  ties a nullable column to the state of another machine. The one fact the
  code needed — did the server store it? — was not representable in the
  device's types at all, because the device genuinely didn't know.
- **The tests couldn't.** The fake API answered every POST. No test ever lost
  a response, because a lost response is not a return value you stub; it is
  the absence of one. On the server, every create test called the create once.
  A duplicate needs two requests carrying one intention, and each test carried
  one request.
- **The users mostly couldn't see it.** The trainee app folds on read: one
  meal per category, one session per workout per day. It rendered a server
  holding three copies of a lunch as one lunch. The Trainer Console did not
  fold, and listed every copy. `docs/trainer-console-duplicate-rows.md` and
  `docs/trainer-nutrition-duplicate-meals.md` are the reports that followed.

### What grew around it

Because the device could not name the row it had just created, it guessed.
Each guess was reasonable in isolation, and each was eventually wrong somewhere:

| Compensation | What it guessed |
|---|---|
| `_stampWorkoutExercisesFromServer` | before creating a workout's exercises, GET the workout and link any local row to a server row with the same exercise at the same position |
| `_stampMealFoodEntriesFromServer` | after a meal create, link local foods to server foods by food item |
| `_syncMissingScheduledExerciseSets` | GET every session whose exercises had no id, and link them by workout exercise |
| `_relinkMissingScheduledExercises` | the same, again, in the pull |
| the pull's "unlinked row" fallbacks | a local meal with no id for the same day and category *is* the server's meal; the same for a session on the same day |
| the batch answers | the *n*th row of the response is the *n*th row of the request |
| server-side content checks | a create for an occupied slot returns the row in it (4 of the 14 creates had one) |
| eleven dedup folds | whatever the guesses above got wrong, fold it afterwards |

Part one removed the two guesses that did real damage. Part two removes the
ones that stood in for an id. The content checks stay, on both sides, for a
reason §17 gives, and the folds stay until the data they heal is gone (§22).

---

## 15. The id is minted where the row is made

Every synced table's `server_id` now has a client default
(`clientDefault(newSyncId)`, `lib/core/database/tables/sync_tables.dart`): a
random version-4 UUID, generated in Dart when the row is inserted. A row has
its global identity before its first push. Every create sends it, every retry
sends the same one, and a row pulled from the server still takes the server's.

Two tables are deliberate exceptions:

- **Built-in exercises.** They are the server's rows, not the device's. The
  seeder inserts them with `server_id` explicitly null, and
  `_syncSystemExerciseIds` links each one to the server's id by its exact name
  (§20). A seeded exercise with a random id would be a reference to nothing.
- **Plan links.** The server never names a link; a link is one plan and one
  workout. Older builds stored the *plan's* server id in the column, which is
  the clearest sign it was never an identity.

### "Not pushed yet" is a status now

The id stopped meaning "the server has this". That fact moved to
`sync_status = 0` (`pending`), which it had always half-duplicated. The change
is one sentence, and it touched every place that had asked the question the
old way: the push sweeps, the pull's fallbacks for unpushed local rows, the
delete trigger, the dedup folds' preference for "the row the server knows",
three DAO call sites and the meal-template store. Two of those — the delete
trigger and the meal-template store's delete — turned out not to want the
status either, and now ask nothing but whether the row has an id. The
subsection after next explains why. The rest now ask it one way,
`SyncStatus.isOnServer`, and §19 is about when a row stops being `pending`.

It is worth being precise about why this was the risky part of the change.
Every one of those checks read `serverId == null`, and after this change every
one of them still compiles — it is simply false for every row, forever.
Nothing fails. A fallback that adopted an unpushed local meal quietly stops
adopting it, and the pull inserts a second meal beside it. The pull's
"session links" step, which GETs a session whenever one of its exercises has
no id, becomes a step that never GETs anything; that one was harmless only
because nothing needed it any more (§22), so it was deleted rather than
converted. The list above came from searching for every null test of a server
id, not from the compiler, and the rules whose failure would be silent are
pinned by tests that were run with the old null test put back (§24).

### The delete trigger

Part one's delete trigger recorded a server DELETE for any deleted row with a
`server_id`. Under server-minted ids that meant "any row the server has", and
the condition read naturally. Once every row had an id from birth, the first
version of part two moved the question to the status, the way the rest of
this section did: the condition became `OLD.sync_status != 0`, on the theory
that a row still `pending` never reached the server and deleting it here was
the end of it. That theory is wrong, and it is wrong in exactly the way §14 is
about.

`pending` records what this device has *heard*: no answer to a create yet. It
does not record what the server *holds*. §14's table has two rows that look
identical from the device — the POST never arrived, or it arrived and the answer
was lost — and a status can't tell them apart any better than a null id could.
Here is the second row, followed by a delete:

| Time | Device | Server |
|---|---|---|
| t0 | weight logged, `pending`, id X; the push POSTs X | stores X; the answer is lost |
| t1 | the user deletes it; status 0, so the trigger records nothing | X |
| t2 | the next push has nothing to send | X |
| t3 | the pull finds X listed and not held here, and inserts it | X |

The user deleted a weigh-in and it came back. Nothing exotic is needed for t0:
it is the lost answer §14 opens with. Nor for t1: a delete made while the POST
is still in flight lands the same way, because the row is still `pending`
when it goes. The first version of this section called the window ten seconds
wide. It is really "any time before the device hears back", which on a phone
that has just lost signal is as long as the phone stays offline.

The pull request that made the change named part three's tombstones as the
eventual cure. They can't be. A tombstone is the server's record of a delete
it carried out, so that a device that missed the delete can be told about it.
Here the server was never told: from where it stands, X is a live row, and an
incremental pull would deliver it as faithfully as the full one does. No fix on
the receiving side can make up for a message that was never sent.

So the condition is now just `OLD.server_id IS NOT NULL`, with each kind's own
extra condition as before (`_deletionCondition`, `sync_triggers.dart`). What
made the status test look necessary was the belief that a DELETE for a row the
server never had would be harmful. It isn't, and the reason is the same one
that made a client-minted id work in the first place: the id is known before
the POST, so the device can name the row whether or not it heard back, and a
DELETE by id is safe to send when there is nothing there. The server answers
404; `_pushDeletions` treats 404 and 410 as "already gone", 403 as "never this
account's" and 409 as a refusal a retry won't change, and drops the entry for
all four. (Every DELETE endpoint looks the row up by id *and* owner, so an id
that names someone else's row deletes nothing and answers 404.) A null id still
means the server can't have it — a built-in exercise, until
`_syncSystemExerciseIds` links it by name — and so records nothing. (Built-in
exercises are also excluded by their kind's own `is_custom = 1` condition,
which stays.)

The cost is one request for each row that is created and deleted inside one
push window, answered 404. Most owned lists don't pay it: a plan's workouts, a
workout exercise's set templates and a session's logged sets never reach the
outbox, because they go as a whole list from their owner. A meal's foods do —
each one removed is its own DELETE (§18) — so a food logged and taken out
again before the push costs one 404. The largest case is deleting a plan whose placeholder sessions haven't been
pushed yet — offline, say — which sends one DELETE per session, once. That was
the price the status test was avoiding. It is small, bounded, and paid once;
a lost delete is none of those.

Meal templates keep the same facts by hand, in SharedPreferences, and had the
same test in `MealTemplateDao.deleteTemplate`. They get the same fix: a
template with an id is remembered as deleted whether or not it was marked
pushed.

**What the fix makes dangerous.** Before it, a sync-engine delete of a
`pending` row that forgot `untracked` was harmless by accident: the status test
skipped it. Now every delete outside `untracked` of a row with an id becomes a
DELETE on the server. For most engine deletes that would be a wasted 404, but
not for all. `_deduplicateByServerId` folds rows that *share* a server id, and
the one it drops can be `pending`. Recorded, that DELETE would name the id the
kept row still holds — the live row on the server. So every engine-side delete
was checked, not assumed:

| Engine delete | Runs inside `untracked` |
|---|---|
| the push's own delete after it sent a DELETE (`_syncDelete*`), and retiring a workout exercise | yes, each call |
| `_mergeIntoServerMeal` — a new meal answered with one this device already holds moves its foods there and is deleted | yes, at its one call site |
| the legacy folds (`_deduplicateAll`), and the pull's content folds | yes, the whole of each |
| `MealDao.deduplicateMeals`, called by the pull and by the progress screen | yes, inside the method |
| `_removeDeletedElsewhere`, and the pull's per-record writes (`_applyEach`) | yes |
| the pull adopting an unpushed meal or session for the same day | restamps the row; deletes nothing |
| the 409 re-mints (`_mintNewIds`, a meal's food entries, a template's `assignServerId`) | change an id; delete nothing |
| the schema-42 heal (`_healBackfilledEntries`, §21) | changes an id; deletes nothing |
| `clearAllUserData` at sign-out | yes, and it empties the outbox |

None needed fixing. Two tests now pin the two where a tracked delete would do
the most damage (§24). The deletes that stay tracked are the user's own — the
calendar's remove, an exercise taken out of a workout, a weigh-in deleted,
a plan deleted with its placeholder sessions — and recording those is the point.

The general lesson is about what a flag can know. `sync_status` is this
device's record of its own conversation with the server: what it sent, and
what it heard back. It cannot say what the other side holds after a
conversation that broke off halfway, because the device genuinely doesn't know.
When a decision depends on a fact you can't observe, look for the action that
is correct under both answers. A DELETE by a client-minted id is one: it
removes the row if the server has it and costs a 404 if not. Skipping it was
correct under one answer only, and the tests happened to ask only that one.

### Why nothing caught the trigger

- **The compiler couldn't.** The condition is a string of SQL inside a trigger
  the database installs at open. Nothing typed ever sees it.
- **The test pinned the premise, not the failure.** *the server never had
  records no DELETE for it* built its "unpushed" row the obvious way: a row
  that was never sent at all, which is the one case where the status test is
  right. The fake could already lose a POST's answer (`postsLosingResponse`) —
  the retry test in the group above used it — but no delete test combined the
  two.
  A test written from inside a rule's own assumption can only confirm the
  assumption.

### Existing installs

Schema 42 (`if (from < 42)`, `app_database.dart`) gives every existing row
without an id one, in SQL rather than a Dart loop over rows: a
`randomblob`-based expression shaped like a v4 UUID, evaluated per row, one
statement per table. Before that it does three things the new rules need:

1. A row with no id that is marked `pendingUpdate` was never created on the
   server — the old push caught that by the null id and POSTed it — so it
   becomes `pending`, which is what now POSTs it.
2. A meal or plan whose list holds a food or workout that never reached the
   server is marked changed. §18 explains why: the owner's push is what sends
   its list now, and a clean one takes the server's list on the next pull.
3. A meal food without an id is flagged (`id_backfilled`) before it is given
   one. An id made up here, years after the food was logged, may not be the
   only id that food has: §21 is about the one it may already have on the
   server.

---

## 16. What the server does with an id

Every create DTO and every batch item gained an optional `Id`. One helper
resolves it for all of them (`ClientIds.CreateOrResolveAsync`,
`FitTracker.Api/Services/ClientIds.cs`):

| The id… | The create… |
|---|---|
| names one of the caller's rows | applies the sent fields to it, and returns it |
| names someone else's row | throws `ClientIdConflictException`, which a global filter answers with 409 |
| is new | inserts the row under it |
| was not sent | mints one, as before — every shipped app sends none |

### Why a repeat applies the fields

The obvious rule is "a repeat returns the row it already made". It loses an
edit:

| Time | Device | Server |
|---|---|---|
| t0 | workout pending; POST id=X, "Push Day" | stores X, "Push Day"; the answer is lost |
| t1 | user renames it "Push Day A" (still pending, `local_rev` 1) | X, "Push Day" |
| t2 | retry: POST id=X, "Push Day A" | *return-only:* answers X, "Push Day" |
| t3 | `_markSent` sees `local_rev` unchanged since t2's read → `synced` | X, "Push Day" |
| t4 | the next pull reconciles a clean row → "Push Day" is back | |

A retry is the device's latest word on the row, so the server applies it. That
makes a create with an id a total operation — "make the server hold this row
as I hold it" — and it paid for itself elsewhere. Part one's
`_keepWorkoutForHistory` had to decide whether a workout it was reviving was on
the server (`pendingUpdate`) or not (`pending`), from a null id that no longer
exists. It now always says `pending`: the create goes out under the workout's
id, and the server answers with its row updated, or makes one.

### Two requests, one new id

The lease (part one §8) stops two runs on one device, but not one request
arriving twice: a client that timed out and retried while the server was still
working on the first attempt. Both find the id free and both insert; the second
fails on the primary key. The helper catches that once and resolves the id
again, which now finds the first request's row.

One detail there is easy to get wrong. After the failed save, Entity Framework
still tracks the row it failed to insert. A tracking query for that key returns
the tracked instance, not the stored one — identity resolution — so the second
look would have been answered by the row that never landed, and the next save
in the request would have tried to insert it again. The repositories' inserts
go through `SaveNewAsync` (`DbContextExtensions.cs`), which stops tracking
whatever a failed save was inserting before the exception goes on.

### 409, and what the device does with it

A v4 UUID colliding with another account's is not something that happens by
chance. The 409 exists so that a guessed or replayed id can neither read nor
overwrite another user's row. The device's answer is to mint a fresh id for the
refused row and leave it pending (`_mintNewIds`, `sync_service.dart`), which
costs nothing: nothing on the server refers to an id it never accepted. This is
also why the push never sends a *reference* to a row the server doesn't have
yet (`_serverIdIfPushed`) — a workout exercise naming a custom exercise that
hasn't been created. Held back until the exercise is created, the reference can
never point at an id that later gets replaced. (Held back means the row that
refers *waits*; §19 is about the version of this that sent null instead.)

`_mintNewIds` only touches rows that are still `pending`, which is what makes
it safe to hand a whole refused batch: a row the server already holds keeps
its id. A meal's foods have no status column, and they are upserted every time
their meal changes, so most of any batch of them is on the server already, under
the ids it carries; a fresh id for each of those would store every one of them
a second time. So the 409 names the id it refused
(`{ "error": "id_in_use", "id": … }`), and only that entry is re-minted
(`_refusedId`).

### A guard that was dead became a hole

`ScheduledWorkoutRepository.CreateScheduledWorkoutAsync` opened by looking the
session up by id — with no owner in the condition. While the server minted
every id this could never match; `docs/trainer-console-duplicate-rows.md` §5
records it as "a guard keyed on an identity the caller never supplies guards
nothing". The moment the app started supplying one, the same line would have
answered anyone who named an id with that session, sets and all. The lookup is
gone; the helper's, which checks the owner, replaces it. The general point is
the reverse of the one that doc made: code that is harmless *because* an input
never arrives stops being harmless the day it does, and nothing marks it.

---

## 17. Why the server still de-duplicates by content

Client ids make one intention idempotent: however many times a device sends
"create meal X", there is one meal X. They say nothing about two intentions.
Two devices logging lunch on the same day mint two ids for what the product
says is one meal. So do a phone before and after a reinstall. Only content can
see that those are the same row:

| Create | Content key the server keeps |
|---|---|
| meal | user, day, category (`docs/trainer-nutrition-duplicate-meals.md`) |
| session | workout, UTC day (`docs/trainer-console-duplicate-rows.md` §3) |
| workout exercise | workout, exercise, position |
| session exercise | session, workout exercise |

So a create can still answer with a different id from the one it was sent.
**The device keeps whichever id comes back** — `_markSent` stores it — and
that is a rule, not a detail: a device that kept its own would push updates to
a row the server doesn't have.

It also means the part of the create that *follows* has to be written for an
answer that names an existing row. That was the lesson of
`docs/trainer-console-duplicate-rows.md` §2 — an idempotent outer call does
not make its side effects idempotent — and it has two halves. The first version
of this part got both wrong.

**What goes next must not replace what that row holds.** The first version
took the other meal's foods into the local one and then sent the union as the
meal's whole list. The union was only as complete as what this device could
see, and §18 is what the gap cost. Now `_mergeIntoServerMeal` only points the
local meal at the server's, and its foods are upserted into that meal one by
one: nothing in that request can remove a food it doesn't name.

**The row is not in step with the server yet.** The server answers a content
duplicate with its own row *as it holds it*: another device's session, not
completed; another device's meal, with that device's primary food; an entry in
the workout's slot, without this device's notes. The first version marked the
local row sent against the `local_rev` it had read, which made it clean — and a
clean row is the server's to overwrite on the next pull. A workout the user had
finished on this device showed as not done after the next sync.

| Time | Device | Server |
|---|---|---|
| t0 | session for today, completed here, `pending`; POST id=X | already has Y for that workout today, not completed; answers Y |
| t1 | `_markSent(Y, local_rev)` → `synced` | Y, not completed |
| t2 | the pull reconciles a clean row: completed ← false | Y, not completed |

That is §16's reason a repeat *applies* its fields, arriving from the other
side. §16 made the server apply what it was sent when it answers with the row
the id names. When it answers with a row the *content* names, it can't apply
anything — it has no way to know the two devices meant the same fields — so
the device has to know it wasn't applied. Every such answer is now marked with
`_markSent(…, -1)`: the row takes the server's id and stays `pendingUpdate`,
and this device's fields follow as an update of that row — later in the same
push for a workout exercise, in the next one for a session or a meal
(`_syncNewScheduledWorkout`, `_syncNewWorkoutExercisesBatch`, `_syncNewMeal`).
The update is last-writer-wins for the row's own fields, which is what every
other edit to it already is.

The rejected alternative was to have the server refuse a content duplicate
with 409. That is simpler on the server and strands the second device: it
holds a meal with foods in it and no way to learn which meal to put them in.

---

## 18. A meal's foods are upserted; a plan's workouts go whole

Part one sent two owned lists one member at a time: a meal's foods were added
with a batch and removed with `DELETE api/Meal/{m}/foods/{food}`, and a plan's
workouts likewise. Each removal needed a row in the deletion outbox carrying
the ids of both ends. The food DELETE was addressed by meal *and food item*,
so it could not say which of two portions of the same food to remove.

The first version of part two sent both lists the way set templates and logged
sets already went: whole, from their owner. The owner is what is dirty — the
owned-list triggers mark it for an addition, and marked it for a removal too —
and its push sent `PUT api/Meal/{id}/foods` with every entry under its id, or
`PUT api/WorkoutPlan/{id}/workouts` with every workout id. No outbox, and two
portions told apart by their ids. For plans it still works that way. For meals
it lost food, and a meal's foods are now upserted instead.

### What the whole list cost

A whole-list PUT says "the meal holds exactly these". A list this device builds
can only name what this device holds. Three ordinary situations left the
device's list short of the server's:

| Situation | What the PUT did |
|---|---|
| Device A logs lunch with a food it has just created, and pushes. Device B hasn't pulled since; it logs lunch too, and its create is answered with A's meal. | The merge added A's entries it could resolve. A's new food wasn't on B yet, so its entry was skipped — and B's PUT deleted it. A's copy of the meal was clean, so A's next pull deleted it there too. |
| A meal with an unsent change is skipped by the pull (a dirty list is this device's to send). Meanwhile another device adds a food to it. | The next PUT, built from the local list, erased it. |
| An entry whose food row is gone from this device (a dangling reference). | It had no food id to send, so it was left out — and deleted from the server, where the append-only push had always left it alone. |

The first version called the list's trade-off last-writer-wins, and for a
plan, that's roughly what it is. For a meal it was worse. Last-writer-wins
loses the other device's *edit*; this lost the other device's *data*, and the
"winning" device had never seen what it removed.

### Why nothing caught it

- **The compiler couldn't.** A list is a list. Nothing in the types says
  "complete" — whether the device's list was the meal's whole contents or only
  the part of it this device could see is a fact about another machine.
- **The tests couldn't, as written.** The fake API has no state: it answers a
  PUT with 200 and forgets it, so no test could observe what the server held
  afterwards. The merge test gave the other device's meal a food this device
  already had, so the one entry that would have been skipped never existed.
  And every test had one device; the failure takes two.
- **The design carried a rule across a boundary it doesn't hold across.** "The
  owner is dirty, and sends its list whole" came from set templates and logged
  sets, where it is right: those lists have one writer, the device that logs
  the set, so this device's list *is* the list. A meal has as many writers as
  the user has devices.

### Upsert by id, delete by id

A dirty meal now sends each of its foods to the foods batch that already existed,
`POST api/Meal/{id}/foods/batch`, as `{id, foodItemId}` (`_upsertMealFoods`).
The server stores each one through `ClientIds.CreateOrResolveAsync`: a repeat
of an id is that entry again, given the food sent; an id stored under another
of the caller's meals is moved into this one (the device's dedup folds move
foods between twin meals, ids and all); someone else's is refused with 409.
Nothing the request doesn't name is touched. Shipped apps send bare food item
ids, which the endpoint still reads, element by element, as new entries.

Removing a food is a DELETE again, recorded by the database like any other row
(`sync_triggers.dart`: the meal-food owned list has a deletion instead of
dirtying its owner on delete). It is addressed by the entry's own id —
`DELETE api/Meal/{m}/foods/{entryId}` — which is what tells two portions of
one food apart; the endpoint still takes a food item id from a shipped app.

Why this can't lose another device's food: every request names what it
changes. An upsert names the entries this device holds; a delete names one
entry this device removed. The server never has to read anything into an
absence. A dangling entry is neither sent nor deleted: it has no food id to
send, and its removal records nothing (the trigger's `EXISTS` condition) —
this device can't say what it was, so it says nothing.

| | Whole-list PUT | Upsert + DELETE |
|---|---|---|
| a food another device added, not yet pulled here | deleted | untouched |
| a food removed here | by its absence from the list | by its id |
| two portions of one food | by id | by id |
| a lost answer | the PUT again | the upsert again, which stores nothing twice |
| a food whose row is gone from this device | deleted | untouched |
| cost of a removal | nothing extra | one outbox row, one DELETE |

### What it still can't do

The upsert sends every food a dirty meal holds, including ones it pulled from
elsewhere. Suppose another device takes oats out of a meal this device holds.
If this device pulls first, the pull makes its clean copy of the meal match the
server's (`_applyServerMeal`), and the oats go. If it edits the meal *before*
pulling, the upsert sends the oats back. So a removal made on one device can be
undone by an edit on another that hasn't pulled — the reverse of the bug above,
and a much narrower one: an addition was erased whenever two devices logged the
same meal; this needs an edit to the same meal in the gap between the other
device's removal and this one's next pull.

Closing it needs one of two things: a sent/unsent state on every meal food, so
only unsent ones go, or the server's own record of what it deleted, so it can
refuse an upsert of an entry it has removed. The second is part three's
tombstones, which do it for every table at once (§23).

### A plan's workouts still go whole

A plan link has no id of its own: the server never named one, and older builds
stored the *plan's* id in the column. There is nothing to upsert a link by, so
a plan still sends its whole list, and a removal still dirties the plan. Two
rules keep that list from doing what the meal list did. It is only sent when it
is complete — while a workout in it is not on the server yet, the list waits
(§19) — and a clean plan takes the server's list on pull
(`_mirrorPlanWorkoutLinks`). What's left is last-writer-wins for the list: a
trainer adding a workout to a client's plan while the client's phone holds an
unsent change to that plan loses to the phone's list. The window is the push
debounce, ten seconds, and part three keeps last-writer-wins at the level of
the whole aggregate for the same reason: anything finer needs a version on
every row.

The server's replace now keeps exactly one link per workout. It used to keep
every link to a wanted workout, and the batch it replaced had stored a link
again each time it was sent one — so plans with twin links exist, and a replace
that kept them left the Trainer Console listing the workout twice.

### The replace endpoints keep ids, through one procedure

`ReplaceSetsAsync` and `ReplaceSetTemplatesAsync` used to mint fresh ids on
every replace, and the device paired the answer with its request by position.
So after every push, the ids the device held named rows the server had just
deleted, correct only for as long as nobody looked. Both now store each row
under the id it was sent with, and the device marks what comes back by id. An
id already stored under another of the caller's parents is moved (the device's
dedup folds move sets between twin session exercises, ids and all); one stored
under someone else's is refused with 409.

The replace was written out three times — the meal-food PUT was the third — and
the copies had already drifted: one detached the stale rows through a helper,
one pruned a loaded navigation, and none checked for foreign ids inside the
transaction. That last one mattered because the check was the only thing
keeping the bulk delete to the caller's rows: it deleted by parent *or by id*,
and an id is exactly what a caller chooses. Now there is one procedure,
`ReplaceListAsync` (`DbContextExtensions.cs`), and in one transaction it checks
for foreign ids, deletes — with the caller's ownership in the delete's own
condition — detaches, inserts and commits. The check makes the ordinary case a
clean 409. The ownership condition makes the race harmless: a row another
account stores under one of those ids between the check and the delete is not
deleted, and the insert fails on its key instead. A check that is a separate
read can only ever describe the past; the write has to carry the rule itself.

The batches that lead to a replace also stopped checking ownership twice. The
service used to ask who owned the parent, then call a repository that asked
again; now the repository's answer (null for a parent that isn't the caller's)
is the only check. An empty batch still asks, so it still answers 404.

---

## 19. `pending` ends the moment the server has the row

§15 moved "not pushed yet" from a null id to `pending`, and read it as "this
device hasn't heard back". The first version still set that status at the end
of a push rather than at the answer: `_syncNewPlan` marked the plan sent after
its workout list had gone, `_syncNewMeal` after its foods, and
`_mergeIntoServerMeal` gave the meal the server's id and left it `pending`
until the list succeeded. The reasoning — "marked first and then failing on
its list left the list behind a row that no longer looked like it had anything
to send" — was right about the list and wrong about the status. A failure
between the two requests left a row the server held at `pending`, and
`pending` is the one status every reader takes for "the server hasn't got it":

| Time | Device | Server |
|---|---|---|
| t0 | new plan P, and its placeholder sessions, `pending` | |
| t1 | POST P — answered | stores P |
| t2 | PUT P's workouts — times out; P stays `pending` | P |
| t3 | phase 5: a session of P. `_serverIdIfPushed(P)` → null, so `workoutPlanId: null`; marked `synced` | stores the session with no plan |
| t4 | nothing left to send for the session, ever | the Trainer Console lists it as unplanned |

Nothing on the device ever corrected t3: the session was clean, so the next
edit to it — if there ever was one — would have sent null again. The same read
dropped the workout from `_putPlanWorkouts`, which unlinked it on the server.

So every successful create or adoption now takes the row out of `pending`
straight away: `_markSent(…, -1)` records the server's id and leaves the row
`pendingUpdate` — on the server, still dirty — and whatever the push sends for
it next is what cleans it (`_syncNewPlan`, `_syncNewMeal`; `_mergeIntoServerMeal`
writes the id and the status in one statement). The status now records exactly
one fact: whether this device has heard the server has the row.

The one place that sets `pending` on purpose is `_keepWorkoutForHistory`, and
it is right to: it can't tell whether the server still has a workout it had
asked to delete, and with client ids it doesn't need to — the create goes out
under the id the workout already has, and the server answers with its row or
makes one (§16).

### One way to ask

"Is this row on the server?" was asked as `!= SyncStatus.pending` in some
places, `== SyncStatus.pending` negated in others, as a private `_onServer` in
the dedup folds, inside `_serverIdIfPushed`, and as `_pushed` in the meal
template store. It is now `SyncStatus.isOnServer`, beside `isDirty`, and every
Dart site asks that (the SQL filters that select by status keep their column
test; they can't call a getter). The template store, which keeps its facts in
SharedPreferences, calls its own check `_isOnServer` and documents it as the
same question. A question that decides what gets sent should have one
spelling, so that changing what it means changes it everywhere.

### A reference that can't be sent yet waits

`_serverIdIfPushed` returns null for a target that isn't on the server yet, and
the callers sent that null. The server can't tell "this session has no plan"
from "this session's plan hasn't arrived", so it believed the first. Null is not
an absence of an answer; it *is* an answer, and a wrong one.

Now a row whose reference can't be sent yet isn't sent. It stays dirty, and
goes on a later push, after its target's:

- `_scheduledWorkoutBody` returns null — the session waits — while its workout,
  its plan or the workout it was generated from is on this device but not on
  the server;
- `_putPlanWorkouts` sends nothing while a workout in the plan isn't on the
  server — sent without it, the list would unlink it from a server that may
  well have it (a lost answer, or a workout kept for its history);
- `_mealBody` waits for the meal's primary food, which it used to send as the
  all-zero id.

Pushes run in dependency order — workouts, then plans, then sessions — so the
usual wait is none at all: the target goes earlier in the same run. The wait is
for the run where the target's push failed. A target that is gone from the
device altogether is different: there is nothing to wait for, and the
reference goes as null (a plan deleted here has already detached its
sessions).

### Why nothing caught it

- **The compiler couldn't.** `_serverIdIfPushed` returns `String?`, and a null
  is exactly what a nullable JSON field takes. "Null because there is none"
  and "null because I can't say yet" have the same type.
- **The tests couldn't.** In every test the plan went up before its sessions,
  and the fake answered every request. The failure needs a request to fail
  *between* two requests of one row — the create answered, the list refused.

---

## 20. An answer says which item it answers

§17's content keys mean a batch, too, can answer an item with a row that isn't
the one it sent: the workout-exercise batch answers an item for an occupied
slot with the entry in it, and the session-exercise batch answers an item with
the entry the session already holds for that workout exercise, or under a fresh
id when the id sent is stored elsewhere. The first version paired such an
answer with its item on the device, by the server's own key — "matching on the
slot there is matching on the server's own key, not guessing". It was guessing:
the device's picture of the slot is not the server's.

| Time | Device | Server |
|---|---|---|
| t0 | entry *a* (Squat, position 0) removed: `pendingDelete`. Squat added back at 0 as *b*, `pending` | *a* in slot (Squat, 0) |
| t1 | the push creates first: POST *b* | slot taken: answers with *a* |
| t2 | no answer carries *b*'s id; the slot matches *a*, so *b* takes *a*'s id, `synced`, and *b*'s set templates replace *a*'s | *a* |
| t3 | the push sends *a*'s DELETE | *a* removed (or retired) |
| t4 | the next pull: *b* is clean and missing from the server, so it is retired | |

An undo, or taking the last exercise out and putting it back, and the exercise
vanished from every device. Two things were wrong, and both changed:

- **Deletes go first.** `_syncWorkoutExercises` sends a workout's removed
  entries before it creates anything, so by the time a create reaches the
  server the slot is free. A delete that fails stops that workout's push for
  the run, for the same reason.
- **The answer names its item.** Both batches now echo, on every entry that
  answers an item, the id that item was sent with (`requestedId`). Pairing is
  a lookup, not an inference, and the device never looks at a slot, a position
  or an order. Shipped apps read the keys they know and ignore the new one, and
  it is left out of every response that isn't a batch answer.

One pairing on the device is still not by id: the entries a session *create*
answers with. The server makes those itself, one per workout exercise, so
nothing was sent for them and there is no id to echo; they are linked by the
(session, workout exercise) key the server made them on — two ids, not a name
or a position. Anything they miss goes to the batch, which names its items.

### Names

The same guess was made with names. `_exerciseServerId` resolved a built-in
exercise this device hadn't linked yet through "a linked built-in of the same
name" — found with a substring search, so an unlinked Squat could go up as
Front Squat — and since the update path used it too, an edit could rewrite an
entry the server already held into a different lift, on every device and in the
Trainer Console. The push now matches nothing by name: an entry whose built-in
exercise isn't linked yet waits, `pending`, until `_syncSystemExerciseIds` links
it on the pull. That linking is now exact — the English name, else the German
one, ignoring case, each local row claimed once — and its old last resort, "the
only unlinked exercise a substring search turned up", is gone.

### Why nothing caught it

- **The tests answered in order.** Every stubbed batch answer listed its rows in
  the order they were sent and under the ids they were sent with; the slot
  fallback ran only in the one test written for it, whose slot held no row
  being deleted.
- **Test data had unique names.** No fixture held two exercises where one name
  contains the other, which is most of a real exercise catalogue.

---

## 21. The one content match: healing what schema 42 minted

Part one kept `_stampMealFoodEntriesFromServer` for one state, and the first
version of this part removed it for the reason §14–§16 give: with ids minted on
the device, nothing new needs it. The state is this. An older build's foods
batch committed on the server and its answer was lost, so the server's meal
holds this device's entries under ids the device never heard, while the
device's rows have no id. Schema 42 then gives those rows fresh ids — and they
are fresh, distinct from each other, and wrong: each is a second name for an
entry the server already holds under its first.

| Step | Device | Server |
|---|---|---|
| before the upgrade | lunch: five foods, no ids | lunch: the same five, under ids it minted |
| schema 42 | five fresh ids | |
| push | the lunch create is answered with the server's lunch; its five foods go up under the fresh ids | ten foods |

A lunch of five became ten: the doubled foods
`docs/trainer-console-duplicate-rows.md` §2 fixed, back for exactly the users
who had them before. Nothing new is at risk: data logged under this build has
had its id from the start. The migration's rows are.

So schema 42 flags each meal food it gives an id to (`id_backfilled`), and the
flag gets one look. Before a meal holding flagged foods is upserted — against
the foods its create was answered with, or one `GET api/Meal/{id}` for a meal
the server already had — and when the pull adopts such a meal, each flagged
food takes the id of an *unclaimed* server entry of the same meal naming the
same food item (`_healBackfilledEntries`). Unclaimed means no row on this
device holds that id, no deletion of it is waiting to go, and no other flagged
food took it first; so two portions each claim one entry, and a server entry
is claimed at most once. The flag is cleared whether or not a match was found.

The match needs no quantity of its own. A food item row is one logged portion
— adding a food writes a new row with that portion's macros — so the same food
item is the same food at the same amount.

Why this does not break "a name, a position or a response index is not an
identity": that rule is about pairing two rows that each have an identity, where
a guess can pair the wrong two. A flagged row has none. Its id was made up by
the migration, after the fact, and names nothing anywhere. The match adopts the
only identity the row ever had, which is on the server. It runs once per row,
only for rows the migration minted, so nothing logged since the upgrade — and
nothing twice — is ever matched this way. And the worst a wrong match can do is
give two portions of one food item each other's ids: the same food at the same
amount, which nothing can tell apart. It is the only content match on a meal's
foods, and nothing else should become one.

Schema 42 hasn't shipped, so the flag is part of it rather than a schema 43. A
schema number is a promise to the installs that already ran it; no install has
run this one.

### Why nothing caught it

- **The upgrade test asked the question the migration answered.** It checked
  that every row got an id, and that the ids were distinct. They were —
  distinct from each other. Whether they were distinct from what the server
  held is a question about another machine's history, and the test had one
  machine.
- **"Nothing new needs it" was true**, and it was the only thing anyone
  checked. A migration's output is old data wearing new clothes.

---

## 22. What went, and what stayed

| Removed | Why it was there | Why it can go |
|---|---|---|
| `_stampWorkoutExercisesFromServer` | GET the workout before creating its exercises, in case a lost response had already created them | the create is idempotent on the id; posting again *is* the question |
| `_stampMealFoodEntriesFromServer` | link local foods to the returned meal's foods by food item | a meal's foods are upserted by id; the one state it existed for, an older build's lost answer, is healed once for the rows schema 42 minted (§21) |
| the GET in the session-exercise sweep | find the entries the server made when the session was created | the session create and the exercise batch both answer with them |
| the pull's "session links" step | the same, in the pull | its null test would never have been true again |
| pairing batch answers by index, then by slot | — | every batch answer names the item it answers (`requestedId`, §20) |
| the name fallback in `_exerciseServerId`, and `_syncSystemExerciseIds`' "only candidate" | resolve a built-in that wasn't linked yet | a name is not an identity; an unlinked built-in's entry waits (§20) |
| `PUT api/Meal/{id}/foods` | added by the first version of this part, never shipped | a replace from a device that can't see the whole list deletes what it can't see (§18) |
| `markMealSynced`, `markPlanWorkoutSynced` | callers above | no callers |

The dedup folds all stayed. It is tempting to call them dead now, and for data
written from here on, they are: no retry makes a second row, and pulls no longer
overlap. But every device that ran an earlier build still holds what those
builds left, and the server still holds the twins they created, which a full
pull on a new phone brings straight down. The folds are what heal that. What
changed is their job description: `_deduplicateAll` now says in its doc comment
that nothing new should be added to them, and they can go when the data they
heal is gone.

---

## 23. What was rejected

- **An `Idempotency-Key` header.** The standard answer for payment APIs. The
  server stores key → response for some hours and replays the response to a
  repeat. It would have fixed retries, and nothing else: the device still
  wouldn't know a row's id until an answer arrived, so it still couldn't refer
  to a row it had just made, and the key would be a second identity living
  beside the row's, in a table of its own, expiring on a timer — a retry after
  the timer is a duplicate again. With the id minted on the device, the key
  *is* the row's primary key: it never expires, and it is the same id the pull
  and every later update use.
- **Better matching on the device.** That is what the table in §14 is. Every
  heuristic identified rows by something that is not an identity — a name, a
  position, a day — and each one had a case where two different rows share it
  (two workouts called "Upper A"; a superset that repeats an exercise; two
  portions of oats). §20's slot fallback was the last of them.
- **A separate client-reference column** on each server table, keeping the
  server's own primary key. It avoids trusting a client-chosen key, at the price
  of two ids per row, and every reference on both sides choosing one of them.
  The server's keys were already GUIDs, the owner check makes a chosen key
  harmless, and a v4 collision is not a real risk.
- **Refusing content duplicates with 409.** See §17.
- **Integer or sequential ids from the device.** Two devices would mint the
  same ones.
- **Keeping the server's unresolved entries in the meal's PUT.** It mends the
  merge in §18 and nothing else: a dirty meal skips the pull, so there is no
  list of the server's entries to keep. The device would have to read the meal
  before every write — a read-modify-write, with a window of its own.
- **Replacing only the entries this device knows about.** "Knows about" is a
  set the server can't see, so every request would have to carry it — every id
  held, plus the ones wanted. That is an upsert with explicit removals, which
  is what §18 does, with the removals sent as they happen.
- **A sync status on every meal food**, so only unsent foods go up. It closes
  the window §18 leaves (a removal undone by an edit on a device that hasn't
  pulled), at the cost of a status, triggers and sweeps for a table that has
  none. Part three's tombstones close the same window for every table.
- **A schema 43 for the heal flag.** §21: 42 hasn't shipped.

---

## 24. What the tests pin

In `test/sync/client_ids_test.dart` unless noted. Each was run against the
code before the change, or — for those marked \* — with just the one rule it
pins put back to its old form, and failed there. The two marked † were run
with `untracked` taken off the delete they cover, and failed; with the old
status test put back in the trigger as well, they pass — which is the point
of them: that test used to hide exactly this mistake.

| Test | Pins |
|---|---|
| *has its global id from the moment it is inserted* | §15 |
| *is created under that id, and a retry after a lost response sends the same one* | §14: the fake stores the POST and loses the answer |
| *whose id the server refuses (409) gets a fresh one* | §16 |
| *is not referred to by id until the server has it* \* | §16: `_serverIdIfPushed` |
| *records a DELETE for any row with an id, pushed or not* \* | §15: the trigger asks only for an id; a built-in exercise records nothing |
| *whose create reached the server but whose answer was lost is deleted there too, and not brought back* \* | §15: the fake stores the POST and loses the answer; the delete goes through the weight screen's own path; one DELETE, and the pull doesn't restore the row |
| *that was never sent costs one DELETE, which a 404 settles* \* | §15: the cost, and that the outbox ends empty |
| *a local row folded into another holding the same id records no DELETE for it* † | §15: `_deduplicateAll` stays `untracked`; tracked, it deletes the server's live meal |
| *a new meal the server answers with one already here records no DELETE when it moves into it* † | §15: `_mergeIntoServerMeal` stays `untracked` |
| *two portions of one food are told apart by their ids* \* | §18: a removed food is a DELETE by the entry's id |
| *an edit sends only this device's foods, and none of them as a list that could leave another device's out* \* | §18: the upsert, not a replace |
| *a new meal the server already had for that day sends only its own foods to it, and is on the server from then on* \* | §17–§19: only this device's foods; `pendingUpdate` after the create even when the foods fail; its fields follow as a PUT |
| *a new meal answered with another stays changed, so its own fields follow as an update* \* | §17 |
| *a food not on the server yet leaves the meal to go again* | §18 |
| *a food whose row is gone from this device is neither sent nor deleted* \* | §18: the trigger's `EXISTS` condition |
| *an id the server refuses (409) is the only one replaced* \* | §16: `_refusedId` |
| *a clean meal takes the server's list on pull, a dirty one keeps its own* | §18 |
| *a meal this device hasn't pushed is adopted by the pull* \* | §15: the fallback tests status |
| *a removed one goes as the list without it, not as a DELETE* (plans) | §18 |
| *a clean plan takes the server's list on pull* | §18 |
| *is out of pending as soon as its create is answered: a plan whose workouts then fail to go still reaches its sessions* \* | §19: `_syncNewPlan`'s `_markSent(…, -1)` |
| *a new meal whose foods fail to go is on the server, and is updated rather than created again* \* | §19: `_syncNewMeal`'s `_markSent(…, -1)` |
| *a session whose plan isn't on the server yet waits for it, rather than going without it* \* | §19: `_scheduledWorkoutBody` |
| *a plan's list waits for a workout the server may not have, rather than unlinking it* \* | §19: `_putPlanWorkouts` |
| *a create the server answers with another row stays changed, so this device's fields follow as an update* \* | §17: sessions |
| *one taken out and put back in the same place is deleted before the new one is created* \* | §20: the request order |
| *an answer is paired with the item it names, not by slot* \* | §20: `requestedId`; the twin answered with the slot's entry takes its id and follows as an update |
| *one whose built-in exercise isn't linked yet waits, and never goes up as another lift with a similar name* \* | §20: no name fallback, in the create or the update |
| *built-ins are linked to the server's by their exact name only* \* | §20: `_syncSystemExerciseIds` |
| *a food an older build sent but never heard back about* — three tests: *in a meal the server has*, *in a meal the create is answered with*, *in a meal the pull adopts* \* | §21: the flag, the three places the heal runs, one server entry per flagged row, the flag cleared, asked once |
| *a meal template is created under the id minted when it was made* | §15, for SharedPreferences |
| *deleted before the server confirmed it is still deleted there, in case its create landed* \* (templates) | §15 |
| *an install upgraded from schema 41* \* | §15: ids backfilled and distinct, built-ins left alone, statuses moved, owners dirtied, the never-sent meal food flagged; a deleted never-pushed row is recorded like a pushed one |
| `sync_tracking_migration_test.dart` › *a trigger an earlier build installed is replaced on open, with no schema bump* \* | §15: an install holding the status-gated trigger takes the new one from `installSyncTriggers` |
| `sync_service_test.dart` › *takes the id of the row the server answers with* \* | §17, §20: the slot's entry, paired by `requestedId`, followed by a PUT |
| `sync_rework_test.dart` › *are linked by the item each answers, not by position* \* | §20: the session-exercise batch |
| `FitTracker.Api.Tests/ClientIdCreateTests.cs` (30 tests) | §16–§20: a repeat returns and updates the same row with no second; every create the app sends; no id still mints one; the PK race; foreign ids refused, including a system exercise's and another user's session; the 409 filter; content de-duplication still answering with its own row; replaces keeping and moving ids; a replace never deleting a row that isn't the caller's, with another account's row appearing between the check and the delete; the foods batch storing each entry once, removing nothing, moving an entry between the caller's meals, refusing someone else's, and reading both shapes; removing a food by its entry id; the plan replace, including empty lists and twin links; every batch answering 404 for someone else's parent, empty ones included; both batches echoing `requestedId`, and nothing else carrying it; both shapes of the session-exercise batch; `TotalWeightGrams` |

The server tests were mutation-checked the same way: with ids ignored, with the
set replace minting ids, with a batch's ownership check removed, with the plan
batch's duplicate check removed, with a repeat that returns without applying,
with the template's weight left unsaved — and, for the review's changes, with
the replace's delete unscoped, the foods batch ignoring ids or not moving an
entry, the foreign owner check gone, the bare-id reader gone, removal by food
item only, twin plan links kept, an empty batch answering `[]`, and either
batch's echo removed.

Existing tests changed where they had encoded the old contract. The fake API
now answers an unstubbed POST the way the API does for a create it accepts —
with what it was sent, a batch naming each item's id as `requestedId` — can
fail one with a status and a body or lose its answer, and records every request
in order. Tests that stubbed a server-minted id for a batch now expect the ids
the device sent. A food removed from a meal now expects a DELETE by the entry's
id, and a food added to one an upsert naming it; a workout exercise answered
with the slot's entry now expects the answer to name it and a PUT to follow;
and a workout kept for its history now comes back `pending` rather than
`pendingUpdate` (§16).

Three tests asserted that deleting a row that was never pushed tells the server
nothing, and now assert the opposite: *the server never had records no DELETE
for it* became *records a DELETE for any row with an id, pushed or not*; the
meal-template test *deleted before it was pushed tells the server nothing*
became the lost-answer case above; and the schema-41 upgrade test's last check
now expects both deletions recorded.

---

## 25. The rules part two leaves behind

- **A row is born with its id.** Never write `server_id` null to "re-queue" a
  row. The server mints an id for one sent without, the device marks what
  comes back by id, and so it never recognises the answer: the row is sent
  again on every push. Re-queue with the status.
- **"On the server" is `SyncStatus.isOnServer`.** Never test `serverId` for
  null; the test still compiles and is simply never true again. Read `pending`
  as "this device hasn't heard back", not "the server doesn't have it" — and
  end it the moment a create is answered, with `_markSent(…, -1)`, before
  anything else the push sends for that row.
- **A delete is recorded for any row with an id, pushed or not.** A DELETE for
  a row the server never got costs a 404, which the push drops; skipping it
  loses the delete whenever a create's answer was lost. The flip side is
  sharper than part one's: an engine delete outside `untracked` is now a
  server DELETE even for a `pending` row — including one that shares its id
  with a row the server has.
- **Send a reference only once its target is on the server, and until then
  hold back the row that refers** (`_serverIdIfPushed`). Never send null in the
  reference's place: the server stores it.
- **Keep the id a create answers with — and if it isn't the one you sent, the
  row stays `pendingUpdate`.** The server de-duplicates by content, answers
  with its own row as it holds it, and has applied none of yours. What follows
  the create is written for an answer that names a row that already exists:
  add to it, never replace it.
- **A batch's answer names the item it answers** (`requestedId`). Pair by it;
  never by index, position, slot or name. Send deletes before creates.
- **A create with an id is the row's whole current state.** The server applies
  a repeat; that is what makes it safe to re-send one whose answer was lost.
- **A list with one writer can be sent whole; a list with several is upserted
  by its members' ids, with each removal its own DELETE.** Set templates and
  logged sets are the first kind; a meal's foods are the second. A plan's
  workouts are sent whole because a link has no id, and pay last-writer-wins
  for it. Either way a clean owner takes the server's list on pull, and the
  sync engine's own write that changes one marks it (`_dirtyIfClean`).
- **A new create endpoint** takes an optional `Id`, resolves it through
  `ClientIds.CreateOrResolveAsync` with an owner lookup, and inserts with
  `SaveNewAsync`. **A batch against a parent that isn't the caller's answers
  404**, never `200 []` — empty batches included — and the owner is checked
  once, where the write happens. **A list replace goes through
  `ReplaceListAsync`**, whose delete carries the caller's ownership itself.
- **The deletion outbox is for rows, and for members of an upserted list.** A
  member leaving a list that is sent whole is a change to its owner.
- **The schema-42 heal is the only content match on a meal's foods.** It adopts
  an identity a migrated row never had here. Don't add another.

Names in part one that this part changed: `_syncMissingScheduledExerciseSets`
is now `_syncSessionExercises`, and `_addMissingPlanWorkoutLinks` is now
`_mirrorPlanWorkoutLinks`. Names the review changed: `_putMealFoods` is now
`_upsertMealFoods`, `_storeScheduledExerciseServerIds` links only a session
create's answer (the batch's goes through `_linkAnsweredScheduledExercises`),
and the dedup folds' `_onServer` is `SyncStatus.isOnServer`.

---

# Part three: pull only what changed, with explicit deletes

Parts one and two made both ends honest about identity and about what changed
on the device. The pull was still the old one: every step downloaded every row
the account had ever written, and a row missing from that download was read as
"deleted somewhere else". That is expensive, which is why the pull still ran at
most every six hours, and it is a guess, which is why §5 needed a guard for the
day the guess is wrong.

Part three replaces the guess with a record and the full download with a
delta. The server keeps two facts it never had: when each aggregate last
changed, and which rows it deleted. A new endpoint, `GET api/Sync/changes`,
sends a device what changed since the last time it asked and what was deleted
since, and a create naming a deleted id is refused.

This part lands in one pull request in two halves. The server's half (§26–§34)
is written first and deploys first, ahead of any app that uses it; every list
endpoint stays as it was, for shipped apps and the Trainer Console. The device's
half follows in the same pull request and is written up in §35 onwards.

---

## 26. Why deleted things kept coming back

Of the four symptoms in §1, "deleted things come back" is the one that survived
the most fixes. Each earlier fix closed one road back, and each road was a
different way of not knowing about a delete:

| How a deleted row came back | Closed by |
|---|---|
| The device saw a row missing from a full list, took it for lost, and pushed it again | Part one §5: a clean row missing from a list is deleted here instead |
| A row deleted on the device while its create's answer was still lost left no DELETE behind | Part two §15: every row with an id records its DELETE |
| A device that hasn't pulled yet still holds the row, and sends it: an edit to a meal upserts every food it holds, the one removed elsewhere included (§18); a retried create re-sends a row whose answer it never heard | This part: the server refuses to re-create an id it deleted (§30) |
| The pull can only learn of a delete by noticing an absence | This part: the server records the delete and says so (§29) |

The last row is the one that matters for everything else. Part one's §5 already
said it: "absent from a list" is an inference. It rests on the list being
complete, and a list can be short for reasons that have nothing to do with
deletes — a server fault, an endpoint that filters, a response cut off. Part
one guarded the worst of it (an empty list deletes nothing) and admitted the
rest.

It also blocks the delta. A pull that only fetches what changed does not list
the rows that didn't, so in a delta *every* unchanged row is absent. The moment
the pull stops downloading everything, absence stops meaning anything at all.
An incremental pull needs deletes to be positive facts — a row the server
writes when it deletes something, which says what and when. That row is a
**tombstone**.

### Why nothing caught it

- **The compiler couldn't.** An absent row is not a value. There is no
  expression in either codebase whose type is "the row the server no longer
  has"; there is only a list that is one element shorter than it used to be,
  and a list of any length type-checks.
- **The tests couldn't.** A pull test stubs the server's list, so "deleted
  elsewhere" is a list the test itself wrote one element shorter. The test and
  the pull share the inference, and neither can check it: the question — did the
  server delete this, or just not send it? — is about another machine.

---

## 27. Every aggregate knows when it last changed

### What is stamped

Nine tables are **aggregate roots**: the rows the feed ships, each with
everything that hangs off it, exactly as the list endpoints already return
them. Each gained `UpdatedAt` (UTC) and implements `ISyncRoot`
(`FitTracker.Api/Models/ISyncRoot.cs`):

| Root | Owner column | Its children |
|---|---|---|
| `Exercise` (the user's own) | `UserId` (null for built-ins) | — |
| `Workout` | `UserId` | exercise entries (`WorkoutExercise`), their set templates |
| `WorkoutPlan` | `UserId` | its workout links (`WorkoutPlanWorkout`) |
| `ScheduledWorkout` | none — its workout's `UserId` | exercise entries (`ScheduledWorkoutExercise`), their logged sets |
| `Meal` | `UserId` | food entries (`MealFoodEntry`) |
| `FoodItem` | `UserId` | — |
| `MealTemplate` | `UserId` | items |
| `WeightTracking` | `UserId` | — |
| `UserSettings` | `UserId` | — |

The stamp lives on the root, not on every row, because the root is what the
feed sends: a device receiving a session replaces its exercises and sets by id
in one go, so it never needs to know which set changed, only that the session
did. That is also why a child's change has to reach its root. A logged set that
changes without its session changing is a set the feed never sends.

### Who stamps it

Nobody by hand. `SyncChangeInterceptor` (`FitTracker.Api/Data/`) runs before
every save, reads the change tracker, and:

1. stamps every root the save adds or changes;
2. stamps the root of every child the save adds, changes or removes — and when
   a change *moves* a child (a meal food upserted into another of the caller's
   meals, which is how part two's dedup folds reach the server), both roots,
   the one it left as much as the one it joined;
3. writes the tombstones (§29).

A root the save isn't already holding is stamped with one `UPDATE` of its
`UpdatedAt` column, issued just before the save's own statements. It is not
loaded. The first version loaded every such root, tracked, and let the save
write it back. That cost a `SELECT` and a whole-row `UPDATE` per save, and the
foods batch saves once per entry, so a meal of eight foods was written eight
times.

A root is also stamped at most once per transaction
(`SyncChanges.StampAsync`, which keeps a record per context of what the
current transaction has stamped). Inside one transaction nobody else can see
anything before the commit. The first stamp is therefore the one every reader
sees, and the next seven would only take the same row lock again. The
record is what makes a foods batch write its meal once, and a sets replace
write its session once instead of twice (§28).

Outside an explicit transaction that `UPDATE` commits on its own, ahead of the
save it belongs to. If the save then fails, the root has been stamped for
nothing and the feed sends it once more than it needed to. That is the harmless
direction. The other order, a save that commits while its stamp doesn't, is a
change nobody hears of.

This is part one's argument about triggers, on the other side of the wire. A
rule every repository must remember ("set `UpdatedAt` when you change a root,
and when you change a child, find its root and set that") is a rule the next
repository forgets, and forgetting it compiles, saves, answers 200 and loses
nothing anybody can see — until a device never receives the change. The
interceptor is registered in `AppDbContext.OnConfiguring`, not in
`Program.cs`, so no context can be built without it: the API's, the test
fixture's, a second one a test opens mid-call.

**Rejected:**

- **Setting `UpdatedAt` in each repository method.** The discipline this whole
  rework has been removing, one table at a time. Part one moved it into the
  device's database for the same reason.
- **Postgres triggers.** They would see bulk statements too (§28), which is
  their one real advantage. But the tests run on SQLite, built from the model
  with `EnsureCreated()`, so a trigger written in a migration would be
  invisible to every test in the suite. That is exactly how three indexes once
  drifted from the model for months (`.github/workflows/api.yml` says so), and a
  change-tracking rule nothing tests is worse than an index nothing tests.
- **Postgres's `xmin`, or a row version per table.** A version per row answers
  "did this row change", not "did this aggregate change". `xmin` in particular
  is a transaction counter that wraps around and has no index, so it can't be
  the cursor.

### The trainer's writes are the client's changes

The owner is the row's owner, not whoever saved. A trainer editing a client's
workout from the Workout Builder writes rows whose `UserId` is the client's,
through the same services the client's own app uses
(`docs/trainer-workout-builder.md` §1), so the client's workout is stamped and
arrives in the client's feed, and a trainer deleting it writes the client's
tombstone. Nothing special happens for trainers; it falls out of stamping the
row that changed. The tests pin it anyway
(`ATrainersEditBumpsTheClientsWorkout`, `ATrainersDeleteWritesTheClientsTombstone`,
`ATrainersEditReachesTheClientsFeedAndNotTheTrainers`), because part four will
hang the trainer's live notifications off exactly this.

### A write that changes nothing stamps nothing

EF marks an entity modified only when a value actually differs. So an update
that writes back what was already stored — a repeat of a create carrying the
same fields, a PUT of an unchanged meal — stamps nothing, and the feed does not
send the row again. A repeat that *does* carry a change is an update like any
other and is stamped (`ARepeatedCreateThatAppliesAChangeStampsTheRoot`). Part
two's reason a repeat applies its fields (§16) is also why it must be stamped:
the device's other installs only hear of that edit through the feed.

That is correct for the server, and it puts one obligation on the device,
which §35 has to meet: a device that skips an aggregate in a delta because its
own copy is dirty cannot count on the push to bring it back. If the push turns
out to change nothing on the server, there is no echo.

### Indexes

Each root has `(UserId, UpdatedAt)`, which is the feed's whole query: this
user's rows changed since the cursor. EF dropped six single-column `UserId`
indexes in the same migration, since the composite serves both. Two roots
differ:

- **`ScheduledWorkout`** has no owner column; it belongs to whoever owns its
  workout. Its index is `(WorkoutId, UpdatedAt)`: the feed joins the user's
  workouts, then range-scans each one's sessions by when they changed.
- **`UserSettings`** has none. Its unique index on `UserId` already narrows a
  user to one row, and a second index would be pure write cost.

### Existing rows

Migration `AddSyncChangeTracking` backfills `UpdatedAt = now()` on all nine
tables. The column default would otherwise be year 1, which hides every
existing row from every cursor; with the backfill, the first delta any device
asks for after the deploy, from any cursor earlier than it, is a full pull.

---

## 28. What the interceptor can't see

The interceptor sees the change tracker, and the change tracker sees what goes
through it. Three kinds of write don't:

- `ExecuteDelete` and `ExecuteUpdate`, which translate straight to SQL;
- the database's own `ON DELETE CASCADE` and `ON DELETE SET NULL`, which delete
  or change rows of *other tables* that EF never loaded;
- raw SQL, of which there is none on synced tables.

Every one of these on synced data has to say what it did by hand, with three
helpers in `SyncChanges` (`FitTracker.Api/Data/SyncChanges.cs`):

- `TouchAsync` stamps roots named by id, in one statement;
- `TouchWhereAsync` stamps whichever roots a predicate matches when the
  statement runs;
- `Bury` adds tombstones to the next save.

These are all of them:

| Call site | What EF doesn't see | What it now does |
|---|---|---|
| `ReplaceListAsync` (`DbContextExtensions.cs`), behind the set and set-template replaces | the bulk delete of the list — and of the caller's rows stored under the sent ids in *other* lists, which the app moved there | immediately before the delete, one statement stamps the list's own root and the root of every row the delete is about to remove |
| `WorkoutRepository.DeleteWorkoutAsync` | the bulk delete of the workout's placeholder sessions | a tombstone for each one actually deleted |
| the same | the cascade deleting links in plans that list the workout | stamps, by predicate, the plans listing it, immediately before the delete |
| `WorkoutRepository.DeleteWorkoutExerciseAsync` | the bulk delete of the placeholder entries sessions hold for the exercise | stamps those sessions |
| `WorkoutPlanRepository.DeletePlanAsync` | `SET NULL` on each of the plan's sessions | stamps, by predicate, the plan's sessions, immediately before the delete |
| `MealRepository.DeleteMealAsync` | the cascade deleting the meal's foods | nothing is left to the cascade: the save loads the foods and deletes them itself, and each gets a tombstone (§29) |
| `UserRepository.DeleteUserAsync` | everything, by cascade | nothing: the account's tombstones go with it, and there is no device left to tell |

Each runs in one transaction, begun before anything it decides from is read,
so the stamp or the tombstone commits if and only if the write it describes
does.

### A list read first is already out of date

The first version of this table did the right things from the wrong
information. Each call site read a list, then wrote. It read the roots to stamp
and the sessions that were "only placeholders", and afterwards it deleted.
The list was correct when it was read. By the time the delete ran, another
request could have committed a change it didn't include. Postgres runs these
transactions at READ COMMITTED, so each statement sees whatever has committed
by the time that statement starts. Starting a transaction is not enough: a
transaction begun before the read still lets the next statement see a newer
database than the read did.

| Time | Trainer deletes a client's workout | The client's phone |
|---|---|---|
| t0 | reads the sessions: all placeholders, none has a logged set | |
| t1 | | logs a set in one of those sessions and commits |
| t2 | deletes the sessions it read, by id | |
| | the cascade deletes the set; the session's tombstone tells every other device to delete it too | the set is gone from the server |

The same shape hid in four more places. A plan linked the workout between the
read of the plans and the cascade that removed the link. A session was
scheduled under a plan between the read and `SET NULL`. A set was stored under
an id the replace was sent between the read of the roots and the delete. A food
was moved into a meal between the read of its foods and the meal's cascade.
Each time, a row was changed or deleted and nothing told a device.

The fix is the same each time: **the write asks the question itself, as it
runs.**

- **A delete that was guarded by a read repeats the guard in its own
  predicate.** The placeholder delete is `emptySessionIds.Contains(sw.Id) &&
  !sw.Exercises.Any(e => e.Sets.Any())`. A session that gained a set since the
  read is left alone. The call site then compares the row count with the list
  it read. For a workout, the rows actually deleted get tombstones and the
  workout stays (`HasLoggedHistory`). For a workout exercise, the entry is
  retired instead of deleted, because it has history now. A tombstone is
  written only for a row the delete really removed. A tombstone for a session
  that survived would make every device delete that session, and the set with
  it.
- **A stamp before a cascade is a predicate, issued immediately before the
  statement that cascades.** For example,
  `WorkoutPlans.Where(p => p.PlanWorkouts.Any(l => l.WorkoutId == id))`, with
  no list of ids read beforehand. The window can't be closed completely
  without locking, but there is no longer a round trip inside it. The
  `UPDATE` also takes a row lock on every root it stamps. Every other writer of
  that root's children stamps the same row (§27), so that writer now waits for
  this transaction to finish.
- **The replace names its list's root outright**
  (`ReplaceListAsync(…, listRoot, …)`), as well as the roots of the rows it is
  about to delete. So even an empty list stamps, and locks, its root. The replace
  records that root as stamped, so the insert's save doesn't write it again.

Nothing in the suite could see any of this, because it takes two requests.
Every test runs one call on one connection, and a race needs a second writer
between two of that call's statements. `InterleavedCommit`
(`FitTracker.Api.Tests/InterleavedCommit.cs`) plays that writer. It runs one
statement on the call's own connection just before the call's first write, so
the call has already read and hasn't written yet. Each race above now has a
test that injects the other request's row there. The test fails against the
read-then-write version and passes when the write asks for itself.

### Why nothing would catch the next one

This section is the one most likely to be wrong again, and it is worth being
exact about why.

- **The compiler can't tell you.** `ExecuteDeleteAsync()` returns the number of
  rows it deleted; the method compiles and the rows are gone. `Remove(workout)`
  compiles to a delete of one row in one table, and nothing in its type says
  that `AppDbContext`, in another folder, told Postgres to delete rows of another
  table with it. What the interceptor can see is a property of a
  runtime object — the change tracker's contents at the moment of a save — and
  no type describes it.
- **The ordinary test can't either.** The replace tests from part two replace a
  list with a non-empty list. The inserted rows are tracked, the interceptor
  stamps their root, and the test passes whether or not the bulk delete said
  anything. The bulk delete is only on its own when the list is replaced with
  *nothing*, or when a row moves in from another parent, and those are the two
  cases the tests had to be written for (`AReplaceThatOnlyDeletesBumpsItsRoot`,
  `ARowAReplaceMovesBumpsTheRootItLeft`).

So the rule is a rule, and the test is how it is kept: **a new `ExecuteDelete`
or `ExecuteUpdate` on a synced table, or a new `ON DELETE` rule between them,
stamps or buries at the call site — by predicate, in the write's transaction,
immediately before it, never from a list read earlier — and gets a test that
backdates every root (`DbFixture.Backdate`) and checks the one it should have
moved, and one that commits a row in between with `InterleavedCommit`.**

---

## 29. Tombstones

A `SyncTombstone` (`FitTracker.Api/Models/SyncTombstone.cs`) is five columns:
its own id, the owner's `UserId`, an `EntityType` (`exercise`, `workout`,
`workoutPlan`, `scheduledWorkout`, `meal`, `mealFood`, `foodItem`,
`mealTemplate`, `weight`), the deleted row's `EntityId`, and `DeletedAt`. The
interceptor writes one in the same save as every root delete, so a delete that
commits has its record and one that fails has none.

### Why meal foods, and only meal foods

Children don't need tombstones. The feed ships an aggregate whole, and a
device replaces its children with the ones it received, so a set template or a
logged set that is gone from the session is gone from the device. A meal's
foods are the exception because of what part two made them: the only list
**upserted by id from several writers** (§18). Every other list is sent whole by
the one device that owns it (sets, set templates) or has no ids (plan links).
A food's id is therefore one a device that hasn't pulled can send again, into
this meal or — after its dedup folds moved it — into another, and refusing
that (§30) needs a record of the id.

For the same reason a deleted meal's foods get tombstones too. Without them, a
device that had folded the deleted meal's twin into another could upsert the
deleted meal's foods into the survivor. The database would cascade them without
EF ever loading them. The first version listed them with a `SELECT` before the
save and tombstoned that list. It was a list of what the cascade was *expected*
to remove, and it was wrong both ways:

- a food moved into the meal after the `SELECT` went with the cascade and no
  tombstone (§28's race);
- a food the same save moved *out* of the meal was still listed under its old
  meal. It got a tombstone although it survived, and the feed would have told
  every device to delete a live food.

The interceptor now loads the meal's foods, tracked, and deletes them itself
in the same save (`DeleteFoodsOfAsync`). The tombstones are then for exactly
the rows the save deletes, by construction. A tracked food answers that query
with its current `MealId`, so one this save moves elsewhere is recognised and
left alone. `MealRepository.DeleteMealAsync` stamps the meal first, inside its
transaction, and that stamp is what closes the race. The foods batch, which is
how the app adds and moves foods, stamps the same meal row inside *its*
transaction before writing a food. Each of the two therefore waits for the
other's row lock. A move either commits before the delete's stamp, and the load
sees its food, or waits until the delete has committed and then finds no meal
to write into.

Workout exercises are the nearest case: the device creates them by id, and
both the trainee and a trainer's Workout Builder remove them. A deleted one is
not tombstoned. That is left for now: a removed entry with history is retired
rather than deleted, the workout it left is re-sent whole, and the trade-off is
written down in "What is deliberately not here yet".

### Never pruned

Tombstones are kept for ever, deliberately:

- a device's cursor can be any age — a phone left in a drawer for a year — and a
  pruned tombstone is a delete that device never hears of, which is the bug
  this part exists to end;
- the 410 in §30 refuses a deleted id for as long as the tombstone exists, and
  a device holding the row is exactly as old as its cursor;
- a tombstone is five narrow columns. A heavy user deleting a hundred rows a
  week writes about a megabyte a year, indexes included.

Pruning is a job with a cut-off that has to be chosen, a rule for what a device
older than the cut-off does, and a test for both. None of it is needed yet.

### Why not a `DeletedAt` column on each table

Soft-delete would have given the feed the same fact without a new table. It
would also have put a filter in every read in the API: every list endpoint,
every Trainer Console aggregate, every ownership check, every content
de-duplication. `docs/trainer-session-review.md` §3 is what one such column cost
— `RemovedAt` on workout exercises — and its rule, that every query answering
"what is in this workout" must exclude it and every query resolving history
must not, is one every new query has to remember. Nine such columns would be
nine such rules. A tombstone keeps deletion out of every read but the one that
asks about it.

---

## 30. A deleted id can't come back

`ClientIds.CreateOrResolveAsync` gained one row in its table
(`FitTracker.Api/Services/ClientIds.cs`):

| The id… | The create… |
|---|---|
| names one of the caller's rows | applies the sent fields and returns it |
| names someone else's row | 409 (`id_in_use`) |
| **names a row the caller deleted** | **410 (`id_deleted`)** |
| is new | inserts under it |
| was not sent | mints one — shipped apps are unaffected |

### Why refuse rather than re-create

The only device that sends a deleted id is one that hasn't heard of the delete.
Here is §18's open window, which part two named and left for this part:

| Time | Device A | Server | Device B (hasn't pulled) |
|---|---|---|---|
| t0 | removes the oats from lunch; DELETE by the entry's id | entry deleted | lunch holds the oats |
| t1 | | | adds a banana to lunch; the dirty meal upserts every food it holds, oats included |
| *before* | | the oats are created again, under their old id | |
| *now* | | 410, naming the oats' id | deletes its oats |

Re-creating would be the server agreeing with whichever device spoke last,
which is last-writer-wins for the row's *existence* — and the writer that speaks
last after a delete is, by construction, the one that didn't know about it. A
lost create answer (§15) ends the same way: a retry after the row was deleted
elsewhere would bring it back.

The 410 names the id, as the 409 does (`ClientIdGoneFilter`), because a foods
batch can be refused for its entries and the device has to know which.
It is registered globally for the 409's reason: a controller that forgot a
catch would turn a deleted id into a 500 the app retries for ever.

### A batch is refused whole

The body is `{ "error": "id_deleted", "id": "…", "ids": ["…", …] }`. `ids`
lists every deleted id the request carried. `id` is the first of them, kept
because the device's first reader of a 410 looks there. A single create
carries one id, so there the two say the same thing.

The foods batch (`MealRepository.UpsertFoodEntriesAsync`) used to find out
about a deleted id the way every create does: one entry at a time, as it
reached it. Each entry saves on its own, and there was no transaction around
them. When entry *k* was refused, entries 1 to *k*−1 had already been
committed, the meal had been stamped, and the entries after *k* had never been
looked at. Other devices then pulled a half-applied meal. The answer also named
one gone id, so a meal holding *n* foods removed elsewhere took *n* sync rounds
to settle.

Now the batch runs in one transaction. Before it writes anything, it asks
about every id it was sent in one query: which of them have a tombstone of the
caller's and no row. If any do, it applies nothing and answers 410 with all of
them. The device drops those entries and sends the rest in one more round. Any
other refusal partway, such as a 409 for someone else's id, rolls back the
entries before it too. The per-entry tombstone lookup inside `ClientIds` is
given `_ => false` there, because the batch has already asked.
`ABatchCarryingDeletedIdsIsRefusedWholeAndNamesEveryOne` and
`ABatchRefusedPartWayAppliesNothing` pin both.

### Before the content check

Meal and session creates also de-duplicate by content (§17): a meal for a day
and category that already has one is answered with that meal. The tombstone is
checked first, before `insert` runs, and this ordering is the point of a test
(`ADeletedMealIsGoneEvenWhenItsDayHasAnotherMeal`). Checked after, a stale
device's create of a deleted lunch would be answered with the day's *other*
lunch — logged since, on another device — and the stale device would then move
the deleted lunch's foods into it.

### Scoped to the caller

The check asks whether *this caller's* tombstone names the id. Another
account's tombstone says nothing about this caller's rows, and refusing on it
would tell the caller that the id had once existed.
`SomeoneElsesDeleteDoesNotStopACreate` pins it: with the owner taken out of the
lookup, it fails.

### What it costs

Delete wins over a concurrent edit. A food added, offline, to a meal another
device has since deleted is lost with the meal. That is the usual rule for
tombstones, and the alternative — the edit resurrects the meal — is the bug.

Every create that sends an id pays one indexed lookup, `(UserId, EntityId)`,
and only when the id isn't already stored: a repeat is resolved before it. The
lookup is `ISyncTombstoneRepository.WasDeletedAsync`, which the services
depend on directly. There is one exception. A workout exercise is never
tombstoned (§29), so its create passes `_ => false` rather than run a query
that can only answer no. That query would also have suggested, to anyone
reading it, that a removed entry's id is refused. It isn't.

---

## 31. The changes feed

`GET api/Sync/changes?since=<ISO-8601 instant>` (`SyncController`,
`SyncFeedService`), authorized, for the caller's data only:

| Field | Holds |
|---|---|
| `exercises` | the caller's own exercises, as `GET api/Exercise/UserExercise` returns them |
| `workouts` | as `GET api/Workout`: every exercise entry — retired ones with `removedAt` set — and their set templates |
| `workoutPlans` | as `GET api/WorkoutPlan`, with the whole `workoutIds` list |
| `scheduledWorkouts` | as `GET api/ScheduledWorkout`, with every exercise and its logged sets |
| `foodItems` | as `GET api/FoodItem` |
| `meals` | as `GET api/Meal/all`, with every `foodEntries` entry |
| `mealTemplates` | as `GET api/MealTemplate`, with every item |
| `weights` | as `GET api/WeightTracking/TrackWeight` |
| `settings` | as `GET api/UserSettings`, or null when unchanged or never saved |
| `deleted` | `[{ entityType, entityId, deletedAt }]`, every delete of the caller's since the cursor — or ever, without one |
| `cursor` | the `since` to send next time |

Each list holds the aggregates whose root was stamped at or after `since`.
Without `since`, every list holds everything and `deleted` holds every
tombstone the caller has. Built-in exercises are not the caller's data and are
never in it; linking them to the device's seeded copies still goes through
`GET api/Exercise/AllExercises`.

### No cursor is not the same as no data

The first version sent no deletes with a full answer. Its reasoning was that a
device with no cursor starts from nothing and holds nothing a tombstone could
remove. That is true of a fresh install. It is false of the device that asks
first and most often: an install upgrading to the app that reads the feed. That
install holds everything its old full pulls downloaded, and it has never had a
cursor.

The API deploys when this pull request merges, and the app ships later. In
between, every delete made on another device or by a trainer is recorded as a
tombstone that the upgrading device has never seen. Its first answer is the
only one that can pass those deletes on, because every later answer starts
from a cursor after them. With `deleted: []` it could only have inferred them
from absence, and absence is the inference this part exists to remove.

So without a cursor, `deleted` is every tombstone the caller has. A fresh
install receives deletes for rows it doesn't hold, and deleting a row that
isn't there costs nothing. The alternative was to have the client send an
epoch `since` on its first run. That puts a rule on every client for a case
the server can cover by itself, and a client that forgot the rule would fail
silently. `WithoutACursorItReturnsEverythingTheCallerHasAndEveryDelete` pins
this behaviour.

### Why the existing DTOs

Every list in the answer comes from the service behind the matching list
endpoint, asked with a filter (`ChangedSince`, `SyncChanges.cs`). There is no
second query and no second mapper, and that is the design, not a shortcut:

- The device already parses these shapes: its pull reads exactly these lists
  today. The client half changes where they come from, not how they're read.
- The feed can't drift from the list endpoints. A field added to a DTO reaches
  both, and so does a fold, a filter or a bug fix. That is
  `docs/trainer-console-duplicate-rows.md` §5's lesson — use the one definition
  rather than keep a second in step with it — applied to a mapper.
- It keeps the list endpoints honest for the readers that stay on them —
  shipped apps and the Trainer Console — because they are the same code.

### Why the cursor overlaps

The cursor is the server's clock when the answer began, taken before the first
query, minus two minutes. The subtraction is for a race that nothing else
covers. A save stamps `UpdatedAt` when it starts, and its rows become visible
when it commits; between the two, a feed can run:

| Time | A client's save (one set logged) | A feed for another device |
|---|---|---|
| 12:00:00.000 | stamps the session 12:00:00.000 | |
| 12:00:00.050 | | cursor taken; the queries don't see the uncommitted session |
| 12:00:00.200 | commits | |
| next pull | | `since` = the cursor. *Without the overlap* it is 12:00:00.050, the session's stamp is earlier, and the set is never sent. *With it*, `since` is 11:58:00.050 and it is. |

Cloud Run can run more than one instance, and their clocks are close but not
identical, which is the same race with the stamp taken on one clock and the
cursor on another. Two minutes is far wider than either needs; the price is
that whatever changed in the last two minutes is sent twice, and applying a row
twice is harmless by construction. The cursor is the server's clock and never
the device's, because a phone's clock is whatever its owner set it to.
`ARowStampedJustBeforeTheLastAnswerArrivesWithTheNextOne` pins the overlap.
The row's stamp in that test is read from the clock *before* the answer began,
one second earlier. The first version took the stamp from the cursor the
answer returned (`cursor + 1 minute`). A stamp derived from the cursor always
lands after the cursor, whatever the overlap is, so that test still passed with
the overlap set to zero. It now fails that way. A test that computes its input
from the output of the code under test is often checking the code against
itself.

### No paging

An answer without `since` is the same data today's full pull downloads over ten
requests, and every later answer is smaller. Paging would need a stable order
across requests and a cursor that points inside one, for a volume nobody has
yet shown to be a problem.

### Not a snapshot

The lists are read one after another, not in one transaction. A write that
commits between two of the reads can leave the answer referring to a row it
doesn't include — a session whose new workout was created just after the
workouts were read. The row is not lost: it was stamped after the cursor was
taken, so the next answer carries it. For the same reason one answer can list a
row as changed *and* deleted, when the delete commits between the read of that
list and the read of the tombstones. Applying the deletes after the
aggregates, as §35 asks of the device, makes that case come out right.

---

## 32. An edit that had never worked

The test for a meal template's items (`ATemplateItemBumpsItsTemplate`) failed
the first time it ran, and not on its assertion.
`MealTemplateRepository.UpdateAsync` replaced a template's items by assigning
the navigation, `template.Items = incoming.Items`. The new items already had
their ids, and a row EF discovers through a navigation with its key already set
is taken for a stored one: it was saved as an `UPDATE`, which matched nothing,
and EF threw a concurrency exception. Every `PUT api/MealTemplate/{id}` that
carried items has failed like this since the service was written, and the app
has been sending those PUTs since part one (§4). The items now go through the
`DbSet`, the fix `WorkoutPlanRepository.ReplacePlanWorkoutsAsync` already
carries a comment about.

Nothing had caught it because no test had ever updated a template that had
items; the part-two test for the same PUT saved its batch weight with an empty
list. It is a small instance of this part's subject: a write can fail, or
succeed without saying what it did, and only a test that reads back the state
another reader will see can tell.

---

## 33. What the tests pin (server)

In `FitTracker.Api.Tests/SyncChangeTrackingTests.cs` (27) and
`SyncFeedTests.cs` (10). Each was run against a skeleton — the columns and
the endpoint in place, no stamping, no tombstones, a feed that returned
everything — and failed there, except the ones that describe what a full answer
already did (everything without a cursor, only the caller's rows, retired
entries included, a whole aggregate for a changed child), which are there so
the delta keeps doing it. *ASessionExercisesNote…* was added after the mutation
run below found a rule no test held, and fails with that rule taken out.

| Test | Pins |
|---|---|
| *ACreateStampsTheRoot*, *AnUpdateStampsTheRoot*, *ARepeatedCreateThatAppliesAChangeStampsTheRoot* | §27 |
| *ASetTemplateChange…*, *ALoggedSet…*, *ASessionExercisesNote…*, *AMealFood…*, *APlanLink…*, *ATemplateItemBumpsItsTemplate* | §27: each child reaches its root; §32 |
| *AMealFoodMovedToAnotherMealBumpsBoth* | §27: both ends of a move |
| *AReplaceThatOnlyDeletesBumpsItsRoot*, *ARowAReplaceMovesBumpsTheRootItLeft* | §28: `ReplaceListAsync` |
| *RemovingAnExerciseBumpsTheSessionsWhosePlaceholdersGoWithIt*, *DeletingAPlanBumpsTheSessionsItDetaches*, *DeletingAWorkoutBumpsThePlansThatListedIt*, *DeletingAWorkoutWritesTombstonesForThePlaceholderSessionsItRemoves* | §28: each bulk statement and cascade |
| *ATrainersEditBumpsTheClientsWorkout*, *ATrainersDeleteWritesTheClientsTombstone* | §27: the owner, not the actor |
| *DeletingEachRootWritesItsTombstone*, *RemovingAFoodFromAMeal…*, *DeletingAMealWritesTombstonesForItsFoods*, *DeletingAnAccountLeavesNoTombstonesBehind* | §29 |
| *ACreateOfAnIdTheCallerDeletedIsGone*, *AFoodRemovedFromAMealCannotBeUpsertedBack*, *ADeletedMealIsGoneEvenWhenItsDayHasAnotherMeal*, *SomeoneElsesDeleteDoesNotStopACreate*, *TheRefusalReachesTheAppAs410* | §30 |
| *WithoutACursor…*, *ItReturnsOnlyWhatChangedSinceTheCursor*, *AChildsChangeShipsItsWholeAggregate*, *ItReturnsTheDeletesSinceTheCursor*, *ItReturnsOnlyTheCallersData*, *ARetiredExerciseStillShipsInsideItsWorkout*, *ATrainersEditReachesTheClientsFeedAndNotTheTrainers* | §31 |
| *TheCursorIsWhenTheAnswerBeganLessTwoMinutes*, *ARowStampedJustBeforeTheLastAnswerArrivesWithTheNextOne*, *TheEndpointAnswersForTheCallerAndReadsTheCursorAsAnInstant* | §31: the cursor, and `since` read as an instant whatever its offset |

Twelve more were added after the owner's review, and
*WithoutACursor…* now expects every delete. The first version passed the whole
suite with each of the defects below, which is the reason each of these tests
exists. Every one of them was checked against a mutation that puts the old
behaviour back, and every one failed there:

| Test | Pins | Fails when… |
|---|---|---|
| *WithoutACursorItReturnsEverythingTheCallerHasAndEveryDelete* | §31: deletes on a full answer | a full answer sends `deleted: []` |
| *ABatchCarryingDeletedIdsIsRefusedWholeAndNamesEveryOne*, *ABatchsRefusalNamesEveryId…* | §30: all or nothing, every id | the up-front tombstone query is taken out |
| *ABatchRefusedPartWayAppliesNothing* | §30: one transaction | the batch runs without one |
| *DeletingAWorkoutKeepsASetLoggedAfterItsCheck*, *RemovingAnExerciseKeepsASetLoggedAfterItsCheck* | §28: the delete repeats its guard | the guard is dropped from the delete's predicate |
| *DeletingAWorkoutBumpsAPlanThatListedItJustBefore*, *DeletingAPlanBumpsASessionScheduledUnderItJustBefore*, *AReplaceBumpsTheRootOfARowMovedUnderASentIdJustBefore* | §28: stamp by predicate, just before | the roots come from a list read earlier |
| *DeletingAMealTombstonesAFoodMovedIntoItJustBefore* | §29: the meal is stamped first | the delete doesn't stamp the meal first |
| *AFoodMovedOutOfAMealInTheSaveThatDeletesItGetsNoTombstone* | §29: tombstones for what the save deletes | foods are matched by the meal they're stored under |
| *ABatchOfFoodsWritesItsMealOnce*, *AReplaceWritesItsSessionOnce* | §27: once per transaction | the per-transaction record is switched off |
| *ARowStampedJustBefore…* (rewritten) | §31: the overlap | `Overlap` is zero |

`SyncChangeTrackingTests.cs` now holds 39 tests and `SyncFeedTests.cs` 10.

Then each rule was taken out on its own and the suite run again. Each of these
failed at least one test: every explicit stamp and tombstone in §28's table; each
child in the interceptor's map; the original parent of a move; the cascaded meal
foods; stamping added and changed roots; the tombstone check, and moving it
after a meal's content check; the owner in the tombstone lookup and in the
feed's tombstone query; a session's owner in its tombstone; the overlap; the
filter; tombstones on a full answer. One did not: without the guard that skips
tombstones for an account deleted in the same save, the tombstones are written
and then cascaded away with the account, which the test can't tell apart. The
guard stays, because it keeps account deletion from depending on the order EF
chooses for an insert and a delete in one save.

---

## 34. The rules part three leaves behind (server)

- **`UpdatedAt` is never set by hand.** The interceptor stamps it; a bulk write
  stamps through `SyncChanges.TouchAsync` or `TouchWhereAsync`. A child table
  added under a synced root goes in the interceptor's map (`CollectRoots`), or
  its changes never leave the server. A root is written once per transaction,
  and only its `UpdatedAt` column.
- **A bulk write, or a database cascade, on a synced table says what it did.**
  `TouchAsync`/`TouchWhereAsync` for the roots it changed, `Bury` for the roots
  it deleted, in the same transaction as the write — and a test that backdates
  and checks, because nothing else will notice (§28).
- **A write never acts on a list read before it.** A delete guarded by a read
  repeats the guard in its own predicate and tombstones only what it removed.
  A stamp ahead of a cascade is a predicate issued immediately before that
  statement. A race needs a test that commits in between (`InterleavedCommit`),
  because no single-request test can fail on one (§28).
- **Every root delete, and every meal food delete, leaves a tombstone,** written
  by the save that deletes it — for the rows it deletes, never for the rows it
  expects a cascade to. Tombstones are never pruned.
- **A create resolves a client id through `ClientIds.CreateOrResolveAsync`,**
  which now needs `deletedByCaller` — `ISyncTombstoneRepository.WasDeletedAsync`
  — and refuses a deleted id with 410 before any content check runs. A batch
  asks for all its ids at once and is refused whole, naming every one.
- **An answer without a cursor carries every tombstone.** No cursor means the
  device has never asked, not that it holds nothing.
- **The feed reuses the list endpoints' own services.** A new synced list is a
  list endpoint with a `changedSince` parameter, and a field in the feed is a
  field in that endpoint's DTO.
- **The cursor is the server's, taken before the first query, minus the
  overlap.** Don't shorten the overlap below the time a save can take between
  stamping and committing.

---

## 35. The device's half

The server's half gave the device two facts it never had — which aggregates
changed since a given moment, and which rows were deleted — and one new answer,
410. This half is what the device does with them. Put shortly: the pull stopped
downloading the account and started asking a question, *what changed since I
last asked?*, and it stopped guessing what had been deleted.

| | Before | Now |
|---|---|---|
| What a pull fetches | nine GETs of the account's data, every list in full, plus the built-in exercise catalogue | one `GET api/Sync/changes?since=<cursor>`; the catalogue only when something needs it (§36) |
| How a delete elsewhere is learned | a row missing from its list, guarded against a list that came back empty | the server says so: a tombstone in the answer (§39), or a 410 answering a create (§40) |
| A clean row the server lists | mostly left alone — only a workout, a plan's list and a meal's list were reconciled | takes the server's copy |
| A dirty row the server lists | skipped | skipped, and the cursor stays where it was (§37) |
| When it runs | launch and resume, at most every six hours | launch and resume, at most every two minutes, and in the background task (§42) |

The apply code did not change shape. Each `_pull…` method used to fetch its
list and then apply it; it now takes its list from the answer and applies it
with the same code — `_applyServerWorkout`, `_applyServerScheduledWorkout`,
`_applyServerMeal` and the rest. The feed was built to send exactly the DTOs
those methods already read (§31), so this half changes where the lists come
from, not how they are read. There is one apply path, not a second one for the
feed that would drift from the first.

What did change inside them is that a clean row now takes the server's copy
wherever it used to be insert-only: a custom exercise, a food item, a weight's
value and note, a plan's name, dates and cycle. Under the full pull those were
written once and never again, so an edit made on another device, or by a
trainer, never reached a device that already had the row. With a delta that
gap would have been the whole point of the answer: the answer lists the row
*because* it changed.

Two things deliberately keep their old rule. Settings have no sync status, so
the pull can't tell a local edit it hasn't sent from a clean copy; they still
only fill in a device that has none, and the push sends them whole. And a
weight's *date* is not overwritten: the push sends a record's local wall-clock
time with no offset and the server stamps it UTC as it stands, so the date it
echoes back is this device's moved by its time-zone offset. Written over a
record logged west of Greenwich, it would move the weigh-in to the day before.
That round trip is its own bug, older than this part, and is listed below.

Two properties of the answer the apply code already had to live with, and now
relies on. A row can arrive twice — the cursor overlaps by two minutes (§31) —
so applying one is idempotent: an insert of a row already held becomes an
update of it. And a row can refer to one that only arrives in the next answer:
a session whose workout isn't here yet is skipped, as it always was. That is
safe only because the two were stamped after the cursor this answer returns,
so the next answer carries both; it is also why the order of the steps — a
row's references before the row — matters for the common case and not for
correctness.

---

## 36. The cursor

`sync_meta` (drift schema 43, `lib/core/database/tables/sync_tables.dart`)
holds one row: the `cursor` of the last answer this device applied whole,
exactly as the server wrote it. The next pull sends it back as `since`
(`ApiClient.getChanges`; Dio encodes it, so an offset's `+` survives).

It lives in the database, not in SharedPreferences beside the pull's
timestamp, because it describes the data and has to go when the data goes.
`clearAllUserData` — sign-out — deletes it in the same `untracked` transaction
that empties the tables. A cursor that outlived its data would tell the next
account's first pull that this device already held everything up to the last
account's position; that pull would fetch nothing, and the new account would
open to an empty app. `clearPerAccountPrefs` removes the pull timestamp for the
same reason, and says so.

### A pull with no cursor

A pull with no cursor sends no `since`, and the server answers with
everything. There are three ways to have no cursor, and they differ in what
the device already holds:

| No cursor because… | The device already holds |
|---|---|
| a fresh install, or a new sign-in | nothing |
| an install upgraded from schema 42 | whatever its last full pull brought down — including rows another device has deleted since |
| the server refused one of this device's DELETEs (§41), or the user pressed "Restore from server" | everything |

The server's half was first written for the first row only: an answer without
`since` listed everything and no deletions, on the reasoning that a device
holding nothing has nothing a deletion could remove. The second row is not
that case. An upgraded install's last full pull ran up to six hours before the
upgrade, and whatever was deleted elsewhere in between is still on it. Before
this part, the next full pull's absence inference would have removed it; that
inference is gone, and the only thing left that can is a tombstone. So the
device treats `deleted` the same in every answer — applied after the
aggregates, with the same protections for history — and a cursorless answer has
to carry every deletion the server has recorded for the account.
*an install upgraded from schema 42 … applies what was deleted meanwhile*
pins the device's side of that.

### When it moves

The cursor is stored only after the whole answer applied: every step ran
without failing, and no row was held back (§37). Anything less, and the next
pull asks for the same changes again. Applying a row twice is harmless by
construction (§31), so asking again costs bandwidth, never correctness.

That made one old kindness wrong. `_applyEach` applied each record in its own
savepoint, and a record that failed was logged, skipped and forgotten — "one
record the device can't take costs that record, not the step". Under the full
pull that was true, because the record came back on the next pull and was
tried again. With a cursor, a skipped record would be behind the cursor and
never be sent again. So a record that fails still doesn't stop the rest of its
step, but the step now reports failure once the rest are applied, and the
cursor stays.

### The built-in catalogue

Built-in exercises are the server's catalogue, not the account's data, so
they are not in the feed; linking the device's seeded copies to the server's
ids still goes through `GET api/Exercise/AllExercises` (`_syncSystemExerciseIds`).
The catalogue is several hundred exercises, with descriptions in two
languages. The full pull fetched it every time, which was affordable once
every six hours and is not on every resume. It is now fetched only when
something needs it (`_needsCatalogue`): a pull without a cursor; an answer
whose workout names an exercise this device holds under no id (a built-in the
server added since the last link, in a workout a trainer assigned); or a
workout here using a built-in that isn't linked yet, whose entry waits, unsent,
for the link (§20).

---

## 37. A row held back holds the cursor

The pull has always skipped the server's copy of a row this device holds an
unsent change to: the change is the push's to send, and overwriting it would
lose it. Skipping is still the rule. What changed is an assumption that used to
come with it for free, and is now false:

> The push will send this device's copy, the server will stamp it, and the next
> answer will bring the result back.

§27 is why not. The server stamps a root only when a value actually changes,
so a push that writes back what the server already holds leaves no trace in
the feed. That is not exotic:

| Time | This phone | Server | Tablet |
|---|---|---|---|
| t0 | lunch: oats, clean | lunch: oats | |
| t1 | | lunch: oats, banana — stamped | adds a banana |
| t2 | logs a yoghurt in lunch by mistake and takes it out again: lunch is marked changed, and its list is what it was | | |
| t3 | pull: lunch is in the answer, and changed here too → skipped | | |
| t4 | push: the yoghurt's DELETE (404), lunch's fields and its oats — all already there, so nothing is stamped | lunch: oats, banana | |
| t5 | *had t3 stored its cursor:* the next answer starts after t1 and doesn't list lunch. The banana never arrives. | | |

Holding the cursor at t3 means t5 asks from before t1 again, finds lunch clean,
and takes the banana. `_holdBack` counts every such skip, and `pullAll` stores
the answer's cursor only when the count is zero.

A skip counts wherever the pull makes one, at every level of an aggregate: a
root; a workout's exercise entry, or an entry's set templates; a session's own
fields, an exercise's note or its log; a meal, a food item, a weight, a custom
exercise, a plan, a meal template. A retired workout exercise is not dirty and
holds nothing: it is history, kept as it is. A row the pull itself marks
changed — a meal it adopts, a log it re-queues to overwrite stale copies on the
server — is not a skip either: the pull applied the server's copy, and the push
that follows does change the server.

### What it costs

Every answer until the held row is clean repeats what the held one carried.
Usually that is one answer: the push runs straight before every launch and
resume pull, so a row is rarely still dirty when the pull arrives. A row the
push can never send would hold the cursor for good, and the one such row the
pull could meet — a workout that isn't a template, which the push never sends —
is not held back for that reason. A row the server keeps refusing does hold it,
and the answers grow until that is fixed. That trade is deliberate: an answer
that grows costs bandwidth, and a cursor that moves past a row it skipped costs
the row.

### Why nothing caught it

- **The compiler couldn't.** A skip is a `return`. A return with a consequence
  somewhere else — "and now the next answer must carry this again" — looks
  exactly like a return with none.
- **The tests couldn't have, as written.** The fake API answers whatever the
  test put in it, whatever the device pushed. "The push's echo will come back"
  is true in every test that doesn't set out to make it false. The test for it
  (*is left for the push, and the cursor stays until it is clean*) asserts the
  cursor itself, not an outcome that a lenient fake would supply anyway.
- It was found at design time, not in production, only because §27 wrote the
  obligation down before this half was written. That is the argument for a
  server change ending with a list of what it assumes of its client, as the
  server's half of this part did.

---

## 38. Deletions after aggregates

An answer is not a snapshot (§31): its lists are read one after another, so a
row deleted while the answer is being put together can be listed as changed
*and* as deleted. The order the device applies them in decides the outcome:

| Order | What happens to the row | And then |
|---|---|---|
| deletions, then aggregates | deleted, then inserted again from the list | the cursor moves past the tombstone, and nothing will ever say it was deleted again — it is back for good |
| aggregates, then deletions | inserted or updated, then deleted | gone, as it is on the server |

So `pullAll` applies `deleted` last, as its own step (`_applyTombstones`).

Within the deletions, rows go before the rows they hang on: a meal's foods
before meals, sessions before workouts, and so on. A workout is kept when a
session here logged sets against it (§39), and that question has to see the
sessions as the server left them. If the same answer deletes a session and then
its workout, deciding about the workout first would find the session still
there, keep the workout, and create it again on the server — and then delete
the session that was the reason.

Neither order is wrong in any one step: each step is correct on its own. The
failure is in the order two correct steps run in, which is the kind of thing a
test only finds when it builds the one answer that shows it. *is applied after
the answer's aggregates, which can list the same row as changed* is that
answer.

---

## 39. A deletion is a fact now

Every deletion reaches the same method, `_goneElsewhere(entityType, id)`,
whether it came as a tombstone in an answer or as a 410 answering a create
(§40). Each runs under `untracked`: the server already deleted the row, so
recording a DELETE for it would only buy a 404.

| Deleted elsewhere | Here |
|---|---|
| a meal's food | that entry goes; its meal is not marked changed — this is the server's list, not an edit to send back |
| a meal | goes, with its foods — whatever unsent change it holds |
| a session | goes, with its exercises and sets — unless it holds logged work not sent yet: then it takes a fresh id and is created again |
| a plan | goes; the sessions it scheduled stay, detached, as the server's `SET NULL` left them |
| a workout | goes, with its entries, templates, plan links and unlogged sessions — unless a session here logged sets against it: then it and the sessions the server had take fresh ids and are created again |
| a custom exercise | goes — unless a workout here uses it: then kept as it is, taking a fresh id only if it holds an edit not sent yet |
| a food item | goes — unless a meal logged it: then kept the same way |
| a weight | goes |
| a meal template | goes, and nothing is remembered to tell the server |

### Deletion wins over an unsent edit

The old sweep left a row with an unsent change alone, for the push. A
tombstone can't be treated that way, for two reasons. The edit could never
land: a PUT of the row finds nothing (404), and a create of its id is refused
(410), so the row would sit dirty for good, sent on every push, keeping the
sign-out warning up. And a deletion skipped for a dirty row would come back in
the next answer, find the row still dirty, and be skipped again — so the cursor
could never move past it. A tombstone always resolves the row, one way or the
other; it never holds the cursor. §30 already made the same call on the
server: a food added offline to a meal another device deleted is lost with the
meal, because the alternative is the addition bringing the meal back.

### Unless history hangs on it — two kinds

The exceptions are the history protections the old sweep had, now applied to a
fact instead of a guess. They come in two kinds, and they are handled
differently on purpose.

**History that needs the row on the server.** A set can only be sent under a
session the server holds, and a session under a workout. A workout the server
deleted can't have had logged sets there — it refuses that delete with 409 — so
if sessions here logged sets against it, those sets are this device's and have
not been sent. Kept under the old id, they never could be: the id is refused
for good. So the workout takes a fresh id and goes `pending`
(`_recreateWorkout`), and so does each session of it the server had
(`_recreateSession`); their exercise entries, set templates, session exercises
and sets keep their ids — the server keeps no tombstone for those — and go
`pending`, so they are created again under the new rows. Sessions nothing was
logged in were deleted on the server with the workout, and go here too. A
session deleted on its own is kept only for logged work not sent yet: sets the
server already had don't keep it, because whoever deleted it did so knowing
what was in it.

**History that only reads the row.** A workout entry refers to its exercise,
and a meal's food to its food item, and on the server both references are
opaque ids with no foreign key behind them (`WorkoutExercise.ExerciseId`,
`MealFoodEntry.FoodItemId`). Nothing there needs the row to exist; this device
needs it to show a name and macros. So it is kept as it is. Creating it again,
as a workout is, would be worse than it looks: every device that kept it would
create its own copy under its own fresh id — the duplicates part two ended.
Only one holding an edit not sent yet takes a fresh id, because that edit needs
somewhere to land.

### What absence inference cost

Removing `_removeDeletedElsewhere` removed one guess, and it is worth listing
what that one guess had been costing, because none of it looked like a cost at
the time:

- **Every pull was a full download.** In a delta every unchanged row is
  absent, so a pull that infers deletes from absence can't be a delta. Hence
  the six-hour throttle, hence data that arrived hours late (§42).
- **It needed a guard for its own failure** — an empty list deletes nothing —
  and the guard was a second guess: "an empty answer is far likelier to be a
  server fault". A list that was short rather than empty, from a filter or a
  cut-off response, had no guard at all.
- **It could only see roots.** A food removed from a meal elsewhere was noticed
  only when this device's copy of the meal was clean; a dirty one sent the food
  back with its next upsert (§18's open window).
- **It left every dirty row alone,** so a row edited here and deleted elsewhere
  was pushed back up — the original "deleted things come back" — and part one
  had to be careful to make that only an update, never a create.

A tombstone has none of these properties, because it isn't read out of
anything. It is a row the server wrote when it deleted something.

---

## 40. A 410 is a tombstone delivered on the push

A device learns of a deletion from whichever of its two conversations with the
server gets there first. Often that is the push: it runs before every launch
and resume pull, and ten seconds after an edit. A device that hasn't pulled
since another device's delete will send a create naming the deleted id, and
the server answers 410 (§30). That answer carries exactly the fact a tombstone
does, so it is handled by exactly the same code: `_create` hands it to
`_goneElsewhere`, and the row is deleted or created again under a fresh id as
the tombstone would have made it. There is no second set of rules for "the
push found out first".

| Where a 410 arrives | What it names | The device |
|---|---|---|
| a create of a root (`_create`) | the row sent | `_goneElsewhere` for the row's type |
| a meal's foods batch (`_upsertMealFoods`) | one entry of the batch | drops that entry, as the tombstone would, and sends the rest again |
| a meal template's create | the template | removes it, remembering nothing to send |

The foods batch is the window part two named and left open (§18, "What it
still can't do"): an edit to a meal on a device that hadn't pulled a food's
removal sent the food back. From the device's side, §30's table ends like this:
the tablet removes the oats; the phone, not having pulled, adds a banana; its
upsert names the oats; the server answers 410 for them; the phone drops its
oats and sends the banana again. *a food removed from a meal on one device is
not put back by an edit to the meal on another device that has not pulled
yet* is that sequence.

One path no longer waits to be told. `_syncDeleteWorkout` sends a workout's
DELETE, the server accepts it, and then the local delete refuses because a set
was logged against the workout in the moment between — an active workout open
on it. It used to create the workout again "under the ids it already has — the
server deleted those rows, so a create under them makes them afresh". The
server now keeps a tombstone for that workout and every placeholder session its
delete removed, so that create would be answered 410. It goes straight to
`_recreateWorkout`.

A PUT is not a create and doesn't go through `ClientIds`, so an update of a
deleted row answers 404, not 410. That is left to the tombstone: the row stays
dirty until the pull brings the deletion, which is now at most one resume away.

---

## 41. A DELETE the server refuses

Part one's `_pushDeletions` dropped a DELETE the server refused — 409 for a
workout that sessions elsewhere logged sets against, 403 for one a trainer
assigned — on the grounds that "the next pull brings the row back, which is the
server's answer". The device had already deleted the row; the full pull would
list it again and restore it.

A delta doesn't. The refused row hasn't changed on the server, so no answer
after the cursor lists it, and the device would be missing a row the server
kept for good. So a refused DELETE now drops the cursor, and the next pull asks
for everything, as the full pull always did. It is rare, and it costs exactly
what every pull used to.

The general shape is worth naming. The full pull was a safety net nobody had
written down: anything the device got wrong about which rows exist was put
right within six hours, by accident. Every comment that said "the next pull
brings it back" was relying on it. Removing the full pull meant reading every
such comment again and asking whether the delta still brings it back — this
was the one where it didn't.

---

## 42. When the pull runs

The pull runs on launch and on resume, at most every two minutes
(`_runInitialSync`, `main.dart`), and in the background task after its push.
Settings' "Restore from server" asks for everything, whatever the cursor says
(`pullAll(everything: true)`): it is what someone presses when this device's
copy looks wrong. Every pull still goes through the in-flight join, the lease
and `SyncBusyException` (§8).

The six-hour throttle could go because the reason for it went. It existed
because a pull downloaded the whole account, every list, plus the catalogue;
run on every resume, that is megabytes for a long-time user on every glance at
the phone. It cost more than bandwidth: a trainer's edit to a client's
workout, or a session logged on the client's tablet, reached the phone up to
six hours late. A delta answer is the size of what changed — on most resumes,
nearly nothing — so the pull can run whenever the app comes to the front. The
two-minute interval is not a throttle on data; it only stops a burst of
resumes — a permission dialog, a glance at the notification shade — from
pulling once each. It keeps the old key, `last_pull_timestamp`, which
sign-out clears, so a new account's first launch never waits for it.

The background task pulls too. That used to be unthinkable for the same
reason: a background task that downloads the account daily is a background
task the OS kills. Now it asks for a day's changes, so a trainer's edits are
often already on the phone when it is next opened.

---

## 43. What the tests pin (device)

In `test/sync/changes_feed_test.dart` (15 tests). Each was run with the one
rule it pins taken out, and failed there — the code had no cursor, feed or
tombstone to run them against before.

| Test | Pins | Taken out, it failed with |
|---|---|---|
| *the pull asks for everything the first time, and after that only for what changed since the last answer* | §36; §35: a clean row takes the server's copy; a row absent from an answer is not deleted | the cursor never stored; food items insert-only again |
| *… asks for everything when the user restores from the server* | §42 | `everything` ignored |
| *… no longer asks for the list endpoints* | §35, §36: after the first, a pull fetches only the feed | a list GET put back; the catalogue fetched on every pull |
| *… fetches the built-in catalogue when an answer names an exercise this device has not linked* | §36 | the catalogue fetched only without a cursor |
| *the built-in catalogue is fetched when a workout here waits on a built-in not linked yet* | §36 | the waiting check removed |
| *a row this device holds an unsent change to is left for the push, and the cursor stays until it is clean* | §37 | the hold ignored |
| *a deletion in the answer removes a clean row with what hangs only on it, and tells the server nothing* | §39 | tombstones not applied |
| *… keeps a workout that a session here logged unsent sets against, and creates it again under a fresh id* | §39 | the workout kept under its old id |
| *… is applied after the answer's aggregates, which can list the same row as changed* | §38 | deletions applied first |
| *a create the server answers 410 deletes the row when nothing hangs on it* | §40; the deletion is `untracked` | the 410 not handled; the deletion tracked |
| *… gives the row a fresh id when history hangs on it, and creates it under that* | §39, §40 | the workout re-created under its old id |
| *a food removed from a meal on one device is not put back by an edit to the meal on another device that has not pulled yet* | §40, closing §18's window | the batch's 410 not handled |
| *a DELETE the server refuses drops the cursor, so the next pull asks for everything and the row comes back* | §41 | the cursor kept |
| *signing out forgets the cursor with the data it describes* | §36 | `clearAllUserData` leaving `sync_meta` |
| *an install upgraded from schema 42 gains the cursor table, and its first pull asks for everything and applies what was deleted meanwhile* | §36: schema 43 on a real upgrade; a cursorless answer's deletions applied | the schema not bumped |

Existing tests changed where they had encoded the list GETs or absence. The
fake API answers `GET api/Sync/changes` from a map a test fills in
(`FakeApiClient.changes`), records each `since`, and refuses a POST naming an
id in `deletedIds` with 410, as the server does; `stubEmptyPull` now stubs the
catalogue and an empty answer. Every test that stubbed a list endpoint for a
pull now puts the same rows in the answer instead — a change of where they come
from, not of what they say. Five in `sync_rework_test.dart` changed in meaning:

- *a pull step that fails* used to fail the workouts step by leaving its GET
  unstubbed; there is no such GET, so it now gives the answer a workout this
  build can't read, and also checks that the cursor stays.
- *a row deleted elsewhere* — *is deleted here, not pushed back to the server*
  and *a session: goes with its exercises and sets* now deliver the deletion as
  a tombstone instead of leaving the row out of a list, and check that nothing
  is sent back; *is not assumed from an empty list* became *is not assumed from
  a row missing from the answer*; and *is kept while it holds an edit this
  device has not sent* became *is deleted even while it holds an edit this
  device has not sent: the edit could never land* — the one assertion that
  turned round, for §39's reason.

---

## 44. The rules part three leaves behind (device)

- **A deletion is known only from the server saying so** — a tombstone in an
  answer, or a 410 answering a create. Never from a row being absent: in a
  delta, every unchanged row is.
- **Both reach `_goneElsewhere`, and nothing else decides.** A new synced type
  gets a case there, with its history rule: history that needs the row on the
  server gets a fresh id and is created again; history that only reads it
  keeps it as it is.
- **Deletions are applied after the answer's aggregates,** and within them
  children before parents.
- **A row the pull skips because it is dirty holds the cursor** (`_holdBack`).
  So does a record that fails to apply, and a step that fails. The cursor is
  stored only when the whole answer applied.
- **A tombstone never holds the cursor.** It always resolves the row.
- **The cursor lives in `sync_meta`, and is cleared with the data** — by
  `clearAllUserData`, and by a refused DELETE, after which the next pull asks
  for everything.
- **A pull without a cursor applies `deleted` like any other answer.** It may
  be an upgraded install that holds rows deleted elsewhere.
- **Anything that relied on "the next pull brings it back" has to be read
  again.** Only an answer after the cursor comes back.
- **A new synced root needs, on the server, `UpdatedAt` and a tombstone on
  delete (§34), and a place in the feed; on the device, an apply method fed
  from the answer, a hold for a dirty copy, and a case in `_goneElsewhere`.**
- **A 410 on a foods batch means the batch applied nothing.** The answer
  names every deleted entry in `ids` (`id` is the first); the device drops all
  of them in one pass and sends the rest again, so a meal that lost several
  foods elsewhere converges in one retry, not one per food.

---

# Part four: live updates

Parts one to three made the data right and the pull cheap. Neither side learned
of a change any sooner, though. The phone pulled when it was opened, and the
Trainer Console read a client's data when the trainer navigated to it. A client
finishing a session at the gym reached the server within seconds (§9), and then
sat there until the trainer happened to click. A trainer editing a client's
programme reached the client's phone the next time it was opened.

Part four has the server say *something changed* to whoever should know, and
each side fetches the change straight away through the paths it already had.
The server says it two ways:

| | To a trainer's console | To a client's phone |
|---|---|---|
| When | anyone changes a client of theirs' data: the client, or a trainer | somebody other than the client changes the client's data |
| How | `ClientDataChanged` on the SignalR socket the console already holds | a data-only FCM message, `sync_requested` |
| Carries | whose data, and which panes it touches | nothing but its type |
| Answered by | refetching those panes through the console's endpoints | a pull (§36) |
| When it is missed | the console refetches on focus and on reconnect | the app pulls when it is next opened |

This part lands in one pull request in two halves, like part three. The
server's half (§45–§49) deploys first; with no console listening, it sends
events to empty groups and pushes a type no shipped app acts on, which costs
nothing. The console's and the app's half follows in the same pull request and
is written up in §50 onwards.

---

## 45. A signal, not the data

### The contract

Both halves were written at once, against this:

- **Where.** The console's existing chat connection, `/hubs/chat` (token in
  `?access_token=`, as for chat). When a connection opens, `ChatHub.OnConnectedAsync`
  puts it in the group `trainer:{trainerId}` if its user holds a trainer licence
  (`ChatHub.TrainerGroup`). The console joins nothing itself.
- **What.** One hub event, `ClientDataChanged`, with one argument. On the wire
  (SignalR's JSON protocol, which camel-cases):

  ```json
  { "type": 1, "target": "ClientDataChanged",
    "arguments": [ { "clientId": "5b1e7c2a-3f0d-4c1e-9a55-0c2f6d8e4b71", "areas": ["sessions", "workouts"] } ] }
  ```

  `clientId` is the owner of the data, formatted exactly as the console's own
  endpoints format a client's id: a lower-case, hyphenated GUID, the same
  string the roster's `clientId` holds. `areas` is a non-empty subset of
  `workouts`, `sessions`, `nutrition` and `weight`, sorted ordinally, so
  `nutrition` comes before `sessions`, `weight` and `workouts`
  (`DataAreas`, `ClientDataChangedDto`).
- **To whom.** The groups of the trainers with an **Active** relationship to
  that client, and nobody else (§46).
- **The push.** When the person who made the change is not the data's owner, the
  owner's devices get `{ "type": "sync_requested" }` and nothing more, collapsed
  under the key `sync_requested` (§46).
- **When.** Once per request, after it has committed, never inside a
  transaction (§48).
- **Failure.** A send or a push that fails is logged. The request never hears
  of it (§48).

An area is a pane of the console, not a table on the server, because the one
thing the console does with it is decide which panes to fetch again:

| The change is to… (a child's change is its root's, as in §27) | Area |
|---|---|
| an exercise, a workout (its entries and set templates), a plan (its workout links) | `workouts` |
| a scheduled workout (its exercises and logged sets) | `sessions` |
| a meal (its foods), a food item, a meal template (its items) | `nutrition` |
| a weight entry | `weight` |
| settings | none — no event |

### Why the event carries nothing

The obvious event carries the change: the session that was logged, the meal
that was added. The console would apply it and never make a request. This one
says only *whose* data changed and roughly where, and the console answers it by
fetching the affected panes through the endpoints it already uses. That costs a
round trip per event. It buys three things, and the first is the reason.

**Every read of a client's data goes through one door.** Each Trainer Console
endpoint checks, on every call, that the caller has an Active relationship with
the client (`IsActiveTrainerOfAsync`), and CLAUDE.md is explicit that this check
is the security boundary and the app's gate is not. An event carrying data would
be a second way for a client's data to reach a trainer, with its own access
check to keep in step with the first. `docs/trainer-console-duplicate-rows.md`
§5 is about exactly that shape of mistake: two definitions of one thing, each
right on the day it was written, drifting apart. An event with nothing in it
has nothing to protect. The worst a wrongly delivered one could leak is that a
named user's data changed.

**The console keeps one way of building a pane.** Session Review, the nutrition
summary and the roster KPIs are aggregates the server computes. An event that
carried a changed set would have the console recompute them from fragments, and
get them subtly different from what the endpoint returns.

**A missed event costs nothing but time.** This is §48's subject, and it
decides the design as much as the first reason does. An event that carries data
is an update to a copy, and a lost one leaves the copy wrong. Nothing will
correct it until something replaces the whole copy. An event that carries
nothing is a hint that the copy is stale. Every such hint means the same thing,
so a refetch after ten missed hints is as good as receiving all ten.

### Why one hub

The console already holds a `ChatHub` connection for as long as it is open.
`TrainerConsoleHome` owns it so that it survives switching sections. A second
hub would mean a second socket per open console. On Cloud Run an open socket is
an in-flight request, which keeps an instance allocated. That is the one real
running cost of SignalR here, and a second hub would double it for the same
people. The group is joined in `OnConnectedAsync` rather than by a hub method
the console calls, so an old console build, or one that reconnects, is in the
group without doing anything.

---

## 46. Who hears of it

### Only an Active relationship, checked when the event is sent

CLAUDE.md's rule for this codebase is to tie SignalR group membership and any
trainer-facing data access to an Active relationship, not to a role. At first
sight `trainer:{trainerId}` breaks it: a connection joins because its user holds
a licence, which is a role, whoever their clients are.

It doesn't, because the group grants nothing. It is an address, one per trainer,
that only that trainer's own connections can be in: the id comes from their
token, not from anything they send. What reaches the address is decided per
event. `LiveUpdateNotifier` looks up, when it sends, the trainers whose
relationship with that client is `Active`, and sends to their groups and no
others. A Pending invite, a relationship the client or the trainer has ended,
and a trainer of somebody else get nothing
(`AClientsWriteReachesOnlyTheirActiveTrainer`).

The alternative keeps membership per client: at connect, the trainer's
connection joins `client:{id}` for each Active client, and events go to the
client's group. It is the same query, run at the wrong time. A relationship that
ends while the console is open leaves the connection in the group, still
receiving, until it reconnects. A client who accepts an invite during that time
is not in it until then either. Membership computed at connect is a snapshot of
the relationships at connect, and it goes stale for exactly as long as the
socket lives, which for a console is all day. Checked at send, the first event
after a relationship ends goes nowhere.

Being a trainer is holding a licence (`docs/trainer-licensing.md`), so that is
what `OnConnectedAsync` checks — not having clients, which would leave a new
trainer's console deaf until the first invite was accepted. A lapsed licence
still joins: a read-only trainer can still read, so they can still be told
something changed.

**Why a group, and not `Clients.User`.** SignalR can address a user directly by
the id its `IUserIdProvider` reads from the connection. The default provider
reads the `NameIdentifier` claim, and a token minted by the OAuth path carries
the user's id as a bare `sub`. The hub already had to learn that once
(`ChatHub.GetUserId`, and `A_token_carrying_only_sub_is_accepted` in the chat
tests). Addressed by user, a trainer who signed in with Google would never have
received an event. The group is joined with the hub's own reading of the id,
which handles both.

### The push goes only to someone else's change

A client who logs a meal on their phone already has the meal on that phone.
Pushing `sync_requested` to every device they own after every write would wake
the phone that just wrote, to pull what it just pushed. The server can't tell
which of the owner's devices made the request, so it can't leave that one out.
The push is therefore for the case the owner could not otherwise learn of: a
change somebody else made. In practice that is a trainer, and the actor is the
signed-in caller, read from the same claims the controllers read, `sub`
included. A client's second device learns of the client's own edit on its next
pull, as it always has. A request with no signed-in caller asks for no pull.
Nobody made it, so it isn't somebody else's change.

The trainer who made the change still gets the event on their own console,
because they are the client's Active trainer like any other. That is
deliberate: the console refetches what it just wrote, which costs one read, and
any second console the trainer has open is brought up to date by it.

### Data-only, collapsed, and not urgent

The message is `{ "type": "sync_requested" }`: no notification block and no
data. The app pulls through endpoints that check who is asking. It shows
nothing, so there is nothing to render, and data in the payload would be
another way round the endpoints (§45).

It is **collapsed**, with Android's `collapse_key` and iOS's `apns-collapse-id`
both set to `sync_requested` (`FirebasePushSender.ToMulticast`). A trainer
saving a workout in the Workout Builder makes a burst of requests, and each
one that changes the client's data queues a push. While a phone is offline or
dozing, FCM keeps only the latest message under one key, so the phone wakes
to one message, not twenty. Chat messages are not collapsed. Each one is its
own content, and the key is null for them.

It is sent at **normal priority**, where chat is sent at high. This is the one
property of the message the contract didn't fix, and it protects chat. FCM
starts delivering an app's high-priority messages at normal priority once it
sees that they don't lead to a visible notification, and a `sync_requested`
never does. Sent at high priority,
it would teach Android that this app's high-priority messages are noise, and
the messages that would then arrive late are chat's. Normal priority costs
nothing here. The app acts on the message only while it is open, and a device
in use receives a normal-priority message at once.

iOS has never been built (`docs/push-notifications.md`). The collapse header is
set anyway, so the server's half of the contract holds for both platforms. What
else a data-only message needs to reach an iOS app, `content-available` among
it, belongs to setting iOS up.

---

## 47. Whose data a write changed

The server already knew which aggregates each write changed. Part three's
interceptor stamps every root a save touches, and §27 recorded that it stamps
the owner's row, not the actor's, "because part four will hang the trainer's
live notifications off exactly this". So recording what changed is not a second
analysis of each write. It is the same one, written down.

Each request has one `ChangedDataLog` (`FitTracker.Api/Data/ChangedDataLog.cs`),
registered per scope and given to the request's `AppDbContext` through its
constructor. The same instance is what the middleware later reads. A context
built without one records nothing: a test's, or the one the notifier itself
queries through.

### Through the change tracker

`SyncChangeInterceptor` records, for every save, the same three things it stamps
and buries (§27, §29):

| What the save does | What is recorded |
|---|---|
| adds or changes a root with an owner column | the owner and the root's area, read off the row |
| adds or changes a session | the session's id: its owner is its workout's, which the save may not hold |
| adds, changes or removes a child | its root's id, the one the interceptor stamps |
| deletes a root, or a meal food | the tombstone's owner and the area of its type |

A change recorded by id has its owner looked up later, after the request, in one
query per kind of root (`LiveUpdateNotifier.OwnersOf`). Doing it in the save
would have put a query into every write's transaction to find out something
nobody needs until after the commit. A root deleted since it was recorded has no
owner left to find, and needs none: its delete was recorded from its tombstone,
which names one.

### What the change tracker doesn't see

§28 listed the writes the interceptor can't see: `ExecuteDelete`,
`ExecuteUpdate` and the database's cascades. Each already had to stamp by hand,
and each now has to say whose data it changed. Otherwise a trainer clearing a
prescription (a replace with nothing), or a client deleting a plan with
sessions under it, commits, answers 200, and is never told to anyone.

| Call site | What it records, and how |
|---|---|
| `ReplaceListAsync` (sets, set templates) | its list's owner, which the caller now passes (`owner:`), in the area of the list's root: `TouchWhereAsync` records it |
| `WorkoutRepository.DeleteWorkoutAsync`, plans losing a link | the workout's owner, `workouts`: `TouchWhereAsync` |
| the same, placeholder sessions deleted in bulk | the tombstones it writes by hand (`Bury`) are rows of the next save, and are recorded like the save's own |
| `WorkoutRepository.DeleteWorkoutExerciseAsync`, sessions losing placeholder entries | the sessions' ids, owner looked up later: `TouchAsync` records the ids it stamps |
| `WorkoutPlanRepository.DeletePlanAsync`, sessions detached by `SET NULL` | the plan's owner, `sessions`: `TouchWhereAsync` |
| `MealRepository.DeleteMealAsync` | the meal's owner, twice over: the stamp, and the meal's tombstone |

`TouchWhereAsync` stamps whatever roots a predicate matches when it runs (§28),
so it can't know their ids, and can't look their owners up. Its caller names the
owner instead, and the parameter is **required**. Every call site already had
the owner at hand: it is the user whose row is being deleted or replaced, and
the roots a predicate stamps there are that user's too. A default of "nobody"
would have compiled everywhere and notified nobody. That is the one part of this
the compiler can hold. A new bulk statement can't be written without saying
whose data it changes, though it can still say the wrong user, which only a test
will notice.

It records only when the statement stamped at least one row. A plan with no
sessions under it, deleted, says `workouts` and not `sessions`.

### Why nothing would catch the next one

This is §28's argument again, with a smaller failure attached. A write that
records nobody is invisible to everything but a test that asks for the event:

- the compiler sees an `ExecuteUpdateAsync` returning a count;
- the write's own tests check the rows, and the rows are right;
- the feed is right too, because the stamp is separate from the record;
- the console still shows the change the next time the trainer looks, so even
  a person testing by hand sees it work, just late.

Nothing fails. The console is merely slower than it should be for one kind of
write, and nobody has a reason to suspect which. That is why each bulk path in
the table has its own test in `LiveUpdateTests`, which ends the request and
checks the areas. For the replace that is `AReplaceWithNothingIsStillReported`;
a replace that inserts rows would pass on the inserts alone, the same trap §28
fell into with stamps.

---

## 48. After the commit, once per request

### Held until it commits

A change is recorded when it is written, which is before anyone knows whether it
will commit. The log holds each one with the transaction it was written in, and
counts it only once that transaction has committed:

| Written by… | Counts when… |
|---|---|
| a save outside any transaction | the save succeeds. If EF opened a transaction of its own for it, that has committed by then |
| a save or a statement inside a transaction | that transaction commits. If it rolls back, or is disposed without a commit, never |
| a statement outside any transaction | at once: it committed by itself |
| a save that fails | never. What it recorded is taken back, even inside a transaction that goes on: EF rolls a failed save back to a savepoint, and the transaction continues |

The interceptor follows the save to its end (`SavedChanges`, `SaveChangesFailed`)
and the transaction to its commit (`TransactionCommitted`). It records last,
after the stamps and tombstones, because EF reports a save as failed only from
its statements on. A record made before a stamp that threw would never be taken
back, and the next successful save would commit it.

The foods batch shows why this can't be simpler. It runs in one transaction and
saves once per food, so its first food's save succeeds before its second food
is refused (§30). A log that counted a save as done when the save returned
would announce a meal that the rollback then took back.
`ARolledBackTransactionNotifiesNobodyAndLeavesWhatCommittedBeforeIt` plays that
request after a weight logged on its own. The event names the weight, and not
the meal.

### Why never before

An event sent from inside a transaction can announce a change that a rollback
then takes back, as above. That only costs a wasted refetch. The worse case is
a change that does commit, because the event can still arrive too early:

| Time | A client's phone logs a set | The trainer's console |
|---|---|---|
| t0 | the sets batch writes the set, in its transaction | |
| t1 | (if the event were sent here) | receives `ClientDataChanged` |
| t2 | | refetches Session Review; its read runs on another connection and can't see an uncommitted row |
| t3 | commits | |
| | | shows the session without the set, and has been told everything it will be told |

An event is a promise that a read will now see something new. Sent before the
commit, it breaks the promise for exactly the reader it was sent to. Nothing
retries: the console has done what it was asked, and the change sits unseen
until the tab next regains focus. Nothing tests this by accident either. In a
test, the read and the write share one connection, where the uncommitted row is
visible.

### Why once per request

A transaction commit is not the unit either. A trainer saving a workout in the
Workout Builder makes one request, and that request is a dozen saves, several
in transactions of their own: the workout, each exercise entry, each list of set
templates.
Sent at each commit, it would be a dozen events for one click, each asking the
console to refetch the same pane. The console debounces, but the server has no
reason to make it.

So nothing is sent at a commit. `LiveUpdateMiddleware` runs around every
request. When the request is done it takes what the log holds as committed, and
hands it on once, with the caller. `LiveUpdateNotifier` sends one event per
owner, naming every area the request changed for them
(`ManyChangesInOneRequestAreOneEventPerOwner`). A trainer's request touching two
clients is two events and two pushes, one each.

The middleware takes the log in a `finally`. A request that commits and then
fails, say while writing its answer, still changed the data, and the change is
still reported (`ARequestThatFailsAfterCommittingStillQueuesWhatItCommitted`).

### After the answer, off the request

The notifying itself runs after the request, on a detached task with its own DI
scope (`LiveUpdateDispatcher`). It is chat's pattern (`ChatPushDispatcher`, and
`docs/chat-architecture.md` §18). Waiting would put an owner lookup, a
relationship query, a hub send and a round trip to Google in front of every
write's answer. Failures are logged there, one send at a time. A hub that throws
doesn't stop the push (`AFailedSendStillAsksForThePull`), a push that throws
doesn't stop the next owner (`AFailedPushStopsNothingElse`), and the request
finished before any of it began.

§18 also warns against exactly this. Cloud Run only guarantees CPU to an
instance while a request is in flight, and work detached from a request that
has answered is throttled. The chat push is safe because it is queued from a
hub, whose socket is itself a request in flight. This is queued from an ordinary
request, and the warning applies. It applies less than it looks:

- **The SignalR event** can only reach connections on this instance (see below).
  An instance holding a console's socket has a request in flight for as long as
  the console is open, so it keeps its CPU. An instance holding none has nobody
  to send to. Throttling can only delay an event that was going nowhere.
- **The push** goes out when a trainer changes a client's data, and a trainer
  does that from the console, which holds such a socket. On a single instance,
  the usual case at this size, that is this instance.
- **Either one lost** is an update that arrives later, never a wrong one (below).

### No backplane, and what a missed event costs

Cloud Run may run several instances of the API, and SignalR's groups live in
each instance's memory. An event sent on one instance reaches only the sockets
held on that one. A backplane (Redis, which on Google Cloud is Memorystore)
would fan every event out to every instance. It is also a fixed monthly cost
and a second piece of infrastructure to run, for a deployment that is usually
one instance. Chat has lived with the same limit since it shipped.

So an event can be missed. A write lands on instance B while the trainer's
socket is on instance A; a socket drops and reconnects between a commit and its
event; the detached task is lost when an instance shuts down. Each costs
**freshness, never correctness**, and §45 is why. The console never applies
anything from an event. Everything it shows comes from a read of the database,
so the worst a missed event can do is leave a pane showing what was true a
moment ago. To bound how long, the console also refetches when it regains focus
and when its socket reconnects, and the app pulls whenever it is opened. That
refetch is the guarantee. The event makes it sooner.

The same reasoning is why there is no acknowledgement, no retry and no queue of
unsent events. Each would make a hint more reliable, and a hint that is late
costs very little.

---

## 49. What it costs, what the tests pin, and the rules (server)

### Running cost

| What | Cost |
|---|---|
| The SignalR events | Nothing per message: the hub is part of the API, not a paid SignalR service. The real cost of SignalR here is an instance kept allocated while a socket is open, and the console already held that socket for chat. The events add a few hundred bytes to it. A second hub would have doubled the sockets, which is why there isn't one. |
| FCM `sync_requested` | Free: FCM has no per-message charge. It is sent only for a change someone other than the owner made, and collapsed. |
| The database | Per request that committed a change, after the request: one query per kind of root recorded by id (usually none or one), and one indexed query for the owners' Active trainers (`TrainerClients.ClientId`). A request that commits nothing, which covers every read, costs nothing but an empty log. |
| Not added | A Redis backplane (Memorystore is a fixed monthly cost). The focus and reconnect refetches cover what it would. |

The rework as a whole still lowers the server's load. Parts one to three replaced
nine full-list downloads on every sync with one delta.

### What the tests pin

In `FitTracker.Api.Tests/LiveUpdateTests.cs` (26), `ChatHubTests.cs` (3 more)
and `DeviceTokenTests.cs` (4 more). Each test was written first and run against a
skeleton: the types and signatures in place, nothing recorded, nothing sent,
nothing joined. The ones that describe an absence (no event for a client with no
trainer, no group for a non-trainer) and the ones that pin a shape (the JSON, chat's FCM
mapping, every tombstone type's area) passed there, as they should. Each of
those, like every other, was then checked against a mutation that puts the
failure back:

| Test | Pins | Fails when… |
|---|---|---|
| *AClientsWriteReachesOnlyTheirActiveTrainer* | §46: Active only, and only trainer groups | the status filter is dropped |
| *AClientWithNoActiveTrainerIsNobodysEvent* | §46 | an event is sent with no group to send it to |
| *ATrainersWriteToAClientsDataAsksTheClientsDevicesToPull*, *ATrainersDeleteOfAClientsWorkoutReachesTheClient*, *ATrainersRequestTouchingTwoClientsIsOneEventAndOnePullEach* | §46: the owner's devices, when somebody else changed the data | nothing is pushed; the push goes to the actor |
| *AUsersWriteToTheirOwnDataAsksForNoPull*, *ARequestWithNoSignedInUserAsksForNoPull* | §46: only somebody else's change | every change is pushed; a request with no caller counts as somebody else |
| *EachKindOfDataIsReportedInItsArea*, *AChildsChangeIsReportedInItsRootsArea*, *EveryTombstoneTypeHasAnArea* | §45: the areas; §47: a root's own change, a child's through its root, a delete through its tombstone | a root is moved to another area; a tombstone type has none; a changed root isn't recorded; a root reached through a child isn't, or its owner isn't looked up |
| *ManyChangesInOneRequestAreOneEventPerOwner* | §48: once per request, naming every area, in order | an event goes per change; the areas aren't ordered |
| *ARolledBackTransactionNotifiesNobodyAndLeavesWhatCommittedBeforeIt* | §48 | a save counts once it returns, whatever its transaction then does |
| *AFailedSaveIsNotReportedByTheSaveAfterIt*, *AFailedSaveInsideATransactionIsNotReportedWhenTheTransactionCommits* | §48: a failed save takes back what it recorded, and only that | nothing is taken back; where the save began isn't marked |
| *AReplaceWithNothingIsStillReported*, *DeletingAPlanReportsTheSessionsItDetaches* | §47: `TouchWhereAsync` | it records nothing |
| *RemovingAnExerciseReportsTheSessionsWhosePlaceholdersGo* | §47: `TouchAsync` | it records nothing |
| *DeletingAWorkoutReportsThePlaceholderSessionsItRemoves* | §47: `Bury` | tombstones written by hand aren't recorded |
| the five above, *AChildsChange…* and *ManyChanges…* | §48: a transaction's changes count at its commit | the commit is ignored |
| *AFailedSendStillAsksForThePull*, *AFailedPushStopsNothingElse* | §48: each send on its own | a failed send or push isn't caught |
| *WhatARequestCommittedIsQueuedWhenItEnds*, *ARequestThatFailsAfterCommittingStillQueuesWhatItCommitted*, *ARequestThatCommitsNothingQueuesNothing*, *TheActorIsReadFromAnOAuthTokensSubClaimToo* | §48: the middleware; §46: the actor | the queue isn't in a `finally`; an empty log is queued; the actor is read from `NameIdentifier` only |
| *AContextBuiltByDependencyInjectionRecordsIntoTheRequestsLog* | §47: the request's context records into the request's log | the context ignores the log it is given |
| *TheEventReachesTheConsoleAsCamelCaseJson* | §45: the wire format the console reads | the payload gains a field |
| *A_trainers_connection_joins_its_trainer_group*, *A_non_trainers_connection_joins_no_group*, *A_trainer_without_a_licence_joins_no_group* | §46: a licence makes a trainer | nothing is joined; the licence isn't checked |
| *A_sync_request_is_data_only_collapsed_and_not_urgent*, *Fcm_is_given_the_collapse_key_for_both_platforms*, *A_chat_push_to_fcm_is_unchanged* | §46: the push, and chat's untouched | it is sent at high priority, or not collapsed; Android isn't given the key; chat gains an APNs block, or loses high priority |

*A_sync_request_prunes_dead_tokens_like_a_chat_push* shares chat's pruning,
and fails with it.

Two mutations survived the first run, and both taught something.

The first took out the line that makes a failed save take back what it had
recorded. The test for a failed save still passed. It checked that the failed
save sent nothing, and nothing had committed after it, so its leftover record
never had a chance to be counted by anything. The failure the line prevents is
the *next* save committing it. The test now does exactly that: it fails a save,
then logs a weight in the same request, and expects only the weight. A second
test does it inside a transaction, with a record made *before* the failure too,
so that taking back too much fails as well. The general form is the one §31
learned about the cursor: a test of "nothing happens" can pass because nothing
could have happened. It has to give the bug its way out and check it wasn't
taken.

The second took out a guard in the interceptor. It took back the save's records
if the interceptor itself threw before EF ran the save's statements, which EF
doesn't report as a failed save. No test could make it throw there. And on
another look, nothing had been recorded by then either: the records were written
after the stamps. The guard is gone, the records are written last on purpose,
and the comment at that line says why.

### The rules part four leaves behind (server)

- **A write to synced data says whose it changed.** Through the change tracker
  that is automatic. A bulk statement stamps through `TouchAsync`, which records
  the roots it stamps, or `TouchWhereAsync`, which takes the owner and records
  them. A row it deletes gets a tombstone through `Bury`, which the next save
  records. A new bulk path gets a test that ends the request and checks the
  areas, because nothing else will notice it doesn't.
- **A new synced root needs an area** in `DataAreas.Of`, a tombstone type in
  `DataAreas.OfTombstone` (a test checks every type has one), and an owner lookup
  in `LiveUpdateNotifier.OwnersOf` if anything records it by id.
- **Nothing is sent before the commit, and nothing more than once a request.**
  Don't send from a save, an interceptor or a transaction hook. Record, and let
  the middleware hand on what committed. The middleware only sees HTTP requests:
  a hub method or a background job has its own scope and its own log, and one
  that ever writes synced data must hand that log to `ILiveUpdateDispatcher`
  itself. None does today; chat writes nothing synced.
- **The event carries no data.** A pane that needs something new gets it from an
  endpoint that checks the relationship itself.
- **Who hears of a change is decided when it is sent**, against Active
  relationships. A group is an address, never a permission, and membership is
  never computed from relationships at connect.
- **The push is for somebody else's change.** It carries only its type, is
  collapsed, and is never sent at high priority, since it never shows a
  notification.
- **A failure to notify is logged and goes no further.** Nothing in the request
  waits on a notification.
- **An event is a hint, and may be lost.** Anything the console relies on must
  also arrive by the refetch on focus or reconnect. With no backplane, a lost
  event is normal operation, not a fault.

The device's half follows in §50.

---

# Part four, continued: the device and the console

Part three made the pull cheap enough to run whenever the app comes to the
front. It did not make anyone *know* when to run it. A trainer watching a
client's session in the console saw it only when they next navigated; a
trainee whose trainer had just rewritten tomorrow's workout saw it only when
they next resumed the app. Part four has the server say "something changed",
and each side fetch it straight away.

The server's half (§45–§49) decides when to say it and to whom. This half is
what the two clients do when they hear it:

| | Hears | Does |
|---|---|---|
| **Trainer Console** | `ClientDataChanged {clientId, areas}` on the `ChatHub` socket it already holds | refetches the panes showing that client's changed areas, about a second after a burst ends; the roster and the Dashboard's figures about three seconds after any client's event; everything shown when the tab regains focus or the socket comes back |
| **Trainee app** | a data-only, collapsed FCM message `{type: "sync_requested"}` | in the foreground, pulls now, skipping the two-minute interval but not the lease; in the background, nothing |

Neither message carries data, and neither side trusts that it will hear every
one. Those two decisions shape everything below.

---

## 50. An event that says only "go and look"

`ClientDataChanged` names a client and the parts of their data that changed —
`workouts`, `sessions`, `nutrition`, `weight` — and nothing else. The console
turns it into `ClientDataChange` (`domain/models/client_data_change.dart`) and
then reads what it shows again, through the endpoints it already reads it
from. It would have been easy to put the changed rows in the event and save the
round trip. Three things make that the wrong trade.

**The endpoints are where the access checks are.** Every Trainer Console
endpoint re-checks the caller against an Active relationship (CLAUDE.md, "Web
support": the console's gate is a UX guard, not a security boundary). An event
that carried data would be a second way for a client's data to reach a
trainer, decided at the moment the server sent it rather than the moment the
trainer reads it. A relationship ended between the save and the event would
still deliver the save. A refetch asks again, and is refused.

**The endpoints are where the shape is.** Session Review folds duplicate rows,
the nutrition summary folds meals per day and category, and the builder reads
retired exercises differently from live ones — each of those rules lives in
one read path on the server (`docs/trainer-console-duplicate-rows.md`,
`docs/trainer-session-review.md`). A payload built from whatever the save
happened to change would be a second read path, and the two would drift the
way every second read path in this repo has. An event with no data can't
drift from anything.

**It can be missed anyway (§54).** A client that must refetch whenever it
might have missed an event needs the refetch path to be complete on its own.
Once it is, data in the event only duplicates it.

What the event costs is one request per pane per burst, against endpoints
`docs/trainer-console-loading.md` §5 already bounded.

The parse is lenient in one direction only. An area this build doesn't know is
dropped and the others kept, so a server that adds an area doesn't silence an
older console; an event with no client id is dropped whole, since there is
nothing to attribute it to. The hub client (`SignalRHubChatClient`) hands the
event up as JSON rather than parsing it: it is chat's transport, the console
depends on chat and not the other way round, and the meaning of the event is
the console's.

---

## 51. One refetch per burst

A push from a phone is several requests — the session, then its exercises, then
each exercise's log — and each commits separately, so each is its own event.
Without a debounce a finished set would refetch Session Review five times in a
second, and the last of those five reads is the only one anyone sees.

`ConsoleLiveUpdates` (`presentation/providers/console_live_updates.dart`)
collects events per client and emits one `ClientRefresh` per client a second
after the last event of a burst, and one `RosterRefresh` three seconds after
the last event for any client. The timer restarts on every event: a window
that opened on the first event and closed a second later would split a push
that takes two seconds into two refetches.

The two delays are different because the two refreshes are different. A pane
shows one client, and a trainer watching it wants the set they just saw logged;
a second is short enough to feel live and long enough to cover a push. The
roster and the KPIs summarise every client, so every event in the console's
whole roster moves them, and an event for any of twenty clients would otherwise
refetch them twenty times; three seconds folds more of that together, and a
roster figure a few seconds behind is not something anyone watches for.

A restarting timer can in principle be starved by events that never stop
arriving, and here that is the intended behaviour: the only realistic source is
one long push — a phone's first sync after a reinstall — and the useful refetch
is the one after it.

Client ids are compared without case. Both sides are the server's GUIDs,
which it writes in lower case today; a pane that stopped refreshing because one
serializer changed its mind would fail silently, and the comparison costs
nothing.

---

## 52. A refresh keeps what is shown

A refresh is not a load, and treating it as one fails in three separate ways,
all of which the existing loaders would have produced if they had simply been
called again.

**It flashes the skeleton.** Every `load` in the console set `isLoading`,
cleared the data it was replacing, and let the screen draw its skeleton —
right for switching to another client, whose data must not show under the new
name. For the same client, a second after the trainer watched a set arrive, it
blanks the pane they were reading.

**A failure becomes an error — or worse, empty.** The loaders set `error` on a
failure, and every client-scoped pane renders a full-page `ErrorStateView`
while `ActiveClientProvider.error` is set. A roster refresh that failed once in
the background would have replaced whatever pane the trainer had open with
"could not load clients". `docs/app-chrome-and-insets.md` records the other way
this goes wrong — a `finally` that restores the loading flag and drops the
reason, so a failure reads as "nothing here". Neither is acceptable for a read
nobody asked for.

**An older answer lands on a newer one.** A refresh and a load, or two
refreshes, can be in flight together; whichever answers last used to win,
including the one asked first.

So each loader grew one parameter rather than a second fetch path:
`load(clientId, keepShown: true)` on `NutritionProvider` and
`SessionReviewProvider`, `load(keepShown: true)` on `TrainerConsoleProvider`
and `ClientDetailProvider`, and `loadClients(keepShown: true)` on
`ActiveClientProvider`. With it, the loader:

- leaves the data, the selection and the loading flag alone while it reads;
- on success, replaces the data and clears any error — a refresh is also how a
  pane that failed earlier recovers;
- on failure, changes nothing. The data stays up, and nothing is set that a
  screen would turn into an error or an empty state.

It is only a refresh when there is something of that client's on screen to
keep. For another client, or while the first load is still in flight, it is an
ordinary load — including clearing what's there. A refresh that arrives during
a pane's first load therefore issues a second read and drops the first one's
answer, which costs a request and is the only way to be sure: the first read
may have reached the server before the change was committed.

Every loader also numbers its reads, and applies an answer only if it is the
latest one asked (`_request`). The old guard compared client ids, which tells a
slow answer for the previous client from one for this client, but not two
answers for the same client.

Two providers needed more than that.

`NutritionProvider` also writes: pinning a nutrient updates the summary
optimistically and then saves. A refresh that read the summary before the save
landed would put the old pins back on screen, and nothing would put them right
again. A read that overlapped a pin write — started before one, or during —
keeps the pins on screen and takes everything else (`_pinEpoch`,
`_pinWrites`); the write's own outcome is what settles them.

`ClientDetailProvider` loads three sections independently. Its refresh keeps
each: a section whose read fails keeps what it showed, and no error is set that
could blank the screen.

---

## 53. The Workout Builder: an open day is the trainer's

The builder is an editor, and the day it has open is a draft the trainer may
be halfway through. Reading the plan again underneath it has the same problem
the pull has with a dirty row (§37), and gets the same answer:

- a **clean** open day takes the server's copy — the trainee reordered their
  exercises, and the trainer should see it before they start editing;
- a day with **unsaved edits** is left exactly as it is, while the rest of the
  pane — the plan card, the list of days — updates around it. The trainer's
  save is what reaches the server next, as it always was;
- a new day that was never saved counts as unsaved.

`WorkoutBuilderProvider.refresh` is its own method rather than `load` with a
flag, because `load` resets the day state and lands on the first day, which is
exactly what a refresh must not do. It reads what `load` and `loadDays` read —
the client's current plan, workouts and exercise library — except the
trainer's own templates, which no change of the client's can move.

Two details made it work in the screen and not only in the provider.

**The editor's fields are built once.** `_DayEditorForm` makes its text
controllers from the draft in `initState` and is keyed by the selected day's
id, so a new draft for the *same* day left the old name in the name field —
and the next keystroke wrote the old name back into the new draft. A refresh
that replaces the draft bumps `draftRevision`, and the editor is keyed on that
too. It is bumped only when the server's copy differs from what the trainer
last saved, so the echo of the trainer's own save — the server sends the event
for that too — doesn't rebuild the form and take their cursor away.

**The builder writes as well as reads.** A refresh that started before a save
could answer after it with the day as it was before the save — and, the draft
being clean again after saving, replace it. So a refresh doesn't start while
any of the builder's own reads or writes is in flight, and it drops its answer
if one started while it was reading (`_epoch`). Whatever it overlapped either
shows data at least as new, or is a save that brings its own event.

A plan deleted elsewhere lands the pane where deleting it here would have —
the create flow — unless a draft holds unsaved edits, in which case the
refresh is dropped rather than taking the draft's context away.

---

## 54. A pane nobody can see waits

The console keeps every section it has shown mounted (`LazyIndexedStack`), so
a trainer who has opened all five has five panes listening. An event for the
client they are looking at would refetch every one, most of them behind the
one on screen — the thing `docs/trainer-console-loading.md` §7 took apart,
and the rule its §12 draws from it: *a screen nobody can see should not be
fetching*.

`LiveRefreshPane` is the one place that rule is kept. A pane's `State` mixes it
in and says three things: whose data it shows (`liveClientId`), which refreshes
concern it (`concernsLive`), and how to read again (`refreshLive`). The mixin
subscribes, and asks `Visibility.of(context)` whether the pane is shown —
`IndexedStack` reports its hidden children as not visible, and the dependency
calls `didChangeDependencies` again when that changes. A refresh for a hidden
pane is remembered, and run when the pane is next shown, unless the pane has
switched to another client in the meantime (and so read that client since).

| Pane | Refreshes on |
|---|---|
| Dashboard (KPIs) | any `RosterRefresh` |
| Nutrition | its client's `nutrition` |
| Session Review | its client's `sessions` or `workouts` — a session shows under its workout's name, against its prescription |
| Workout Builder | its client's `workouts` |
| Client Detail | any of its client's areas |
| the roster (`ActiveClientProvider`) | any `RosterRefresh`, from the shell — every pane shows it in the client switcher, so it is never hidden |

Client Detail is pushed as a route, and a route isn't under the console's
providers; `_openClientDetail` hands the `ConsoleLiveUpdates` across in a
`Provider` of its own. A pane mounted with none — alone, in a test — never
refreshes, and says so rather than failing.

A pane refreshes for the client *it* shows, not for "the active client". The
two are the same for the four sections, which follow the switcher; Client
Detail shows the client whose row was tapped, and refreshes for them.

---

## 55. Focus and reconnect: a missed event costs freshness, never correctness

The server sends `ClientDataChanged` to a SignalR group, and a group reaches
only the connections on the instance that sends to it. Cloud Run runs more than
one instance when it needs to, and there is no backplane (Redis would be a
fixed monthly cost; chat already lives with the same limit). A trainer whose
socket landed on instance A never hears about a save handled by instance B.
Events are also lost while the socket is down, and a browser tab in the
background can have its socket closed under it.

So the event is an accelerator, never the mechanism. The console reads again
without one at the two moments a missed one is most likely to matter:

- **when the tab or window regains focus.** `TrainerConsoleHome` listens with
  an `AppLifecycleListener`; on web, Flutter reports a window losing focus as
  `inactive` and regaining it as `resumed`, so `onResume` covers a browser tab
  the trainer comes back to as well as the desktop and mobile apps. It goes
  through the same debounce, so a flurry of focus changes reads once.
- **when the socket comes back.** `ConsoleLiveUpdates.reconnectsOf` watches the
  connection's status and counts a return to `connected` after anything else —
  SignalR's own reconnect, and also a fresh start after it gave up and closed,
  which `onreconnected` never reports — but not the first connect, which lands
  while the panes make their first reads anyway. A socket that keeps dropping
  refetches at most once per 30 seconds (`reconnectCooldown`), and once more
  when the cooldown ends if it dropped again meanwhile: the last drop's gap is
  exactly the one no refetch has covered yet.

Either refetches everything shown: every pane's areas, whatever client it
shows, and the roster. That is the trade the design makes on purpose: without
a backplane an event can be missed, and when one is, the console is stale
until the trainer next looks away and back — never wrong, and never stuck.

---

## 56. The phone's half: `sync_requested`

When someone other than a row's owner changes it — a trainer editing a
client's workout — the server sends the client's devices a data-only FCM
message, `{type: "sync_requested"}`, with a collapse key, so a burst of edits
reaches a phone as one message.

**In the foreground it pulls, now.** `handleForegroundPush`
(`lib/core/services/push_messages.dart`) routes it to
`PushService.requestSync`, and `HomeScreen` — which owns the pull — hears it on
`onSyncRequested` and runs `ForegroundPull.run(requested: true)`
(`lib/core/sync/foreground_pull.dart`). It's a stream rather than a call
because `HomeScreen` may not be mounted; a request nobody hears is dropped, and
the next launch or resume pulls anyway.

**It skips the interval.** A launch or resume pulls at most every two minutes
(§42). That interval exists to stop pulls nobody asked for — a resume after a
permission dialog, a glance at the notification shade. A `sync_requested` is
the server saying there is something to fetch, which is the one case the
interval was never meant for.

**It does not skip the lease.** It goes through `pullAll`, which takes the
lease (§8) and joins a pull already running in this isolate. Everything the
lease protects — a push and a pull interleaving, the background task running
alongside — is as true for a pull the server asked for as for any other.

**But it doesn't join a pull already running.** It first waits for this
isolate's runs to finish (`SyncService.whenIdle`), then pulls. A pull already
in flight may have asked the server before the announced change was committed;
joining it would answer the request with the older answer, and the change
would wait for the next resume, which could be hours. Waiting costs the rest
of that run. It is still never two pulls at once: the second starts after the
first ends, and a pull that starts in between is one that asked after the
message, which it then joins.

**In the background it does nothing** — no notification, and no pull. Both
paths go through the same decision by type, `PushMessageType.of`, and
`handleBackgroundPush` passes on only chat. A pull in the FCM background
isolate would have to build everything the WorkManager task builds — locator,
database connection, API client — inside a handler the OS gives a short
window it doesn't promise to keep; one killed halfway leaves the lease held
until it expires, and the app's own sync then waits behind it on the next
launch. And nothing would be gained: the app pulls when it next comes to the
front, and the daily background task pulls too. The message exists to save a
wait while someone is looking.

**Chat is unchanged.** Chat push was already data-only, and the device writes
the notification (`docs/push-notifications.md`, `docs/chat-encryption.md`).
That made "does a new type show a notification?" a question the device
answers, and before this part it answered it with a `type != 'chat_message'`
check repeated in two places in `main.dart`. The check is now one function per
path, beside the enum, where a test can hold it; `main.dart` only supplies what
"show a chat notification" means in each isolate.

---

## 57. Why nothing caught it

Most of this part adds behaviour rather than fixing a bug, but each rule above
is one the code would have broken silently if written the obvious way.

- **The compiler couldn't tell a refresh from a load.** Both are
  `Future<void> load(String clientId)`. A refresh written as a second call to
  the existing loader type-checks, runs, and flashes the skeleton, clears the
  data on failure, and lets an older answer win — three regressions no type
  describes.
- **The fakes answer at once.** `FakeTrainerConsoleRepository` returns
  synchronously unless a test holds it, so "the refresh is in flight" is a
  state no existing test ever drew. The tests for §52 hold the fake open with a
  gate, and flip it to failing after the first load, to draw the states a real
  network produces.
- **A missed event looks like nothing.** No test can observe an event that
  was never sent. The fallback is pinned by its triggers — focus, reconnect —
  not by an event going missing.
- **A notification is decided by type, and types are strings.** A new push
  type fell through the existing checks only because both happened to test for
  `chat_message` exactly. A check written as `type != 'sync_requested'` in one
  place would have drawn an empty notification for every future type.
- **"Joins a pull in flight" reads as a safety property.** It is, for
  concurrency. It is also a way to answer a request with an answer from before
  it, and no test about duplicates would notice.

---

## 58. What the tests pin (device and console)

In `test/trainer_console/live_updates_test.dart` (14 tests),
`test/push/push_messages_test.dart` (6) and `test/sync/foreground_pull_test.dart`
(3). Each was run with the rule it pins taken out, and failed there.

| Test | Pins | Taken out, it failed with |
|---|---|---|
| *an event for the active client refetches its pane once for a burst* | §51 | the pane debounce removed; the pane ignoring refreshes |
| *… for another client refreshes only the roster* | §50, §54: a pane refreshes for its own client | the client id not compared |
| *… for an area the pane does not show leaves it alone* | §54's table | the pane's area filter widened to every area |
| *… for a section nobody is looking at waits until it is shown* | §54 | the visibility check removed |
| *… refetches a client detail opened from the roster* | §54: the route is handed the source | the route's `Provider` removed |
| *a refresh keeps what is shown on screen while it reads* | §52 | `keepShown` ignored |
| *… that fails keeps what is shown instead of an error* | §52, for a pane and for the roster | the pane's failure setting its error; the roster's |
| *the fallback refetches when the window comes back into focus* | §55 | the lifecycle listener removed |
| *… when the socket comes back, at most once a cooldown* | §55 | the cooldown removed; the trailing refetch removed |
| *reconnects are a connection coming back, not the first connect* | §55 | the first connect counted |
| *the event drops an area this build does not know, and keeps the rest* / *… with no client … is ignored* | §50 | an unknown area throwing |
| *the Workout Builder gives a clean open day the server copy* | §53 | the copy not taken; the revision not bumped |
| *… never overwrites a day with unsaved edits* | §53 | the dirty check removed |
| *a sync_requested in the foreground asks for a pull and shows nothing* | §56 | the request not made; a notification drawn as well |
| *… in the background shows nothing* | §56 | the type check removed |
| *a chat message, as before, in the foreground is shown, and asks for no pull* / *… in the background is shown* | §56: chat unchanged | chat not shown |
| *a type this build does not know does nothing anywhere* | §56 | an unknown type shown as chat |
| *PushService hands a requested pull to whoever is listening* | §56 | `requestSync` emitting nothing |
| *a resume inside the interval does not pull* / *a sync_requested pulls even inside the interval* | §56 | `requested` not skipping the interval |
| *a sync_requested during a pull already running waits for it, then pulls again* | §56 | `whenIdle` removed — the request joins the older pull, and the trainer's row never arrives |

The fakes grew three seams: `FakeTrainerConsoleRepository`'s nutrition
fixture, its `throwOnNutrition`/`throwOnRoster` and its `gate` can be changed
after the first load, and it counts weight-history reads; `FakeApiClient`'s
`holdChanges` answers a changes request with what the server held when the
request arrived, but only once released — a pull whose answer is still on its
way back when the change it should have carried is committed.

---

## 59. The rules part four leaves behind (device and console)

- **An event says only "go and look".** It never carries data; the console
  reads through the endpoints that check access and fold duplicates. A new
  kind of live update gets an area name, not a payload.
- **A refresh is a load that keeps what is shown** — `keepShown`, on the one
  loader, never a second fetch path. It raises no loading state, keeps the data
  and sets no error on failure, and applies only the latest answer asked for.
- **A read that overlaps a write of the same thing keeps what the write set.**
  The nutrition pins, the builder's saves: whichever side can overwrite the
  other has to know the other was in flight.
- **An open draft with unsaved edits is the trainer's.** Only a clean one takes
  the server's copy, and an editor built from a draft once is keyed on its
  revision.
- **A pane nobody can see doesn't fetch; it catches up when shown.** New panes
  mix in `LiveRefreshPane`, and a pushed route is handed the source.
- **An event can be missed, so it is never the only trigger.** Focus and
  reconnect read everything shown again; a reconnect refetch is throttled with a
  trailing run, not dropped.
- **Whether a push draws anything is decided by type, on the device, in one
  place per path** (`push_messages.dart`). An unknown type draws nothing and
  does nothing.
- **`sync_requested` bypasses the interval, never the lease.** It waits for a
  run in flight and then pulls, rather than joining an answer that may predate
  it. In the background it does nothing.

### What this half deliberately leaves out

- **Push to the console when it isn't open.** The console is a browser app, and
  web push needs a service worker and a VAPID key (`docs/push-notifications.md`).
  A trainer who opens the console reads everything fresh anyway.
- **A pull in the background on `sync_requested`**, for the reasons in §56.
- **Refetching only the changed section of a pane.** Every pane reads its one
  endpoint whole; Client Detail reads its three. Finer would need the event to
  say more, which §50 argues against.
- **A refetch on the very first connect.** A change committed after a pane's
  first read but before the socket joined the trainer's group is missed until
  the next event for that client or the next focus. The window is one
  handshake long, and closing it would add a refetch to every console open.

---

## What is deliberately not here yet

- **A SignalR backplane** (§48). An event reaches only the sockets on the
  instance that sent it. The console's refetch on focus and on reconnect covers
  what a missed one costs. A backplane is worth its fixed cost only once
  someone measures trainers waiting on it.
- **Telling a user's other devices about their own change** (§46). The server
  can't tell which of the owner's devices made a request, so a push for the
  owner's own write would wake the phone that made it. Their other devices see
  it on their next pull, as before.
- **An area for settings** (§45). The contract gives settings none, but the
  console's Nutrition pane shows the client's calorie goal, which lives there.
  A client changing it is seen at the console's next refetch, not at once.
  Mapping `UserSettings` to `nutrition` in `DataAreas.Of` is the whole fix.
- **`sync_requested` on iOS** (§46). The collapse header is set. What else a
  data-only message needs to reach an iOS app belongs to building iOS at all
  (`docs/push-notifications.md`).
- **Anything finer than last-writer-wins for a plan's workouts or a row's
  fields.** A plan's list is replaced as a whole (§18), and part three keeps the
  same rule for whole aggregates. Merging concurrent edits needs a version on
  every row.
- **Tombstones for workout exercises.** They are the one other child a device
  creates by id and someone else — a trainer's Workout Builder — can remove
  (§29). A removed entry with history is retired, not deleted, and its workout is re-sent
  whole; one without history is deleted and leaves no record, so a device that
  hasn't pulled the removal could create it again under its id. Closing it is
  the meal-food treatment — a tombstone and the 410 — if it is ever seen.
- **Pruning tombstones** (§29), **paging the feed**, and **a snapshot-consistent
  feed** (§31). Each is a cost nobody has yet shown is worth paying.
- **Removing the dedup folds.** They heal what earlier builds left on devices
  and on the server (§22), and go when that data does.
- **Foreign-key enforcement** on the device — see §6 for why not.
- **Settings taking the server's copy on pull.** They have no sync status, so
  the pull can't tell an unsent edit from a clean copy; they only fill in a
  device that has none (§35). Giving them one is the fix.
- **A weight's date round trip.** The push sends local wall-clock time with no
  offset and the server stamps it UTC, so the pull can't write the date it
  echoes over a record logged here (§35). Sending the date as an instant, as
  meals and sessions do, is the fix — on both sides, since shipped apps send
  the other form.
- **Anything to bound a held cursor.** A row the server keeps refusing holds
  the cursor until it is fixed, and each answer until then repeats the last
  (§37). Nobody has yet shown one that does.
