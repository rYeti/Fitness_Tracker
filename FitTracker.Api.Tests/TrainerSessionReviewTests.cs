using FitTracker.Api.DTOs;
using FitTracker.Api.Models;
using FitTracker.Api.Repositories;
using FitTracker.Api.Services;
using Xunit;

namespace FitTracker.Api.Tests;

/// <summary>
/// What the trainer is shown about a client's training, and specifically the three
/// ways it used to show more than the client actually has.
///
/// None of them are type errors, and none of them fail a query: every row involved
/// is a legitimately stored row with a valid foreign key. They are all the same
/// mistake — reading a table that accumulates history as though it described the
/// present. Scheduled workouts outlive the plan that generated them, scheduled
/// exercise entries outlive the exercise leaving the workout, and set templates used
/// to outlive the prescription being rewritten. A trainer looking at a client's
/// session review saw all three of those ghosts reported as the client's own failure
/// to turn up, skip nothing, and finish every set.
/// </summary>
public class TrainerSessionReviewTests : IDisposable
{
    private readonly DbFixture _fx = new();
    private readonly TrainerConsoleService _console;
    private readonly WorkoutService _workouts;
    private readonly User _trainer;
    private readonly User _client;
    private readonly Exercise _squat;

    public TrainerSessionReviewTests()
    {
        _trainer = _fx.AddUser("Dana", "Whitfield");
        _client = _fx.AddUser("Marco", "Fenn");
        _fx.AddRelationship(_trainer.Id, _client.Id, TrainerClientStatus.Active);

        _squat = new Exercise { Id = Guid.NewGuid(), Name = "Back Squat" };
        _fx.Db.Exercise.Add(_squat);
        _fx.Db.SaveChanges();

        _workouts = new WorkoutService(new WorkoutRepository(_fx.Db));
        _console = new TrainerConsoleService(
            new ActiveRelationshipStub(_trainer.Id, _client.Id),
            null!,
            new WorkoutPlanService(new WorkoutPlanRepository(_fx.Db)),
            new ScheduledWorkoutService(new ScheduledWorkoutRepository(_fx.Db)),
            null!,
            null!,
            new ExerciseService(new ExerciseRepository(_fx.Db)),
            null!,
            _workouts,
            null!);
    }

    public void Dispose() => _fx.Dispose();

    // ── Sessions from plans the client has moved off ────────────────────────

    [Fact]
    public async Task DropsUntouchedSessionsFromAnAbandonedPlan()
    {
        var workout = AddWorkout("Lower A");
        var oldPlan = AddPlan("Winter Block", isActive: false);
        AddPlan("Spring Block", isActive: true);
        AddSession(workout, oldPlan, DaysAgo(10));

        var sessions = await LoadHistory();

        // Switching plan only clears IsActive on the old one; the dates it generated
        // stay in the table untouched forever. Listing them as Missed accused the
        // client of skipping work nobody ever asked them to do.
        Assert.Empty(sessions);
    }

    [Fact]
    public async Task KeepsAbandonedPlanSessionsTheClientActuallyDid()
    {
        var workout = AddWorkout("Lower A");
        var exercise = AddWorkoutExercise(workout, sets: 3);
        var oldPlan = AddPlan("Winter Block", isActive: false);
        AddPlan("Spring Block", isActive: true);
        var session = AddSession(workout, oldPlan, DaysAgo(10), isCompleted: true);
        LogSets(session, exercise, reps: 8, weight: 100, count: 3);

        var sessions = await LoadHistory();

        // The plan is dead, but this session happened while it was live. Real history
        // is never hidden — only the dates that never became anything.
        var only = Assert.Single(sessions);
        Assert.Equal(SessionStatusDto.Done, only.Status);
    }

    [Fact]
    public async Task KeepsSessionsScheduledByHand()
    {
        var workout = AddWorkout("Lower A");
        AddPlan("Spring Block", isActive: true);
        AddSession(workout, plan: null, DaysAgo(3));

        // No owning plan means nobody deactivated anything — an ad-hoc session is
        // always the client's current business.
        Assert.Single(await LoadHistory());
    }

    // ── Exercises that left the workout ─────────────────────────────────────

