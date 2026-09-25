using FitTracker.Api.DTOs;
using FitTracker.Api.Filters;
using FitTracker.Api.Models;
using FitTracker.Api.Repositories;
using FitTracker.Api.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Abstractions;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace FitTracker.Api.Tests;

/// <summary>
/// What the changes feed stands on: every aggregate knows when it last changed, and every
/// delete leaves a record. See docs/sync-architecture.md, part three.
///
/// Nothing here can be checked by the compiler. A save that changes a set but not its
/// session compiles, returns 200 and stores the set; the only symptom is that the session
/// never appears in anyone's feed again, on a device nobody is watching. So every way a
/// row changes is pinned here: through the change tracker, through a bulk statement the
/// change tracker never sees, and through the database's own cascades.
/// </summary>
public class SyncChangeTrackingTests : IDisposable
{
    private static readonly DateTime LongAgo = new(2020, 1, 1, 0, 0, 0, DateTimeKind.Utc);

    private readonly DbFixture _fx = new();
    private readonly User _me;
    private readonly User _someoneElse;

    public SyncChangeTrackingTests()
    {
        _me = _fx.AddUser("Robin", "Hale");
        _someoneElse = _fx.AddUser("Kit", "Moreau");
    }

    public void Dispose() => _fx.Dispose();

    private WorkoutService Workouts => new(new WorkoutRepository(_fx.Db), new SyncTombstoneRepository(_fx.Db));
    private WorkoutPlanService Plans => new(new WorkoutPlanRepository(_fx.Db), new SyncTombstoneRepository(_fx.Db));
    private ScheduledWorkoutService Sessions => new(new ScheduledWorkoutRepository(_fx.Db), new SyncTombstoneRepository(_fx.Db));
    private MealService Meals => new(new MealRepository(_fx.Db), new SyncTombstoneRepository(_fx.Db));
    private MealTemplateService Templates => new(new MealTemplateRepository(_fx.Db), new SyncTombstoneRepository(_fx.Db));

    private DateTime UpdatedAt<T>(Guid id) where T : class, ISyncRoot => _fx.UpdatedAtOf<T>(id);

    private List<SyncTombstone> Tombstones() => _fx.Db.SyncTombstones.AsNoTracking().ToList();

    private static MealTemplateRequestDto Template(Guid? id, params string[] foods) => new()
    {
        Id = id,
        Name = "Overnight oats",
        Category = "Breakfast",
        Items = [.. foods.Select(f => new MealTemplateItemRequestDto
        {
            FoodId = Guid.NewGuid(), FoodName = f, Quantity = 50, Unit = "g", Calories = 180,
        })],
    };

    // ── A root knows when it last changed ────────────────────────────────────

    [Fact]
    public async Task ACreateStampsTheRoot()
    {
        var before = DateTime.UtcNow;

        var workout = await Workouts.CreateWorkoutAsync(new WorkoutRequestDto { Name = "Push Day" }, _me.Id);

        Assert.InRange(UpdatedAt<Workout>(workout.Id), before, DateTime.UtcNow);
    }

    [Fact]
    public async Task AnUpdateStampsTheRoot()
    {
        var workout = await Workouts.CreateWorkoutAsync(new WorkoutRequestDto { Name = "Push Day" }, _me.Id);
        var untouched = await Workouts.CreateWorkoutAsync(new WorkoutRequestDto { Name = "Pull Day" }, _me.Id);
        _fx.Backdate(LongAgo);
        var before = DateTime.UtcNow;

        await Workouts.UpdateWorkoutAsync(workout.Id, _me.Id, new WorkoutRequestDto { Name = "Push Day A" });

        Assert.True(UpdatedAt<Workout>(workout.Id) >= before);
        Assert.Equal(LongAgo, UpdatedAt<Workout>(untouched.Id));
    }

    [Fact]
    public async Task ARepeatedCreateThatAppliesAChangeStampsTheRoot()
    {
        // Part two: a create repeated under the same id applies what it carries, because it
        // is the device's latest word on the row. That makes it an update, and an update the
        // feed didn't see would never reach the device's other installs.
        var id = Guid.NewGuid();
        await Workouts.CreateWorkoutAsync(new WorkoutRequestDto { Id = id, Name = "Push Day" }, _me.Id);
        _fx.Backdate(LongAgo);

        await Workouts.CreateWorkoutAsync(new WorkoutRequestDto { Id = id, Name = "Push Day A" }, _me.Id);

        Assert.True(UpdatedAt<Workout>(id) > LongAgo);
    }

    // ── A child's change is its root's change ────────────────────────────────

    [Fact]
    public async Task ASetTemplateChangeBumpsItsWorkout()
    {
        var workout = await Workouts.CreateWorkoutAsync(new WorkoutRequestDto { Name = "Push Day" }, _me.Id);
        var other = await Workouts.CreateWorkoutAsync(new WorkoutRequestDto { Name = "Pull Day" }, _me.Id);
        var entry = await Workouts.AddExerciseToWorkoutAsync(workout.Id, _me.Id, new WorkoutExerciseRequestDto { ExerciseId = Guid.NewGuid() });
        var sets = await Workouts.AddSetTemplatesBatchAsync(entry!.Id, _me.Id,
            [new WorkoutSetTemplateRequestDto { Id = Guid.NewGuid(), SetNumber = 1, TargetReps = "8" }]);
        _fx.Backdate(LongAgo);

        await Workouts.UpdateSetTemplateAsync(sets![0].Id, _me.Id,
            new WorkoutSetTemplateRequestDto { SetNumber = 1, TargetReps = "10" });

        Assert.True(UpdatedAt<Workout>(workout.Id) > LongAgo);
        Assert.Equal(LongAgo, UpdatedAt<Workout>(other.Id));
    }

