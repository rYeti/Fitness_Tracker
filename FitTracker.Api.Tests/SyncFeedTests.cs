using System.Security.Claims;
using FitTracker.Api.Controllers;
using FitTracker.Api.DTOs;
using FitTracker.Api.Models;
using FitTracker.Api.Repositories;
using FitTracker.Api.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace FitTracker.Api.Tests;

/// <summary>
/// <c>GET api/Sync/changes</c>: the pull that downloads only what changed, and is told
/// about deletes rather than inferring them. See docs/sync-architecture.md, part three.
/// </summary>
public class SyncFeedTests : IDisposable
{
    private static readonly DateTime LongAgo = new(2020, 1, 1, 0, 0, 0, DateTimeKind.Utc);

    /// <summary>A cursor between everything <see cref="DbFixture.Backdate"/> touched and now.</summary>
    private static readonly DateTime Cursor = LongAgo.AddDays(1);

    private readonly DbFixture _fx = new();
    private readonly User _me;
    private readonly User _someoneElse;

    public SyncFeedTests()
    {
        _me = _fx.AddUser("Robin", "Hale");
        _someoneElse = _fx.AddUser("Kit", "Moreau");
    }

    public void Dispose() => _fx.Dispose();

    private WorkoutService Workouts => new(new WorkoutRepository(_fx.Db), new SyncTombstoneRepository(_fx.Db));
    private ScheduledWorkoutService Sessions => new(new ScheduledWorkoutRepository(_fx.Db), new SyncTombstoneRepository(_fx.Db));
    private MealService Meals => new(new MealRepository(_fx.Db), new SyncTombstoneRepository(_fx.Db));

    private SyncFeedService Feed => new(
        new ExerciseService(new ExerciseRepository(_fx.Db), new SyncTombstoneRepository(_fx.Db)),
        Workouts,
        new WorkoutPlanService(new WorkoutPlanRepository(_fx.Db), new SyncTombstoneRepository(_fx.Db)),
        Sessions,
        new FoodItemService(new FoodItemRepository(_fx.Db), new SyncTombstoneRepository(_fx.Db)),
        Meals,
        new MealTemplateService(new MealTemplateRepository(_fx.Db), new SyncTombstoneRepository(_fx.Db)),
        new WeightTrackingService(new WeightTrackingRepository(_fx.Db), new SyncTombstoneRepository(_fx.Db)),
        new UserSettingsService(new UserSettingsRepository(_fx.Db)),
        new SyncTombstoneRepository(_fx.Db));

    private Task<SyncChangesDto> ChangesAsync(User user, DateTime? since)
    {
        // Each call is a request of its own; nothing tracked by the last one should answer it.
        _fx.Db.ChangeTracker.Clear();
        return Feed.GetChangesAsync(user.Id, since);
    }

    /// <summary>One of everything, for <paramref name="user"/>.</summary>
    private async Task<(Guid Workout, Guid Session, Guid Meal)> SeedAsync(User user)
    {
        var exercise = new ExerciseService(new ExerciseRepository(_fx.Db), new SyncTombstoneRepository(_fx.Db));
        await exercise.CreateExercise(new ExerciseRequestDto { Name = "Sissy Squat", IsCustom = true }, user.Id);
        var workout = _fx.AddWorkout(user.Id);
        var entry = _fx.AddWorkoutExercise(workout.Id, Guid.NewGuid());
        _fx.AddPlan(user.Id, "Block 1", isActive: true);
        var session = _fx.AddSession(workout.Id, new DateTime(2026, 3, 2, 0, 0, 0, DateTimeKind.Utc));
        _fx.AddLoggedSet(session.Id, entry.Id, weight: 60);
        var food = _fx.AddFoodItem(user.Id);
        var meal = _fx.AddMeal(user.Id, new DateTime(2026, 3, 1, 23, 0, 0, DateTimeKind.Utc));
        _fx.AddFoodToMeal(meal.Id, food.Id);
        await new MealTemplateService(new MealTemplateRepository(_fx.Db), new SyncTombstoneRepository(_fx.Db))
            .CreateAsync(new MealTemplateRequestDto { Name = "Overnight oats", Category = "Breakfast" }, user.Id);
        await new WeightTrackingService(new WeightTrackingRepository(_fx.Db), new SyncTombstoneRepository(_fx.Db))
            .LogWeightAsync(new WeightTrackingRequestDto { Date = DateTime.UtcNow, Weight = 81.4 }, user.Id);
        await new UserSettingsService(new UserSettingsRepository(_fx.Db))
            .UpsertSettingsAsync(user.Id, new UserSettingsRequestDto { DailyCalorieGoal = 2400 });
        return (workout.Id, session.Id, meal.Id);
    }

