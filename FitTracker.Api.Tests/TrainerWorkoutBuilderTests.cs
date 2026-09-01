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

    private Exercise AddExercise(Guid? userId, string name)
    {
        var exercise = new Exercise { Id = Guid.NewGuid(), UserId = userId, Name = name };
        _fx.Db.Exercise.Add(exercise);
        _fx.Db.SaveChanges();
        return exercise;
    }
}
