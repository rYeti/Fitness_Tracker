using System.Security.Claims;
using System.Text.Json;
using FitTracker.Api.Controllers;
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
/// Creates that take the row's id from the app. See docs/sync-architecture.md, part two.
///
/// The app used to learn a new row's id only from the response to its POST. A response
/// lost on the way back left the row looking unsent, the retry wrote it a second time,
/// and the server — which had no way to tell a repeat from a new request — kept both.
/// Every test here would have failed against that: a repeated create made a second row,
/// a batch replace minted ids the app had never seen, and an id belonging to someone else
/// was either inserted beside theirs or, for sessions, answered with their row.
/// </summary>
public class ClientIdCreateTests : IDisposable
{
    private readonly DbFixture _fx = new();
    private readonly User _me;
    private readonly User _someoneElse;

    public ClientIdCreateTests()
    {
        _me = _fx.AddUser("Robin", "Hale");
        _someoneElse = _fx.AddUser("Kit", "Moreau");
    }

    public void Dispose() => _fx.Dispose();

    private WorkoutService Workouts => new(new WorkoutRepository(_fx.Db));
    private WorkoutPlanService Plans => new(new WorkoutPlanRepository(_fx.Db));
    private ScheduledWorkoutService Sessions => new(new ScheduledWorkoutRepository(_fx.Db));
    private MealService Meals => new(new MealRepository(_fx.Db));

    private static WorkoutRequestDto Workout(Guid? id, string name = "Push Day") =>
        new() { Id = id, Name = name, EstimatedDurationMinutes = 45, IsTemplate = true };

    private static T WithCaller<T>(T controller, Guid callerId) where T : ControllerBase
    {
        controller.ControllerContext = new ControllerContext
        {
            HttpContext = new DefaultHttpContext
            {
                User = new ClaimsPrincipal(new ClaimsIdentity(
                    [new Claim(ClaimTypes.NameIdentifier, callerId.ToString())],
                    authenticationType: "Test")),
            },
        };
        return controller;
    }

    // ── A repeated id ────────────────────────────────────────────────────────

    [Fact]
    public async Task ARepeatedWorkoutCreateReturnsTheSameRowAndStoresNoSecond()
    {
        var id = Guid.NewGuid();

        var first = await Workouts.CreateWorkoutAsync(Workout(id), _me.Id);
        var retry = await Workouts.CreateWorkoutAsync(Workout(id), _me.Id);

        Assert.Equal(id, first.Id);
        Assert.Equal(id, retry.Id);
        Assert.Single(await _fx.Db.Workouts.Where(w => w.UserId == _me.Id).ToListAsync());
    }

    [Fact]
    public async Task ARepeatCarriesTheEditMadeAfterTheFirstAttempt()
    {
        // The first POST landed but its response didn't; the user renamed the workout
        // before the retry went out. Answering the retry with the stored row unchanged
        // would let the app mark the rename sent when it never arrived.
        var id = Guid.NewGuid();
        await Workouts.CreateWorkoutAsync(Workout(id, "Push Day"), _me.Id);

        var retry = await Workouts.CreateWorkoutAsync(Workout(id, "Push Day A"), _me.Id);

        Assert.Equal("Push Day A", retry.Name);
        Assert.Equal("Push Day A", (await _fx.Db.Workouts.AsNoTracking().SingleAsync(w => w.Id == id)).Name);
    }

