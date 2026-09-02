# The Workout Builder: how a prescription reaches a client, and why it isn't a reference

A walkthrough of what it took to let a trainer actually build a client's
workouts — not just name and assign a plan — written to be read on its own.
It covers the trap that isn't visible from either side of the diff, the
sync gap that would have made "edit" a console-only illusion, and the
decisions that don't show up just from reading the code.

Line references are to the commit that introduces this document.

---

## 1. What was actually wrong

The Trainer Console's Workout Builder could create a `WorkoutPlan` — a name,
a description, a start date — and assign it to a client. That was the whole
feature. The screen said so plainly, in a card headed "Exercise editing isn't
available yet": `WorkoutPlanRequestDto` carried plan metadata only, and there
was no trainer-facing endpoint for a client's actual workouts. A trainer could
hand a client a folder with a label on it and nothing inside.

The gap wasn't a missing screen. `IWorkoutService`, `IWorkoutPlanService` and
their repositories already had every operation a workout editor needs —
create, update, add an exercise, replace its set templates, retire an
exercise that has logged history against it — because the trainee's own
workout builder (`gym_tracking/presentation/view/workouts/`) already uses all
of it. What didn't exist was a way for a *trainer* to call any of it on
someone else's account. Every one of those methods takes a `userId` and
trusts the caller is that user. `TrainerConsoleService` is the one place in
this codebase that is allowed to act as a client on the client's behalf, and
only after checking `IsActiveTrainerOfAsync` — see the class doc comment on
`ITrainerConsoleService`. The actual work in this change is almost entirely
in that service: passing `clientId` through to services that already do the
right thing, and handling the two places where "trainer" and "client" are
different accounts stops being free.

## 2. The exercise-visibility trap

`ExerciseRepository.GetAllExercisesAsync(userId)` returns system exercises
plus that user's own. That's correct and long-standing: a user's custom
exercise is private to them. It is also, on its own, enough to make a
trainer-authored prescription silently unusable.

Say the trainer types up a movement of their own — "Cable Iso Row," say —
and prescribes it to a client. The naive version of `CreateClientWorkoutAsync`
just writes `new WorkoutExercise { ExerciseId = dto.ExerciseId, ... }` with
`UserId = clientId` on the *workout*, same as the trainee's own create flow
does. That compiles. The API returns 200. And the client's app will never
show it.

Not because anything crashes — because `WorkoutExercise.ExerciseId` carries
no foreign key (see the comment on it in `AppDbContext.cs`; exercises can be
seeded client-side, so the column is deliberately unconstrained), and the
client's own sync pull resolves it by asking *its own* `Exercise` table for a
row with that server id. The trainer's exercise was never given to the
client, so that table has nothing. `SyncService._pullWorkouts` already has a
comment for exactly this shape of failure, written for a different exercise
(a retired one) but true here too: skip the reference and you've merely
declined to say what actually happened. Per
`docs/sync-dangling-references.md`, the client's pull logs a warning and
moves on — the exercise doesn't appear, the set templates under it don't
either, and nothing about the response the trainer got back suggested any of
that.

This is the failure mode the rest of this document keeps returning to: a
value that is perfectly valid on the writing side and silently unusable on
the reading side, in a schema that has nothing enforcing the relationship
between them. The compiler has nothing to say about it. Neither does a
passing `dotnet test`, unless a test specifically constructs the
cross-account case — which is exactly what
`FitTracker.Api.Tests/TrainerWorkoutBuilderTests.cs` now does.

### 2a. Two ways to fix it, and why only one survives the relationship ending

The obvious-looking fix is to widen visibility: let a client's exercise
picker also see their trainer's exercises, so the reference resolves. Rejected,
for a reason that only shows up later — when the relationship ends. A
`TrainerClient` going inactive doesn't rewrite history: the client keeps
every workout they were prescribed, and keeps training it. If prescribing a
trainer's exercise had meant *referencing* the trainer's row rather than
owning a copy, every workout built on it would start silently failing to
resolve the moment the relationship lapsed — the exact same "compiles, 200s,
resolves to nothing" failure, just deferred to a later and less obvious
trigger. A client shouldn't lose access to a lift they've been doing for six
months because they switched trainers.

