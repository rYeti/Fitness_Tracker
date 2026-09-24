# Exercise notes: how a client's note reaches their trainer

A walkthrough of why a note a client typed under an exercise during an active
workout never reached the Trainer Console, what it took to get it there, and
the rule it leaves behind. Written to be read on its own.

Line references are to the commit that introduced this document.

---

## 1. What was asked for

During an active workout, every exercise has an **Exercise notes** card
("How did it feel?"). A trainee with a trainer writes things there that a
trainer genuinely needs: *"left knee caved on the last rep"*, *"skipped the
last set, shoulder pinched"*. The request was simple: the trainer should see
those notes in the client's workout overview — Session Review in the console.

Session Review already showed one note: the client's note on the **whole
session** (`ScheduledWorkout.Notes`, the "Workout notes" field), rendered as
the *CLIENT NOTE* card under the session's hero stats. The per-exercise note
was nowhere.

## 2. The note never left the phone

It would be natural to assume this was a display gap — the server has the
data, the console just doesn't draw it. Every layer looked ready:

| Layer | Has an exercise-note field? |
|---|---|
| Local drift table `ScheduledWorkoutExerciseTable` | `notes` column |
| Server model `ScheduledWorkoutExercise` | `Notes` column |
| Server response `ScheduledWorkoutExerciseResponseDto` | `Notes` |
| Sync pull (`_pullScheduledWorkouts`) | reads `se['notes']` |

And yet the server's column was always null, for every client, forever. There
was **no way to write it**:

- `POST api/ScheduledWorkout` creates the session's exercise entries itself,
  from the workout's exercise list, with no note.
- `POST api/ScheduledWorkout/{id}/exercises/batch` takes a bare list of
  workout-exercise ids.
- There was no update endpoint for an exercise entry at all — only
  `PATCH .../complete`.

On the device side it was the same story from the other direction. The active
workout's `_saveCurrentExercise` wrote the note to the local row and **did not
touch `syncStatus`**; and nothing in `SyncService` ever looked at a scheduled
exercise's `syncStatus` anyway. The row's only transition was
`markScheduledExerciseSynced`, called when the device learned the server's id
for the entry — which set it to *synced* whether or not its content had ever
been sent.

### Why nothing complained

A column that exists on both sides, a DTO that carries it, and a pull that
reads it is exactly what a working round trip looks like to the compiler. The
types line up end to end. The tests exercised the pull (which dutifully read
back the server's null) and the console (which dutifully rendered what the
payload held). No test ever asked the only question that mattered: *does a
note typed on the phone come out of the API?* — because there was no single
component whose job that was. It is the failure mode `docs/sync-account-switch-duplication.md`
names: **a `syncStatus` left unchanged is an edit that never leaves the device.**
Here it was worse, because there wasn't even a push to leave through.

## 3. What changed

```
Active workout                 SyncService                       API                         Console
───────────────                ───────────                       ───                         ───────
note typed  ──► row.notes      _syncSetsForScheduledWorkout      PUT api/ScheduledWorkout/   Session Review
                syncStatus=2 ──►  if syncStatus==2:          ──►   exercises/{id}/notes  ──►   _ExerciseCard
                (only if it       _syncScheduledExerciseNotes      (owner-scoped)              └ CLIENT NOTE
                 changed)                                          │
                                                                   ▼
                                                   GetClientSessionHistoryAsync
                                                   SessionExerciseLogDto.ClientNote
```

### 3a. The API: one owner-scoped write

`PUT api/ScheduledWorkout/exercises/{scheduledExerciseId}/notes`
(`ScheduledWorkoutController.UpdateExerciseNotes`) replaces the note, with the
same ownership predicate every other write in that controller uses —
`e.ScheduledWorkout.Workout.UserId == userId`. A trainer can *read* a client's
notes through Session Review, which re-checks the Active relationship; they
cannot write one, and `OnlyTheOwnerCanWriteAnExerciseNote` pins that.

It is a separate endpoint rather than a new field on an existing payload
because there is no existing payload that describes one exercise entry. The
body is a tiny DTO (`ScheduledExerciseNotesRequestDto`) with the same
`[MaxLength(2000)]` the session note has. A blank note is stored as null so
the console never draws an empty card.

### 3b. Session Review: `ClientNote` on each exercise

`SessionExerciseLogDto` gains `ClientNote`, filled from
`ScheduledWorkoutExercise.Notes`. It is named after the session-level
`ClientSessionSummaryDto.ClientNote` on purpose: both are the client's own
words. It is deliberately *not* `Notes`, because an exercise already has a
different note — the trainer's guidance on `WorkoutExercise.Notes`, which the
client sees as the *Coach note* banner. Reading "notes" off the wrong table
would have shown the trainer their own instructions and called it feedback.

