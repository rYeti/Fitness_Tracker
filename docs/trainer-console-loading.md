# The Trainer Console made the trainer wait

A trainer opened the console and watched a skeleton. Not for a moment — long
enough to be the first thing anyone said about the feature.

This is what was actually wrong, why nothing in the repository could see it, and
the rules the fix leaves behind. It is written to be read on its own.

Line references are to the commit that introduced this document.

---

## 1. Four causes, stacked

No single one of them explains the wait, which is most of why it went unfixed:
each is defensible on its own, and each was written by someone with a reasonable
model of what they were doing.

| | Where | What it cost |
|---|---|---|
| 1 | `TrainerConsoleService.GetRosterAsync` / `GetDashboardKpisAsync` | `4N + 2` queries per dashboard paint, each reading a client's entire training history |
| 2 | `trainer_console_home.dart`, a plain `IndexedStack` | ~7 requests on open, five of them for sections nobody was looking at |
| 3 | `trainer_console_provider.dart`, one `isLoading` over a `Future.wait` | the roster waited on the slowest thing beside it |
| 4 | `ActiveClientProvider` and the Dashboard fetching the roster separately | the same list, twice, from two different queries |

They compound. The server was slow, the client asked it for more than it needed
at a moment when it needed the answer most, and then declined to draw anything
until all of it arrived.

---

## 2. Why nothing caught it

This is the part worth keeping.

**The compiler had nothing to say**, because there was nothing to say. Here is
the defect, in full:

```csharp
foreach (var client in clients)
{
    var plans = await _workoutPlanService.GetUserPlansAsync(client.ClientId);
    var scheduled = FilterToCurrentProgramme(
        await _scheduledWorkoutService.GetUserScheduledWorkoutsAsync(client.ClientId),
        plans);
    …
}
```

Every type is right. Every call is correct. It returns the correct numbers. There
is no version of a type system that objects to this.

**The tests had nothing to say, for three separate reasons**, and they are worth
naming individually because they are three different holes:

1. **These two endpoints had no tests at all.** Not weak ones — none.
   `TrainerConsoleService` had coverage for session review and for the nutrition
   summary, and nothing whatsoever for the roster or the KPI row.
2. **The suite runs on SQLite in-memory with two seeded clients.** At that size
   an N+1 is four fast queries against a database in the same process. Even a
   test that existed would not have been slow.
3. **Flutter widget tests pump a fake repository that returns instantly.** "All
   five sections fetch on open" is invisible when a fetch costs nothing. The
   test asserting the console renders was *passing*, and it was passing on a
   console doing seven times the work it needed to.

Put together:

> A performance defect is invisible to every check this repository runs, because
> every check runs at a scale where the defect is free.

That is not a gap in the test suite so much as a property of test suites. It is
the reason the regression test for this one had to be a different *kind* of
assertion — see §8.

---

## 3. The two N+1s, and why there were two

`GetRosterAsync` and `GetDashboardKpisAsync` both loop the roster, and both call
down to `ScheduledWorkoutRepository.GetUserScheduledWorkoutsAsync`:

```csharp
return await _context.ScheduledWorkouts
    .Where(sw => sw.Workout.UserId == userId)
    .Include(sw => sw.Exercises)
        .ThenInclude(e => e.Sets)
    .ToListAsync();
```

No date predicate. Every session the client has ever had, with every exercise and
every logged set, as one join whose row count is `sessions × exercises × sets`,
tracked by the change tracker, and mapped to DTOs — so that the service could
count four weeks of them and take one `MAX`.

For a client eighteen months into training that is tens of thousands of rows
materialised to produce two integers and a date.

And the Dashboard calls both endpoints in parallel, so a single paint read every
client's whole history **twice, concurrently**. Neither method knew the other
existed. They were two endpoints, in two methods, computing the same thing over
the same rows through two different date windows — which is exactly the shape
that hides duplicated work from the person writing either half.

Both now project from one `BuildRosterAggregateAsync`. The cost is four queries,
whatever the roster's size:

| | before | after |
|---|---|---|
| `GET /roster` | `1 + 2N` | 4 |
| `GET /dashboard-kpis` | `1 + 2N` | 4 |
| one dashboard paint | `2 + 4N` | 8 |

At 25 clients that is 102 queries down to 8, and the eight are aggregates rather
than history dumps.

---

## 4. The rule that had to survive the rewrite

`docs/trainer-session-review.md` describes a rule this codebase learned the hard
way: a scheduled workout outlives the plan that generated it, so a client moved
onto a new programme leaves behind every date the old one ever produced. Counted
as planned-and-not-completed, those hold adherence down for work never asked of
the client.

`FilterToCurrentProgramme` encodes it. Moving the count into SQL meant expressing
it there, and the interesting part is that it got **cheaper**:

```csharp
sw => sw.WorkoutPlanId == null
   || sw.WorkoutPlan!.IsActive
   || sw.IsCompleted
   || sw.IsSkipped
   || sw.Exercises.Any(e => e.Sets.Any())
```

The in-memory version needed the client's whole plan list loaded first, to build
an `activePlanIds` set to test membership against. In SQL it needs nothing:
**the navigation property is the join**. A scheduled workout's plan always
belongs to the same user, so `sw.WorkoutPlan!.IsActive` is the same question,
asked where the answer already lives.

The rule it leaves behind, and the one to quote in review:

> The current-programme predicate exists once, as
> `ScheduledWorkoutRepository.InCurrentProgramme`. Every console read that counts
> sessions uses that one. Two copies of it will drift — which is the failure the
> session-review doc already describes, in a different costume.

The in-memory `FilterToCurrentProgramme` still exists for the paths that filter
DTOs rather than rows. The two sit next to each other with a comment tying them
together, so editing one is visibly editing both.

---

## 5. Bounding, and what a bound is for

The roster was the worst case, not the only one. The same shape was everywhere:

- `workout-history?date=` read the client's **entire** history to return **one day**.
- `workout-summary` read all of it to report twelve weeks.
- `session-history?count=10` built the full prescribed-vs-logged graph for every
  past session and then kept ten — `Take(count)` was the *last* line of the method.
- `weight-history` returned every weigh-in ever recorded, in no defined order.
- `nutrition-summary` loaded the client's whole food library to resolve seven days of meals.
- Exercise names came from loading the **global exercise catalogue** as full
  entities — descriptions, image URLs, muscle groups — and keeping one string per row.

There is one sentence under all of these:

> Every read path needs a bound, because *"all of it" is a size that only exists
> in production.*

On a developer's seeded account "all of it" is forty rows. There is no local
condition under which the unbounded version feels wrong.

### Session history is the one place bounding and correctness fought

Personal-record detection walks a client's sessions oldest-first carrying a
running maximum per exercise. Read ten sessions instead of all of them and a PR
becomes relative to *the page* — the first time an exercise appears in those ten
looks like a career best.

The fix is one extra projected query,
`ScheduledWorkoutRepository.GetBestWeightsBeforeAsync`: the heaviest completed
set per exercise across everything older than the page, used to seed the running
maximum before the walk starts. Ten lines, and the flags come out identical.

One detail that looks like fussiness and is not: the seed filters `Weight > 0`.
The unbounded walk only ever recorded a baseline for a positive weight, so
seeding a zero would invent a baseline it never had — turning somebody's first
real lift into a personal record. Reproducing old behaviour exactly sometimes
means reproducing where it declined to act.

---

## 6. `AsNoTracking`, and the shape of a dangerous optimisation

Not one read in the entire API used it. Every console read is a projection to
DTOs, so the change tracker was building identity-map entries for tens of
thousands of entities that were about to be thrown away.

The tempting fix is one line in `Program.cs`:
`QueryTrackingBehavior.NoTracking`, applied globally.

It would have broken, silently, every fetch-then-mutate-then-`SaveChangesAsync`
path in the codebase — `UpdateScheduledWorkoutAsync`, `AcceptInviteAsync`,
`RevokeInviteAsync`, `RemoveRelationshipAsync`, `UpdateWeightAsync`,
`UpdateExerciseAsync`, `UpdateWorkoutAsync`. Each would compile, run, mutate the
object, return it, persist nothing, and answer 200.