    // ── Without a cursor ─────────────────────────────────────────────────────

    [Fact]
    public async Task WithoutACursorItReturnsEverythingTheCallerHasAndEveryDelete()
    {
        // No cursor is not the same as no data. An install upgrading to the feed holds
        // everything its old full pulls fetched and has never had a cursor, so its first
        // answer is the only one that can tell it about a delete made before it upgraded —
        // however long ago that was.
        await SeedAsync(_me);
        var gone = _fx.AddWorkout(_me.Id);
        await Workouts.DeleteWorkoutAsync(gone.Id, _me.Id);
        _fx.Backdate(LongAgo);

        var changes = await ChangesAsync(_me, since: null);

        Assert.Single(changes.Exercises);
        Assert.Single(changes.Workouts);
        Assert.Single(changes.WorkoutPlans);
        Assert.Single(changes.ScheduledWorkouts);
        Assert.Single(changes.FoodItems);
        Assert.Single(changes.Meals);
        Assert.Single(changes.MealTemplates);
        Assert.Single(changes.Weights);
        Assert.NotNull(changes.Settings);
        var deleted = Assert.Single(changes.Deleted);
        Assert.Equal((SyncEntityTypes.Workout, gone.Id), (deleted.EntityType, deleted.EntityId));
    }

    // ── With a cursor ────────────────────────────────────────────────────────

    [Fact]
    public async Task ItReturnsOnlyWhatChangedSinceTheCursor()
    {
        var (workout, session, meal) = await SeedAsync(_me);
        var unchanged = _fx.AddWorkout(_me.Id, "Pull Day");
        _fx.Backdate(LongAgo);

        await Workouts.UpdateWorkoutAsync(workout, _me.Id, new WorkoutRequestDto { Name = "Push Day A" });

        var changes = await ChangesAsync(_me, Cursor);

        Assert.Equal(workout, Assert.Single(changes.Workouts).Id);
        Assert.Empty(changes.Exercises);
        Assert.Empty(changes.WorkoutPlans);
        Assert.Empty(changes.ScheduledWorkouts);
        Assert.Empty(changes.FoodItems);
        Assert.Empty(changes.Meals);
        Assert.Empty(changes.MealTemplates);
        Assert.Empty(changes.Weights);
        Assert.Null(changes.Settings);
        Assert.DoesNotContain(changes.Workouts, w => w.Id == unchanged.Id);
    }

    [Fact]
    public async Task AChildsChangeShipsItsWholeAggregate()
    {
        // One set edited: the session goes out with every exercise and every set it has,
        // exactly as GET api/ScheduledWorkout lists it, so the device can replace its
        // children by id without asking for anything else.
        var workout = _fx.AddWorkout(_me.Id);
        var bench = _fx.AddWorkoutExercise(workout.Id, Guid.NewGuid(), 0);
        var row = _fx.AddWorkoutExercise(workout.Id, Guid.NewGuid(), 1);
        var session = _fx.AddSession(workout.Id, new DateTime(2026, 3, 2, 0, 0, 0, DateTimeKind.Utc));
        var edited = _fx.AddLoggedSet(session.Id, bench.Id, weight: 60);
        _fx.AddLoggedSet(session.Id, row.Id, weight: 50);
        _fx.Backdate(LongAgo);

        await Sessions.UpdateSetAsync(edited.Id, _me.Id, new WorkoutSetRequestDto { SetNumber = 1, Weight = 62.5, IsCompleted = true });

        var changes = await ChangesAsync(_me, Cursor);
        var shipped = Assert.Single(changes.ScheduledWorkouts);
        var listed = Assert.Single(await Sessions.GetUserScheduledWorkoutsAsync(_me.Id));
        Assert.Equal(2, shipped.Exercises.Count);
        Assert.Equal(2, shipped.Exercises.SelectMany(e => e.Sets).Count());
        Assert.Equivalent(listed, shipped, strict: true);
    }