Two existing folds in `TrainerConsoleService` decide which exercise entries a
session reports, and both had to learn that a note is real content:

- **Retired and unlogged entries were dropped** as ghosts — an exercise that
  left the workout and has no sets "describes nothing that ever happened"
  (`docs/trainer-session-review.md`). A note is something that happened.
  *"Skipped, shoulder flared up"* on an exercise later dropped from the plan is
  precisely the thing a trainer needs to see, so an entry with a note is kept.
- **`CollapseDuplicateEntries`** folds twin entries in one workout slot,
  keeping the ones with sets. Which twin a note landed on depends on which
  local row the device had linked when it pushed — not necessarily the twin
  the sets went to. So among empty twins the noted one is preferred, and if
  the kept entries carry no note while a folded twin does, the note moves onto
  the survivor. This is the same move `CollapseDuplicateSessions` already made
  for the session note (`Notes = first non-blank across twins`); without it
  the fold would have silently thrown away exactly the notes that arrived by
  the less common path. `docs/trainer-console-duplicate-rows.md` is the
  standing warning here: a read-side fold is only correct if it knows
  everything the write side can put in the rows it discards.

### 3c. The console

`_ExerciseCard` renders the note under the set table with the existing
`_ClientNote` widget — the one already used for the session note — so the two
read as the same kind of thing and there is one widget for one pattern.

### 3d. The device: flag it, push it, and don't let a link un-flag it

This is where the subtlety is.

**Flagging.** `_saveCurrentExercise` runs on every debounced keystroke in a
set field, not just when the note changes. Setting `syncStatus = 2` on every
run would push every exercise's note on every sync. So it reads the stored row
first and only writes — and flags — when the note actually differs.

**Pushing.** `_syncSetsForScheduledWorkout` already visits every scheduled
exercise that has a server id, both right after a session is created or
updated and on every sync via `_syncMissingScheduledExerciseSets`. It now
pushes the note for any entry at `syncStatus == 2` before handling its sets.

**Linking.** Here is the trap. The most common way a note is written is
*before the session has ever synced*: the client trains offline or quickly,
the local entry has a note and no server id. The session's POST then creates
the server's entries — with no note — and the device links its local rows to
them. The old `markScheduledExerciseSynced` set `syncStatus = 1` at that
point, and the note would have been marked as sent without ever being sent.

So `markScheduledExerciseSynced` is gone, replaced by
`linkScheduledExerciseToServer(localId, serverId, serverNotes:)`. It compares
the local note with the server's (blank and null are equal) and leaves the row
at **2** when they differ. A link records *which server row this is*; it
says nothing about whether their contents agree, and conflating the two is
the whole bug. The same helper is reused after the push itself, comparing
against what was just sent, so a note edited while the request was in flight
stays pending rather than being stamped synced.

### 3e. The pull: don't erase what never left

The pull now also reconciles the note on an entry the device already has, so
a note written on a second device arrives on the first — under the usual rule
that only a clean (`syncStatus == 1`) local row is overwritten.

The first draft of that did the obvious thing: server differs from a clean
local row, so take the server's. That would have **deleted every exercise
note written before this change**. Every one of those rows is clean by
`syncStatus` and has a note the server has never heard of — because until now
nothing ever sent it. Overwriting it with the server's null is data loss
presented as a sync.

The rule instead: if the server has a note, take it; if the server has none
and the device does, queue the device's for pushing. That turns the pull into
the backfill — the first sync after upgrading sends every historic note up —
at the cost of one rare case: if a client *clears* a note on one device, a
second device that still holds it will push it back. Losing a deliberate
clear occasionally is a far better failure than losing every note ever
written. `held from before notes were pushed is queued by the pull, not erased`
pins the rule.

## 4. The rule it leaves behind

**A field that exists on both sides of the API is not a field that syncs.**
Before trusting that a round trip works, find the line of code that *sends*
it and the endpoint that *writes* it; a matching column, DTO and pull are what
a working round trip looks like, and also what this one looked like while
carrying nothing.

Two narrower rules fall out of it:

- **Linking a local row to a server row is not the same as syncing it.** If a
  row can carry content before it has a server id, the link must compare that
  content with the server's instead of stamping the row synced.
- **When you start syncing a field that never synced, the existing data is
  ahead of the server, not behind it.** A reconcile rule that is correct for
  the steady state ("server wins over a clean row") will wipe out the one
  thing the change was meant to deliver on its first run.

## 5. Tests

