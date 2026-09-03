using FitTracker.Api.DTOs;
using FitTracker.Api.Models;
using FitTracker.Api.Repositories;
using FitTracker.Api.Services;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace FitTracker.Api.Tests;

/// <summary>
/// The Trainer Console's Workout Builder: a trainer creating and editing a client's
/// workouts — the one Trainer Console feature that used to stop at "create a plan" and go
/// no further, because there was no trainer-facing API for a client's exercises and sets.
///
/// The trap these pin isn't in the CRUD itself — every individual write here reuses an
/// already-correct, already-tested path (<see cref="WorkoutService"/>,
/// <see cref="WorkoutPlanService"/>). It's in what "prescribe an exercise" has to mean once
/// the exercise is the trainer's own: <see cref="ExerciseRepository.GetAllExercisesAsync"/>
/// only ever returns system exercises plus the caller's own, so a client's app can never
/// resolve a `WorkoutExercise` pointing at their trainer's private row. Nothing here is a
/// type error or a failing query — every reference would be a legitimately valid foreign
/// value, in a table where nothing enforces the foreign key at all (see
/// <see cref="Exercise.SourceExerciseId"/>'s remarks). The failure is silent and only shows
/// up on the client's phone, which is exactly what a green suite and a passing build have
/// nothing to say about.
/// </summary>
public class TrainerWorkoutBuilderTests : IDisposable
{
    private readonly DbFixture _fx = new();
    private readonly TrainerConsoleService _console;
    private readonly ExerciseService _exercises;
    private readonly User _trainer;
    private readonly User _client;

    public TrainerWorkoutBuilderTests()
    {
        _trainer = _fx.AddUser("Dana", "Whitfield");
        _client = _fx.AddUser("Marco", "Fenn");
        _fx.AddRelationship(_trainer.Id, _client.Id, TrainerClientStatus.Active);

        _exercises = new ExerciseService(new ExerciseRepository(_fx.Db));
        _console = new TrainerConsoleService(
            new ActiveRelationshipStub(_trainer.Id, _client.Id),
            null!,
            new WorkoutPlanService(new WorkoutPlanRepository(_fx.Db)),
            new ScheduledWorkoutService(new ScheduledWorkoutRepository(_fx.Db)),
            null!,
            null!,
            _exercises,
            null!,
            new WorkoutService(new WorkoutRepository(_fx.Db)));
    }

    public void Dispose() => _fx.Dispose();

    // ── The relationship gate ────────────────────────────────────────────────

    [Fact]
    public async Task NonTrainerGetsNothing()
    {
        var stranger = _fx.AddUser("Nobody", "Special");

        Assert.Null(await _console.GetClientWorkoutsAsync(stranger.Id, _client.Id));
        Assert.Null(await _console.GetClientExerciseLibraryAsync(stranger.Id, _client.Id));

        var result = await _console.CreateClientWorkoutAsync(stranger.Id, _client.Id, new ClientWorkoutRequestDto
        {
            Name = "Push Day",
        });
        Assert.Equal(TrainerWorkoutStatus.NotPermitted, result.Status);
    }

    // ── Deleting a plan ──────────────────────────────────────────────────────

    [Fact]
    public async Task NonTrainerCannotDeleteAPlan()
    {
        var plan = _fx.AddPlan(_client.Id, "Hypertrophy Block", isActive: true);
        var stranger = _fx.AddUser("Nobody", "Special");

        Assert.Equal(TrainerWorkoutStatus.NotPermitted,
            await _console.DeleteClientWorkoutPlanAsync(stranger.Id, _client.Id, plan.Id));
        Assert.NotNull(await _fx.Db.WorkoutPlans.AsNoTracking().SingleOrDefaultAsync(p => p.Id == plan.Id));
    }