    [Fact]
    public async Task ALoggedSetBumpsItsSession()
    {
        var workout = _fx.AddWorkout(_me.Id);
        var entry = _fx.AddWorkoutExercise(workout.Id, Guid.NewGuid());
        var session = _fx.AddSession(workout.Id, new DateTime(2026, 3, 2, 0, 0, 0, DateTimeKind.Utc));
        var set = _fx.AddLoggedSet(session.Id, entry.Id, weight: 60);
        _fx.Backdate(LongAgo);

        await Sessions.UpdateSetAsync(set.Id, _me.Id, new WorkoutSetRequestDto { SetNumber = 1, Reps = 8, Weight = 62.5, IsCompleted = true });

        Assert.True(UpdatedAt<ScheduledWorkout>(session.Id) > LongAgo);
        Assert.Equal(LongAgo, UpdatedAt<Workout>(workout.Id));
    }

    [Fact]
    public async Task ASessionExercisesNoteBumpsItsSession()
    {
        // The trainee's note under one exercise of a session (docs/trainer-exercise-notes.md)
        // changes that entry and nothing else.
        var workout = _fx.AddWorkout(_me.Id);
        var entry = _fx.AddWorkoutExercise(workout.Id, Guid.NewGuid());
        var session = _fx.AddSession(workout.Id, new DateTime(2026, 3, 2, 0, 0, 0, DateTimeKind.Utc));
        var sessionEntry = _fx.AddLoggedSet(session.Id, entry.Id, weight: 60).ScheduledWorkoutExerciseId;
        _fx.Backdate(LongAgo);

        await Sessions.UpdateExerciseNotesAsync(sessionEntry, _me.Id, "Left knee felt off on set 3");

        Assert.True(UpdatedAt<ScheduledWorkout>(session.Id) > LongAgo);
    }

    [Fact]
    public async Task AMealFoodBumpsItsMeal()
    {
        var meal = _fx.AddMeal(_me.Id, new DateTime(2026, 3, 1, 23, 0, 0, DateTimeKind.Utc));
        _fx.Backdate(LongAgo);

        await Meals.AddFoodsToMealBatchAsync(meal.Id, _me.Id,
            [new MealFoodEntryRequestDto { Id = Guid.NewGuid(), FoodItemId = Guid.NewGuid() }]);

        Assert.True(UpdatedAt<Meal>(meal.Id) > LongAgo);
    }

    [Fact]
    public async Task AMealFoodMovedToAnotherMealBumpsBoth()
    {
        // The app's dedup folds move a twin meal's foods, ids and all, into the meal it
        // keeps; the upsert then moves the entry on the server. Both meals' lists changed.
        var lunch = _fx.AddMeal(_me.Id, new DateTime(2026, 3, 1, 23, 0, 0, DateTimeKind.Utc), "Lunch");
        var twin = _fx.AddMeal(_me.Id, new DateTime(2026, 3, 2, 23, 0, 0, DateTimeKind.Utc), "Lunch");
        var entry = _fx.AddFoodToMeal(twin.Id, Guid.NewGuid());
        _fx.Backdate(LongAgo);

        await Meals.AddFoodsToMealBatchAsync(lunch.Id, _me.Id,
            [new MealFoodEntryRequestDto { Id = entry.Id, FoodItemId = entry.FoodItemId }]);

        Assert.True(UpdatedAt<Meal>(lunch.Id) > LongAgo);
        Assert.True(UpdatedAt<Meal>(twin.Id) > LongAgo);
    }

    [Fact]
    public async Task APlanLinkBumpsItsPlan()
    {
        var plan = _fx.AddPlan(_me.Id, "Block 1", isActive: true);
        var workout = _fx.AddWorkout(_me.Id);
        _fx.Backdate(LongAgo);

        await Plans.ReplacePlanWorkoutsAsync(plan.Id, [workout.Id], _me.Id);

        Assert.True(UpdatedAt<WorkoutPlan>(plan.Id) > LongAgo);
    }

    [Fact]
    public async Task ATemplateItemBumpsItsTemplate()
    {
        // Only the items differ: the template's own fields are written back unchanged, so
        // the root is bumped by its children or not at all.
        var template = await Templates.CreateAsync(Template(Guid.NewGuid(), "Oats"), _me.Id);
        _fx.Backdate(LongAgo);

        var updated = await Templates.UpdateAsync(template.Id, _me.Id, Template(template.Id, "Oats", "Blueberries"));

        Assert.True(UpdatedAt<MealTemplate>(template.Id) > LongAgo);
        // The update used to throw here: the new items reached the context only through the
        // template's navigation, with their ids already set, so EF took them for stored rows
        // and saved each as an UPDATE that matched nothing. Every edit of a template with
        // items failed, and the app has pushed template edits since part one.
        Assert.Equal(["Blueberries", "Oats"], updated!.Items.Select(i => i.FoodName).Order());
        Assert.Equal(2, await _fx.Db.MealTemplateItems.AsNoTracking().CountAsync());
    }

    // ── What the change tracker never sees ───────────────────────────────────

    [Fact]
    public async Task AReplaceThatOnlyDeletesBumpsItsRoot()
    {
        // The Workout Builder clears an exercise's prescription with an empty replace. The
        // replace deletes in one statement, straight to the database, and inserts nothing:
        // a save with no tracked changes at all, for the interceptor to learn anything from.
        var workout = await Workouts.CreateWorkoutAsync(new WorkoutRequestDto { Name = "Push Day" }, _me.Id);
        var entry = await Workouts.AddExerciseToWorkoutAsync(workout.Id, _me.Id, new WorkoutExerciseRequestDto { ExerciseId = Guid.NewGuid() });
        await Workouts.ReplaceSetTemplatesAsync(entry!.Id, _me.Id,
            [new WorkoutSetTemplateRequestDto { Id = Guid.NewGuid(), SetNumber = 1, TargetReps = "8" }]);
        _fx.Backdate(LongAgo);

        await Workouts.ReplaceSetTemplatesAsync(entry.Id, _me.Id, []);

        Assert.Empty(await _fx.Db.WorkoutSetTemplates.AsNoTracking().ToListAsync());
        Assert.True(UpdatedAt<Workout>(workout.Id) > LongAgo);
    }