    [Fact]
    public async Task EveryCreateTheAppSendsIsIdempotentOnItsId()
    {
        var exercises = new ExerciseService(new ExerciseRepository(_fx.Db));
        var foods = new FoodItemService(new FoodItemRepository(_fx.Db));
        var templates = new MealTemplateService(new MealTemplateRepository(_fx.Db));
        var weights = new WeightTrackingService(new WeightTrackingRepository(_fx.Db));
        var workout = await Workouts.CreateWorkoutAsync(Workout(Guid.NewGuid()), _me.Id);

        async Task Twice<T>(Func<Task<T>> create, Func<T, Guid> idOf, Guid expected)
        {
            Assert.Equal(expected, idOf(await create()));
            Assert.Equal(expected, idOf(await create()));
        }

        var exerciseId = Guid.NewGuid();
        await Twice(() => exercises.CreateExercise(
            new ExerciseRequestDto { Id = exerciseId, Name = "Sissy Squat", IsCustom = true }, _me.Id), e => e.id, exerciseId);
        var weId = Guid.NewGuid();
        await Twice(async () => (await Workouts.AddExerciseToWorkoutAsync(workout.Id, _me.Id,
            new WorkoutExerciseRequestDto { Id = weId, ExerciseId = exerciseId }))!, e => e.Id, weId);
        var planId = Guid.NewGuid();
        await Twice(() => Plans.CreatePlanAsync(
            new WorkoutPlanRequestDto { Id = planId, Name = "Block 1", StartDate = DateTime.UtcNow }, _me.Id), p => p.Id, planId);
        var sessionId = Guid.NewGuid();
        await Twice(async () => (await Sessions.CreateScheduledWorkoutAsync(
            new ScheduledWorkoutRequestDto { Id = sessionId, WorkoutId = workout.Id, ScheduledDate = new DateTime(2026, 3, 2, 0, 0, 0, DateTimeKind.Utc) },
            _me.Id))!, s => s.Id, sessionId);
        var foodId = Guid.NewGuid();
        await Twice(() => foods.CreateFoodItemAsync(
            new FoodItemRequestDto { Id = foodId, Name = "Skyr", Calories = 63 }, _me.Id), f => f.Id, foodId);
        var mealId = Guid.NewGuid();
        await Twice(() => Meals.CreateMealAsync(
            new MealRequestDto { Id = mealId, Date = new DateTime(2026, 3, 1, 23, 0, 0, DateTimeKind.Utc), Category = "Breakfast", FoodItemId = foodId },
            _me.Id), m => m.Id, mealId);
        var templateId = Guid.NewGuid();
        await Twice(() => templates.CreateAsync(
            new MealTemplateRequestDto { Id = templateId, Name = "Overnight oats", Category = "Breakfast" }, _me.Id), t => t.Id, templateId);
        var weightId = Guid.NewGuid();
        await Twice(() => weights.LogWeightAsync(
            new WeightTrackingRequestDto { Id = weightId, Date = DateTime.UtcNow, Weight = 81.4 }, _me.Id), w => w.Id, weightId);

        Assert.Equal(1, await _fx.Db.Exercise.CountAsync(e => e.UserId == _me.Id));
        Assert.Equal(1, await _fx.Db.WorkoutExercises.CountAsync());
        Assert.Equal(1, await _fx.Db.WorkoutPlans.CountAsync());
        Assert.Equal(1, await _fx.Db.ScheduledWorkouts.CountAsync());
        Assert.Equal(1, await _fx.Db.FoodItems.CountAsync());
        Assert.Equal(1, await _fx.Db.Meals.CountAsync());
        Assert.Equal(1, await _fx.Db.MealTemplates.CountAsync());
        Assert.Equal(1, await _fx.Db.WeightTrackings.CountAsync());
    }

    [Fact]
    public async Task ACreateWithoutAnIdStillMintsOne()
    {
        // What every shipped app sends. The API deploys ahead of any app release.
        var first = await Workouts.CreateWorkoutAsync(Workout(null), _me.Id);
        var second = await Workouts.CreateWorkoutAsync(Workout(null), _me.Id);

        Assert.NotEqual(Guid.Empty, first.Id);
        Assert.NotEqual(first.Id, second.Id);
        Assert.Equal(2, await _fx.Db.Workouts.CountAsync());
    }