    [Fact]
    public async Task DropsRetiredExercisesNobodyLoggedAgainst()
    {
        var workout = AddWorkout("Lower A");
        var kept = AddWorkoutExercise(workout, sets: 3);
        var dropped = AddWorkoutExercise(workout, sets: 3);
        var plan = AddPlan("Spring Block", isActive: true);
        var session = AddSession(workout, plan, DaysAgo(2));
        LogSets(session, kept, reps: 8, weight: 100, count: 3);
        AddScheduledEntry(session, dropped);

        dropped.RemovedAt = DateTime.UtcNow;
        await _fx.Db.SaveChangesAsync();

        var only = Assert.Single(await LoadHistory());

        // The entry is still in the table with a valid foreign key — it just no
        // longer describes anything that was asked of the client, so reporting it
        // as an exercise they skipped was a fabricated miss.
        var logged = Assert.Single(only.Exercises);
        Assert.Equal(kept.Id, logged.WorkoutExerciseId);
    }

    [Fact]
    public async Task KeepsRetiredExercisesTheClientLogged()
    {
        var workout = AddWorkout("Lower A");
        var dropped = AddWorkoutExercise(workout, sets: 3);
        var plan = AddPlan("Spring Block", isActive: true);
        var session = AddSession(workout, plan, DaysAgo(2), isCompleted: true);
        LogSets(session, dropped, reps: 8, weight: 100, count: 3);

        dropped.RemovedAt = DateTime.UtcNow;
        await _fx.Db.SaveChangesAsync();

        var only = Assert.Single(await LoadHistory());
        var logged = Assert.Single(only.Exercises);

        Assert.Equal(3, logged.Sets.Count);
        Assert.False(logged.Skipped);
        // No prescription: there is no longer one to have hit or missed, and
        // comparing the sets against a target the workout no longer carries would
        // mark work the client did as falling short of nothing.
        Assert.Null(logged.Prescribed);
    }

    [Fact]
    public async Task DropsEntriesLeftBehindWhenTheSessionChangedWorkout()
    {
        var monday = AddWorkout("Lower A");
        var tuesday = AddWorkout("Upper A");
        var lowerExercise = AddWorkoutExercise(monday, sets: 3);
        var upperExercise = AddWorkoutExercise(tuesday, sets: 3);
        var plan = AddPlan("Spring Block", isActive: true);

        // Repointing a scheduled workout at a different workout leaves the entries
        // stamped from the first one attached to it.
        var session = AddSession(monday, plan, DaysAgo(2));
        AddScheduledEntry(session, lowerExercise);
        LogSets(session, upperExercise, reps: 8, weight: 60, count: 3);
        session.WorkoutId = tuesday.Id;
        await _fx.Db.SaveChangesAsync();

        var only = Assert.Single(await LoadHistory());
        var logged = Assert.Single(only.Exercises);
        Assert.Equal(upperExercise.Id, logged.WorkoutExerciseId);
    }

    // ── Prescriptions inflated by stale set templates ───────────────────────

    [Fact]
    public async Task CountsEachPrescribedSetOnce()
    {
        var workout = AddWorkout("Lower A");
        var exercise = AddWorkoutExercise(workout, sets: 3);
        // A second generation of the same three sets, as re-saving a workout used to
        // leave behind server-side.
        AddSetTemplates(exercise, count: 3);
        var plan = AddPlan("Spring Block", isActive: true);
        var session = AddSession(workout, plan, DaysAgo(2), isCompleted: true);
        LogSets(session, exercise, reps: 8, weight: 100, count: 3);

        var only = Assert.Single(await LoadHistory());
        var logged = Assert.Single(only.Exercises);

        Assert.Equal(3, logged.Prescribed!.SetCount);
        Assert.Equal(3, logged.Prescribed.TargetRepsPerSet.Count);
    }

    // ── The write paths that produced the stale rows ────────────────────────

    [Fact]
    public async Task PushingAPrescriptionReplacesTheOldOne()
    {
        var workout = AddWorkout("Lower A");
        var exercise = AddWorkoutExercise(workout, sets: 4);

        await _workouts.AddSetTemplatesBatchAsync(exercise.Id, _client.Id,
        [
            new WorkoutSetTemplateRequestDto { SetNumber = 1, TargetReps = "8", OrderPosition = 0 },
            new WorkoutSetTemplateRequestDto { SetNumber = 2, TargetReps = "8", OrderPosition = 1 },
            new WorkoutSetTemplateRequestDto { SetNumber = 3, TargetReps = "8", OrderPosition = 2 },
        ]);

        // The client rebuilds every set template locally on save and pushes the lot,
        // so the batch is the whole prescription. Appending it left the previous
        // generation in place and the exercise reported seven sets, not three.
        var stored = _fx.Db.WorkoutSetTemplates.Where(t => t.WorkoutExerciseId == exercise.Id).ToList();
        Assert.Equal(3, stored.Count);
    }