    [Fact]
    public async Task ARowAReplaceMovesBumpsTheRootItLeft()
    {
        // A replace deletes the caller's rows stored elsewhere under the ids it was sent —
        // the app moved them — so the session they left changed too, and only the bulk
        // delete knows it.
        var workout = _fx.AddWorkout(_me.Id);
        var entry = _fx.AddWorkoutExercise(workout.Id, Guid.NewGuid());
        var monday = _fx.AddSession(workout.Id, new DateTime(2026, 3, 2, 0, 0, 0, DateTimeKind.Utc));
        var tuesday = _fx.AddSession(workout.Id, new DateTime(2026, 3, 3, 0, 0, 0, DateTimeKind.Utc));
        var set = _fx.AddLoggedSet(monday.Id, entry.Id, weight: 60);
        var tuesdayEntry = _fx.AddLoggedSet(tuesday.Id, entry.Id, weight: 70).ScheduledWorkoutExerciseId;
        _fx.Backdate(LongAgo);

        await Sessions.AddSetsBatchAsync(tuesdayEntry, _me.Id,
            [new WorkoutSetRequestDto { Id = set.Id, SetNumber = 1, Weight = 60, IsCompleted = true }]);

        Assert.True(UpdatedAt<ScheduledWorkout>(monday.Id) > LongAgo);
        Assert.True(UpdatedAt<ScheduledWorkout>(tuesday.Id) > LongAgo);
    }

    [Fact]
    public async Task RemovingAnExerciseBumpsTheSessionsWhosePlaceholdersGoWithIt()
    {
        // Removing an exercise deletes the unlogged entries sessions hold for it, in one
        // statement — each of those sessions lost an exercise.
        var workout = _fx.AddWorkout(_me.Id);
        var entry = _fx.AddWorkoutExercise(workout.Id, Guid.NewGuid());
        var trained = _fx.AddSession(workout.Id, new DateTime(2026, 3, 2, 0, 0, 0, DateTimeKind.Utc));
        _fx.AddLoggedSet(trained.Id, entry.Id, weight: 60);
        var upcoming = _fx.AddSession(workout.Id, new DateTime(2026, 3, 9, 0, 0, 0, DateTimeKind.Utc));
        _fx.Db.ScheduledWorkoutExercises.Add(new ScheduledWorkoutExercise
        {
            Id = Guid.NewGuid(),
            ScheduledWorkoutId = upcoming.Id,
            WorkoutExerciseId = entry.Id,
        });
        _fx.Db.SaveChanges();
        _fx.Backdate(LongAgo);

        await Workouts.DeleteWorkoutExerciseAsync(entry.Id, _me.Id);

        Assert.True(UpdatedAt<ScheduledWorkout>(upcoming.Id) > LongAgo);
        Assert.True(UpdatedAt<Workout>(workout.Id) > LongAgo); // retired: it has history
    }

    [Fact]
    public async Task DeletingAPlanBumpsTheSessionsItDetaches()
    {
        // The database nulls each session's plan (ON DELETE SET NULL). EF never loaded them.
        var plan = _fx.AddPlan(_me.Id, "Block 1", isActive: true);
        var workout = _fx.AddWorkout(_me.Id);
        var session = _fx.AddSession(workout.Id, new DateTime(2026, 3, 2, 0, 0, 0, DateTimeKind.Utc), planId: plan.Id);
        _fx.Backdate(LongAgo);

        await Plans.DeletePlanAsync(plan.Id, _me.Id);

        Assert.Null((await _fx.Db.ScheduledWorkouts.AsNoTracking().SingleAsync()).WorkoutPlanId);
        Assert.True(UpdatedAt<ScheduledWorkout>(session.Id) > LongAgo);
    }

    [Fact]
    public async Task DeletingAWorkoutBumpsThePlansThatListedIt()
    {
        // The database deletes the plan's link to it (ON DELETE CASCADE). EF never loaded it.
        var plan = _fx.AddPlan(_me.Id, "Block 1", isActive: true);
        var workout = _fx.AddWorkout(_me.Id);
        await Plans.ReplacePlanWorkoutsAsync(plan.Id, [workout.Id], _me.Id);
        _fx.Backdate(LongAgo);

        await Workouts.DeleteWorkoutAsync(workout.Id, _me.Id);

        Assert.Empty(await _fx.Db.WorkoutPlanWorkouts.AsNoTracking().ToListAsync());
        Assert.True(UpdatedAt<WorkoutPlan>(plan.Id) > LongAgo);
    }

    // ── A write decided by a read asks again as it runs ──────────────────────
    //
    // Each of these plays a second request that commits between the call's reads and its
    // first write (InterleavedCommit). Code that decided what to delete or stamp from what
    // it read beforehand acts on a stale answer; code that asks in the write's own predicate
    // sees the other request's row.

    [Fact]
    public async Task DeletingAWorkoutKeepsASetLoggedAfterItsCheck()
    {
        // The phone logs a set in a placeholder session between the delete's "nothing
        // logged" read and its bulk delete. The cascade took the set with the session, and
        // the session's tombstone then told every device to delete it too.
        var workout = _fx.AddWorkout(_me.Id);
        var entry = _fx.AddWorkoutExercise(workout.Id, Guid.NewGuid());
        var placeholder = _fx.AddSession(workout.Id, new DateTime(2026, 3, 9, 0, 0, 0, DateTimeKind.Utc));
        var slot = AddSessionEntry(placeholder.Id, entry.Id);
        var set = SetLoggedElsewhere();
        await using var db = _fx.NewContext(new InterleavedCommit(MoveSet(set, slot)));

        var result = await new WorkoutService(new WorkoutRepository(db), new SyncTombstoneRepository(db))
            .DeleteWorkoutAsync(workout.Id, _me.Id);

        Assert.Equal(WorkoutDeleteResult.HasLoggedHistory, result);
        Assert.Equal(slot, (await _fx.Db.WorkoutSets.AsNoTracking().SingleAsync(s => s.Id == set.Id)).ScheduledWorkoutExerciseId);
        Assert.DoesNotContain(Tombstones(), t => t.EntityId == placeholder.Id);
    }