So it is applied per query, on read methods only, and never on the `*ById` /
`Find*` / `GetActiveRelationship*` methods the write paths call first.

> An optimisation that changes a default changes it for all the code you haven't
> read.

---

## 7. The client half: what "keep the screens alive" was asking for

The console shell built its five sections like this:

```dart
child: IndexedStack(
  index: …,
  children: [ TrainerDashboardScreen(…), MessagesScreen(), … ],
),
```

with a doc comment explaining the intent:

> Screens are kept alive in an `IndexedStack` so switching sections doesn't
> re-fetch everything.

That intent is real, and `IndexedStack` does deliver it. What the comment did not
know is that it also *builds every child immediately*. Five `initState`s ran on
the first frame; each fired its own loads; the trainer looking at the Dashboard
was waiting behind requests for four screens they could not see.

> In Flutter, "keep this alive" and "build this now" are the same API, and the
> comment only knew about one of them.

The fix was already in the repository. `core/widgets/lazy_indexed_stack.dart`
exists, is used by the trainee app, and its doc comment describes this exact bug
— in the trainee tab bar, where it was found and fixed first. The console did not
inherit the lesson, because the lesson lived in a widget rather than in a
convention.

> A fix that lives in a widget rather than a convention gets re-lost.

### Messages is the exception, and the exception is instructive

Deferring `ChatProvider.loadConversations()` to the first visit of the Messages
tab would have been wrong. Loading conversations is also what joins this device
to every thread's SignalR hub group, and the sidebar's unread badge is folded
from the same list. Defer it and the badge is blank and the device stops hearing
about the threads it is *not* in — which is the only kind that needs a badge.

So that call moved **up**, into `TrainerConsoleHome.initState`, next to
`signalR.connect()` — which was already there, for the same reason, with a
comment already making the argument. The Messages *screen* is still lazily
mounted; only its data is shell-level state.

The general form: when a section's fetch turns out to be load-bearing for the
shell, the answer is to hoist it, not to keep it eager where it sits. If it
belongs to the shell, say so.

---

## 8. One loading flag over several requests

```dart
final results = await Future.wait([
  _repository.getRosterWithStats(),
  _repository.getDashboardKpis(),
]);
```
…with a single `_isLoading` cleared in `finally`, and a screen that returned a
full-page skeleton while it was set.

Two consequences, both bad, and the second one worse than it sounds:

- **Every section is as slow as the slowest.** The roster is the thing the
  trainer came for. It waited on three integers.
- **Every section is as fragile as the flakiest.** One failed request blanked the
  page. `ClientDetailProvider` had the same structure and its own comment
  admitted it: *"Any one of the three failing blanks the whole screen, so the log
  is the only thing that says which."*

And a third, which is really a UX bug wearing a loading state: the page *chrome*
was behind the gate too. A trainer with no clients, waiting on a slow roster,
could not reach the invite button — the one action an empty console exists for.

Each section now owns its four states, and the skeleton follows the shape
`MessagesScreen` already used: `isLoading && isEmpty`, so a refresh redraws over
what is on screen instead of blanking it.

---

## 9. Two date bugs found on the way

Neither is a performance bug; both were sitting in the code being rewritten.

**The week started on the wrong day, one day in seven.**

```csharp
var weekStart = DateTime.UtcNow.Date.AddDays(-(int)DateTime.UtcNow.DayOfWeek + 1);
```

`DayOfWeek.Sunday` is `0`, so on Sunday this lands on **tomorrow**. Every Sunday,
`SessionsThisWeek` and `AvgAdherencePercent` read zero, and the twelve-week
attendance chart beside them was shifted a week. It also reads `DateTime.UtcNow`
twice, which disagree across midnight.

**Strength progression had no labels.** The chart built a dictionary keyed by
`Exercise.Id` and looked it up with a `WorkoutExercise.Id` — different tables. It
never matched, and `GetValueOrDefault(id, "")` turned every miss into an empty
string, so the failure rendered as a chart of blank names rather than as an
error.

