# Session Review: reading history as though it were the present

The Trainer Console's Session Review screen showed a client's training back to
their trainer, and it consistently showed more than the client had. Three
complaints, reported together:

1. Sessions from programmes the client isn't on any more.
2. Exercises that aren't in the workout any more, listed as *Skipped*.
3. Exercises prescribing more sets than the client actually has.

They look like three bugs. They are one mistake made three times, and none of
them could have been caught by a compiler or by a green test suite, because at
no point was anything wrong with the data. Every row involved was a legitimately
stored row with a valid foreign key, returned by a query that did exactly what
it said. The mistake is upstream of all that: **four tables in this schema
accumulate history, and the console read them as though they described the
present.**

Line references are to the commit that introduced this document.

---

## 1. The shape of the mistake

Three of the tables Session Review reads are append-mostly. Nothing ever cleans
them, because nothing is supposed to — that is what makes them useful.

| Table | Grows when | Never shrinks when |
|---|---|---|
| `ScheduledWorkouts` | a plan generates its dates | the client moves to a new plan |
| `ScheduledWorkoutExercises` | a session is created from a workout | the exercise leaves that workout |
| `WorkoutSetTemplates` | a prescription is pushed | the prescription is rewritten |

Each row is true *about a moment*. `ScheduledWorkouts` says "on 3 March, this
workout was on the calendar". `ScheduledWorkoutExercises` says "when that
session was generated, this exercise was in it". Read back as "the client is
supposed to train on 3 March" and "this exercise is in the workout", every one
of them is a claim about now that the row was never making.

That is why the compiler was silent. `List<ScheduledWorkoutResponseDto>` is the
same type whether it holds the client's current programme or the residue of
three abandoned ones. And it is why the tests were silent: a test that seeds one
plan, one workout and one session passes under both readings, because with no
history there is no difference between the two.

The general lesson is worth stating on its own, because it will come up again in
this codebase wherever a `Scheduled*` or `*Template` table is read:

> A row that records what was true at a point in time cannot answer a question
> about what is true now. Somewhere between the two there has to be an explicit
> filter, and if you can't point at it, you are reading history as fact.

---

## 2. Sessions from plans the client left

Activating a workout plan does not delete the previous one. Both the client
app's plan editor and its plan creator do the same two writes — clear `IsActive`
on every plan, then set it on the new one — and that is all. The dates the old
plan generated stay in `ScheduledWorkouts` forever, unstarted and now
unstartable.

`GetClientSessionHistoryAsync` fetched every scheduled workout the client had
ever had and, after excluding future dates, listed them. A client six months
into their third programme had two dead programmes' worth of dates in the list,
every one of them classified `Missed` by `DeriveStatus` — which is correct on
its own terms, since a past-dated session with nothing logged *is* a session the
client didn't do. It just wasn't a session anybody had asked them to do.

The fix is `FilterToCurrentProgramme` (`TrainerConsoleService.cs`). A session
counts as the client's current business when:

- it has no owning plan — it was scheduled by hand, so nothing deactivated it; or
- its plan is still active; or
- the client actually engaged with it: completed it, explicitly skipped it, or
  logged a set against it.

That last clause is the one that matters. Filtering on `IsActive` alone would
have deleted the client's real training history from the trainer's view every
time they changed programme, which is a worse bug than the one being fixed. A
session that happened is real regardless of what has since become of the plan
that scheduled it; a date that never became anything is not.

### It had to apply to the numbers too

The same padding sat behind `AvgAdherencePercent`, the roster's per-client
adherence, and the 12-week attendance chart, all of which count
`planned = sessions in window` and `completed = those marked complete`. Dead
plans inflate the denominator only, so every affected client's adherence was
understated — sometimes drastically, since an abandoned four-day-a-week
programme keeps generating four "planned" sessions a week indefinitely.

Fixing only the list would have been worse than fixing nothing: the trainer
would have seen a session list with the ghosts gone sitting next to an adherence
figure that still counted them, and no way to reconcile the two. All four reads
now go through the same filter, so every number on the screen is drawn from the
same set of sessions.

---

## 3. Exercises that had left the workout

This one is not a read bug. The read was faithfully reporting what the server
had, and what the server had was wrong — because the client could not tell it
otherwise.

`ScheduledWorkoutExercise.WorkoutExerciseId` is a **restricted** foreign key
(`AppDbContext.cs`, and the original `Workout` migration):

```
WorkoutExercises  ◄──── Restrict ──── ScheduledWorkoutExercises ◄── Cascade ── WorkoutSets
```