    [Fact]
    public async Task RemovingAnExerciseClearsTheSessionsThatNeverLoggedIt()
    {
        var workout = AddWorkout("Lower A");
        var exercise = AddWorkoutExercise(workout, sets: 3);
        var plan = AddPlan("Spring Block", isActive: true);
        var session = AddSession(workout, plan, DaysAgo(2));
        AddScheduledEntry(session, exercise);

        // ScheduledWorkoutExercise holds a restricted foreign key here, so this used
        // to fail outright and the exercise stayed in the workout server-side.
        Assert.True(await _workouts.DeleteWorkoutExerciseAsync(exercise.Id, _client.Id));

        Assert.Empty(_fx.Db.WorkoutExercises.Where(e => e.Id == exercise.Id).ToList());
        Assert.Empty(_fx.Db.ScheduledWorkoutExercises.Where(e => e.WorkoutExerciseId == exercise.Id).ToList());
    }

    [Fact]
    public async Task RemovingAnExerciseWithLoggedHistoryRetiresItInstead()
    {
        var workout = AddWorkout("Lower A");
        var exercise = AddWorkoutExercise(workout, sets: 3);
        var plan = AddPlan("Spring Block", isActive: true);
        var doneSession = AddSession(workout, plan, DaysAgo(9), isCompleted: true);
        LogSets(doneSession, exercise, reps: 8, weight: 100, count: 3);
        var upcoming = AddSession(workout, plan, DaysAgo(-2));
        AddScheduledEntry(upcoming, exercise);

        Assert.True(await _workouts.DeleteWorkoutExerciseAsync(exercise.Id, _client.Id));

        // Deleting the row would take the logged sets with it, so the exercise is
        // retired: out of the workout, still resolvable for what was performed.
        var stored = Assert.Single(_fx.Db.WorkoutExercises.Where(e => e.Id == exercise.Id).ToList());
        Assert.NotNull(stored.RemovedAt);
        // The session it was never logged against loses it outright.
        Assert.Empty(_fx.Db.ScheduledWorkoutExercises
            .Where(e => e.WorkoutExerciseId == exercise.Id && e.ScheduledWorkoutId == upcoming.Id)
            .ToList());
    }

    [Fact]
    public async Task RetiredExercisesAreNotStampedOntoNewSessions()
    {
        var workout = AddWorkout("Lower A");
        var kept = AddWorkoutExercise(workout, sets: 3);
        var retired = AddWorkoutExercise(workout, sets: 3);
        retired.RemovedAt = DateTime.UtcNow;
        await _fx.Db.SaveChangesAsync();

        var scheduling = new ScheduledWorkoutService(new ScheduledWorkoutRepository(_fx.Db));
        var created = await scheduling.CreateScheduledWorkoutAsync(new ScheduledWorkoutRequestDto
        {
            WorkoutId = workout.Id,
            ScheduledDate = DateTime.UtcNow.Date,
        }, _client.Id);

        // Generating a session from the workout is where the ghosts came from: every
        // session created after an exercise was dropped carried it again.
        var entry = Assert.Single(created!.Exercises);
        Assert.Equal(kept.Id, entry.WorkoutExerciseId);
        Assert.DoesNotContain(created!.Exercises, e => e.WorkoutExerciseId == retired.Id);
    }

    // ── Duplicate rows left behind by a repeated push ───────────────────────

    [Fact]
    public async Task DuplicateSessionsForOneWorkoutAndDateFoldToOne()
    {
        var workout = AddWorkout("Lower A");
        var exercise = AddWorkoutExercise(workout, sets: 3);
        var plan = AddPlan("Spring Block", isActive: true);

        // The shape a lost sync response, or a second device, leaves behind: two
        // ScheduledWorkout rows for the same workout on the same day. Only one was
        // ever logged against.
        var real = AddSession(workout, plan, DaysAgo(2), isCompleted: true);
        LogSets(real, exercise, reps: 8, weight: 100, count: 3);
        AddSession(workout, plan, DaysAgo(2));

        var sessions = await LoadHistory();

        var only = Assert.Single(sessions);
        Assert.Equal(SessionStatusDto.Done, only.Status);
        var logged = Assert.Single(only.Exercises);
        Assert.Equal(3, logged.Sets.Count);
    }