    [Fact]
    public async Task DeletingAnotherClientsPlanIsNotFound()
    {
        var otherClient = _fx.AddUser("Priya", "Nair");
        _fx.AddRelationship(_trainer.Id, otherClient.Id, TrainerClientStatus.Active);
        var plan = _fx.AddPlan(otherClient.Id, "Someone Else's Plan", isActive: true);

        Assert.Equal(TrainerWorkoutStatus.NotFound,
            await _console.DeleteClientWorkoutPlanAsync(_trainer.Id, _client.Id, plan.Id));
    }

    [Fact]
    public async Task DeletingAPlanKeepsItsDaysAndLoggedHistory()
    {
        var squat = AddExercise(null, "Back Squat");
        var created = await _console.CreateClientWorkoutAsync(_trainer.Id, _client.Id, new ClientWorkoutRequestDto
        {
            Name = "Leg Day",
            Exercises = [new ClientWorkoutExerciseRequestDto { ExerciseId = squat.Id, TargetReps = ["5"] }],
        });
        var planResult = await _console.CreateClientWorkoutPlanAsync(_trainer.Id, _client.Id, new WorkoutPlanRequestDto
        {
            Name = "Leg Day Block",
            StartDate = DateTime.UtcNow.Date,
            IsFreeChoice = true,
        });
        await _fx.Db.WorkoutPlanWorkouts.AddAsync(new WorkoutPlanWorkout
        {
            Id = Guid.NewGuid(),
            PlanId = planResult!.Id,
            WorkoutId = created.Workout!.Id,
        });
        await _fx.Db.SaveChangesAsync();
        var entry = created.Workout.Exercises.Single();
        var session = _fx.AddSession(created.Workout.Id, DateTime.UtcNow.Date, planId: planResult.Id);
        _fx.AddLoggedSet(session.Id, entry.Id);

        var status = await _console.DeleteClientWorkoutPlanAsync(_trainer.Id, _client.Id, planResult.Id);

        Assert.Equal(TrainerWorkoutStatus.Ok, status);
        Assert.Null(await _fx.Db.WorkoutPlans.AsNoTracking().SingleOrDefaultAsync(p => p.Id == planResult.Id));

        // The plan is gone; the day it grouped, and the history logged against it, are not.
        var workouts = await _console.GetClientWorkoutsAsync(_trainer.Id, _client.Id);
        Assert.Contains(workouts!, w => w.Id == created.Workout.Id);
        Assert.NotEmpty(await _fx.Db.WorkoutSets.AsNoTracking()
            .Where(s => s.ScheduledWorkoutExercise.WorkoutExerciseId == entry.Id)
            .ToListAsync());

        // The link the deleted plan made no longer dangles.
        var reloadedSession = await _fx.Db.ScheduledWorkouts.AsNoTracking().SingleAsync(s => s.Id == session.Id);
        Assert.Null(reloadedSession.WorkoutPlanId);
    }

    // ── A client can't delete what their trainer assigned ───────────────────

    [Fact]
    public async Task AClientCannotDeleteAWorkoutTheirTrainerAssigned()
    {
        var squat = AddExercise(null, "Back Squat");
        var created = await _console.CreateClientWorkoutAsync(_trainer.Id, _client.Id, new ClientWorkoutRequestDto
        {
            Name = "Leg Day",
            Exercises = [new ClientWorkoutExerciseRequestDto { ExerciseId = squat.Id, TargetReps = ["5"] }],
        });
        var workoutService = new WorkoutService(new WorkoutRepository(_fx.Db));

        // The self-service path — no actingAsTrainer flag — is what the client's own app calls.
        var clientAttempt = await workoutService.DeleteWorkoutAsync(created.Workout!.Id, _client.Id);
        Assert.Equal(WorkoutDeleteResult.AssignedByTrainer, clientAttempt);
        Assert.NotNull(await _fx.Db.Workouts.AsNoTracking().SingleOrDefaultAsync(w => w.Id == created.Workout.Id));

        // The assigning trainer can still remove their own prescription.
        Assert.Equal(TrainerWorkoutStatus.Ok,
            await _console.DeleteClientWorkoutAsync(_trainer.Id, _client.Id, created.Workout.Id));
    }