So prescribing a trainer-owned exercise **copies it**:
`TrainerConsoleService.ResolvePrescribedExerciseIdsAsync`
(`FitTracker.Api/Services/TrainerConsoleService.cs`) checks, for every
exercise id in the prescription, whether the client can already see it; if
not, whether it's the *trainer's* own (an ownership check done **before**
copying anything, precisely so a stranger's private exercise can't be
smuggled through the same path); and only then calls
`IExerciseService.CopyExerciseAsync`, which creates a new `Exercise` row
owned by the client. The client's `api/Exercise/UserExercise` endpoint and
`SyncService._pullCustomExercises` already serve and pull exactly this shape
of row — a user's own custom exercise — so the copy reaches the device with
**zero client-side changes**. It even pulls in the right order already:
`pullAll()` runs custom exercises before workouts, which is exactly the
order a workout referencing a freshly-copied exercise needs.

Copying needed one new column to be idempotent:
`Exercise.SourceExerciseId` (nullable, no foreign key — same reasoning as
`WorkoutExercise.ExerciseId`: the copy must stay resolvable even after the
trainer edits or deletes their original). Without it, prescribing the same
trainer exercise to the same client twice would grow their library by one
exercise every time the trainer hit Save. `ExerciseRepository.GetCopyAsync`
checks for an existing copy by `(sourceExerciseId, ownerId)` before creating
a new one.

One consequence worth being explicit about: the copy is a snapshot, not a
link. If the trainer later renames their master exercise, clients who
already have a copy don't see the rename. That's the right default, not a
shortcut — a trainer maintaining a shared "Cable Iso Row" for their whole
roster shouldn't have a wording tweak for one client change what every other
client sees mid-plan.

## 3. Editing without disowning logged history

A workout the trainer edited a week ago may already have sets logged against
it. The identity of a `WorkoutExercise` row matters for exactly the same
reason it matters on the trainee's own side (see
`docs/sync-dangling-references.md` again): a `WorkoutSet` is stamped against
a *`ScheduledWorkoutExercise`*, which in turn points at a `WorkoutExercise`
row, not at an exercise definition. Delete the row and reinsert an
equivalent one, and the history under it has nothing left to point at.

`ClientWorkoutRequestDto` sends the whole prescription as one document, not
a stream of add/update/delete calls — a Save button and half-applied writes
don't mix. Each incoming exercise entry optionally carries the `id` of the
`WorkoutExercise` row it's meant to keep. The diff in
`TrainerConsoleService.ApplyExercisePrescriptionAsync` treats an entry as
"kept" only when **both** the id and the exercise id match an existing live
row:

- Same id, same exercise → `UpdateWorkoutExerciseAsync`: order, notes and
  superset grouping change; the row and its history don't move.
- Same id, *different* exercise → not a match. This is a substitution, and
  it's handled as remove-then-add: the old row goes through
  `DeleteWorkoutExerciseAsync` — which already retires rather than deletes
  when the client has logged sets against it — and a new row is created for
  the new exercise. Reusing the row for a different lift would silently
  reattribute the client's squat history to whatever now occupies that slot.
- No id, or an id that no longer matches anything live → a new row.
- A previously-live row absent from the payload entirely → removed the same
  way a swap's old half is: retired if it has history, gone if it doesn't.

Set templates are simpler because there's no history to protect at that
level — a `WorkoutSetTemplate` is a *prescription*, not a log — so each kept
or newly-created exercise gets `IWorkoutService.ReplaceSetTemplatesAsync`,
a small addition next to the existing `AddSetTemplatesBatchAsync`. That
method couldn't be reused directly: it early-returns on an empty list on
purpose, because it serves the trainee's own sync push, where an empty batch
means "nothing new to send." The Workout Builder needs to be able to say
the opposite thing — "this exercise now has zero prescribed sets" — so it
gets its own method rather than that early return being changed out from
under the push.

## 4. The sync gap that would have made "edit" console-only

None of the above reaches a client's phone without one more fix, and it's
the one that's easiest to miss because nothing about the API is wrong.
`SyncService._pullWorkouts` (`fittnes_tracker/lib/core/network/services/`)
opened with:

```dart
if (await _db.workoutDao.getWorkoutByServerId(workoutServerId) != null)
  continue;
```

Every other pull in this file has the same shape, and until now it was
correct everywhere it appeared: the trainee is the only writer of their own
workouts, food items, weight logs. Once you've pulled something, there's
nothing else that changes it, so re-pulling is just wasted work to skip.
That assumption is exactly what a trainer editing a client's workout from
the console breaks. The API call succeeds. The server's row changes. And a
device that already holds the workout — which, for an existing client, is
every device — never asks about it again, because the pull's first line
told it not to. The feature would have worked in the console and nowhere
else, which is a worse failure than not shipping it at all: the trainer sees
their edit saved and has no way to know the client never received it.