    [Fact]
    public async Task ARequestThatLosesTheRaceForItsIdAnswersWithTheWinnersRow()
    {
        // Two requests with the same new id both find it free; the second insert fails
        // on the primary key. It must resolve to the first request's row, not surface 500.
        var id = Guid.NewGuid();
        var lookups = 0;
        var result = await ClientIds.CreateOrResolveAsync<string>(
            id,
            _me.Id,
            _ => Task.FromResult<Guid?>(lookups++ == 0 ? null : _me.Id),
            _ => Task.FromResult<string?>("the stored row"),
            _ => throw new DbUpdateException("duplicate key"));

        Assert.Equal("the stored row", result);
    }

    // ── Someone else's id ────────────────────────────────────────────────────

    [Fact]
    public async Task AnIdBelongingToSomeoneElseIsRefused()
    {
        var theirs = await Workouts.CreateWorkoutAsync(Workout(Guid.NewGuid(), "Their Workout"), _someoneElse.Id);

        var refused = await Assert.ThrowsAsync<ClientIdConflictException>(
            () => Workouts.CreateWorkoutAsync(Workout(theirs.Id, "Mine"), _me.Id));

        Assert.Equal(theirs.Id, refused.Id);
        var stored = await _fx.Db.Workouts.AsNoTracking().SingleAsync();
        Assert.Equal("Their Workout", stored.Name);
        Assert.Equal(_someoneElse.Id, stored.UserId);
    }

    [Fact]
    public async Task ASessionIdBelongingToSomeoneElseIsRefusedRatherThanHandedBack()
    {
        // The create used to look the id up with no owner check at all. Harmless while
        // the server minted every id; once the app sends its own, it would have answered
        // anyone naming an id with that session, sets and all.
        var theirWorkout = _fx.AddWorkout(_someoneElse.Id);
        var theirSession = _fx.AddSession(theirWorkout.Id, new DateTime(2026, 3, 2, 0, 0, 0, DateTimeKind.Utc));
        var myWorkout = _fx.AddWorkout(_me.Id);

        await Assert.ThrowsAsync<ClientIdConflictException>(() => Sessions.CreateScheduledWorkoutAsync(
            new ScheduledWorkoutRequestDto { Id = theirSession.Id, WorkoutId = myWorkout.Id, ScheduledDate = DateTime.UtcNow },
            _me.Id));
    }

    [Fact]
    public async Task ASystemExerciseIdIsNobodysToCreate()
    {
        var system = new Exercise { Id = Guid.NewGuid(), Name = "Deadlift" };
        _fx.Db.Exercise.Add(system);
        await _fx.Db.SaveChangesAsync();

        await Assert.ThrowsAsync<ClientIdConflictException>(() =>
            new ExerciseService(new ExerciseRepository(_fx.Db)).CreateExercise(
                new ExerciseRequestDto { Id = system.Id, Name = "Mine", IsCustom = true }, _me.Id));
    }

    [Fact]
    public void TheConflictReachesTheAppAs409()
    {
        var context = new ExceptionContext(
            new ActionContext(new DefaultHttpContext(), new RouteData(), new ActionDescriptor()),
            [])
        {
            Exception = new ClientIdConflictException(Guid.NewGuid()),
        };

        new ClientIdConflictFilter().OnException(context);

        Assert.True(context.ExceptionHandled);
        Assert.IsType<ConflictObjectResult>(context.Result);
    }

    // ── Server content de-duplication still answers with its own row ────────

    [Fact]
    public async Task ANewIdForADayThatAlreadyHasTheMealIsAnsweredWithThatMeal()
    {
        // A second device, or this one after a reinstall, mints its own id for a meal the
        // server already holds. Ids can't see that; the day-and-category check can, and
        // its answer carries the stored meal's id, which the app then keeps.
        var day = new DateTime(2026, 3, 1, 23, 0, 0, DateTimeKind.Utc);
        var phone = await Meals.CreateMealAsync(new MealRequestDto { Id = Guid.NewGuid(), Date = day, Category = "Lunch" }, _me.Id);

        var tablet = await Meals.CreateMealAsync(new MealRequestDto { Id = Guid.NewGuid(), Date = day, Category = "Lunch" }, _me.Id);

        Assert.Equal(phone.Id, tablet.Id);
        Assert.Single(await _fx.Db.Meals.ToListAsync());
    }

