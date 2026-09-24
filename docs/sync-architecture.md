# Sync: how it works, why it kept breaking, and the rules it leaves behind

A walkthrough of the device ↔ server sync, written to be read on its own. It
starts with why the same kinds of bug kept coming back after seven separate
post-mortems had each fixed one, then goes through what changed, the decisions
behind it that aren't obvious from the diff, and the rules to keep.

The rework is staged. Part one (§1–§13) changes only the app. Part two
(§14–§22) changes the API as well: the device mints every row's id, and a
create can tell a repeat from a new request. Later parts make the pull fetch
only what changed and tell each side when the other changes something; they
will be added here as they land.

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
| `sync_service.dart` | the class: entry points (`syncAll`, `pullAll`), the lease and step isolation, `_markSent`, the deletion outbox drain, `_applyEach`, `_removeDeletedElsewhere` |
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
reason §17 gives, and the folds stay until the data they heal is gone (§19).

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
  `_syncSystemExerciseIds` links each one to the server's id by name, as
  before. A seeded exercise with a random id would be a reference to nothing.
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
subsection after next explains why.

It is worth being precise about why this was the risky part of the change.
Every one of those checks read `serverId == null`, and after this change every
one of them still compiles — it is simply false for every row, forever.
Nothing fails. A fallback that adopted an unpushed local meal quietly stops
adopting it, and the pull inserts a second meal beside it. The pull's
"session links" step, which GETs a session whenever one of its exercises has
no id, becomes a step that never GETs anything; that one was harmless only
because nothing needed it any more (§19), so it was deleted rather than
converted. The list above came from searching for every null test of a server
id, not from the compiler, and the rules whose failure would be silent are
pinned by tests that were run with the old null test put back (§21).

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
push window, answered 404. Owned lists don't pay it: a meal's foods, a plan's
workouts, a workout exercise's set templates and a session's logged sets never
reach the outbox, because they go as a whole-list PUT from their owner (§18).
The largest case is deleting a plan whose placeholder sessions haven't been
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
| `clearAllUserData` at sign-out | yes, and it empties the outbox |

None needed fixing. Two tests now pin the two where a tracked delete would do
the most damage (§21). The deletes that stay tracked are the user's own — the
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
statement per table. Before that it does two things the new rules need:

1. A row with no id that is marked `pendingUpdate` was never created on the
   server — the old push caught that by the null id and POSTed it — so it
   becomes `pending`, which is what now POSTs it.
2. A meal or plan whose list holds a food or workout that never reached the
   server is marked changed. §18 explains why: its whole list is what gets
   sent now, and a clean one takes the server's list on the next pull.

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
never point at an id that later gets replaced.

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
not make its side effects idempotent — and it applies with more force here,
because the foods are now sent as a whole list (§18). Sent as a whole list to
a meal another device already filled, this device's foods would *replace*
that device's. `_mergeIntoServerMeal` takes the other meal's foods into the
local one first (or, if the device already holds that meal as another row,
moves its foods there), and only then sends the combined list. The pull does
the same when it adopts an unpushed local meal.

The rejected alternative was to have the server refuse a content duplicate
with 409. That is simpler on the server and strands the second device: it
holds a meal with foods in it and no way to learn which meal to put them in.

---

## 18. Lists are sent whole

Part one sent two owned lists one member at a time: a meal's foods were added
with a batch and removed with `DELETE api/Meal/{m}/foods/{food}`, and a plan's
workouts likewise. Each removal needed a row in the deletion outbox carrying
the ids of both ends. The food DELETE was addressed by meal *and food item*,
so it could not say which of two portions of the same food to remove.

With every member carrying its own id, both lists now go the way set templates
and logged sets already did: the owner is what is dirty (its owned-list
triggers marked it for an addition already, and now do for a removal too), and
its push sends the whole list —
`PUT api/Meal/{id}/foods` with `{id, foodItemId}` per entry, and
`PUT api/WorkoutPlan/{id}/workouts` with workout ids. An empty list empties
it. The server keeps each entry's id. The two outbox kinds are no longer
recorded, and entries an older build queued are still sent.