The fix (`_reconcileWorkoutFromServer`, added next to `_pullWorkouts`)
mirrors the identity-preserving logic from section 3, one layer down and
in the other direction — reading the server's copy back onto the device
instead of writing the device's copy up to the server. It runs only when
the local workout is `SyncStatus.synced`:

```dart
if (SyncStatus.values[existingWorkout.syncStatus] == SyncStatus.synced) {
  await _reconcileWorkoutFromServer(existingWorkout, w);
}
```

A dirty local copy — `pending`, `pendingUpdate` or `pendingDelete` — is the
device's own change that hasn't reached the server yet. Reconciling over it
would silently discard that change in favor of a server copy that doesn't
know about it. This is the same lesson
`docs/sync-account-switch-duplication.md` already drew from the opposite
direction (a `syncStatus` that's never flipped is an edit that never leaves
the device); here the risk runs the other way — a `syncStatus` read
carelessly would let the *server* clobber a device's own unsent edit. The
check is applied twice more, at finer grain, for the same reason: once per
exercise (a workout can be clean while one of its exercises is mid-edit
locally) and once per exercise's set templates (an exercise can be clean
while its own sets aren't). Skipping at the wrong granularity would either
under-protect a dirty child row or over-protect siblings that are actually
safe to refresh.

An exercise the server no longer lists at all — not flagged `removedAt`,
just absent — is treated exactly like one that is: retired
(`syncStatus = 4`), never deleted outright. The reasoning is identical to
the reasoning already documented for `removedAt`: a `ScheduledWorkoutExercise`
on this device may still point at that row, and dropping it out from under
that reference reproduces the exact bug `docs/sync-dangling-references.md`
exists to describe, just triggered by an edit instead of a delete.

Plan membership gets the lighter version of the same treatment
(`_addMissingPlanWorkoutLinks`): a trainer adding a day to a plan that
already exists on the device needs that link to arrive too. It's additive
only — links are added, never removed — because neither this method nor
`_pullScheduledWorkouts` has a path for deleting a scheduled session the
server stops reporting. A server-side removal here would either leave a
stale link behind or, worse, strand a session on the device with nothing
account for it. The same reasoning is why the optional cycle-schedule
endpoint (`ScheduleClientPlanAsync`, `docs/…` below) only ever adds
sessions for dates that don't already have one.

## 5. What's deliberately not here yet

- **Prescribed weight and RPE.** The design's SET / REPS / WEIGHT / RPE table
  only has a home for reps: `WorkoutSetTemplate` (server) and
  `WorkoutSetTemplateTable` (client) store `TargetReps` alone. Adding the
  other two means a migration and a client schema bump on both sides, plus
  the sync fields to carry them — real scope, not a UI gap. In the meantime,
  weight and RPE guidance goes in the per-exercise coach note (`Notes` on
  `WorkoutExercise`), which this change also makes visible to the trainee for
  the first time — it round-tripped through sync already, but nothing on the
  trainee side ever rendered it. It now shows, read-only, in both the
  workout overview and the set-focused view, visually distinct from the
  client's own editable note beneath it.
- **A UI for the cycle-schedule endpoint.** `ScheduleClientPlanAsync` exists
  and is tested — a trainer can lay a weekly cycle of named days across a
  plan's duration, additive-only for the reasons in section 4 — but nothing
  in the Workout Builder screen calls it yet. Plans built through the console
  today are free-choice: the trainer builds the days, the client picks which
  one to train, the same way a client's own free-choice plan already works.
  Wiring a calendar/cycle picker into the screen is a follow-up, not a gap in
  the backend.
- **Swapping which exercise a picked entry prescribes, from the UI.** The
  backend distinguishes a swap from a remove-and-add (section 3) and is
  tested for it; the screen itself only exposes remove-and-re-add, which
  produces the same end state. A dedicated "replace this exercise" action is
  a smaller follow-up than either of the above.

## 6. The general lesson