`Restrict` is the right choice. `WorkoutSets` — everything the client has ever
lifted — hangs off `ScheduledWorkoutExercises`, which hangs off
`WorkoutExercises`. A cascade here would mean that dropping an exercise from
your programme silently erases every set you ever did of it.

But `DeleteWorkoutExerciseAsync` called `Remove` and `SaveChangesAsync` with no
regard for that constraint, so for any workout the user had *ever scheduled* —
which is to say, any workout they actually use — the delete raised a foreign-key
violation, surfaced as a 500, and the sync client's `DELETE` failed. The
exercise vanished locally and stayed on the server.

From there it compounds. `CreateScheduledWorkoutAsync` builds a new session's
exercise entries by reading the server's `WorkoutExercises` for that workout, so
**every session generated afterwards was stamped with the exercise again**. The
client never displayed those entries — its own session view is built from the
local workout template, not from the scheduled entries — so nothing logged
against them, and Session Review, which *does* read the scheduled entries,
reported each one as an exercise the client skipped.

Worth dwelling on: the trainee app and the Trainer Console were reading the same
session through two different sources of truth. The trainee's active-workout
screen asks the workout what it contains; the console asks the session what it
was stamped with. As long as those agree, the divergence is invisible. It became
visible the first time somebody edited a workout.

### Retiring instead of deleting

The delete now separates the two kinds of dependent row
(`WorkoutRepository.cs`):

- **Entries with no logged sets** are placeholders for a session that was never
  performed, or one still in the future. They are deleted outright — there is
  nothing in them to lose.
- **Entries with logged sets** are real history. They keep the exercise alive,
  so instead of deleting the `WorkoutExercise` row, it is stamped with
  `RemovedAt` (migration `20260822120000_AddWorkoutExerciseRemovedAt`).

A retired exercise is out of the workout for every purpose that asks what the
workout contains — it is not stamped onto new sessions, not pulled back down by
the sync client, not prescribed in Session Review — and still resolvable for the
sessions that logged sets against it, so the trainer keeps seeing what the
client actually lifted, under its proper name.

**The alternative that was rejected** was leaving the schema alone and filtering
harder in the console. It cannot work, and understanding why is the useful part:
the stale exercise is genuinely still in the workout server-side, so there is no
signal in the data that distinguishes a phantom entry from an exercise the
client really did skip. A read-path fix can only paper over defects that left a
trace. This one hadn't, because the write that should have removed it never
happened. The console-side guard (`stillProgrammed`) is still there, and it
catches a second, rarer path to the same state — repointing a scheduled workout
at a different workout, which updates `WorkoutId` and leaves the entries stamped
from the old one attached — but on its own it would have fixed nothing.