    [Fact]
    public async Task AClientCannotDeleteAPlanTheirTrainerAssigned()
    {
        var planResult = await _console.CreateClientWorkoutPlanAsync(_trainer.Id, _client.Id, new WorkoutPlanRequestDto
        {
            Name = "Trainer's Block",
            StartDate = DateTime.UtcNow.Date,
            IsFreeChoice = true,
        });
        var planService = new WorkoutPlanService(new WorkoutPlanRepository(_fx.Db));

        Assert.Equal(PlanDeleteResult.AssignedByTrainer,
            await planService.DeletePlanAsync(planResult!.Id, _client.Id));

        Assert.Equal(TrainerWorkoutStatus.Ok,
            await _console.DeleteClientWorkoutPlanAsync(_trainer.Id, _client.Id, planResult.Id));
    }

    [Fact]
    public async Task AClientCanStillDeleteAWorkoutAndPlanTheyBuiltThemselves()
    {
        var workoutService = new WorkoutService(new WorkoutRepository(_fx.Db));
        var planService = new WorkoutPlanService(new WorkoutPlanRepository(_fx.Db));

        var ownWorkout = await workoutService.CreateWorkoutAsync(new WorkoutRequestDto { Name = "My Own Day" }, _client.Id);
        var ownPlan = await planService.CreatePlanAsync(new WorkoutPlanRequestDto
        {
            Name = "My Own Plan",
            StartDate = DateTime.UtcNow.Date,
            IsFreeChoice = true,
        }, _client.Id);

        Assert.Equal(WorkoutDeleteResult.Deleted, await workoutService.DeleteWorkoutAsync(ownWorkout.Id, _client.Id));
        Assert.Equal(PlanDeleteResult.Deleted, await planService.DeletePlanAsync(ownPlan.Id, _client.Id));
    }

    // ── Copy-on-prescribe ────────────────────────────────────────────────────

    [Fact]
    public async Task PrescribingATrainerOwnedExerciseGivesTheClientACopyOfIt()
    {
        var benchPress = AddExercise(_trainer.Id, "Cable Bench Press");

        var result = await _console.CreateClientWorkoutAsync(_trainer.Id, _client.Id, new ClientWorkoutRequestDto
        {
            Name = "Push Day",
            Exercises =
            [
                new ClientWorkoutExerciseRequestDto { ExerciseId = benchPress.Id, TargetReps = ["8-12", "8-12"] },
            ],
        });

        Assert.Equal(TrainerWorkoutStatus.Ok, result.Status);
        var prescribed = Assert.Single(result.Workout!.Exercises);

        // The workout doesn't reference the trainer's row at all — it references a copy.
        Assert.NotEqual(benchPress.Id, prescribed.ExerciseId);
        Assert.Equal("Cable Bench Press", prescribed.ExerciseName);
        Assert.Equal(2, prescribed.Sets.Count);

        var copy = await _fx.Db.Exercise.AsNoTracking().SingleAsync(e => e.Id == prescribed.ExerciseId);
        Assert.Equal(_client.Id, copy.UserId);
        Assert.Equal(benchPress.Id, copy.SourceExerciseId);

        // The client's own library now resolves it directly — no trainer-scoped lookup
        // needed, which is the whole point: this is what the client's sync pull reads.
        var clientLibrary = await _exercises.GetAllExercisesAsync(_client.Id);
        Assert.Contains(clientLibrary, e => e.id == prescribed.ExerciseId);
    }