Every failure this change had to guard against has the same shape: a value
that is completely valid where it's written and silently unusable where it's
read, in a boundary nothing but application code enforces. `ExerciseId` on a
`WorkoutExercise`, `ScheduledDate` on a workout the pull can't delete,
`SourceExerciseId` with no foreign key — none of these are typed as "might
not resolve." They're `Guid`, not `Guid?`, and the schema has no constraint
saying so. The type system will wave through a reference to data the reader
can never see, every time, because from where the write happens that data is
real. The only place that fact becomes visible is downstream, after the
values have already crossed an account boundary or a device boundary the
writer wasn't thinking about — which is exactly why `dotnet build` and a
green `flutter test` run had nothing to say about any of the three bugs this
document walks through, and why each of them needed a test that specifically
constructs the cross-boundary case to catch.

## 7. The read path nobody had folded, and a phone screen with no room for the thing it's for

Two reports came in together — a client's workout showing duplicate and
"deleted" exercises and sets in the console, and the exercise editor on
mobile being too cramped to use. Neither needed a migration; both were fixed
by looking at code that already worked correctly *somewhere else* in this
codebase and asking why the Workout Builder wasn't doing the same thing.

### 7.1 A fold that three other readers already had, and the builder didn't

`docs/trainer-console-duplicate-rows.md` had already named the shape of this
bug once, for `WorkoutExercises`: rows written before adding an exercise
became idempotent per `(WorkoutId, ExerciseId, OrderPosition)` slot are still
in the database, will never be deleted (this is a training log), and every
reader has to fold them on the way out. Three readers already did — the sync
client (`_collapseDuplicateServerExercises`, `_collapseDuplicateSetTemplates`
in `sync_service.dart`) and Session Review (`CollapseDuplicateEntries`,
`TrainerConsoleService.cs:564`). `TrainerConsoleService.ToClientWorkoutDto`,
the mapper behind the Workout Builder's read and every save response, still
only filtered `RemovedAt == null`. A duplicate slot rendered as two
exercises; a prescription re-saved under the old append-not-replace bug
rendered as three times its actual set count; an exercise the client deleted
on their device — which only ever unlinks the *one* row their local pull had
already collapsed onto — left its untouched twin sitting server-side with
nothing to delete it, for the builder to be the first screen ever to show.

None of this tripped a test, because none of the tests for this endpoint
constructed the dirty-data case — the only assertion against
`GetClientWorkoutsAsync` before this change was `Assert.Empty` on a workout
with nothing in it at all. A green `dotnet test` run says the *clean* path
works; it says nothing about rows a bug five releases ago already wrote and
this table will hold onto forever.

The fix (`ToClientWorkoutDto`, `TrainerConsoleService.cs:1128-1213`) folds on
the same two keys the other three readers already use — `(ExerciseId,
OrderPosition)` for exercises, `SetNumber` for set templates — specifically
*because* they're the same keys, not out of convenience. Reusing the write
path's own idempotency key (`WorkoutRepository.AddExerciseToWorkoutAsync`,
the slot check at line 158) means the read fold and the write path can never
quietly disagree about what counts as a duplicate; a fold with its own
separate notion of identity is a second place for that definition to drift
from the first, which is exactly what `trainer-console-duplicate-rows.md`
warned about the second time this shape of bug showed up.

**The one way this fold couldn't just copy Session Review's.** Session
Review reports a session's history; if two twins in one slot both carry
logged sets, it keeps both, because there's no way to merge two sets of real
training history and showing both is the honest answer. The Workout Builder
is an editor. It has to return exactly one `Id` per slot, because that `Id`
is what the trainer's next save echoes back — and `UpdateClientWorkoutAsync`
treats an omitted `Id` as "gone," retiring or deleting whatever the payload
doesn't mention. Handing back two ids on a slot the fold ostensibly
collapsed to one exercise would mean the *next* save silently drops one
of them. So the survivor has to be chosen, not merely narrowed down: the
twin with logged sets, via a new one-query-per-request lookup
(`WorkoutRepository.GetWorkoutExerciseIdsWithLoggedSetsAsync`, line 309),
tie-broken by the lowest `Id` for a result that's stable between requests.
That, in turn, is what makes the self-healing property safe: because
`UpdateClientWorkoutAsync` diffs against the *unfolded* live rows
(`existingLive`, line ~916 — unchanged by this fix), a twin the read-side
fold hid from the trainer is simply an entry that day's next save doesn't
mention, and the existing cleanup pass removes it exactly the way it removes
anything else the trainer took off the day. **Saving a day heals its
duplicates** — confirmed against production data (34 duplicated slots across
six workouts, one holding the same exercise six times over) rather than
assumed, and pinned by a test (`SavingADayRemovesTheDuplicateTheFoldHid`,
`TrainerWorkoutBuilderTests.cs`) precisely because it's a consequence of the
survivor rule, not a separate mechanism — get the survivor wrong and a save
would retire the row the client actually trained against instead of its
empty twin.