**The cost** is a rule that now has to be remembered: any query answering "what
is in this workout" must exclude `RemovedAt != null`, and any query resolving
logged history must not. There are three such places today
(`ScheduledWorkoutRepository.CreateScheduledWorkoutAsync`, the console's
`stillProgrammed` check, and the sync client's workout pull), and the property's
doc comment says so. A global query filter would have enforced it automatically
— and would also have hidden the rows the history path needs, which is the case
it exists for.

---

## 4. Prescriptions that grew every time you saved

An exercise programmed for three sets could report nine.

The client rebuilds set templates wholesale. Saving a workout deletes every
local `WorkoutSetTemplate` for each exercise and re-inserts the lot from the
edited form (`workout_dao.dart`, "ALWAYS rebuild template sets") — a reasonable
choice, since a prescription is small and diffing set-by-set buys nothing. The
freshly-inserted rows have no `serverId`, so sync treats them as new and posts
them to `POST api/Workout/exercises/{id}/sets/batch`.

That endpoint appended. Nothing ever deleted the previous generation, because
the sync client has no delete path for set templates at all — it never needed
one locally, where the rebuild is a delete. So each save left another complete
copy of the prescription on the server, and `PrescribedSetsDto.SetCount` counted
them all.

Two changes, deliberately both:

- **`AddSetTemplatesBatchAsync` now replaces** rather than appends
  (`WorkoutService.cs`, `WorkoutRepository.ReplaceSetTemplatesAsync`). The batch
  has exactly one caller and it always sends the exercise's complete
  prescription, so replacement is the semantics the client already assumed. This
  stops new duplicates.
- **Session Review deduplicates by `SetNumber`** when building the prescription
  (`TrainerConsoleService.cs`). This handles the duplicates already sitting in
  production, which the first change does nothing about until every affected
  workout is saved again. Set numbers are ordinals within an exercise — two
  templates numbered 2 are by definition the same set — so collapsing them is
  not a heuristic.

The neighbouring line had been getting this right all along, for a different
reason: `targetsBySetNumber` already grouped by `SetNumber` and took the first
of each group, because per-set targets have to be matched to per-set logs. The
count and the target list, four lines apart, disagreed about whether the
template rows were unique. That is what a duplicate-tolerant table looks like
when only one of its readers knows.

---

## 5. What to take from this

- **Ask what a row is a claim about.** Every table here stores facts about a
  moment. Whether that is also a fact about now is a separate question, and one
  the type system will never ask for you.
- **A failing write becomes a reading bug somewhere else.** The `Restrict`
  violation surfaced as a 500 on a sync call nobody watched; it was *reported*
  as a display problem in a different app, months later. When a screen shows
  something impossible, the fault is not always in the screen.
- **Two clients reading the same thing through different paths will diverge.**
  The trainee app read the workout, the console read the session. Nothing
  enforced that they agreed, so nothing told anyone when they stopped.
- **A read-path fix only works on defects that left a trace.** Duplicated set
  templates are self-evidently duplicates and can be cleaned up on read; a stale
  exercise that is still legitimately in the workout is not distinguishable from
  a real one, and no amount of filtering will make it so.

---

## 6. Postscript: the above was half wrong

Everything up to here shipped as PR #48, deployed, and **changed nothing the trainer could see.**
The corrections matter more than the original, so they are recorded here rather than quietly fixed.

### What §4 got wrong

Section 4 claims the "too many sets" report was duplicated `WorkoutSetTemplates`. It was not. The
prescription was always correct — the screenshot that prompted the report reads
`Prescribed 2 × 8 - 12` next to four logged rows numbered `1, 1, 2, 2`. The duplication was in
`WorkoutSets`, the *logged* table. Two tables, both plausible, and the fix landed on the wrong one.

The mechanism is the one §4 describes, one table over. `active_workout_view.dart:616` hard-deletes
every local set row for an exercise on save and rebuilds it from the templates, which throws away
their `serverId`s; the sync then posts the whole log as new, and `AddSetsBatchAsync` appended it.
One extra copy of every set, per save. `markWorkoutSetPendingDelete` exists in the DAO and has
never had a caller.

### What §3 got wrong

Section 3 presents the retired-exercise fix as complete. The server half was. The client half was
not, and nobody checked: `saveWorkout` marks a removed exercise `syncStatus = 3` but never marks
the **workout** dirty — `workoutCompanion` omits `syncStatus` and `markWorkoutPendingUpdate` has
zero callers — while `getUnsyncedTemplates()` returns only `syncStatus != 1`. The pendingDelete
loop lives inside `_syncUpdateWorkout`, which is therefore unreachable for any workout that has
synced once. The `DELETE` was fixed and then never called.

Worse, `_syncUpdateWorkout` marked the workout synced *before* running its exercise loop, so the
first failure permanently removed the workout from the retry set.

### The one that was never looked for

`ScheduledWorkout → Workout` is `Restrict` too. `DeleteWorkoutAsync` was a bare `Remove` +
`SaveChanges`, so deleting a workout that had ever been scheduled raised a foreign-key violation,
500'd, and left the workout on the server. Deleted workouts kept generating tabs in the trainer's
Session Review, under names the client had removed weeks earlier.

§3 had already found and fixed exactly this shape on `WorkoutExercise`. The identical defect sat
one level up in the same file, on the same kind of foreign key, and the fix did not go looking for
it. **Finding the shape of a bug is not the same as finding its instances.** When a defect turns
out to be structural — a restricted foreign key nobody accounted for — the next move is to
enumerate every relationship with that structure, not to fix the one that was reported.

### The lesson that outlives all of it

The framing in §1 — *history read as the present* — was real but secondary. The stronger pattern,
visible only once all four defects are laid side by side, is this:

> **A write that fails silently becomes a reading bug somewhere else.** Every one of these surfaced
> as "the Trainer Console is showing the wrong thing", and not one of them was a bug in the Trainer
> Console. Three were failed or unreachable deletes; one was a client that rebuilds while the
> server appends. The console was the first screen honest enough to display what the database
> actually contained.

Two practical consequences, both of which would have caught these years earlier:

- **A sync client that swallows its errors has no error budget.** Every one of these failures was
  caught, logged at `warn`, and dropped. The user saw a workout disappear locally and had no way to
  know the server disagreed. Failed pushes need to be visible somewhere a human looks.
- **Symmetry between local and remote mutation is a testable invariant.** "The client rebuilds, the
  server appends" and "the client deletes, the server refuses" are both statements about the pair,
  and neither side's tests can express them alone. They only fail in integration, against real
  foreign keys — which is exactly why `DbFixture` uses SQLite rather than the InMemory provider.