    [Fact]
    public async Task PrescribingTheSameTrainerExerciseTwiceReusesOneCopy()
    {
        var romanianDeadlift = AddExercise(_trainer.Id, "Romanian Deadlift");

        await _console.CreateClientWorkoutAsync(_trainer.Id, _client.Id, new ClientWorkoutRequestDto
        {
            Name = "Pull Day",
            Exercises = [new ClientWorkoutExerciseRequestDto { ExerciseId = romanianDeadlift.Id, TargetReps = ["10"] }],
        });
        await _console.CreateClientWorkoutAsync(_trainer.Id, _client.Id, new ClientWorkoutRequestDto
        {
            Name = "Lower Day",
            Exercises = [new ClientWorkoutExerciseRequestDto { ExerciseId = romanianDeadlift.Id, TargetReps = ["10"] }],
        });

        var copies = await _fx.Db.Exercise.AsNoTracking()
            .Where(e => e.UserId == _client.Id && e.SourceExerciseId == romanianDeadlift.Id)
            .ToListAsync();
        Assert.Single(copies);
    }

    [Fact]
    public async Task AStrangersPrivateExerciseIsRejectedNotCopied()
    {
        var stranger = _fx.AddUser("Someone", "Else");
        var strangersExercise = AddExercise(stranger.Id, "Stranger's Curl");

        var result = await _console.CreateClientWorkoutAsync(_trainer.Id, _client.Id, new ClientWorkoutRequestDto
        {
            Name = "Arm Day",
            Exercises = [new ClientWorkoutExerciseRequestDto { ExerciseId = strangersExercise.Id, TargetReps = ["10"] }],
        });

        Assert.Equal(TrainerWorkoutStatus.UnknownExercise, result.Status);
        Assert.Equal([strangersExercise.Id], result.UnknownExerciseIds);

        // Nothing was created — a rejected prescription must not leave a half-built workout.
        Assert.Empty((await _console.GetClientWorkoutsAsync(_trainer.Id, _client.Id))!);
    }

    // ── Editing without disturbing logged history ───────────────────────────

    [Fact]
    public async Task KeepingAnEntrysIdOnUpdateKeepsItsLoggedSetsAttached()
    {
        var squat = AddExercise(null, "Back Squat"); // system exercise
        var created = await _console.CreateClientWorkoutAsync(_trainer.Id, _client.Id, new ClientWorkoutRequestDto
        {
            Name = "Leg Day",
            Exercises = [new ClientWorkoutExerciseRequestDto { ExerciseId = squat.Id, TargetReps = ["5", "5", "5"] }],
        });
        var entry = created.Workout!.Exercises.Single();

        // The client actually trains it, logging a set against this exact WorkoutExercise.
        var session = _fx.AddSession(created.Workout.Id, DateTime.UtcNow.Date);
        _fx.AddLoggedSet(session.Id, entry.Id, weight: 100);

        var updated = await _console.UpdateClientWorkoutAsync(_trainer.Id, _client.Id, created.Workout.Id, new ClientWorkoutRequestDto
        {
            Name = "Leg Day",
            Exercises =
            [
                new ClientWorkoutExerciseRequestDto
                {
                    Id = entry.Id,
                    ExerciseId = squat.Id,
                    TargetReps = ["3", "3", "3", "3"], // reps changed; identity kept
                },
            ],
        });

        Assert.Equal(TrainerWorkoutStatus.Ok, updated.Status);
        var stillThere = Assert.Single(updated.Workout!.Exercises);
        Assert.Equal(entry.Id, stillThere.Id); // same row, not a replacement
        Assert.Equal(4, stillThere.Sets.Count);

        var loggedSet = await _fx.Db.WorkoutSets.AsNoTracking()
            .SingleAsync(s => s.ScheduledWorkoutExercise.WorkoutExerciseId == entry.Id);
        Assert.Equal(100, loggedSet.Weight);
    }