    [Fact]
    public async Task RemovingAnExerciseKeepsASetLoggedAfterItsCheck()
    {
        // The same race one level down: the placeholder entry gains a set, so the exercise
        // now has history and is retired rather than deleted.
        var workout = _fx.AddWorkout(_me.Id);
        var entry = _fx.AddWorkoutExercise(workout.Id, Guid.NewGuid());
        var upcoming = _fx.AddSession(workout.Id, new DateTime(2026, 3, 9, 0, 0, 0, DateTimeKind.Utc));
        var slot = AddSessionEntry(upcoming.Id, entry.Id);
        var set = SetLoggedElsewhere();
        await using var db = _fx.NewContext(new InterleavedCommit(MoveSet(set, slot)));

        Assert.True(await new WorkoutService(new WorkoutRepository(db), new SyncTombstoneRepository(db))
            .DeleteWorkoutExerciseAsync(entry.Id, _me.Id));

        Assert.Equal(slot, (await _fx.Db.WorkoutSets.AsNoTracking().SingleAsync(s => s.Id == set.Id)).ScheduledWorkoutExerciseId);
        Assert.NotNull((await _fx.Db.WorkoutExercises.AsNoTracking().SingleAsync(e => e.Id == entry.Id)).RemovedAt);
    }

    [Fact]
    public async Task DeletingAWorkoutBumpsAPlanThatListedItJustBefore()
    {
        var plan = _fx.AddPlan(_me.Id, "Block 1", isActive: true);
        var workout = _fx.AddWorkout(_me.Id);
        _fx.Backdate(LongAgo);
        await using var db = _fx.NewContext(new InterleavedCommit(
            $"INSERT INTO WorkoutPlanWorkouts (Id, PlanId, WorkoutId) " +
            $"VALUES ({InterleavedCommit.Sql(Guid.NewGuid())}, {InterleavedCommit.Sql(plan.Id)}, {InterleavedCommit.Sql(workout.Id)})"));

        await new WorkoutService(new WorkoutRepository(db), new SyncTombstoneRepository(db)).DeleteWorkoutAsync(workout.Id, _me.Id);

        Assert.Empty(await _fx.Db.WorkoutPlanWorkouts.AsNoTracking().ToListAsync());
        Assert.True(UpdatedAt<WorkoutPlan>(plan.Id) > LongAgo);
    }

    [Fact]
    public async Task DeletingAPlanBumpsASessionScheduledUnderItJustBefore()
    {
        var plan = _fx.AddPlan(_me.Id, "Block 1", isActive: true);
        var workout = _fx.AddWorkout(_me.Id);
        var session = _fx.AddSession(workout.Id, new DateTime(2026, 3, 2, 0, 0, 0, DateTimeKind.Utc));
        _fx.Backdate(LongAgo);
        await using var db = _fx.NewContext(new InterleavedCommit(
            $"UPDATE ScheduledWorkouts SET WorkoutPlanId = {InterleavedCommit.Sql(plan.Id)} WHERE Id = {InterleavedCommit.Sql(session.Id)}"));

        await new WorkoutPlanService(new WorkoutPlanRepository(db), new SyncTombstoneRepository(db)).DeletePlanAsync(plan.Id, _me.Id);

        Assert.Null((await _fx.Db.ScheduledWorkouts.AsNoTracking().SingleAsync()).WorkoutPlanId);
        Assert.True(UpdatedAt<ScheduledWorkout>(session.Id) > LongAgo);
    }

    [Fact]
    public async Task AReplaceBumpsTheRootOfARowMovedUnderASentIdJustBefore()
    {
        // The replace deletes the caller's rows stored under the ids it was sent. One
        // stored under a sent id after the replace looked for them is deleted with the rest,
        // and the session it left has to hear of it.
        var workout = _fx.AddWorkout(_me.Id);
        var entry = _fx.AddWorkoutExercise(workout.Id, Guid.NewGuid());
        var monday = _fx.AddSession(workout.Id, new DateTime(2026, 3, 2, 0, 0, 0, DateTimeKind.Utc));
        var tuesday = _fx.AddSession(workout.Id, new DateTime(2026, 3, 3, 0, 0, 0, DateTimeKind.Utc));
        var set = _fx.AddLoggedSet(monday.Id, entry.Id, weight: 60);
        var tuesdayEntry = AddSessionEntry(tuesday.Id, entry.Id);
        _fx.Backdate(LongAgo);
        var sent = Guid.NewGuid();
        await using var db = _fx.NewContext(new InterleavedCommit(
            $"UPDATE WorkoutSets SET Id = {InterleavedCommit.Sql(sent)} WHERE Id = {InterleavedCommit.Sql(set.Id)}"));

        await new ScheduledWorkoutService(new ScheduledWorkoutRepository(db), new SyncTombstoneRepository(db)).AddSetsBatchAsync(
            tuesdayEntry, _me.Id, [new WorkoutSetRequestDto { Id = sent, SetNumber = 1, Weight = 60, IsCompleted = true }]);

        Assert.True(UpdatedAt<ScheduledWorkout>(monday.Id) > LongAgo);
    }

    [Fact]
    public async Task DeletingAMealTombstonesAFoodMovedIntoItJustBefore()
    {
        // The meal's foods used to be listed before the save and the rest left to the
        // cascade: a food moved in after the listing went with the meal and no tombstone,
        // and a device still holding it could upsert it straight back.
        var meal = _fx.AddMeal(_me.Id, new DateTime(2026, 3, 1, 23, 0, 0, DateTimeKind.Utc), "breakfast");
        var lunch = _fx.AddMeal(_me.Id, new DateTime(2026, 3, 1, 23, 0, 0, DateTimeKind.Utc), "lunch");
        var oats = _fx.AddFoodToMeal(lunch.Id, Guid.NewGuid());
        await using var db = _fx.NewContext(new InterleavedCommit(
            $"UPDATE MealFoodEntries SET MealId = {InterleavedCommit.Sql(meal.Id)} WHERE Id = {InterleavedCommit.Sql(oats.Id)}"));

        Assert.True(await new MealService(new MealRepository(db), new SyncTombstoneRepository(db)).DeleteMealAsync(meal.Id, _me.Id));

        Assert.Empty(await _fx.Db.MealFoodEntries.AsNoTracking().ToListAsync());
        Assert.Contains(Tombstones(), t => (t.EntityType, t.EntityId) == (SyncEntityTypes.MealFood, oats.Id));
    }