    [Fact]
    public async Task CreatingASessionTwiceForOneWorkoutAndDayReturnsTheFirst()
    {
        var workout = AddWorkout("Lower A");
        AddWorkoutExercise(workout, sets: 3);

        var scheduling = new ScheduledWorkoutService(new ScheduledWorkoutRepository(_fx.Db));
        var dto = new ScheduledWorkoutRequestDto
        {
            WorkoutId = workout.Id,
            ScheduledDate = DateTime.UtcNow.Date,
        };
        var first = await scheduling.CreateScheduledWorkoutAsync(dto, _client.Id);
        var second = await scheduling.CreateScheduledWorkoutAsync(dto, _client.Id);

        // Idempotent per workout and day, not only per the id the caller happened to
        // send — the sync client sends none, so matching on id alone caught nothing.
        Assert.Equal(first!.Id, second!.Id);
        Assert.Single(_fx.Db.ScheduledWorkouts.Where(s => s.WorkoutId == workout.Id));
    }

    [Fact]
    public async Task DuplicateExerciseSlotFoldsToTheLoggedOne()
    {
        var workout = AddWorkout("Lower A");
        var live = AddWorkoutExercise(workout, sets: 2);
        // A second WorkoutExercise row in the exact same slot — the shape a lost
        // batch-post response leaves behind.
        var stale = new WorkoutExercise
        {
            Id = Guid.NewGuid(),
            WorkoutId = workout.Id,
            ExerciseId = _squat.Id,
            OrderPosition = live.OrderPosition,
        };
        _fx.Db.WorkoutExercises.Add(stale);
        _fx.Db.SaveChanges();

        var plan = AddPlan("Spring Block", isActive: true);
        var session = AddSession(workout, plan, DaysAgo(2), isCompleted: true);
        LogSets(session, live, reps: 8, weight: 100, count: 2);
        AddScheduledEntry(session, stale);

        var only = Assert.Single(await LoadHistory());

        // Without the fold this reported a second exercise, unlogged, as Skipped.
        var logged = Assert.Single(only.Exercises);
        Assert.Equal(live.Id, logged.WorkoutExerciseId);
        Assert.False(logged.Skipped);
    }

    [Fact]
    public async Task AStalePrescriptionInTheDuplicateSlotDoesNotInflateTheCount()
    {
        var workout = AddWorkout("Lower A");
        var live = AddWorkoutExercise(workout, sets: 2);
        var stale = new WorkoutExercise
        {
            Id = Guid.NewGuid(),
            WorkoutId = workout.Id,
            ExerciseId = _squat.Id,
            OrderPosition = live.OrderPosition,
        };
        _fx.Db.WorkoutExercises.Add(stale);
        _fx.Db.SaveChanges();
        // The stale row's own generation of set templates — nobody rewrote it once
        // `live` took over the slot, so its prescription is frozen at 3 sets.
        AddSetTemplates(stale, count: 3);

        var plan = AddPlan("Spring Block", isActive: true);
        var session = AddSession(workout, plan, DaysAgo(2), isCompleted: true);
        LogSets(session, live, reps: 8, weight: 100, count: 2);
        // Both rows get stamped onto the session — that's how the duplicate row got
        // there in the first place — but only `live` was ever logged against.
        AddScheduledEntry(session, stale);

        var only = Assert.Single(await LoadHistory());
        var logged = Assert.Single(only.Exercises);

        // Reported off the live slot's own 2 sets, never the stale row's 3.
        Assert.Equal(2, logged.Prescribed!.SetCount);
    }

    [Fact]
    public async Task BothEntriesLoggedInADuplicateSlotAreBothKept()
    {
        var workout = AddWorkout("Lower A");
        var first = AddWorkoutExercise(workout, sets: 2);
        var second = new WorkoutExercise
        {
            Id = Guid.NewGuid(),
            WorkoutId = workout.Id,
            ExerciseId = _squat.Id,
            OrderPosition = first.OrderPosition,
        };
        _fx.Db.WorkoutExercises.Add(second);
        _fx.Db.SaveChanges();

        var plan = AddPlan("Spring Block", isActive: true);
        var session = AddSession(workout, plan, DaysAgo(2), isCompleted: true);
        // The client logged against both twins — there is no way to merge two sets
        // of real history without inventing or destroying some of it.
        LogSets(session, first, reps: 8, weight: 100, count: 2);
        LogSets(session, second, reps: 8, weight: 100, count: 2);

        var only = await LoadHistory();
        var logged = Assert.Single(only).Exercises;

        Assert.Equal(2, logged.Count);
    }