    [Fact]
    public async Task SwappingAnEntrysExerciseRetiresTheOldRowInsteadOfDeletingIt()
    {
        var squat = AddExercise(null, "Back Squat");
        var frontSquat = AddExercise(null, "Front Squat");

        var created = await _console.CreateClientWorkoutAsync(_trainer.Id, _client.Id, new ClientWorkoutRequestDto
        {
            Name = "Leg Day",
            Exercises = [new ClientWorkoutExerciseRequestDto { ExerciseId = squat.Id, TargetReps = ["5"] }],
        });
        var originalEntry = created.Workout!.Exercises.Single();

        var session = _fx.AddSession(created.Workout.Id, DateTime.UtcNow.Date);
        _fx.AddLoggedSet(session.Id, originalEntry.Id);

        // Same entry id, different exercise — a substitution, not an edit.
        var updated = await _console.UpdateClientWorkoutAsync(_trainer.Id, _client.Id, created.Workout.Id, new ClientWorkoutRequestDto
        {
            Name = "Leg Day",
            Exercises =
            [
                new ClientWorkoutExerciseRequestDto { Id = originalEntry.Id, ExerciseId = frontSquat.Id, TargetReps = ["5"] },
            ],
        });

        Assert.Equal(TrainerWorkoutStatus.Ok, updated.Status);
        var current = Assert.Single(updated.Workout!.Exercises);
        Assert.NotEqual(originalEntry.Id, current.Id); // a new row, not the old one renamed
        Assert.Equal(frontSquat.Id, current.ExerciseId);

        // The old row still exists — retired, not gone — so the logged set still resolves.
        var oldRow = await _fx.Db.WorkoutExercises.AsNoTracking().SingleAsync(e => e.Id == originalEntry.Id);
        Assert.NotNull(oldRow.RemovedAt);
    }

    [Fact]
    public async Task ClearingAnExercisesSetsActuallyClearsThem()
    {
        var squat = AddExercise(null, "Back Squat");
        var created = await _console.CreateClientWorkoutAsync(_trainer.Id, _client.Id, new ClientWorkoutRequestDto
        {
            Name = "Leg Day",
            Exercises = [new ClientWorkoutExerciseRequestDto { ExerciseId = squat.Id, TargetReps = ["5", "5", "5"] }],
        });
        var entry = created.Workout!.Exercises.Single();

        var updated = await _console.UpdateClientWorkoutAsync(_trainer.Id, _client.Id, created.Workout.Id, new ClientWorkoutRequestDto
        {
            Name = "Leg Day",
            Exercises = [new ClientWorkoutExerciseRequestDto { Id = entry.Id, ExerciseId = squat.Id, TargetReps = [] }],
        });

        Assert.Empty(updated.Workout!.Exercises.Single().Sets);
        Assert.Empty(await _fx.Db.WorkoutSetTemplates.AsNoTracking()
            .Where(t => t.WorkoutExerciseId == entry.Id).ToListAsync());
    }

    // ── Scheduling ───────────────────────────────────────────────────────────

    [Fact]
    public async Task SchedulingTwiceDoesNotDoubleUpAlreadyScheduledDates()
    {
        var squat = AddExercise(null, "Back Squat");
        var created = await _console.CreateClientWorkoutAsync(_trainer.Id, _client.Id, new ClientWorkoutRequestDto
        {
            Name = "Full Body",
            Exercises = [new ClientWorkoutExerciseRequestDto { ExerciseId = squat.Id, TargetReps = ["5"] }],
        });
        var plan = _fx.AddPlan(_client.Id, "Block 1", isActive: true);

        var first = await _console.ScheduleClientPlanAsync(
            _trainer.Id, _client.Id, plan.Id, ["Full Body"], durationWeeks: 1);
        var second = await _console.ScheduleClientPlanAsync(
            _trainer.Id, _client.Id, plan.Id, ["Full Body"], durationWeeks: 1);

        Assert.Equal(7, first);
        Assert.Equal(0, second); // every date already had a session for this plan
        Assert.Equal(7, await _fx.Db.ScheduledWorkouts.CountAsync(s => s.WorkoutPlanId == plan.Id));
    }

