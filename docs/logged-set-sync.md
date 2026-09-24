# Logged sets: RPE, set type and side, and why none of them ever left the phone

A walkthrough of why the Trainer Console's Session Review showed "—" in the RPE
column for every set a client had ever logged, why the same was true of two
other fields nobody had noticed yet, what it took to fix it, and the rule it
leaves behind. Written to be read on its own.

Line references are to the commit that introduced this document.

---

## 1. What was seen

Session Review — the console screen where a trainer reads what a client
actually did in a session — has a set table: **SET / REPS / WEIGHT / RPE**, one
row per logged set, plus an *Avg RPE* figure in the session's hero stats. The
reps and weights were right. The RPE column read "—" on every row of every
session, and Avg RPE was always absent, including for clients who log RPE on
every working set.

That is not a display bug. The console renders exactly what it is sent, and
what it was sent was `null`.

## 2. Three values that never left the phone

Schema version 35 of the device's drift database added three columns to
`workout_set_table` in one migration (`app_database.dart`, `if (from < 35)`):

- `rpe` — Rate of Perceived Exertion, 6–10, null when not logged. Opt-in from
  Settings; the active workout shows the field only when it's on.
- `set_type` — the `SetType` ordinal: normal, warm-up, drop set, failure.
- `side` — the `SetSide` ordinal: both, left, right, for unilateral work.

The active workout writes all three when it saves a set. Then this is what
happened to them on the way to the trainer:

| Hop | Where | RPE | Set type / side |
|---|---|---|---|
| Server column | `Models/WorkoutSet.cs` | existed (`AddWorkoutSetRpe`) | did not exist |
| Request DTO | `WorkoutSetRequestDto` | existed, `[Range(1,10)]` | did not exist |
| Response DTO | `WorkoutSetResponseDto` | existed | did not exist |
| Device → server, new set | `SyncService._syncNewWorkoutSetsBatch` | **not sent** | not sent |
| Device → server, edited set | `SyncService._syncUpdateWorkoutSet` | **not sent** | not sent |
| Server writes a new set | `ScheduledWorkoutService.AddSetAsync` | **dropped** | — |
| Server writes an edit | `ScheduledWorkoutRepository.UpdateSetAsync` | **dropped** | — |
| Server returns a set | `ScheduledWorkoutService.ToSetDto` | **dropped** | — |
| Server → device, pull | `SyncService._pullScheduledWorkouts` | **ignored** | ignored |
| Server → console | `TrainerConsoleService` → `SessionSetLogDto` | read `set.Rpe` | — |

RPE is the instructive column. Everything a reviewer would look for was there:
a server column, a migration, a validated DTO property on both the request and
the response, and a console that read the column and averaged it. The one
thing missing was the code that moves the value from one of those places to
the next — and it was missing at *every* hop, not one. Any single hop fixed on
its own would still have produced "—".

Set type and side were further behind: they had no server column at all. They
had simply never been thought of as synced data, even though a set's being a
warm-up is exactly the kind of thing a trainer reading a session wants to know.

## 3. Why nothing caught it

Every piece type-checked, because every piece was correct *in isolation*. A
DTO with a property nobody assigns compiles. An object initializer that lists
six of seven properties compiles; C# fills the seventh with its default, which
for `int?` is `null` — a perfectly legal value that means "not logged". A Dart
map literal that omits a key compiles. An endpoint that receives a JSON body
without an `rpe` key binds it as `null` and returns 200.

So the failure was indistinguishable from the success case in which the client
simply never logs RPE. The tests had the same blind spot: the Session Review
tests seeded `WorkoutSet` rows straight into the database with `Rpe` already
set, which proves the console reads the column and says nothing about whether
anything ever writes it.

Nothing crashed, nothing logged a warning, and the data wasn't lost — it was
sitting on the client's phone the whole time, which matters in §6.

## 4. The fix, hop by hop

### 4a. The server

`WorkoutSet` gains `SetType` and `Side` as `int` columns, `NOT NULL DEFAULT 0`
(migration `AddWorkoutSetTypeAndSide`), holding the same ordinals the device
stores. Ordinals rather than strings because that is what both ends already
use; `WorkoutSetRequestDto` pins the range with `[Range(0, 3)]` and
`[Range(0, 2)]` so a value outside it is a 400, not a row.