    // ── Replaces keep the ids they are given ─────────────────────────────────

    [Fact]
    public async Task ReplacingALoggedSetsListKeepsTheIdsItWasGiven()
    {
        var workout = _fx.AddWorkout(_me.Id);
        var we = _fx.AddWorkoutExercise(workout.Id, Guid.NewGuid());
        var session = _fx.AddSession(workout.Id, DateTime.UtcNow);
        var entry = new ScheduledWorkoutExercise { Id = Guid.NewGuid(), ScheduledWorkoutId = session.Id, WorkoutExerciseId = we.Id };
        _fx.Db.ScheduledWorkoutExercises.Add(entry);
        await _fx.Db.SaveChangesAsync();
        var set1 = Guid.NewGuid();
        var set2 = Guid.NewGuid();

        var stored = await Sessions.AddSetsBatchAsync(entry.Id, _me.Id,
        [
            new WorkoutSetRequestDto { Id = set1, SetNumber = 1, Reps = 8, Weight = 100 },
            new WorkoutSetRequestDto { Id = set2, SetNumber = 2, Reps = 8, Weight = 100 },
        ]);
        var again = await Sessions.AddSetsBatchAsync(entry.Id, _me.Id,
        [
            new WorkoutSetRequestDto { Id = set1, SetNumber = 1, Reps = 8, Weight = 100 },
            new WorkoutSetRequestDto { Id = set2, SetNumber = 2, Reps = 7, Weight = 100 },
        ]);

        Assert.Equal([set1, set2], stored!.Select(s => s.Id));
        Assert.Equal([set1, set2], again!.Select(s => s.Id));
        var rows = await _fx.Db.WorkoutSets.AsNoTracking().OrderBy(s => s.SetNumber).ToListAsync();
        Assert.Equal([set1, set2], rows.Select(s => s.Id));
        Assert.Equal(7, rows[1].Reps);
    }

    [Fact]
    public async Task ReplacingAPrescriptionKeepsTheIdsItWasGiven()
    {
        var workout = _fx.AddWorkout(_me.Id);
        var we = _fx.AddWorkoutExercise(workout.Id, Guid.NewGuid());
        var t1 = Guid.NewGuid();
        var t2 = Guid.NewGuid();

        var stored = await Workouts.AddSetTemplatesBatchAsync(we.Id, _me.Id,
        [
            new WorkoutSetTemplateRequestDto { Id = t1, SetNumber = 1, TargetReps = "8-10" },
            new WorkoutSetTemplateRequestDto { Id = t2, SetNumber = 2, TargetReps = "8-10", OrderPosition = 1 },
        ]);

        Assert.Equal([t1, t2], stored!.Select(t => t.Id));
        Assert.Equal([t1, t2], (await _fx.Db.WorkoutSetTemplates.AsNoTracking().OrderBy(t => t.SetNumber).ToListAsync()).Select(t => t.Id));
    }

    [Fact]
    public async Task ASetTheAppMovedToAnotherExerciseIsMovedNotDuplicated()
    {
        // The app folds a twin session exercise's sets into the one it keeps, ids and all;
        // the replace for the survivor then names ids the server holds under the twin.
        var workout = _fx.AddWorkout(_me.Id);
        var we = _fx.AddWorkoutExercise(workout.Id, Guid.NewGuid());
        var session = _fx.AddSession(workout.Id, DateTime.UtcNow);
        var twin = new ScheduledWorkoutExercise { Id = Guid.NewGuid(), ScheduledWorkoutId = session.Id, WorkoutExerciseId = we.Id };
        var kept = new ScheduledWorkoutExercise { Id = Guid.NewGuid(), ScheduledWorkoutId = session.Id, WorkoutExerciseId = we.Id };
        _fx.Db.ScheduledWorkoutExercises.AddRange(twin, kept);
        await _fx.Db.SaveChangesAsync();
        var setId = Guid.NewGuid();
        await Sessions.AddSetsBatchAsync(twin.Id, _me.Id, [new WorkoutSetRequestDto { Id = setId, SetNumber = 1 }]);

        await Sessions.AddSetsBatchAsync(kept.Id, _me.Id, [new WorkoutSetRequestDto { Id = setId, SetNumber = 1 }]);

        var row = await _fx.Db.WorkoutSets.AsNoTracking().SingleAsync();
        Assert.Equal(kept.Id, row.ScheduledWorkoutExerciseId);
    }