    // ── Reading a client's workouts back ─────────────────────────────────────
    //
    // Everything below is about residue this table already holds. Duplicate
    // WorkoutExercise rows and stacked generations of WorkoutSetTemplates were
    // written by sync bugs fixed forward long ago (docs/trainer-session-review.md §2
    // and §4), and nothing will ever delete them: a training log is not something a
    // migration gets to tidy. Every other reader folds them — the sync client as it
    // pulls (`_collapseDuplicateServerExercises`), Session Review as it reports
    // (`CollapseDuplicateEntries`) — which is exactly why nobody saw them until the
    // Workout Builder read the same rows raw.

    [Fact]
    public async Task ADuplicateSlotIsShownOnce()
    {
        var squat = AddExercise(null, "Back Squat");
        var created = await _console.CreateClientWorkoutAsync(_trainer.Id, _client.Id, new ClientWorkoutRequestDto
        {
            Name = "Leg Day",
            Exercises = [new ClientWorkoutExerciseRequestDto { ExerciseId = squat.Id, TargetReps = ["5", "5"] }],
        });
        AddRawEntry(created.Workout!.Id, squat.Id, orderPosition: 0, sets: 2);

        var workouts = await _console.GetClientWorkoutsAsync(_trainer.Id, _client.Id);

        var only = Assert.Single(Assert.Single(workouts!).Exercises);
        Assert.Equal(2, only.Sets.Count);
    }

    [Fact]
    public async Task TheSurvivorOfADuplicateSlotIsTheRowTheClientLoggedAgainst()
    {
        var squat = AddExercise(null, "Back Squat");
        var created = await _console.CreateClientWorkoutAsync(_trainer.Id, _client.Id, new ClientWorkoutRequestDto
        {
            Name = "Leg Day",
            Exercises = [new ClientWorkoutExerciseRequestDto { ExerciseId = squat.Id, TargetReps = ["5", "5"] }],
        });
        var live = created.Workout!.Exercises.Single();
        // The twin carries its own, older prescription — three sets to the live row's two.
        AddRawEntry(created.Workout.Id, squat.Id, orderPosition: 0, sets: 3);

        var session = _fx.AddSession(created.Workout.Id, DateTime.UtcNow.Date);
        _fx.AddLoggedSet(session.Id, live.Id);

        var workouts = await _console.GetClientWorkoutsAsync(_trainer.Id, _client.Id);

        // Which row survives is not cosmetic: its id is what the builder sends back on
        // save, and every entry the payload omits is removed. Keeping the twin the
        // client's sessions point at is what stops a save retiring their own history.
        var only = Assert.Single(Assert.Single(workouts!).Exercises);
        Assert.Equal(live.Id, only.Id);
        Assert.Equal(2, only.Sets.Count);
    }

    [Fact]
    public async Task TheSameExerciseAtTwoPositionsIsARealSupersetNotADuplicate()
    {
        var squat = AddExercise(null, "Back Squat");
        var created = await _console.CreateClientWorkoutAsync(_trainer.Id, _client.Id, new ClientWorkoutRequestDto
        {
            Name = "Leg Day",
            Exercises =
            [
                new ClientWorkoutExerciseRequestDto { ExerciseId = squat.Id, TargetReps = ["5"] },
                new ClientWorkoutExerciseRequestDto { ExerciseId = squat.Id, TargetReps = ["12"] },
            ],
        });

        Assert.Equal(TrainerWorkoutStatus.Ok, created.Status);
        var workouts = await _console.GetClientWorkoutsAsync(_trainer.Id, _client.Id);

        // A movement paired with itself is a legitimate superset. Position is what tells
        // the two apart, which is why it is part of the fold's key and not just the
        // write path's.
        Assert.Equal(2, Assert.Single(workouts!).Exercises.Count);
    }