    [Fact]
    public async Task TheSameExerciseTwiceAtDifferentPositionsIsARealSupersetNotADuplicate()
    {
        var workout = AddWorkout("Lower A");
        var firstSlot = AddWorkoutExercise(workout, sets: 2);
        var secondSlot = AddWorkoutExercise(workout, sets: 2); // same exercise, next OrderPosition
        var plan = AddPlan("Spring Block", isActive: true);
        var session = AddSession(workout, plan, DaysAgo(2), isCompleted: true);
        LogSets(session, firstSlot, reps: 8, weight: 100, count: 2);
        LogSets(session, secondSlot, reps: 8, weight: 100, count: 2);

        var only = await LoadHistory();
        var logged = Assert.Single(only).Exercises;

        // Different OrderPosition means a different slot — pairing the same movement
        // with itself in a superset — and must never be folded away.
        Assert.Equal(2, logged.Count);
    }

    // ── Seeding ─────────────────────────────────────────────────────────────

    private static DateTime DaysAgo(int days) => DateTime.UtcNow.Date.AddDays(-days);

    private async Task<List<ClientSessionSummaryDto>> LoadHistory() =>
        (await _console.GetClientSessionHistoryAsync(_trainer.Id, _client.Id, 20))!;

    private Workout AddWorkout(string name)
    {
        var workout = new Workout { Id = Guid.NewGuid(), UserId = _client.Id, Name = name };
        _fx.Db.Workouts.Add(workout);
        _fx.Db.SaveChanges();
        return workout;
    }

    private WorkoutPlan AddPlan(string name, bool isActive)
    {
        var plan = new WorkoutPlan
        {
            Id = Guid.NewGuid(),
            UserId = _client.Id,
            Name = name,
            IsActive = isActive,
            StartDate = DaysAgo(60),
            CreatedAt = DaysAgo(60),
        };
        _fx.Db.WorkoutPlans.Add(plan);
        _fx.Db.SaveChanges();
        return plan;
    }

    private WorkoutExercise AddWorkoutExercise(Workout workout, int sets)
    {
        var we = new WorkoutExercise
        {
            Id = Guid.NewGuid(),
            WorkoutId = workout.Id,
            ExerciseId = _squat.Id,
            OrderPosition = _fx.Db.WorkoutExercises.Count(e => e.WorkoutId == workout.Id),
        };
        _fx.Db.WorkoutExercises.Add(we);
        _fx.Db.SaveChanges();
        AddSetTemplates(we, sets);
        return we;
    }

    private void AddSetTemplates(WorkoutExercise exercise, int count)
    {
        for (var i = 1; i <= count; i++)
        {
            _fx.Db.WorkoutSetTemplates.Add(new WorkoutSetTemplate
            {
                Id = Guid.NewGuid(),
                WorkoutExerciseId = exercise.Id,
                SetNumber = i,
                TargetReps = "8",
                OrderPosition = i - 1,
            });
        }
        _fx.Db.SaveChanges();
    }

    private ScheduledWorkout AddSession(
        Workout workout,
        WorkoutPlan? plan,
        DateTime date,
        bool isCompleted = false)
    {
        var session = new ScheduledWorkout
        {
            Id = Guid.NewGuid(),
            WorkoutId = workout.Id,
            WorkoutPlanId = plan?.Id,
            ScheduledDate = date,
            CreatedAt = date,
            IsCompleted = isCompleted,
        };
        _fx.Db.ScheduledWorkouts.Add(session);
        _fx.Db.SaveChanges();
        return session;
    }

    private ScheduledWorkoutExercise AddScheduledEntry(ScheduledWorkout session, WorkoutExercise exercise)
    {
        var entry = new ScheduledWorkoutExercise
        {
            Id = Guid.NewGuid(),
            ScheduledWorkoutId = session.Id,
            WorkoutExerciseId = exercise.Id,
        };
        _fx.Db.ScheduledWorkoutExercises.Add(entry);
        _fx.Db.SaveChanges();
        return entry;
    }

    private void LogSets(
        ScheduledWorkout session,
        WorkoutExercise exercise,
        int reps,
        double weight,
        int count)
    {
        var entry = AddScheduledEntry(session, exercise);
        entry.IsCompleted = true;
        for (var i = 1; i <= count; i++)
        {
            _fx.Db.WorkoutSets.Add(new WorkoutSet
            {
                Id = Guid.NewGuid(),
                ScheduledWorkoutExerciseId = entry.Id,
                SetNumber = i,
                Reps = reps,
                Weight = weight,
                WeightUnit = "kg",
                IsCompleted = true,
            });
        }
        _fx.Db.SaveChanges();
    }
}