    [Fact]
    public async Task ItReturnsTheDeletesSinceTheCursor()
    {
        var old = _fx.AddWorkout(_me.Id, "Old");
        await Workouts.DeleteWorkoutAsync(old.Id, _me.Id);
        _fx.Backdate(LongAgo);
        var meal = _fx.AddMeal(_me.Id, new DateTime(2026, 3, 1, 23, 0, 0, DateTimeKind.Utc));
        var food = _fx.AddFoodToMeal(meal.Id, Guid.NewGuid());
        await Meals.RemoveFoodFromMealAsync(meal.Id, _me.Id, food.Id);

        var changes = await ChangesAsync(_me, Cursor);

        var deleted = Assert.Single(changes.Deleted);
        Assert.Equal(SyncEntityTypes.MealFood, deleted.EntityType);
        Assert.Equal(food.Id, deleted.EntityId);
        Assert.True(deleted.DeletedAt > Cursor);
        Assert.Equal(meal.Id, Assert.Single(changes.Meals).Id);
    }

    [Fact]
    public async Task ItReturnsOnlyTheCallersData()
    {
        // Sessions have no owner column of their own; theirs is their workout's. Both the
        // aggregates and the deletes are the caller's alone.
        await SeedAsync(_me);
        var (_, theirSession, _) = await SeedAsync(_someoneElse);
        var theirs = _fx.AddWorkout(_someoneElse.Id, "Theirs");
        await Workouts.DeleteWorkoutAsync(theirs.Id, _someoneElse.Id);

        foreach (var since in new DateTime?[] { null, Cursor })
        {
            var changes = await ChangesAsync(_me, since);

            Assert.All(changes.Workouts, w => Assert.Equal(_me.Id, w.UserId));
            Assert.All(changes.WorkoutPlans, p => Assert.Equal(_me.Id, p.UserId));
            Assert.All(changes.Exercises, e => Assert.Equal(_me.Id, e.UserId));
            Assert.DoesNotContain(changes.ScheduledWorkouts, s => s.Id == theirSession);
            Assert.Single(changes.ScheduledWorkouts);
            Assert.Single(changes.Meals);
            Assert.Single(changes.FoodItems);
            Assert.Single(changes.MealTemplates);
            Assert.Single(changes.Weights);
            Assert.Empty(changes.Deleted);
        }
    }

    [Fact]
    public async Task ARetiredExerciseStillShipsInsideItsWorkout()
    {
        // Retired entries are what logged sets resolve through; the workout GET has always
        // listed them, with removedAt set, and so does the feed.
        var workout = _fx.AddWorkout(_me.Id);
        var retired = _fx.AddWorkoutExercise(workout.Id, Guid.NewGuid(), 0);
        _fx.AddWorkoutExercise(workout.Id, Guid.NewGuid(), 1);
        var session = _fx.AddSession(workout.Id, new DateTime(2026, 3, 2, 0, 0, 0, DateTimeKind.Utc));
        _fx.AddLoggedSet(session.Id, retired.Id, weight: 60);
        _fx.Backdate(LongAgo);

        await Workouts.DeleteWorkoutExerciseAsync(retired.Id, _me.Id);

        var shipped = Assert.Single((await ChangesAsync(_me, Cursor)).Workouts);
        Assert.Equal(2, shipped.Exercises.Count);
        Assert.NotNull(Assert.Single(shipped.Exercises, e => e.Id == retired.Id).RemovedAt);
    }

    [Fact]
    public async Task ATrainersEditReachesTheClientsFeedAndNotTheTrainers()
    {
        _fx.AddRelationship(_someoneElse.Id, _me.Id, TrainerClientStatus.Active);
        var console = new TrainerConsoleService(
            new ActiveRelationshipStub(_someoneElse.Id, _me.Id), null!,
            new WorkoutPlanService(new WorkoutPlanRepository(_fx.Db), new SyncTombstoneRepository(_fx.Db)), Sessions, null!, null!,
            new ExerciseService(new ExerciseRepository(_fx.Db), new SyncTombstoneRepository(_fx.Db)), null!, Workouts, null!);
        var created = await console.CreateClientWorkoutAsync(_someoneElse.Id, _me.Id, new ClientWorkoutRequestDto { Name = "Leg Day" });
        _fx.Backdate(LongAgo);

        await console.UpdateClientWorkoutAsync(_someoneElse.Id, _me.Id, created.Workout!.Id,
            new ClientWorkoutRequestDto { Name = "Leg Day A" });

        Assert.Equal(created.Workout.Id, Assert.Single((await ChangesAsync(_me, Cursor)).Workouts).Id);
        Assert.Empty((await ChangesAsync(_someoneElse, Cursor)).Workouts);
    }