    [Fact]
    public async Task AFoodMovedOutOfAMealInTheSaveThatDeletesItGetsNoTombstone()
    {
        // A tombstone for a food that survives would tell every device to delete a live row.
        var meal = _fx.AddMeal(_me.Id, new DateTime(2026, 3, 1, 23, 0, 0, DateTimeKind.Utc), "breakfast");
        var lunch = _fx.AddMeal(_me.Id, new DateTime(2026, 3, 1, 23, 0, 0, DateTimeKind.Utc), "lunch");
        var oats = _fx.AddFoodToMeal(meal.Id, Guid.NewGuid());
        _fx.Db.ChangeTracker.Clear();

        var moved = await _fx.Db.MealFoodEntries.SingleAsync(e => e.Id == oats.Id);
        moved.MealId = lunch.Id;
        _fx.Db.Meals.Remove(await _fx.Db.Meals.SingleAsync(m => m.Id == meal.Id));
        await _fx.Db.SaveChangesAsync();

        Assert.Equal(lunch.Id, (await _fx.Db.MealFoodEntries.AsNoTracking().SingleAsync()).MealId);
        Assert.DoesNotContain(Tombstones(), t => t.EntityId == oats.Id);
    }

    /// <summary>An unlogged entry for <paramref name="workoutExerciseId"/> in a session.</summary>
    private Guid AddSessionEntry(Guid sessionId, Guid workoutExerciseId)
    {
        var entry = new ScheduledWorkoutExercise { Id = Guid.NewGuid(), ScheduledWorkoutId = sessionId, WorkoutExerciseId = workoutExerciseId };
        _fx.Db.ScheduledWorkoutExercises.Add(entry);
        _fx.Db.SaveChanges();
        return entry.Id;
    }

    /// <summary>A set logged in a session of another of the caller's workouts.</summary>
    private WorkoutSet SetLoggedElsewhere()
    {
        var other = _fx.AddWorkout(_me.Id, "Pull Day");
        var session = _fx.AddSession(other.Id, new DateTime(2026, 3, 2, 0, 0, 0, DateTimeKind.Utc));
        return _fx.AddLoggedSet(session.Id, _fx.AddWorkoutExercise(other.Id, Guid.NewGuid()).Id, weight: 60);
    }

    private static string MoveSet(WorkoutSet set, Guid toEntry) =>
        $"UPDATE WorkoutSets SET ScheduledWorkoutExerciseId = {InterleavedCommit.Sql(toEntry)} WHERE Id = {InterleavedCommit.Sql(set.Id)}";

    // ── A root is written once per transaction ───────────────────────────────

    [Fact]
    public async Task ABatchOfFoodsWritesItsMealOnce()
    {
        // The batch saves once per entry. Each save used to load the meal, tracked, and
        // update it: a meal of n foods was written n times, row lock and all.
        var meal = _fx.AddMeal(_me.Id, new DateTime(2026, 3, 1, 23, 0, 0, DateTimeKind.Utc));
        _fx.Backdate(LongAgo);
        var log = new CommandLog();
        await using var db = _fx.NewContext(log);

        await new MealService(new MealRepository(db), new SyncTombstoneRepository(db)).AddFoodsToMealBatchAsync(meal.Id, _me.Id,
            [.. Enumerable.Range(0, 3).Select(_ => new MealFoodEntryRequestDto { Id = Guid.NewGuid(), FoodItemId = Guid.NewGuid() })]);

        Assert.Equal(3, await _fx.Db.MealFoodEntries.AsNoTracking().CountAsync());
        Assert.Equal(1, log.UpdatesOf("Meals"));
        Assert.True(UpdatedAt<Meal>(meal.Id) > LongAgo);
    }

    [Fact]
    public async Task AReplaceWritesItsSessionOnce()
    {
        // The replace stamps the session before its delete, and its insert's save used to
        // stamp it again.
        var workout = _fx.AddWorkout(_me.Id);
        var entry = _fx.AddWorkoutExercise(workout.Id, Guid.NewGuid());
        var session = _fx.AddSession(workout.Id, new DateTime(2026, 3, 2, 0, 0, 0, DateTimeKind.Utc));
        var logged = _fx.AddLoggedSet(session.Id, entry.Id, weight: 60).ScheduledWorkoutExerciseId;
        _fx.Backdate(LongAgo);
        var log = new CommandLog();
        await using var db = _fx.NewContext(log);

        await new ScheduledWorkoutService(new ScheduledWorkoutRepository(db), new SyncTombstoneRepository(db)).AddSetsBatchAsync(logged, _me.Id,
        [
            new WorkoutSetRequestDto { Id = Guid.NewGuid(), SetNumber = 1, Weight = 60, IsCompleted = true },
            new WorkoutSetRequestDto { Id = Guid.NewGuid(), SetNumber = 2, Weight = 60, IsCompleted = true },
        ]);

        Assert.Equal(1, log.UpdatesOf("ScheduledWorkouts"));
        Assert.True(UpdatedAt<ScheduledWorkout>(session.Id) > LongAgo);
    }

    // ── A trainer's write is the client's change ─────────────────────────────