Both are the same species as the meal-day-window failures already on record in
`docs/trainer-nutrition-duplicate-meals.md`: identifiers and instants that the
type system is happy to let you confuse, because `Guid` is `Guid` and `DateTime`
is `DateTime`.

The week arithmetic is now `WeekStartFor`, spelled `(dayOfWeek + 6) % 7`, with
the clock read once. It is pinned by a test over all seven days. A proper clock
seam (`TimeProvider`) would let the service itself be tested on a Sunday and is
the obvious next step; this repo now has date-window bugs on record in three
separate features, which is the argument for it.

---

## 10. How this is pinned

`TrainerRosterTests` and `TrainerDashboardKpiTests` are new — neither endpoint had
any coverage. Most of them pin *answers* that a rewrite into SQL could quietly
change: adherence is `null` and not `0` when nothing was scheduled; the window is
the trailing 28 days; a session logged at six this evening still counts as today;
`LastSessionDate` is the newest *completed* session; the three
`FilterToCurrentProgramme` clauses; and — the security-relevant one — a trainer's
aggregate cannot pick up another trainer's clients, now that `ids.Contains(…)` is
the only thing separating them where a per-client loop used to be.

But the assertion that matters most is this one:

```csharp
_fx.Queries.Reset();
await _console.GetRosterAsync(smallTrainer.Id);
var withOneClient = _fx.Queries.Count;
…
Assert.Equal(withOneClient, withTenClients);
```

`DbFixture` now carries a `QueryCounter` (`FitTracker.Api.Tests/QueryCounter.cs`),
a `DbCommandInterceptor` that counts commands. The test seeds one client, counts,
seeds ten, counts again, and asserts they match.

That is the test the original defect needed, and it could not have been written
as a timing assertion — at fixture scale the slow version is not slow, and a
timing assertion on CI is a flaky test. **The cost growing with the roster was
the defect. Assert the shape, not the speed.**

On the Flutter side, `shell_test.dart` now counts fetches per section: nothing
fetches until its tab is opened, and opening a tab twice still fetches once —
which pins both halves of what `LazyIndexedStack` is for.

---

## 11. What was deliberately not done

- **The endpoints were not merged into one `/dashboard`.** Published mobile
  clients call both, and — more to the point — the client-side fix *wants* them
  separate, so the two sections can resolve independently. Merging saves one
  round trip and costs the ability to draw the roster before the KPIs.
- **No caching layer.** There is none anywhere in this API. Adding the first one
  to solve a problem that measurement had not yet shown is what YAGNI is for.
  Each endpoint is now a single indexed aggregate; running it twice costs less
  than merging would save.
- **No `(WorkoutId, IsCompleted, ScheduledDate)` index** for the last-session
  query — write amplification on the hottest table in the schema for a marginal
  gain over the two-column index. **No `(UserId, IsActive)` on `WorkoutPlans`** —
  low-cardinality flag, few rows per user. Indexes that were not added need a
  reason as much as ones that were.
- **Cloud Run still scales to zero.** `deploy.yml` sets no `--min-instances`, and
  `Program.cs` runs `db.Database.Migrate()` on every cold start. That is seconds
  of first-open latency that none of this removes, and it is a cost decision
  rather than a code one. It matters for measurement: **take baselines against a
  warm instance**, or the cold start swamps everything you are trying to compare.

---

## 12. What to take from this

- An `await` inside a `foreach` over a collection whose size you don't control is
  an N+1. The unit is not "two queries" — it is "two queries per row of the
  response".
- `.Where()` on a `List` and `.Where()` on an `IQueryable` are spelled
  identically, and only one of them ran on the database. The `ToListAsync()`
  above it is the boundary, and where that boundary sits is the whole performance
  story.
- One loading flag covering several requests makes every section as slow as the
  slowest and as fragile as the flakiest — and usually hides the page's chrome
  along with its data.
- A screen nobody can see should not be fetching.
- Every read path needs a bound.
- And if a defect only shows up at a scale none of your checks run at, the
  regression test has to assert something other than the symptom.