    [Fact]
    public async Task SeveralGenerationsOfAPrescriptionShowAsOneSetPerNumber()
    {
        var squat = AddExercise(null, "Back Squat");
        var created = await _console.CreateClientWorkoutAsync(_trainer.Id, _client.Id, new ClientWorkoutRequestDto
        {
            Name = "Leg Day",
            Exercises = [new ClientWorkoutExerciseRequestDto { ExerciseId = squat.Id, TargetReps = ["5", "5", "5"] }],
        });
        var entry = created.Workout!.Exercises.Single();
        // A second generation of the same three sets, the shape an append-instead-of-replace
        // batch post left behind before it was fixed.
        AddRawSetTemplates(entry.Id, count: 3);

        var workouts = await _console.GetClientWorkoutsAsync(_trainer.Id, _client.Id);

        var only = Assert.Single(Assert.Single(workouts!).Exercises);
        Assert.Equal(3, only.Sets.Count);
        Assert.Equal([1, 2, 3], only.Sets.Select(s => s.SetNumber));
    }

    [Fact]
    public async Task AnEntryWhoseExerciseNoLongerExistsIsHidden()
    {
        var squat = AddExercise(null, "Back Squat");
        var curl = AddExercise(_client.Id, "Preacher Curl");
        var created = await _console.CreateClientWorkoutAsync(_trainer.Id, _client.Id, new ClientWorkoutRequestDto
        {
            Name = "Leg Day",
            Exercises =
            [
                new ClientWorkoutExerciseRequestDto { ExerciseId = squat.Id, TargetReps = ["5"] },
                new ClientWorkoutExerciseRequestDto { ExerciseId = curl.Id, TargetReps = ["10"] },
            ],
        });
        Assert.Equal(TrainerWorkoutStatus.Ok, created.Status);

        // The client deletes their own custom exercise. WorkoutExercise.ExerciseId carries
        // no foreign key, so the entry survives as a reference to nothing — invisible on
        // the client's device (docs/sync-dangling-references.md) and, sent back on save,
        // enough to fail the whole day with unknown_exercise.
        _fx.Db.Exercise.Remove(_fx.Db.Exercise.Single(e => e.Id == curl.Id));
        _fx.Db.SaveChanges();

        var workouts = await _console.GetClientWorkoutsAsync(_trainer.Id, _client.Id);

        var only = Assert.Single(Assert.Single(workouts!).Exercises);
        Assert.Equal(squat.Id, only.ExerciseId);
    }

    [Fact]
    public async Task ARetiredEntryIsNotOfferedBackToTheTrainer()
    {
        var squat = AddExercise(null, "Back Squat");
        var created = await _console.CreateClientWorkoutAsync(_trainer.Id, _client.Id, new ClientWorkoutRequestDto
        {
            Name = "Leg Day",
            Exercises = [new ClientWorkoutExerciseRequestDto { ExerciseId = squat.Id, TargetReps = ["5"] }],
        });
        var entry = created.Workout!.Exercises.Single();

        var session = _fx.AddSession(created.Workout.Id, DateTime.UtcNow.Date);
        _fx.AddLoggedSet(session.Id, entry.Id);

        // Dropped from the prescription: retired rather than deleted, because the logged
        // set above still has to resolve through it.
        await _console.UpdateClientWorkoutAsync(_trainer.Id, _client.Id, created.Workout.Id, new ClientWorkoutRequestDto
        {
            Name = "Leg Day",
            Exercises = [],
        });

        Assert.NotNull((await _fx.Db.WorkoutExercises.AsNoTracking().SingleAsync(e => e.Id == entry.Id)).RemovedAt);
        Assert.Empty(Assert.Single((await _console.GetClientWorkoutsAsync(_trainer.Id, _client.Id))!).Exercises);
    }