    [Fact]
    public async Task ATrainersEditBumpsTheClientsWorkout()
    {
        _fx.AddRelationship(_someoneElse.Id, _me.Id, TrainerClientStatus.Active);
        var console = Console(trainer: _someoneElse);
        var squat = _fx.Db.Exercise.Add(new Exercise { Id = Guid.NewGuid(), Name = "Back Squat" }).Entity;
        _fx.Db.SaveChanges();
        var created = await console.CreateClientWorkoutAsync(_someoneElse.Id, _me.Id, new ClientWorkoutRequestDto
        {
            Name = "Leg Day",
            Exercises = [new ClientWorkoutExerciseRequestDto { ExerciseId = squat.Id, TargetReps = ["5"] }],
        });
        var workout = created.Workout!;
        _fx.Backdate(LongAgo);

        // Only the prescription changes: a replace of one exercise's set templates.
        await console.UpdateClientWorkoutAsync(_someoneElse.Id, _me.Id, workout.Id, new ClientWorkoutRequestDto
        {
            Name = "Leg Day",
            Exercises = [new ClientWorkoutExerciseRequestDto
            {
                Id = workout.Exercises.Single().Id,
                ExerciseId = squat.Id,
                TargetReps = ["5", "5", "5"],
            }],
        });

        Assert.True(UpdatedAt<Workout>(workout.Id) > LongAgo);
        Assert.Equal(_me.Id, (await _fx.Db.Workouts.AsNoTracking().SingleAsync(w => w.Id == workout.Id)).UserId);
    }

    [Fact]
    public async Task ATrainersDeleteWritesTheClientsTombstone()
    {
        _fx.AddRelationship(_someoneElse.Id, _me.Id, TrainerClientStatus.Active);
        var console = Console(trainer: _someoneElse);
        var created = await console.CreateClientWorkoutAsync(_someoneElse.Id, _me.Id, new ClientWorkoutRequestDto { Name = "Leg Day" });

        await console.DeleteClientWorkoutAsync(_someoneElse.Id, _me.Id, created.Workout!.Id);

        var tombstone = Assert.Single(Tombstones());
        Assert.Equal(_me.Id, tombstone.UserId);
        Assert.Equal(SyncEntityTypes.Workout, tombstone.EntityType);
        Assert.Equal(created.Workout.Id, tombstone.EntityId);
    }

    private TrainerConsoleService Console(User trainer) => new(
        new ActiveRelationshipStub(trainer.Id, _me.Id),
        null!,
        new WorkoutPlanService(new WorkoutPlanRepository(_fx.Db), new SyncTombstoneRepository(_fx.Db)),
        new ScheduledWorkoutService(new ScheduledWorkoutRepository(_fx.Db), new SyncTombstoneRepository(_fx.Db)),
        null!,
        null!,
        new ExerciseService(new ExerciseRepository(_fx.Db), new SyncTombstoneRepository(_fx.Db)),
        null!,
        new WorkoutService(new WorkoutRepository(_fx.Db), new SyncTombstoneRepository(_fx.Db)),
        null!);

    // ── A delete leaves a record ─────────────────────────────────────────────

    [Fact]
    public async Task DeletingEachRootWritesItsTombstone()
    {
        var exercises = new ExerciseService(new ExerciseRepository(_fx.Db), new SyncTombstoneRepository(_fx.Db));
        var foods = new FoodItemService(new FoodItemRepository(_fx.Db), new SyncTombstoneRepository(_fx.Db));
        var weights = new WeightTrackingService(new WeightTrackingRepository(_fx.Db), new SyncTombstoneRepository(_fx.Db));

        var exercise = await exercises.CreateExercise(new ExerciseRequestDto { Name = "Sissy Squat", IsCustom = true }, _me.Id);
        var workout = await Workouts.CreateWorkoutAsync(new WorkoutRequestDto { Name = "Push Day" }, _me.Id);
        var sessionWorkout = await Workouts.CreateWorkoutAsync(new WorkoutRequestDto { Name = "Pull Day" }, _me.Id);
        var plan = await Plans.CreatePlanAsync(new WorkoutPlanRequestDto { Name = "Block 1", StartDate = DateTime.UtcNow }, _me.Id);
        var session = await Sessions.CreateScheduledWorkoutAsync(new ScheduledWorkoutRequestDto
        {
            WorkoutId = sessionWorkout.Id, ScheduledDate = new DateTime(2026, 3, 2, 0, 0, 0, DateTimeKind.Utc),
        }, _me.Id);
        var food = await foods.CreateFoodItemAsync(new FoodItemRequestDto { Name = "Skyr", Calories = 63 }, _me.Id);
        var meal = await Meals.CreateMealAsync(new MealRequestDto
        {
            Date = new DateTime(2026, 3, 1, 23, 0, 0, DateTimeKind.Utc), Category = "Breakfast", FoodItemId = food.Id,
        }, _me.Id);
        var template = await Templates.CreateAsync(Template(null, "Oats"), _me.Id);
        var weight = await weights.LogWeightAsync(new WeightTrackingRequestDto { Date = DateTime.UtcNow, Weight = 81.4 }, _me.Id);
        _fx.Db.ChangeTracker.Clear();

        Assert.True(await exercises.DeleteExercise(exercise.id, _me.Id));
        Assert.Equal(WorkoutDeleteResult.Deleted, await Workouts.DeleteWorkoutAsync(workout.Id, _me.Id));
        Assert.Equal(PlanDeleteResult.Deleted, await Plans.DeletePlanAsync(plan.Id, _me.Id));
        Assert.True(await Sessions.DeleteScheduledWorkoutAsync(session!.Id, _me.Id));
        Assert.True(await foods.DeleteFoodItemAsync(food.Id, _me.Id));
        Assert.True(await Meals.DeleteMealAsync(meal.Id, _me.Id));
        Assert.True(await Templates.DeleteAsync(template.Id, _me.Id));
        Assert.True(await weights.DeleteWeightAsync(weight.Id, _me.Id));

        var written = Tombstones();
        Assert.All(written, t => Assert.Equal(_me.Id, t.UserId));
        Assert.Equal(
            new[]
            {
                (SyncEntityTypes.Exercise, exercise.id),
                (SyncEntityTypes.Workout, workout.Id),
                (SyncEntityTypes.WorkoutPlan, plan.Id),
                (SyncEntityTypes.ScheduledWorkout, session.Id),
                (SyncEntityTypes.FoodItem, food.Id),
                (SyncEntityTypes.Meal, meal.Id),
                (SyncEntityTypes.MealTemplate, template.Id),
                (SyncEntityTypes.Weight, weight.Id),
            }.OrderBy(t => t.Item2),
            written.Select(t => (t.EntityType, t.EntityId)).OrderBy(t => t.EntityId));
    }