| Test | Pins |
|---|---|
| `TrainerSessionReviewTests.AnExerciseNoteTheClientWroteReachesTheirTrainer` | written through the service, read back in Session Review |
| `…OnlyTheOwnerCanWriteAnExerciseNote` | a trainer cannot write a client's note |
| `…ABlankExerciseNoteIsStoredAsNoNote` | blank → null |
| `…ANoteOnARetiredExerciseTheClientNeverLoggedIsStillShown` | the ghost-entry drop keeps noted entries |
| `…FoldingAnEmptyTwinAwayKeepsTheNoteItCarried` | the duplicate fold moves the note onto the survivor |
| `sync_service_test` › *written before the session ever synced, is pushed once it links* | the link leaves a noted row pending, and the push sends it |
| › *already on the server is not pushed again* | no push per exercise per sync |
| › *held from before notes were pushed is queued by the pull, not erased* | the backfill rule in §3e |
| › *edited on a linked entry is pushed* | the ordinary edit path |
| `session_review_screen_test` › *the client's note on an exercise is shown under it* | the console renders it, and only where there is one |
| `sync_service_test` › *on a twin the sync de-duplicates away is moved onto the survivor* | §6b |
| `e2e/tests/trainer-exercise-notes.spec.ts` | the whole path in two real browsers — §6 |

## 6. Driving it in a browser, and what that found

Every test in §5 checks one side of the API boundary. The defect in §2 lived
*between* the sides, so the last check is a Playwright spec that runs the whole
path in two real browsers against a seeded local API:

```
trainee browser   Gym → Start Workout → type weight, reps and a note
                  → Next Set until "Workout completed!" → Done
                  → Profile → Sync now → "Sync complete"
API               GET api/ScheduledWorkout: the note is on the session's entry
trainer browser   Session Review → the note is on screen, under CLIENT NOTE
```

The API check in the middle is deliberate: when the spec fails, it says which
half broke. A missing note there is the push; a missing note at the end is the
console.

It runs only with `E2E_API=1`, like `chat-attachments.spec.ts`, and only in
the desktop project. The API allows five auth requests a minute per IP and the
spec makes three, and it also resets the one seeded session scheduled for
today, which three projects would race over. It signs in inside the test, not
through the `traineePage` fixture, because a fixture signs in *before* the
project check can skip it, and the skipped projects would still spend two logins.

### 6a. The first failures were the test, and the fixture's readback hid it

The spec failed intermittently at the API check: the session and its sets
reached the server, but no note request was ever made. Temporary `print`
statements in a release build (the app's logger is silent outside debug) showed
the client doing exactly what §3d says, given what it had been handed: the
save compared the stored note with the field's controller and found them
equal, because the controller still held the *old* note, or none.

The typed text had reached the browser's `<input>` and never reached Flutter.
On the active workout screen, clicking a field's semantics node moves the
*browser's* focus onto that node's element but not Flutter's: after the first
field, every click left Flutter focused on Weight. `typeReliably` reads the
value back from the element it clicked, so it reported success on a field the
framework was not listening to. Tab moves both foci together. The spec now
clicks only the first field, reaches every later one by tabbing until it is
`document.activeElement`, and for the note waits for the one signal that comes
from the framework itself: once the controller holds text, the hint leaves the
field's accessible name ("Exercise Notes How did it feel?" becomes
"Exercise Notes").

This is the same shape as the rest of this document, in the test instead of
the app: a readback from the layer you typed into is not evidence that the
layer you care about received it. `docs/e2e-playwright.md` has the general form.

### 6b. Two real gaps the investigation turned up on the way

Chasing that failure meant reading every path by which a note could be lost
between the field and the push, and two of them were real. Neither is what
caused the flaky runs above, and neither was reproduced in a browser, so
the second is covered only by reading the code and the first by a unit test:

- **Sync de-duplication deleted a twin's note.** `_deduplicateScheduledExercisesByContent`
  merges two local entries for the same (session, workout exercise), keeping
  the one linked to the server. Its own comment says how twins arise: two saves
  racing to insert. The screen's save can also race the sign-in pull, which
  runs in the background. Either way the unlinked twin is the one holding what the user
  just typed, and the merge moved its logged sets onto the survivor but not its
  note. It now carries an unpushed note across and flags the survivor pending,
  unless the survivor has an unpushed edit of its own.
- **The screen kept saving to a row the merge had deleted.** The active
  workout remembers each entry's row id; after a merge that id points at
  nothing, and every later save wrote to it and changed nothing. The save now
  checks the remembered row still exists and looks it up again if not. The
  path that finds an existing row by (session, workout exercise) also now
  writes and flags the note: it used to take the row's id and leave the note behind.

### 6c. Something it showed that this change does not fix

Repeated runs against one database left Session Review listing Bench Press
with a new "set 1" row for every run. The active workout saves a set by
deleting the exercise's local sets and inserting fresh ones; the fresh rows
have no server id, so they are pushed as new sets, and the server's copies of
the deleted ones are never deleted. Any session saved twice accumulates
duplicate sets on the server. That predates this change and is not about
notes, so it is recorded here rather than fixed in passing.