    [Fact]
    public async Task AReplaceNamingSomeoneElsesSetIsRefusedAndChangesNothing()
    {
        var theirWorkout = _fx.AddWorkout(_someoneElse.Id);
        var theirSet = _fx.AddLoggedSet(_fx.AddSession(theirWorkout.Id, DateTime.UtcNow).Id,
            _fx.AddWorkoutExercise(theirWorkout.Id, Guid.NewGuid()).Id);
        var myWorkout = _fx.AddWorkout(_me.Id);
        var mySession = _fx.AddSession(myWorkout.Id, DateTime.UtcNow);
        var myEntry = new ScheduledWorkoutExercise
        {
            Id = Guid.NewGuid(),
            ScheduledWorkoutId = mySession.Id,
            WorkoutExerciseId = _fx.AddWorkoutExercise(myWorkout.Id, Guid.NewGuid()).Id,
        };
        _fx.Db.ScheduledWorkoutExercises.Add(myEntry);
        await _fx.Db.SaveChangesAsync();

        await Assert.ThrowsAsync<ClientIdConflictException>(() =>
            Sessions.AddSetsBatchAsync(myEntry.Id, _me.Id, [new WorkoutSetRequestDto { Id = theirSet.Id, SetNumber = 1 }]));

        var stored = await _fx.Db.WorkoutSets.AsNoTracking().SingleAsync();
        Assert.Equal(theirSet.ScheduledWorkoutExerciseId, stored.ScheduledWorkoutExerciseId);
    }

    // ── The full-list PUTs ──────────────────────────────────────────────────

    [Fact]
    public async Task PuttingAMealsFoodsReplacesTheListUnderTheGivenIds()
    {
        var meal = _fx.AddMeal(_me.Id, DateTime.UtcNow);
        _fx.AddFoodToMeal(meal.Id, Guid.NewGuid()); // removed on the device since
        var oats = Guid.NewGuid();
        var first = Guid.NewGuid();
        var second = Guid.NewGuid();
        var controller = WithCaller(new MealController(Meals), _me.Id);

        var result = await controller.ReplaceFoods(meal.Id,
        [
            new MealFoodEntryRequestDto { Id = first, FoodItemId = oats },
            // Two portions of one food are two entries, told apart by their ids.
            new MealFoodEntryRequestDto { Id = second, FoodItemId = oats },
        ]);

        var body = Assert.IsType<MealResponseDto>(Assert.IsType<OkObjectResult>(result).Value);
        Assert.Equal(new[] { first, second }.OrderBy(g => g), body.FoodEntries.Select(e => e.Id).OrderBy(g => g));
        Assert.Equal(new[] { first, second }.OrderBy(g => g),
            (await _fx.Db.MealFoodEntries.AsNoTracking().Select(e => e.Id).ToListAsync()).OrderBy(g => g));
    }

    [Fact]
    public async Task PuttingAnEmptyFoodListEmptiesTheMeal()
    {
        var meal = _fx.AddMeal(_me.Id, DateTime.UtcNow);
        _fx.AddFoodToMeal(meal.Id, Guid.NewGuid());

        await WithCaller(new MealController(Meals), _me.Id).ReplaceFoods(meal.Id, []);

        Assert.Empty(await _fx.Db.MealFoodEntries.ToListAsync());
    }