`AddSetAsync`, `UpdateSetAsync` and `ToSetDto` now carry all three.

The non-obvious part is that on the **request** DTO, `SetType` and `Side` are
`int?`, not `int`, and the two are treated differently from RPE on update
(`ScheduledWorkoutRepository.cs:355`):

```csharp
set.Rpe = dto.Rpe;
if (dto.SetType is int setType) set.SetType = setType;
if (dto.Side is int side) set.Side = side;
```

A client on an older build still pushes set edits — it just doesn't know these
fields exist. If `SetType` were a plain `int`, an absent key would bind as `0`,
and a trainee with the app on two devices, one not yet updated, would have
every warm-up they tagged on the new one silently turned back into a working
set the moment the old one edited a rep count. Null on the wire means "this
caller didn't say", and "didn't say" must leave the stored value alone.

RPE can't use the same trick, because for RPE null is a real answer: the user
cleared it, or the set was logged with RPE switched off. There's no way to tell
"cleared" from "old client" in the payload, so RPE is assigned outright. The
cost is the mixed-version case above for RPE only — an edit from an old build
blanks the RPE on that one set. That's narrow (two devices, one un-updated,
editing the same historic set) and self-limiting (it stops the moment the old
device updates), which is why it is accepted rather than engineered around.

### 4b. Pushing

Both push maps — the batch create and the single-set PUT — now include `rpe`,
`setType` and `side`. That is the entire change for sets logged after the
update.

### 4c. Pulling, and an ordinal the device doesn't know

The pull inserts all three from the server's copy, but reads the two ordinals
through `_setTypeOrdinal` / `_setSideOrdinal` (`sync_service.dart:3045`), which
fall back to `0` for anything out of range.

This is the lesson `docs/chat-attachments.md` records for `MediaType`: the
device reads these columns back as `SetType.values[row.setType]`
(`WorkoutSet.fromMap`, the active workout, the CSV exporter), and indexing past
the end of `values` throws. Today the server can't produce a bad value — the
DTO range forbids it — but the day someone adds a fifth set type, every
already-shipped build would pull it and crash on every screen that lists that
set. Clamping at the point of entry means the database never holds an ordinal
this build can't read, so none of those three readers needs to defend itself.
The console model does the same in `SessionSetLog.fromJson` (`_byOrdinal`).

### 4d. Linking is not syncing

The pull has a fallback for a local set with no server id that matches a
server set on exercise + set number: rather than insert a duplicate, it stamps
the local row with the server's id. It used to stamp it `syncStatus = 1`,
synced.

That is exactly the trap `docs/trainer-exercise-notes.md` §3d describes for
notes. The common way to reach that branch is a set that *was* pushed, then
lost its link locally. If it was pushed before this change, the server's copy
has no RPE, type or side, and marking the local row synced would declare them
sent without sending them — permanently, because nothing looks at a clean row
again. The link now compares the three fields and leaves the row at `2`
(pending update) when they differ, so the next sync pushes them
(`sync_service.dart:3010`).

## 5. The data that was already there

Fixing the push only helps sets logged from now on. Every set logged since
version 35 is already on the device, with its RPE, and marked **synced** —
because the push that marked it synced succeeded; it just didn't carry those
fields. `docs/trainer-exercise-notes.md` §4 names the shape: *when you start
syncing a field that never synced, the existing data is ahead of the server,
not behind it.*

The notes fix handled that inside the pull: while reconciling an exercise
entry it already held, a note present locally and absent on the server was
queued rather than cleared. That doesn't work here. The set pull never
reconciles a set it already holds — it `continue`s on any known server id —
so there is no branch to hang the comparison on, and adding a reconcile there
would be a much larger change to a path with its own history
(`docs/sync-account-switch-duplication.md`).

Instead the backfill is a one-off drift migration, schema **40**
(`app_database.dart:416`):

```sql
UPDATE workout_set_table SET sync_status = 2
WHERE sync_status = 1 AND server_id IS NOT NULL
  AND (rpe IS NOT NULL OR set_type != 0 OR side != 0)
```

It changes no table; the version bump exists to run this statement once. It
flips exactly the rows that are synced *and* carry a value the server has
never seen, and the ordinary machinery does the rest:
`_syncMissingScheduledExerciseSets` visits every synced session on every sync
and hands `syncStatus == 2` sets to `_syncUpdateWorkoutSet`, which now sends
them. What it deliberately leaves alone:

| Row | Why it's excluded |
|---|---|
| `sync_status = 0`, no server id | Not pushed yet. The create push carries the values anyway; turning it into an update would PUT to a server id it doesn't have. |
| `sync_status = 3` | Queued for deletion. Re-flagging it as an edit would resurrect it. |
| `sync_status = 1`, all three at default | Nothing to send; pushing it would be noise. |

It has no `try/catch`, unlike the `ALTER TABLE` branches around it. Those
catch "duplicate column", which is an expected outcome of `createAll()`
running first. Nothing about this `UPDATE` is expected to fail, and if it
did, silently swallowing that would leave the values stranded with nobody
the wiser — the bug this change exists to fix.

**Ordering.** The migration runs when the device updates, and the pushes it
queues are only useful once the server keeps what they send. That holds by
construction: `deploy.yml` ships the API on every merge to `main`, while the
app only reaches devices through a `v*` tag and a Play release. The server is
always ahead.

**What it can't recover.** Values logged on a device since wiped or
reinstalled are gone — they only ever existed there.

## 6. What the trainer sees

The RPE column and Avg RPE now fill in on their own; nothing in the console
needed to change for them.

Set type and side are new to the console. `SessionSetLogDto` carries both, and
Session Review draws a small neutral tag under a set's cells — *Warm-up*,
*Drop set*, *Failure*, *Left*, *Right* — using the strings the active workout
already had. A normal two-sided set, which is most of them, gets nothing.
They sit under the row rather than in a fifth column because that column
would be empty on nearly every row, and they're neutral-toned rather than a
`StatusBadge` because none of them is good or bad. They are also part of the
row's single semantics label ("Set 1, 12 reps, 10 kg, Warm-up"), so they
aren't visual-only.

The numbers were deliberately left alone: a warm-up still counts toward the
session's volume, Avg RPE and PR detection on the server. The device's own
personal-best queries already skip warm-ups (`workout_dao.dart`), so the two
disagree about that, and a trainer may reasonably expect them not to. That
is a behaviour change to figures trainers already read, and it was scoped out
of this fix on purpose — it's the obvious next step, not an oversight.

## 7. The rule it leaves behind

**Adding a column on both sides of the API is half the change.** The other
half is five lines of code that are each easy to forget and that no compiler
will ask for: the device's push map, the server's create mapping, the
server's update mapping, the server's response mapping, and the device's
pull. Before believing a field round-trips, find each of those five lines.
If a test seeds the field directly into the database, it has proved the
reader works and nothing else.

Two narrower rules fall out of it:

- **On a request DTO, a field an older client doesn't send must be nullable,
  and null must mean "leave it".** Otherwise shipping the field is a silent
  reset for everyone still on the previous build. Where null is already a
  real value, say so and accept the cost explicitly.
- **An enum ordinal is validated where it enters the device's database, not
  where it's read.** There are more readers than writers, and each reader
  that indexes `values` is a crash waiting for a new enum member.

## 8. Tests

| Test | Pins |
|---|---|
| `TrainerSessionReviewTests.WhatTheClientLoggedOnASetReachesTheirTrainer` | written through the batch endpoint the device uses, read back in Session Review with Avg RPE |
| `…UpdatingASetRoundTripsRpeTypeAndSide` | the update path and the response DTO carry all three |
| `…AnUpdateFromAnOlderClientLeavesSetTypeAndSideAlone` | null means "not sent" (§4a) |
| `sync_service_test` › *RPE, set type and side on a logged set* › *are sent when a new set is pushed* / *…when a synced set is edited* | both push maps |
| › *arrive on pull, and an ordinal this build does not know reads as normal rather than crashing* | the pull and the clamp (§4c) |
| › *a local set linked to a server row that lacks them stays pending* / *…that agrees is marked synced* | the link compare (§4d) |
| `logged_set_backfill_migration_test` | the schema-40 backfill flips exactly the rows in §5's table, on a real upgrade from a file at version 39 |
| `session_review_screen_test` › *a warm-up or one-sided set is tagged, and says so out loud* | the tag, and that it's in the semantics label |
| › *a set type or side this build does not know reads as normal* | the console model's clamp |