Sending a list whole has a consequence the append-only version never had.
Suppose another device takes oats out of a meal. This device still holds the
oats entry, and its copy of the meal is clean. Under the old push that was
harmless: only new entries were ever sent. Under the new one, the next edit to
this meal sends its whole list — oats included — and puts them back. So the
pull now makes a **clean** meal's or plan's list match the server's, removing
what the server no longer lists (`_applyServerMeal`, `_mirrorPlanWorkoutLinks`),
and leaves a **dirty** one alone, because a dirty list is this device's unsent
change. The rule is the same one part one gave the pull for rows: a clean copy
is the server's to set.

And a rule for the sync engine's own writes follows from it. A dedup fold that
moves a meal's foods onto the meal it keeps writes under `untracked`, which the
triggers ignore, so the kept meal would look clean with foods the server has
never seen — and the next pull would remove them. `_dirtyIfClean` marks it.

The trade-off is last-writer-wins for the list. A trainer adding a workout to a
client's plan while the client's phone holds an unsent change to that plan
loses to the phone's list. The window is the push debounce, ten seconds, and
part three keeps last-writer-wins at the level of the whole aggregate for the
same reason: anything finer needs a version on every row.

### The replace endpoints keep ids

`ReplaceSetsAsync` and `ReplaceSetTemplatesAsync` used to mint fresh ids on
every replace, and the device paired the answer with its request by position.
So after every push, the ids the device held named rows the server had just
deleted, correct only for as long as nobody looked. Both now store each row
under the id it was sent with, and the device marks what comes back by id. An
id already stored under another of the caller's parents is moved (the device's
dedup folds move sets between twin session exercises, ids and all); one stored
under someone else's is refused with 409. The template replace is now a
transaction, as the set replace always was.

---

## 19. What went, and what stayed

| Removed | Why it was there | Why it can go |
|---|---|---|
| `_stampWorkoutExercisesFromServer` | GET the workout before creating its exercises, in case a lost response had already created them | the create is idempotent on the id; posting again *is* the question |
| `_stampMealFoodEntriesFromServer` | link local foods to the returned meal's foods by food item | the meal's list is sent whole, merged first |
| the GET in the session-exercise sweep | find the entries the server made when the session was created | the session create and the exercise batch both answer with them |
| the pull's "session links" step | the same, in the pull | its null test would never have been true again |
| pairing batch answers by index | — | answers are matched by id; the workout-exercise batch falls back to the server's own slot key, the only case in which it answers with a different id |
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

## 20. What was rejected

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
  portions of oats).
- **A separate client-reference column** on each server table, keeping the
  server's own primary key. It avoids trusting a client-chosen key, at the price
  of two ids per row, and every reference on both sides choosing one of them.
  The server's keys were already GUIDs, the owner check makes a chosen key
  harmless, and a v4 collision is not a real risk.
- **Refusing content duplicates with 409.** See §17.
- **Integer or sequential ids from the device.** Two devices would mint the
  same ones.

---

## 21. What the tests pin

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
| *two portions of one food are told apart by their ids* | §18 |
| *a new meal the server already had for that day keeps the foods on both* | §17 |
| *a food not on the server yet leaves the meal to go again* | §18 |
| *a clean meal takes the server's list on pull, a dirty one keeps its own* | §18 |
| *a meal this device hasn't pushed is adopted by the pull* \* | §15: the fallback tests status |
| *a removed one goes as the list without it, not as a DELETE* (plans) | §18 |
| *a clean plan takes the server's list on pull* | §18 |
| *a meal template is created under the id minted when it was made* | §15, for SharedPreferences |
| *deleted before the server confirmed it is still deleted there, in case its create landed* \* (templates) | §15 |
| *an install upgraded from schema 41* | §15: ids backfilled and distinct, built-ins left alone, statuses moved, owners dirtied; a deleted never-pushed row is recorded like a pushed one |
| `sync_tracking_migration_test.dart` › *a trigger an earlier build installed is replaced on open, with no schema bump* \* | §15: an install holding the status-gated trigger takes the new one from `installSyncTriggers` |
| `FitTracker.Api.Tests/ClientIdCreateTests.cs` (23 tests) | §16–18: a repeat returns and updates the same row with no second; every create the app sends; no id still mints one; the PK race; foreign ids refused, including a system exercise's and another user's session; the 409 filter; content de-duplication still answering with its own row; replaces keeping and moving ids; both new PUTs, including empty lists; every batch answering 404 for someone else's parent; both shapes of the session-exercise batch; `TotalWeightGrams` |