    [Fact]
    public async Task RemovingAFoodFromAMealWritesATombstoneForTheEntry()
    {
        var meal = _fx.AddMeal(_me.Id, new DateTime(2026, 3, 1, 23, 0, 0, DateTimeKind.Utc));
        var entry = _fx.AddFoodToMeal(meal.Id, Guid.NewGuid());
        _fx.Backdate(LongAgo);

        Assert.True(await Meals.RemoveFoodFromMealAsync(meal.Id, _me.Id, entry.Id));

        var tombstone = Assert.Single(Tombstones());
        Assert.Equal((SyncEntityTypes.MealFood, entry.Id, _me.Id), (tombstone.EntityType, tombstone.EntityId, tombstone.UserId));
        Assert.True(UpdatedAt<Meal>(meal.Id) > LongAgo);
    }

    [Fact]
    public async Task DeletingAMealWritesTombstonesForItsFoods()
    {
        // The database deletes a meal's foods with it. Their ids are ones a device that
        // hasn't pulled can still upsert into another meal, so each gets a record.
        var meal = _fx.AddMeal(_me.Id, new DateTime(2026, 3, 1, 23, 0, 0, DateTimeKind.Utc));
        var oats = _fx.AddFoodToMeal(meal.Id, Guid.NewGuid());
        var milk = _fx.AddFoodToMeal(meal.Id, Guid.NewGuid());
        _fx.Db.ChangeTracker.Clear();

        await Meals.DeleteMealAsync(meal.Id, _me.Id);

        Assert.Equal(
            new[] { (SyncEntityTypes.Meal, meal.Id), (SyncEntityTypes.MealFood, oats.Id), (SyncEntityTypes.MealFood, milk.Id) }
                .OrderBy(t => t.Item2),
            Tombstones().Select(t => (t.EntityType, t.EntityId)).OrderBy(t => t.EntityId));
    }

    [Fact]
    public async Task DeletingAWorkoutWritesTombstonesForThePlaceholderSessionsItRemoves()
    {
        // The unlogged sessions go in one bulk statement, before the workout itself.
        var workout = _fx.AddWorkout(_me.Id);
        var monday = _fx.AddSession(workout.Id, new DateTime(2026, 3, 2, 0, 0, 0, DateTimeKind.Utc));
        var tuesday = _fx.AddSession(workout.Id, new DateTime(2026, 3, 3, 0, 0, 0, DateTimeKind.Utc));
        _fx.Db.ChangeTracker.Clear();

        Assert.Equal(WorkoutDeleteResult.Deleted, await Workouts.DeleteWorkoutAsync(workout.Id, _me.Id));

        Assert.Equal(
            new[]
            {
                (SyncEntityTypes.Workout, workout.Id),
                (SyncEntityTypes.ScheduledWorkout, monday.Id),
                (SyncEntityTypes.ScheduledWorkout, tuesday.Id),
            }.OrderBy(t => t.Item2),
            Tombstones().Select(t => (t.EntityType, t.EntityId)).OrderBy(t => t.EntityId));
    }

    [Fact]
    public async Task DeletingAnAccountLeavesNoTombstonesBehind()
    {
        // Everything of the account's goes, its tombstones included: there is no device
        // left to tell. The sessions are removed through the change tracker in the same save
        // as the account, so this is also the one save that deletes synced rows and the
        // user a tombstone would point at, together — it must still succeed.
        var workout = _fx.AddWorkout(_me.Id);
        _fx.AddSession(workout.Id, new DateTime(2026, 3, 2, 0, 0, 0, DateTimeKind.Utc));
        _fx.Db.ChangeTracker.Clear();

        await new UserRepository(_fx.Db).DeleteUserAsync(_me.Id);

        Assert.Empty(Tombstones());
        Assert.Empty(await _fx.Db.ScheduledWorkouts.AsNoTracking().ToListAsync());
    }

    // ── A deleted id can't come back ─────────────────────────────────────────

    [Fact]
    public async Task ACreateOfAnIdTheCallerDeletedIsGone()
    {
        // A device that hasn't pulled the delete still holds the workout, and a create is
        // how it sends a row it thinks the server may not have. Inserting it would undo the
        // delete on every device.
        var id = Guid.NewGuid();
        await Workouts.CreateWorkoutAsync(new WorkoutRequestDto { Id = id, Name = "Push Day" }, _me.Id);
        await Workouts.DeleteWorkoutAsync(id, _me.Id);

        var gone = await Assert.ThrowsAsync<ClientIdGoneException>(
            () => Workouts.CreateWorkoutAsync(new WorkoutRequestDto { Id = id, Name = "Push Day" }, _me.Id));

        Assert.Equal(id, gone.Id);
        Assert.Empty(await _fx.Db.Workouts.AsNoTracking().ToListAsync());
    }

    [Fact]
    public async Task ADeletedMealIsGoneEvenWhenItsDayHasAnotherMeal()
    {
        // The content check (one meal per day and category) would otherwise answer the
        // stale create with the day's other meal, and the stale device would then move the
        // deleted meal's foods into it. The id is checked first.
        var day = new DateTime(2026, 3, 1, 23, 0, 0, DateTimeKind.Utc);
        var deleted = await Meals.CreateMealAsync(new MealRequestDto { Id = Guid.NewGuid(), Date = day, Category = "Lunch" }, _me.Id);
        await Meals.DeleteMealAsync(deleted.Id, _me.Id);
        await Meals.CreateMealAsync(new MealRequestDto { Id = Guid.NewGuid(), Date = day, Category = "Lunch" }, _me.Id);

        await Assert.ThrowsAsync<ClientIdGoneException>(
            () => Meals.CreateMealAsync(new MealRequestDto { Id = deleted.Id, Date = day, Category = "Lunch" }, _me.Id));
    }