    [Fact]
    public async Task PuttingAPlansWorkoutsReplacesTheList()
    {
        var plan = _fx.AddPlan(_me.Id, "Block 1", isActive: true);
        var kept = _fx.AddWorkout(_me.Id, "Upper");
        var dropped = _fx.AddWorkout(_me.Id, "Lower");
        var added = _fx.AddWorkout(_me.Id, "Arms");
        await Plans.AddWorkoutToPlanAsync(plan.Id, kept.Id, _me.Id);
        await Plans.AddWorkoutToPlanAsync(plan.Id, dropped.Id, _me.Id);
        var controller = WithCaller(new WorkoutPlanController(Plans), _me.Id);

        // A workout id the server doesn't hold (not pushed yet, or deleted elsewhere) is
        // left out rather than failing the rest of the list.
        var result = await controller.ReplaceWorkouts(plan.Id, [kept.Id, added.Id, Guid.NewGuid()]);

        Assert.IsType<OkObjectResult>(result);
        var linked = await _fx.Db.WorkoutPlanWorkouts.AsNoTracking().Where(l => l.PlanId == plan.Id).Select(l => l.WorkoutId).ToListAsync();
        Assert.Equal(new[] { kept.Id, added.Id }.OrderBy(g => g), linked.OrderBy(g => g));

        await controller.ReplaceWorkouts(plan.Id, []);
        Assert.Empty(await _fx.Db.WorkoutPlanWorkouts.ToListAsync());
    }

    [Fact]
    public async Task TheOldPlanBatchNoLongerStoresALinkTwice()
    {
        var plan = _fx.AddPlan(_me.Id, "Block 1", isActive: true);
        var upper = _fx.AddWorkout(_me.Id, "Upper");

        await Plans.AddWorkoutsToPlanBatchAsync(plan.Id, [upper.Id], _me.Id);
        await Plans.AddWorkoutsToPlanBatchAsync(plan.Id, [upper.Id], _me.Id);

        Assert.Single(await _fx.Db.WorkoutPlanWorkouts.ToListAsync());
    }

    // ── A batch against someone else's parent ───────────────────────────────

    [Fact]
    public async Task BatchesAgainstSomeoneElsesParentAnswer404()
    {
        // They answered 200 with an empty list, which the app can't tell from "created
        // nothing" — so it said nothing and never tried again.
        var theirWorkout = _fx.AddWorkout(_someoneElse.Id);
        var theirWe = _fx.AddWorkoutExercise(theirWorkout.Id, Guid.NewGuid());
        var theirSession = _fx.AddSession(theirWorkout.Id, DateTime.UtcNow);
        var theirEntry = new ScheduledWorkoutExercise { Id = Guid.NewGuid(), ScheduledWorkoutId = theirSession.Id, WorkoutExerciseId = theirWe.Id };
        _fx.Db.ScheduledWorkoutExercises.Add(theirEntry);
        await _fx.Db.SaveChangesAsync();
        var theirMeal = _fx.AddMeal(_someoneElse.Id, DateTime.UtcNow);
        var theirPlan = _fx.AddPlan(_someoneElse.Id, "Theirs", isActive: true);

        var workouts = WithCaller(new WorkoutController(Workouts), _me.Id);
        var sessions = WithCaller(new ScheduledWorkoutController(Sessions), _me.Id);
        var meals = WithCaller(new MealController(Meals), _me.Id);
        var plans = WithCaller(new WorkoutPlanController(Plans), _me.Id);

        Assert.IsType<NotFoundObjectResult>(await workouts.AddExercisesBatch(theirWorkout.Id,
            [new WorkoutExerciseRequestDto { ExerciseId = Guid.NewGuid() }]));
        Assert.IsType<NotFoundObjectResult>(await workouts.AddSetTemplatesBatch(theirWe.Id,
            [new WorkoutSetTemplateRequestDto { SetNumber = 1, TargetReps = "5" }]));
        Assert.IsType<NotFoundObjectResult>(await sessions.AddSetsBatch(theirSession.Id, theirEntry.Id,
            [new WorkoutSetRequestDto { SetNumber = 1 }]));
        Assert.IsType<NotFoundResult>(await meals.AddFoodsBatch(theirMeal.Id, [Guid.NewGuid()]));
        Assert.IsType<NotFoundResult>(await meals.ReplaceFoods(theirMeal.Id, []));
        Assert.IsType<NotFoundObjectResult>(await plans.AddWorkoutsBatch(theirPlan.Id, [theirWorkout.Id]));
        Assert.IsType<NotFoundObjectResult>(await plans.ReplaceWorkouts(theirPlan.Id, []));

        Assert.Empty(await _fx.Db.MealFoodEntries.ToListAsync());
        Assert.Empty(await _fx.Db.WorkoutPlanWorkouts.ToListAsync());
        Assert.Single(await _fx.Db.WorkoutExercises.ToListAsync());
    }