The server tests were mutation-checked the same way: with ids ignored, with the
set replace minting ids, with a batch's ownership check removed, with the plan
batch's duplicate check removed, with a repeat that returns without applying,
and with the template's weight left unsaved.

Existing tests changed where they had encoded the old contract. The fake API
now answers an unstubbed POST the way the API does for a create it accepts —
with what it was sent — and can fail one with a status or lose its answer.
Tests that stubbed a server-minted id for a batch now expect the ids the
device sent. The tests for a food removed from a meal, a food added to one,
and a workout exercise the server already has now expect the list PUT and the
slot answer instead of a DELETE, a batch append and a GET, and a workout kept
for its history now comes back `pending` rather than `pendingUpdate` (§16).

Three tests asserted that deleting a row that was never pushed tells the server
nothing, and now assert the opposite: *the server never had records no DELETE
for it* became *records a DELETE for any row with an id, pushed or not*; the
meal-template test *deleted before it was pushed tells the server nothing*
became the lost-answer case above; and the schema-41 upgrade test's last check
now expects both deletions recorded.

---

## 22. The rules part two leaves behind

- **A row is born with its id.** Never write `server_id` null to "re-queue" a
  row. The server mints an id for one sent without, the device marks what
  comes back by id, and so it never recognises the answer: the row is sent
  again on every push. Re-queue with the status.
- **"Pushed" is `sync_status != 0`.** Never test `serverId` for null. The test
  still compiles and is simply never true again. And read `pending` as "this
  device hasn't heard back", not "the server doesn't have it": a lost answer
  leaves the row on the server and the status at 0.
- **A delete is recorded for any row with an id, pushed or not.** A DELETE for
  a row the server never got costs a 404, which the push drops; skipping it
  loses the delete whenever a create's answer was lost. The flip side is
  sharper than part one's: an engine delete outside `untracked` is now a
  server DELETE even for a `pending` row — including one that shares its id
  with a row the server has.
- **Send a reference only once its target is on the server**
  (`_serverIdIfPushed`).
- **Keep the id a create answers with.** It can differ — the server still
  de-duplicates by content — and what follows the create must be written for
  an answer that names a row that already exists: merge into it, don't replace
  it.
- **A create with an id is the row's whole current state.** The server applies
  a repeat; that is what makes it safe to re-send one whose answer was lost.
- **A list the server replaces is sent whole, under its members' ids, and it is
  the owner that is dirty.** A clean owner takes the server's list on pull; the
  sync engine's own write that changes one marks it (`_dirtyIfClean`).
- **A new create endpoint** takes an optional `Id`, resolves it through
  `ClientIds.CreateOrResolveAsync` with an owner lookup, and inserts with
  `SaveNewAsync`. **A batch against a parent that isn't the caller's answers
  404**, never `200 []`, which the device can't tell from "created nothing".
- **The deletion outbox is for rows, not list members.** A member leaving a
  list is a change to its owner.

Names in part one that this part changed: `_syncMissingScheduledExerciseSets`
is now `_syncSessionExercises`, and `_addMissingPlanWorkoutLinks` is now
`_mirrorPlanWorkoutLinks`.

---

## What is deliberately not here yet

- **An incremental pull with tombstones** (part three). The pull still
  downloads everything, which is why it keeps its throttle, and it still infers
  a deletion from a row's absence from a full list (§5).
- **Live updates to the Trainer Console and to the trainee's phone** (part
  four).
- **Anything finer than last-writer-wins.** A meal's foods and a plan's
  workouts are replaced as a whole (§18), and part three keeps the same rule for
  whole aggregates. Merging concurrent edits needs a version on every row.
- **Removing the dedup folds.** They heal what earlier builds left on devices
  and on the server (§19), and go when that data does.
- **Foreign-key enforcement** — see §6 for why not.