    [Fact]
    public async Task SavingADayRemovesTheDuplicateTheFoldHid()
    {
        var squat = AddExercise(null, "Back Squat");
        var created = await _console.CreateClientWorkoutAsync(_trainer.Id, _client.Id, new ClientWorkoutRequestDto
        {
            Name = "Leg Day",
            Exercises = [new ClientWorkoutExerciseRequestDto { ExerciseId = squat.Id, TargetReps = ["5", "5"] }],
        });
        var live = created.Workout!.Exercises.Single();
        AddRawEntry(created.Workout.Id, squat.Id, orderPosition: 0, sets: 2);

        // The trainer edits the day they can see — one exercise — and saves. The diff
        // reads the *unfolded* rows, so the twin the fold hid is simply an entry the
        // payload does not account for, and the cleanup pass removes it. That is the
        // whole cleanup story for this data: no migration, no delete script.
        var updated = await _console.UpdateClientWorkoutAsync(_trainer.Id, _client.Id, created.Workout.Id, new ClientWorkoutRequestDto
        {
            Name = "Leg Day",
            Exercises = [new ClientWorkoutExerciseRequestDto { Id = live.Id, ExerciseId = squat.Id, TargetReps = ["5", "5"] }],
        });

        Assert.Equal(TrainerWorkoutStatus.Ok, updated.Status);
        var remaining = await _fx.Db.WorkoutExercises.AsNoTracking()
            .Where(e => e.WorkoutId == created.Workout.Id && e.RemovedAt == null)
            .ToListAsync();
        Assert.Equal([live.Id], remaining.Select(e => e.Id));
    }

    [Fact]
    public async Task ReadingAWorkoutCostsTheSameNumberOfQueriesHoweverManyExercisesItHas()
    {
        var squat = AddExercise(null, "Back Squat");
        var created = await _console.CreateClientWorkoutAsync(_trainer.Id, _client.Id, new ClientWorkoutRequestDto
        {
            Name = "Leg Day",
            Exercises = [new ClientWorkoutExerciseRequestDto { ExerciseId = squat.Id, TargetReps = ["5"] }],
        });

        _fx.Queries.Reset();
        await _console.GetClientWorkoutsAsync(_trainer.Id, _client.Id);
        var withOne = _fx.Queries.Count;

        for (var position = 1; position < 10; position++)
        {
            AddRawEntry(created.Workout!.Id, AddExercise(null, $"Accessory {position}").Id, position, sets: 3);
        }

        _fx.Queries.Reset();
        await _console.GetClientWorkoutsAsync(_trainer.Id, _client.Id);
        var withTen = _fx.Queries.Count;

        // The logged-history lookup the fold's survivor rule needs is one query for the
        // whole request, not one per exercise.
        Assert.Equal(withOne, withTen);
    }

    /// <summary>Writes a <see cref="WorkoutExercise"/> straight to the database, past the
    /// per-slot idempotency guard in <c>AddExerciseToWorkoutAsync</c> — the only way to
    /// reproduce the duplicate rows production already holds.</summary>
    private WorkoutExercise AddRawEntry(Guid workoutId, Guid exerciseId, int orderPosition, int sets)
    {
        var we = new WorkoutExercise
        {
            Id = Guid.NewGuid(),
            WorkoutId = workoutId,
            ExerciseId = exerciseId,
            OrderPosition = orderPosition,
        };
        _fx.Db.WorkoutExercises.Add(we);
        _fx.Db.SaveChanges();
        AddRawSetTemplates(we.Id, sets);
        return we;
    }

    private void AddRawSetTemplates(Guid workoutExerciseId, int count)
    {
        for (var setNumber = 1; setNumber <= count; setNumber++)
        {
            _fx.Db.WorkoutSetTemplates.Add(new WorkoutSetTemplate
            {
                Id = Guid.NewGuid(),
                WorkoutExerciseId = workoutExerciseId,
                SetNumber = setNumber,
                TargetReps = "8",
                OrderPosition = setNumber - 1,
            });
        }
        _fx.Db.SaveChanges();
    }

    private Exercise AddExercise(Guid? userId, string name)
    {
        var exercise = new Exercise { Id = Guid.NewGuid(), UserId = userId, Name = name };
        _fx.Db.Exercise.Add(exercise);
        _fx.Db.SaveChanges();
        return exercise;
    }
}
