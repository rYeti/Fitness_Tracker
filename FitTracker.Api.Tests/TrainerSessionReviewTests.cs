using FitTracker.Api.DTOs;
using FitTracker.Api.Models;
using FitTracker.Api.Repositories;
using FitTracker.Api.Services;
using FitTracker.Api.Services.Interfaces;
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
    private readonly ScheduledWorkoutService _scheduling;
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
        _scheduling = new ScheduledWorkoutService(new ScheduledWorkoutRepository(_fx.Db));
        _console = new TrainerConsoleService(
            new ActiveRelationshipStub(_trainer.Id, _client.Id),
            null!,
            new WorkoutPlanService(new WorkoutPlanRepository(_fx.Db)),
            new ScheduledWorkoutService(new ScheduledWorkoutRepository(_fx.Db)),
            null!,
            null!,
            new ExerciseService(new ExerciseRepository(_fx.Db)),
            null!,
            _workouts);
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

        var created = await _scheduling.CreateScheduledWorkoutAsync(new ScheduledWorkoutRequestDto
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


    // ── Logged sets: the client rebuilds, the server must not accumulate ─────

    [Fact]
    public async Task PushingTheSameSetsTwiceLeavesOneRowPerSetNumber()
    {
        var workout = AddWorkout("Lower A");
        var exercise = AddWorkoutExercise(workout, sets: 2);
        var plan = AddPlan("Spring Block", isActive: true);
        var session = AddSession(workout, plan, DaysAgo(1), isCompleted: true);
        var entry = AddScheduledEntry(session, exercise);

        var batch = new List<WorkoutSetRequestDto>
        {
            new() { SetNumber = 1, Reps = 8, Weight = 100, WeightUnit = "kg", IsCompleted = true },
            new() { SetNumber = 2, Reps = 8, Weight = 100, WeightUnit = "kg", IsCompleted = true },
        };

        // Saving an exercise rebuilds every local set row and drops their server ids, so the
        // client posts the whole log as new on each save. Appending it meant the trainer saw
        // the same set two, three, four times while the client showed the right count.
        await _scheduling.AddSetsBatchAsync(entry.Id, _client.Id, batch);
        await _scheduling.AddSetsBatchAsync(entry.Id, _client.Id, batch);

        Assert.Equal(2, _fx.Db.WorkoutSets.Count(s => s.ScheduledWorkoutExerciseId == entry.Id));

        var only = Assert.Single(await LoadHistory());
        var logged = Assert.Single(only.Exercises);
        Assert.Equal(2, logged.Sets.Count);
        // Volume counted each set once, not twice.
        Assert.Equal(1600, only.TotalVolume);
    }

    [Fact]
    public async Task PushingFewerSetsRemovesTheOnesThatAreGone()
    {
        var workout = AddWorkout("Lower A");
        var exercise = AddWorkoutExercise(workout, sets: 3);
        var plan = AddPlan("Spring Block", isActive: true);
        var session = AddSession(workout, plan, DaysAgo(1), isCompleted: true);
        var entry = AddScheduledEntry(session, exercise);

        await _scheduling.AddSetsBatchAsync(entry.Id, _client.Id,
        [
            new() { SetNumber = 1, Reps = 8, Weight = 100, IsCompleted = true },
            new() { SetNumber = 2, Reps = 8, Weight = 100, IsCompleted = true },
            new() { SetNumber = 3, Reps = 8, Weight = 100, IsCompleted = true },
        ]);

        // The client dropped a set. The batch is the whole log, so the third must go.
        await _scheduling.AddSetsBatchAsync(entry.Id, _client.Id,
        [
            new() { SetNumber = 1, Reps = 8, Weight = 100, IsCompleted = true },
            new() { SetNumber = 2, Reps = 8, Weight = 100, IsCompleted = true },
        ]);

        var stored = _fx.Db.WorkoutSets.Where(s => s.ScheduledWorkoutExerciseId == entry.Id).ToList();
        Assert.Equal(2, stored.Count);
        Assert.DoesNotContain(stored, s => s.SetNumber == 3);
    }

    [Fact]
    public async Task RpeSurvivesTheRoundTrip()
    {
        var workout = AddWorkout("Lower A");
        var exercise = AddWorkoutExercise(workout, sets: 1);
        var plan = AddPlan("Spring Block", isActive: true);
        var session = AddSession(workout, plan, DaysAgo(1), isCompleted: true);
        var entry = AddScheduledEntry(session, exercise);

        await _scheduling.AddSetsBatchAsync(entry.Id, _client.Id,
        [
            new() { SetNumber = 1, Reps = 8, Weight = 100, Rpe = 9, IsCompleted = true },
        ]);

        // Rpe was on the request, on the entity and on the response, and was mapped in none
        // of them — so the trainer's RPE column read "—" for every set ever logged.
        var only = Assert.Single(await LoadHistory());
        var logged = Assert.Single(only.Exercises);
        Assert.Equal(9, Assert.Single(logged.Sets).Rpe);
        Assert.Equal(9, only.AvgRpe);
    }

    // ── Deleting a workout ──────────────────────────────────────────────────

    [Fact]
    public async Task DeletingAWorkoutNobodyLoggedRemovesItAndItsSessions()
    {
        var workout = AddWorkout("Test1");
        AddWorkoutExercise(workout, sets: 3);
        var plan = AddPlan("Spring Block", isActive: true);
        AddSession(workout, plan, DaysAgo(2));

        // ScheduledWorkouts holds a restricted foreign key to Workouts, so this used to fail
        // outright and the workout stayed in the trainer's tab row after the client deleted it.
        Assert.True(await _workouts.DeleteWorkoutAsync(workout.Id, _client.Id));

        Assert.Empty(_fx.Db.Workouts.Where(w => w.Id == workout.Id).ToList());
        Assert.Empty(_fx.Db.ScheduledWorkouts.Where(sw => sw.WorkoutId == workout.Id).ToList());
        Assert.Empty(await LoadHistory());
    }

    [Fact]
    public async Task DeletingAWorkoutWithLoggedHistoryRetiresItAndKeepsThatHistory()
    {
        var workout = AddWorkout("Test2");
        var exercise = AddWorkoutExercise(workout, sets: 3);
        var plan = AddPlan("Spring Block", isActive: true);
        var performed = AddSession(workout, plan, DaysAgo(9), isCompleted: true);
        LogSets(performed, exercise, reps: 8, weight: 100, count: 3);
        var neverDone = AddSession(workout, plan, DaysAgo(2));

        Assert.True(await _workouts.DeleteWorkoutAsync(workout.Id, _client.Id));

        var stored = Assert.Single(_fx.Db.Workouts.Where(w => w.Id == workout.Id).ToList());
        Assert.NotNull(stored.RemovedAt);
        // The date nobody trained on goes; the session actually performed stays, and keeps
        // the workout row precisely so it can still be named.
        Assert.Empty(_fx.Db.ScheduledWorkouts.Where(sw => sw.Id == neverDone.Id).ToList());

        var only = Assert.Single(await LoadHistory());
        Assert.Equal(performed.Id, only.ScheduledWorkoutId);
        Assert.Equal("Test2", only.WorkoutName);
    }

    [Fact]
    public async Task ARetiredWorkoutIsGoneFromTheClientsWorkoutsAndCannotBeScheduled()
    {
        var workout = AddWorkout("Test2");
        var exercise = AddWorkoutExercise(workout, sets: 3);
        var plan = AddPlan("Spring Block", isActive: true);
        LogSets(AddSession(workout, plan, DaysAgo(9), isCompleted: true), exercise,
            reps: 8, weight: 100, count: 3);

        await _workouts.DeleteWorkoutAsync(workout.Id, _client.Id);

        // Still returned by the workouts read, flagged, so logged sessions can resolve it —
        // but the client filters on RemovedAt and nothing new may be scheduled from it.
        var listed = await _workouts.GetUserWorkoutsAsync(_client.Id);
        Assert.NotNull(listed.Single(w => w.Id == workout.Id).RemovedAt);

        var created = await _scheduling.CreateScheduledWorkoutAsync(new ScheduledWorkoutRequestDto
        {
            WorkoutId = workout.Id,
            ScheduledDate = DateTime.UtcNow.Date,
        }, _client.Id);
        Assert.Null(created);
    }

    [Fact]
    public async Task ARetiredWorkoutsUnloggedSessionsAreNotReported()
    {
        var workout = AddWorkout("Test1");
        var plan = AddPlan("Spring Block", isActive: true);
        var stranded = AddSession(workout, plan, DaysAgo(2), isCompleted: true);
        workout.RemovedAt = DateTime.UtcNow;
        await _fx.Db.SaveChangesAsync();

        // Belt and braces for sessions already stranded by the delete that used to 500:
        // the workout is gone, nothing was logged, so there is nothing to report.
        Assert.DoesNotContain(await LoadHistory(), s => s.ScheduledWorkoutId == stranded.Id);
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

    /// <summary>Stands in for the relationship gate, which these tests are not about —
    /// it is covered by TrainerClientServiceTests.</summary>
    private sealed class ActiveRelationshipStub(Guid expectedTrainer, Guid expectedClient) : ITrainerClientService
    {
        public Task<bool> IsActiveTrainerOfAsync(Guid trainer, Guid client) =>
            Task.FromResult(trainer == expectedTrainer && client == expectedClient);

        public Task<List<TrainerClientResponseDto>> GetClientsAsync(Guid trainer)
        {
            var clients = new List<TrainerClientResponseDto>();
            if (trainer == expectedTrainer)
            {
                clients.Add(new TrainerClientResponseDto { ClientId = expectedClient });
            }
            return Task.FromResult(clients);
        }

        public Task<CreateInviteOutcome> CreateInviteAsync(Guid trainerId) => throw new NotSupportedException();
        public Task<AcceptInviteOutcome> AcceptInviteAsync(string inviteCode, Guid clientId) => throw new NotSupportedException();
        public Task<bool> RevokeInviteAsync(Guid inviteId, Guid trainerId) => throw new NotSupportedException();
        public Task<List<PendingInviteDto>> GetPendingInvitesAsync(Guid trainerId) => throw new NotSupportedException();
        public Task<TrainerClientStatusDto> GetStatusAsync(Guid userId) => throw new NotSupportedException();
        public Task<bool> RemoveRelationshipAsync(Guid relationshipId, Guid requestingUserId) => throw new NotSupportedException();
        public Task<TrainerClient?> GetActiveRelationshipAsync(Guid trainerId, Guid clientId) => throw new NotSupportedException();
    }
}