    // ── The session-exercise batch ──────────────────────────────────────────

    [Fact]
    public void TheSessionExerciseBatchReadsBothShapesTheAppsSend()
    {
        var weId = Guid.NewGuid();
        var entryId = Guid.NewGuid();
        var options = new JsonSerializerOptions(JsonSerializerDefaults.Web);

        var old = JsonSerializer.Deserialize<List<ScheduledExerciseBatchItemDto>>($"[\"{weId}\"]", options)!;
        var current = JsonSerializer.Deserialize<List<ScheduledExerciseBatchItemDto>>(
            $"[{{\"id\":\"{entryId}\",\"workoutExerciseId\":\"{weId}\"}}]", options)!;

        Assert.Null(old.Single().Id);
        Assert.Equal(weId, old.Single().WorkoutExerciseId);
        Assert.Equal(entryId, current.Single().Id);
        Assert.Equal(weId, current.Single().WorkoutExerciseId);
    }

    [Fact]
    public async Task TheSessionExerciseBatchKeepsTheIdsItWasGiven()
    {
        var workout = _fx.AddWorkout(_me.Id);
        var session = _fx.AddSession(workout.Id, DateTime.UtcNow);
        var we = _fx.AddWorkoutExercise(workout.Id, Guid.NewGuid());
        var entryId = Guid.NewGuid();
        var batch = new List<ScheduledExerciseBatchItemDto> { new() { Id = entryId, WorkoutExerciseId = we.Id } };

        var first = await Sessions.CreateExercisesBatchAsync(session.Id, _me.Id, batch);
        var retry = await Sessions.CreateExercisesBatchAsync(session.Id, _me.Id, batch);

        Assert.Equal(entryId, first!.Single().Id);
        Assert.Equal(entryId, retry!.Single().Id);
    }

    [Fact]
    public async Task TheSessionExerciseBatchIgnoresWorkoutExercisesThatAreNotTheCallers()
    {
        var myWorkout = _fx.AddWorkout(_me.Id);
        var session = _fx.AddSession(myWorkout.Id, DateTime.UtcNow);
        var theirWe = _fx.AddWorkoutExercise(_fx.AddWorkout(_someoneElse.Id).Id, Guid.NewGuid());

        var result = await Sessions.CreateExercisesBatchAsync(session.Id, _me.Id,
            [new ScheduledExerciseBatchItemDto { WorkoutExerciseId = theirWe.Id }]);

        Assert.Empty(result!);
    }

    // ── Meal template edits ─────────────────────────────────────────────────

    [Fact]
    public async Task EditingAMealTemplateSavesItsTotalWeight()
    {
        var templates = new MealTemplateService(new MealTemplateRepository(_fx.Db));
        var created = await templates.CreateAsync(
            new MealTemplateRequestDto { Name = "Chili", Category = "Dinner", TotalWeightGrams = 1200 }, _me.Id);

        await templates.UpdateAsync(created.Id, _me.Id,
            new MealTemplateRequestDto { Name = "Chili", Category = "Dinner", TotalWeightGrams = 1500 });

        Assert.Equal(1500m, (await _fx.Db.MealTemplates.AsNoTracking().SingleAsync()).TotalWeightGrams);
    }
}