An entry whose `ExerciseId` no longer resolves to a live `Exercise` row (the
client deleted their own custom exercise) is dropped for a second, harder
reason than tidiness: `ResolvePrescribedExerciseIdsAsync` rejects an unknown
exercise id with `unknown_exercise` and fails the *entire* save if the
builder ever echoed one back. Showing it and then refusing to save it would
have been a worse failure than not showing it.

### 7.2 A screen where every block fit and the one that mattered didn't

The mobile complaint wasn't about width — it was that at 390×844, the plan
summary, the day's own name/description/difficulty/duration fields, and the
day-selector chips together ran to roughly 700px before a single exercise
was drawn, leaving under 150px for the list the screen exists to show, with
Save scrolled out of reach below it. Every individual block was reasonably
sized. None of them, individually, looked wrong in isolation — which is
exactly why this kind of bug survives: nothing crashes, nothing mis-renders,
a screenshot of any one card looks fine. The defect is only visible as a sum
across the whole column, and nothing short of laying the actual screen out
at phone width and asking "how far down is the first exercise" would catch
it — which is why the regression test for this
(`the first exercise of an existing day is visible without scrolling`,
`workout_builder_screen_test.dart`) asserts exactly that number, in pixels,
rather than anything about an individual widget.

Three changes bought the space back, all gated to `!Breakpoints.isDesktop`
so the desktop layout is untouched: the plan card collapses to one line
(name, active pill, start date — no description) on mobile; the day's own
metadata fields move behind a collapsible section
(`_detailsExpanded`, `workout_builder_screen.dart:860`) that starts closed
for a day the trainer is opening to edit its exercises and open for a new
one that has nothing else yet; and Save/Delete move out of the scrollable
column into a pinned sibling below it, so only the exercise list itself ever
needs scrolling. The collapsible section's one subtlety: collapsing it means
its `TextFormField`s aren't in the widget tree, which also means
`Form.validate()` can't see them — a day saved with an empty name while
collapsed would previously have skipped local validation entirely and relied
on the provider's own empty-name guard alone. `_save()` (line ~900) now
expands the section whenever either the local `validate()` or the provider's
`saveDraft()` fails, so the trainer always ends up looking at the field an
error is actually about, rather than a message with nothing near it to fix.

Fixing the space also surfaced a second, independent bug in the set list
that widening the space wouldn't have caught on its own: `_SetChip`
(`workout_builder_screen.dart:1355`) is stateful, and its
`TextEditingController` was seeded once from `sets[setIndex]` in `initState`
and never re-seeded — built, like everything else in that `Wrap`/`Column`,
by position with no `Key`. Remove the middle set of three and Flutter
reuses each surviving `State` object by its position, not by which set it
used to represent, so the two remaining rows keep showing the *old* values
at their old positions while the underlying data has already shifted. Worse,
because `updateSetReps` writes by index, the next keystroke on either
surviving row would have written that stale on-screen value straight back
into whichever set was really at that index — a set the trainer never
touched. The fix is `key: ObjectKey(entry.sets[setIndex])` at both call
sites (lines 1234 and 1253): `ExerciseSetDraft` is a plain mutable object
with no id of its own, but `removeSet` removes the object itself from the
list, so the *surviving objects' identity* is exactly what Flutter's element
reconciliation needs to reattach the right `State` to the right data
regardless of where it now sits in the list — not a synthetic id manufactured
for the purpose, the same instance the draft has held all along.

### 7.3 The general lesson

Both halves of this have the same shape as `trainer-console-duplicate-rows.md`'s
own closing lesson, applied one level further out: **a fix that lives in one
reader doesn't reach the readers that never got it, and a screen built one
card at a time doesn't add up to a screen that works, even when every card
was reviewed on its own.** The compiler has nothing to say about a mapper
missing a fold three siblings already have, and a passing widget test that
only ever pumps at 1400×1200 has nothing to say about a viewport where the
same widgets, laid out the same way, leave nothing for the one thing the
screen is for. Both needed the actual dirty state — a duplicated database
row, a 390px-tall viewport — constructed on purpose to see at all.