    // ── The cursor ───────────────────────────────────────────────────────────

    [Fact]
    public async Task TheCursorIsWhenTheAnswerBeganLessTwoMinutes()
    {
        var before = DateTime.UtcNow;
        var changes = await ChangesAsync(_me, since: null);
        var after = DateTime.UtcNow;

        Assert.Equal(DateTimeKind.Utc, changes.Cursor.Kind);
        Assert.InRange(changes.Cursor, before.AddMinutes(-2), after.AddMinutes(-2));
    }

    [Fact]
    public async Task ARowStampedJustBeforeTheLastAnswerArrivesWithTheNextOne()
    {
        // The overlap's job: a transaction that stamped its rows a moment before the last
        // answer began, but committed after that answer's queries ran, was invisible to it.
        // The next answer, from the returned cursor, still includes it.
        //
        // The stamp is taken from the clock before the last answer began, not from the
        // cursor it returned: a stamp derived from the cursor lands after it whatever the
        // overlap is, and the test would pass with the overlap removed.
        var workout = _fx.AddWorkout(_me.Id);
        var before = DateTime.UtcNow;
        var first = await ChangesAsync(_me, since: null);
        await _fx.Db.Workouts.ExecuteUpdateAsync(s => s.SetProperty(w => w.UpdatedAt, before.AddSeconds(-1)));

        var next = await ChangesAsync(_me, first.Cursor);

        Assert.Equal(workout.Id, Assert.Single(next.Workouts).Id);
    }

    [Fact]
    public async Task TheEndpointAnswersForTheCallerAndReadsTheCursorAsAnInstant()
    {
        // A cursor sent with an offset names the same instant as its UTC form.
        var workout = _fx.AddWorkout(_me.Id);
        _fx.AddWorkout(_someoneElse.Id);
        await _fx.Db.Workouts.Where(w => w.Id == workout.Id)
            .ExecuteUpdateAsync(s => s.SetProperty(w => w.UpdatedAt, new DateTime(2026, 3, 1, 12, 0, 0, DateTimeKind.Utc)));
        var controller = SyncControllerFor(new Claim(ClaimTypes.NameIdentifier, _me.Id.ToString()));

        // 13:30 at +02:00 is 11:30 UTC: before the workout's 12:00.
        var included = (SyncChangesDto)Assert.IsType<OkObjectResult>(await controller.GetChanges(
            new DateTimeOffset(2026, 3, 1, 13, 30, 0, TimeSpan.FromHours(2)))).Value!;
        // 14:30 at +02:00 is 12:30 UTC: after it.
        var excluded = (SyncChangesDto)Assert.IsType<OkObjectResult>(await controller.GetChanges(
            new DateTimeOffset(2026, 3, 1, 14, 30, 0, TimeSpan.FromHours(2)))).Value!;

        Assert.Equal(workout.Id, Assert.Single(included.Workouts).Id);
        Assert.Empty(excluded.Workouts);
    }

    [Fact]
    public async Task ATokenCarryingOnlySubReadsTheFeed()
    {
        // The OAuth case ClaimsPrincipal.TryGetUserId exists for. The sync controllers parsed
        // NameIdentifier alone, so this token made every one of them throw, a 500, while the
        // hub and the console accepted it.
        var workout = _fx.AddWorkout(_me.Id);

        var answer = await SyncControllerFor(new Claim("sub", _me.Id.ToString())).GetChanges(since: null);

        var changes = (SyncChangesDto)Assert.IsType<OkObjectResult>(answer).Value!;
        Assert.Equal(workout.Id, Assert.Single(changes.Workouts).Id);
    }

    [Fact]
    public async Task ATokenWithoutAUserIdIsUnauthorized()
    {
        // Not a 500: nothing went wrong on the server.
        var answer = await SyncControllerFor(new Claim("scope", "sync")).GetChanges(since: null);

        Assert.IsType<UnauthorizedResult>(answer);
    }

    private SyncController SyncControllerFor(Claim claim) => new(Feed)
    {
        ControllerContext = new ControllerContext
        {
            HttpContext = new DefaultHttpContext
            {
                User = new ClaimsPrincipal(new ClaimsIdentity([claim], authenticationType: "Test")),
            },
        },
    };
}