    [Fact]
    public async Task AFoodRemovedFromAMealCannotBeUpsertedBack()
    {
        // docs/sync-architecture.md §18's window: device A removes the oats; device B, which
        // hasn't pulled, edits the meal and upserts every food it holds — the oats included.
        var meal = _fx.AddMeal(_me.Id, new DateTime(2026, 3, 1, 23, 0, 0, DateTimeKind.Utc));
        var oats = _fx.AddFoodToMeal(meal.Id, Guid.NewGuid());
        await Meals.RemoveFoodFromMealAsync(meal.Id, _me.Id, oats.Id);

        var gone = await Assert.ThrowsAsync<ClientIdGoneException>(() => Meals.AddFoodsToMealBatchAsync(meal.Id, _me.Id,
            [new MealFoodEntryRequestDto { Id = oats.Id, FoodItemId = oats.FoodItemId }]));

        Assert.Equal(oats.Id, gone.Id);
        Assert.Empty(await _fx.Db.MealFoodEntries.AsNoTracking().ToListAsync());
    }

    [Fact]
    public async Task ABatchCarryingDeletedIdsIsRefusedWholeAndNamesEveryOne()
    {
        // Refused at the first gone id, the batch used to have applied the entries before
        // it, and named only that one: a meal holding n foods removed elsewhere took n
        // rounds to converge, with other devices pulling a half-applied meal in between.
        var meal = _fx.AddMeal(_me.Id, new DateTime(2026, 3, 1, 23, 0, 0, DateTimeKind.Utc));
        var oats = _fx.AddFoodToMeal(meal.Id, Guid.NewGuid());
        var milk = _fx.AddFoodToMeal(meal.Id, Guid.NewGuid());
        await Meals.RemoveFoodFromMealAsync(meal.Id, _me.Id, oats.Id);
        await Meals.RemoveFoodFromMealAsync(meal.Id, _me.Id, milk.Id);
        _fx.Backdate(LongAgo);

        var gone = await Assert.ThrowsAsync<ClientIdGoneException>(() => Meals.AddFoodsToMealBatchAsync(meal.Id, _me.Id,
        [
            new MealFoodEntryRequestDto { Id = Guid.NewGuid(), FoodItemId = Guid.NewGuid() },
            new MealFoodEntryRequestDto { Id = oats.Id, FoodItemId = oats.FoodItemId },
            new MealFoodEntryRequestDto { Id = milk.Id, FoodItemId = milk.FoodItemId },
        ]));

        Assert.Equal([oats.Id, milk.Id], gone.Ids);
        Assert.Equal(oats.Id, gone.Id);
        Assert.Empty(await _fx.Db.MealFoodEntries.AsNoTracking().ToListAsync());
        Assert.Equal(LongAgo, UpdatedAt<Meal>(meal.Id));
    }

    [Fact]
    public async Task ABatchRefusedPartWayAppliesNothing()
    {
        // Any refusal, not only a 410: the entries before it are rolled back with it.
        var meal = _fx.AddMeal(_me.Id, new DateTime(2026, 3, 1, 23, 0, 0, DateTimeKind.Utc));
        var theirs = _fx.AddFoodToMeal(_fx.AddMeal(_someoneElse.Id, new DateTime(2026, 3, 1, 23, 0, 0, DateTimeKind.Utc)).Id, Guid.NewGuid());
        _fx.Backdate(LongAgo);

        await Assert.ThrowsAsync<ClientIdConflictException>(() => Meals.AddFoodsToMealBatchAsync(meal.Id, _me.Id,
        [
            new MealFoodEntryRequestDto { Id = Guid.NewGuid(), FoodItemId = Guid.NewGuid() },
            new MealFoodEntryRequestDto { Id = theirs.Id, FoodItemId = Guid.NewGuid() },
        ]));

        Assert.Equal(theirs.Id, (await _fx.Db.MealFoodEntries.AsNoTracking().SingleAsync()).Id);
        Assert.Equal(LongAgo, UpdatedAt<Meal>(meal.Id));
    }

    [Fact]
    public async Task SomeoneElsesDeleteDoesNotStopACreate()
    {
        // The refusal is about the caller's own history. Another account's tombstone says
        // nothing about this caller, and refusing on it would tell them it existed.
        var id = Guid.NewGuid();
        await Workouts.CreateWorkoutAsync(new WorkoutRequestDto { Id = id, Name = "Theirs" }, _someoneElse.Id);
        await Workouts.DeleteWorkoutAsync(id, _someoneElse.Id);

        var mine = await Workouts.CreateWorkoutAsync(new WorkoutRequestDto { Id = id, Name = "Mine" }, _me.Id);

        Assert.Equal(id, mine.Id);
    }

    [Fact]
    public void TheRefusalReachesTheAppAs410()
    {
        var id = Guid.NewGuid();
        var context = new ExceptionContext(
            new ActionContext(new DefaultHttpContext(), new RouteData(), new ActionDescriptor()),
            [])
        {
            Exception = new ClientIdGoneException(id),
        };

        new ClientIdGoneFilter().OnException(context);

        Assert.True(context.ExceptionHandled);
        var result = Assert.IsType<ObjectResult>(context.Result);
        Assert.Equal(StatusCodes.Status410Gone, result.StatusCode);
        Assert.Contains(id.ToString(), System.Text.Json.JsonSerializer.Serialize(result.Value));
    }

    [Fact]
    public void ABatchsRefusalNamesEveryIdAndKeepsTheFirstWhereOlderReadersLook()
    {
        var first = Guid.NewGuid();
        var second = Guid.NewGuid();
        var context = new ExceptionContext(
            new ActionContext(new DefaultHttpContext(), new RouteData(), new ActionDescriptor()),
            [])
        {
            Exception = new ClientIdGoneException([first, second]),
        };

        new ClientIdGoneFilter().OnException(context);

        var body = System.Text.Json.JsonDocument.Parse(
            System.Text.Json.JsonSerializer.Serialize(Assert.IsType<ObjectResult>(context.Result).Value)).RootElement;
        Assert.Equal("id_deleted", body.GetProperty("error").GetString());
        Assert.Equal(first, body.GetProperty("id").GetGuid());
        Assert.Equal([first, second], body.GetProperty("ids").EnumerateArray().Select(e => e.GetGuid()));
    }
}
