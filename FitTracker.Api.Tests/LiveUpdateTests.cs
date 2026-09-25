using System.Buffers;
using System.Security.Claims;
using System.Text.Json;
using FitTracker.Api.Data;
using FitTracker.Api.DTOs;
using FitTracker.Api.Hubs;
using FitTracker.Api.Models;
using FitTracker.Api.Repositories;
using FitTracker.Api.Services;
using FitTracker.Api.Services.Interfaces;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.SignalR;
using Microsoft.AspNetCore.SignalR.Protocol;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace FitTracker.Api.Tests;

/// <summary>
/// Live updates: after a request commits a change to someone's data, their Active trainers
/// hear <c>ClientDataChanged</c>, and their own devices are asked to pull when somebody else
/// made the change. See docs/sync-architecture.md, part four.
///
/// Every test here plays one or more requests through the services the controllers use, on
/// a context that records into a <see cref="ChangedDataLog"/> as a request's does, then ends
/// the request by handing what it committed to <see cref="LiveUpdateNotifier"/> with fakes for
/// the hub and the push. Nothing in the compiler connects a write to its notification: a
/// bulk statement that forgets to say whose data it changed compiles, commits and answers 200,
/// and the trainer simply never hears of it.
/// </summary>
public class LiveUpdateTests : IDisposable
{
    private readonly DbFixture _fx = new();
    private readonly ChangedDataLog _log = new();
    private readonly AppDbContext _db;

    private readonly User _client;
    private readonly User _trainer;
    private readonly User _pendingTrainer;
    private readonly User _formerTrainer;
    private readonly User _otherTrainer;

    public LiveUpdateTests()
    {
        _client = _fx.AddUser("Robert", "Meyer");
        _trainer = _fx.AddUser("Dana", "Ruiz");
        _pendingTrainer = _fx.AddUser("Lena", "Brandt");
        _formerTrainer = _fx.AddUser("Tomas", "Novak");
        _otherTrainer = _fx.AddUser("Aiko", "Mori");
        foreach (var trainer in new[] { _trainer, _pendingTrainer, _formerTrainer, _otherTrainer })
        {
            _fx.AddLicence(trainer.Id);
        }

        _fx.AddRelationship(_trainer.Id, _client.Id, TrainerClientStatus.Active);
        // A Pending row naming the client can't come from the invite flow (an invite has no
        // client until it's redeemed), which is exactly why it is here: if the status filter
        // went, this is the row that would slip through.
        _fx.AddRelationship(_pendingTrainer.Id, _client.Id, TrainerClientStatus.Pending);
        _fx.AddRelationship(_formerTrainer.Id, _client.Id, TrainerClientStatus.Revoked);
        _fx.AddRelationship(_otherTrainer.Id, _fx.AddUser("Petra", "Voss").Id, TrainerClientStatus.Active);

        _db = _fx.NewContext(_log);
    }

    public void Dispose()
    {
        _db.Dispose();
        _fx.Dispose();
    }

    private WorkoutService Workouts => new(new WorkoutRepository(_db), new SyncTombstoneRepository(_db));
    private WorkoutPlanService Plans => new(new WorkoutPlanRepository(_db), new SyncTombstoneRepository(_db));
    private ScheduledWorkoutService Sessions => new(new ScheduledWorkoutRepository(_db), new SyncTombstoneRepository(_db));
    private MealService Meals => new(new MealRepository(_db), new SyncTombstoneRepository(_db));
    private MealTemplateService Templates => new(new MealTemplateRepository(_db), new SyncTombstoneRepository(_db));
    private ExerciseService Exercises => new(new ExerciseRepository(_db), new SyncTombstoneRepository(_db));
    private FoodItemService Foods => new(new FoodItemRepository(_db), new SyncTombstoneRepository(_db));
    private WeightTrackingService Weights => new(new WeightTrackingRepository(_db), new SyncTombstoneRepository(_db));
    private UserSettingsService Settings => new(new UserSettingsRepository(_db));

    private static readonly DateTime Monday = new(2026, 3, 2, 0, 0, 0, DateTimeKind.Utc);

    private Task LogWeightAsync(Guid userId) =>
        Weights.LogWeightAsync(new WeightTrackingRequestDto { Date = Monday, Weight = 81.4 }, userId);

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

    /// <summary>Ends the request <paramref name="actor"/> made: what it committed goes to the
    /// notifier, as the middleware hands it on.</summary>
    private async Task<Sent> EndRequestAsync(Guid? actor, bool hubFails = false, bool pushFails = false)
    {
        var hub = new RecordingHub { Fails = hubFails };
        var push = new RecordingPush { Fails = pushFails };
        var notifier = new LiveUpdateNotifier(_fx.Db, hub, push, NullLogger<LiveUpdateNotifier>.Instance);

        await notifier.NotifyAsync(actor, _log.TakeCommitted());

        return new Sent(hub.Sent, push.Requested);
    }

    private sealed record Sent(
        List<(IReadOnlyList<string> Groups, string Method, object?[] Args)> Events,
        List<Guid> Pulls)
    {
        public ClientDataChangedDto Only()
        {
            var (groups, method, args) = Assert.Single(Events);
            Assert.Equal(LiveUpdateNotifier.ClientDataChanged, method);
            return Assert.IsType<ClientDataChangedDto>(Assert.Single(args));
        }

        public List<string> Areas() => Events.Count == 0 ? [] : [.. Only().Areas];
    }

    // ── Who hears of it ──────────────────────────────────────────────────────

    [Fact]
    public async Task AClientsWriteReachesOnlyTheirActiveTrainer()
    {
        await LogWeightAsync(_client.Id);

        var sent = await EndRequestAsync(actor: _client.Id);

        // One send, to one group: the Active trainer's. Not the Pending one, not the one whose
        // relationship ended, not a trainer of somebody else — and not the client's own
        // connections, which have no group of this kind at all.
        var (groups, _, _) = Assert.Single(sent.Events);
        Assert.Equal([ChatHub.TrainerGroup(_trainer.Id)], groups);
        var payload = sent.Only();
        Assert.Equal(_client.Id, payload.ClientId);
        Assert.Equal([DataAreas.Weight], payload.Areas);
    }

    [Fact]
    public async Task AClientWithNoActiveTrainerIsNobodysEvent()
    {
        var loner = _fx.AddUser("Mara", "Vogel");

        await LogWeightAsync(loner.Id);

        Assert.Empty((await EndRequestAsync(actor: loner.Id)).Events);
    }

    [Fact]
    public async Task ATrainersWriteToAClientsDataAsksTheClientsDevicesToPull()
    {
        var console = Console(_trainer);

        await console.CreateClientWorkoutAsync(_trainer.Id, _client.Id, new ClientWorkoutRequestDto { Name = "Leg Day" });
        var sent = await EndRequestAsync(actor: _trainer.Id);

        // The owner's devices, never the actor's: the trainer already has what they wrote.
        Assert.Equal([_client.Id], sent.Pulls);
        // And the console hears of it like any other change to the client's data.
        Assert.Equal(_client.Id, sent.Only().ClientId);
        Assert.Equal([DataAreas.Workouts], sent.Only().Areas);
    }

    [Fact]
    public async Task AUsersWriteToTheirOwnDataAsksForNoPull()
    {
        var food = _fx.AddFoodItem(_client.Id);

        await Meals.CreateMealAsync(new MealRequestDto { Date = Monday, Category = "Breakfast", FoodItemId = food.Id }, _client.Id);
        var sent = await EndRequestAsync(actor: _client.Id);

        // The device that made the change has it. Its other devices find out on their next
        // pull; a push is for a change the owner didn't make.
        Assert.Empty(sent.Pulls);
        Assert.Single(sent.Events);
    }

    [Fact]
    public async Task ARequestWithNoSignedInUserAsksForNoPull()
    {
        await LogWeightAsync(_client.Id);

        var sent = await EndRequestAsync(actor: null);

        Assert.Empty(sent.Pulls);
        Assert.Single(sent.Events);
    }

    // ── Which area ───────────────────────────────────────────────────────────

    [Fact]
    public async Task EachKindOfDataIsReportedInItsArea()
    {
        var workout = _fx.AddWorkout(_client.Id);
        var food = _fx.AddFoodItem(_client.Id);
        var reported = new Dictionary<string, string>();

        async Task Request(string what, Func<Task> write)
        {
            await write();
            reported[what] = string.Join(",", (await EndRequestAsync(actor: _client.Id)).Areas());
        }

        await Request("exercise", () => Exercises.CreateExercise(new ExerciseRequestDto { Name = "Sissy Squat", IsCustom = true }, _client.Id));
        await Request("workout", () => Workouts.CreateWorkoutAsync(new WorkoutRequestDto { Name = "Push Day" }, _client.Id));
        await Request("plan", () => Plans.CreatePlanAsync(new WorkoutPlanRequestDto { Name = "Block 1", StartDate = Monday }, _client.Id));
        await Request("session", () => Sessions.CreateScheduledWorkoutAsync(
            new ScheduledWorkoutRequestDto { WorkoutId = workout.Id, ScheduledDate = Monday }, _client.Id));
        await Request("food item", () => Foods.CreateFoodItemAsync(new FoodItemRequestDto { Name = "Skyr", Calories = 63 }, _client.Id));
        await Request("meal", () => Meals.CreateMealAsync(new MealRequestDto { Date = Monday, Category = "Lunch", FoodItemId = food.Id }, _client.Id));
        await Request("meal template", () => Templates.CreateAsync(Template(null, "Oats"), _client.Id));
        await Request("weight", () => LogWeightAsync(_client.Id));
        await Request("settings", () => Settings.UpsertSettingsAsync(_client.Id, new UserSettingsRequestDto { DailyCalorieGoal = 2400 }));

        Assert.Equal(new Dictionary<string, string>
        {
            ["exercise"] = DataAreas.Workouts,
            ["workout"] = DataAreas.Workouts,
            ["plan"] = DataAreas.Workouts,
            ["session"] = DataAreas.Sessions,
            ["food item"] = DataAreas.Nutrition,
            ["meal"] = DataAreas.Nutrition,
            ["meal template"] = DataAreas.Nutrition,
            ["weight"] = DataAreas.Weight,
            // The calorie goal is a setting, and the Nutrition pane and Client Detail's intake
            // are measured against it. With no area, a client's new goal left the trainer
            // looking at the old one, and a wrong kcal remaining, until the tab lost focus.
            ["settings"] = DataAreas.Nutrition,
        }, reported);
    }

    [Fact]
    public async Task AChildsChangeIsReportedInItsRootsArea()
    {
        var workout = _fx.AddWorkout(_client.Id);
        var entry = _fx.AddWorkoutExercise(workout.Id, Guid.NewGuid());
        var session = _fx.AddSession(workout.Id, Monday);
        var set = _fx.AddLoggedSet(session.Id, entry.Id, weight: 60);
        var meal = _fx.AddMeal(_client.Id, Monday);
        var plan = _fx.AddPlan(_client.Id, "Block 1", isActive: true);
        var template = await Templates.CreateAsync(Template(Guid.NewGuid(), "Oats"), _client.Id);
        await EndRequestAsync(actor: _client.Id);
        var reported = new Dictionary<string, string>();

        async Task Request(string what, Func<Task> write)
        {
            _db.ChangeTracker.Clear();
            await write();
            reported[what] = string.Join(",", (await EndRequestAsync(actor: _client.Id)).Areas());
        }

        // None of these writes a root. Each only reaches its owner through its root.
        await Request("set template", () => Workouts.AddSetTemplateAsync(entry.Id, _client.Id,
            new WorkoutSetTemplateRequestDto { SetNumber = 1, TargetReps = "8" }));
        await Request("logged set", () => Sessions.UpdateSetAsync(set.Id, _client.Id,
            new WorkoutSetRequestDto { SetNumber = 1, Reps = 8, Weight = 62.5, IsCompleted = true }));
        await Request("meal food", () => Meals.AddFoodsToMealBatchAsync(meal.Id, _client.Id,
            [new MealFoodEntryRequestDto { Id = Guid.NewGuid(), FoodItemId = Guid.NewGuid() }]));
        await Request("plan link", () => Plans.ReplacePlanWorkoutsAsync(plan.Id, [workout.Id], _client.Id));
        await Request("template item", () => Templates.UpdateAsync(template.Id, _client.Id, Template(template.Id, "Oats", "Blueberries")));

        Assert.Equal(new Dictionary<string, string>
        {
            ["set template"] = DataAreas.Workouts,
            ["logged set"] = DataAreas.Sessions,
            ["meal food"] = DataAreas.Nutrition,
            ["plan link"] = DataAreas.Workouts,
            ["template item"] = DataAreas.Nutrition,
        }, reported);
    }

    [Fact]
    public void EverySyncedRootHasAnArea()
    {
        // A root with no area is written, stamped, fed to every device, and never told to a
        // trainer. Settings were exactly that until they were given the calorie goal's pane.
        var roots = typeof(ISyncRoot).Assembly.GetTypes()
            .Where(t => typeof(ISyncRoot).IsAssignableFrom(t) && t is { IsClass: true, IsAbstract: false })
            .ToList();

        Assert.Contains(typeof(UserSettings), roots);
        Assert.All(roots, root => Assert.NotNull(DataAreas.Of(root)));
    }

    [Fact]
    public void EveryTombstoneTypeHasAnArea()
    {
        // The area of a delete comes from its tombstone. A type added to SyncEntityTypes and
        // not to DataAreas would be deleted, recorded, fed to every device — and never told
        // to a trainer.
        var types = typeof(SyncEntityTypes).GetFields()
            .Where(f => f.IsLiteral)
            .Select(f => (string)f.GetRawConstantValue()!)
            .ToList();

        Assert.NotEmpty(types);
        Assert.All(types, type => Assert.NotNull(DataAreas.OfTombstone(type)));
    }

    // ── How many ─────────────────────────────────────────────────────────────

    [Fact]
    public async Task ManyChangesInOneRequestAreOneEventPerOwner()
    {
        var workout = _fx.AddWorkout(_client.Id);
        var entry = _fx.AddWorkoutExercise(workout.Id, Guid.NewGuid());
        var session = _fx.AddSession(workout.Id, Monday);
        var sessionEntry = _fx.AddLoggedSet(session.Id, entry.Id, weight: 60).ScheduledWorkoutExerciseId;
        var food = _fx.AddFoodItem(_client.Id);

        // One request, many saves and many rows, in four areas.
        await LogWeightAsync(_client.Id);
        await Meals.CreateMealAsync(new MealRequestDto { Date = Monday, Category = "Dinner", FoodItemId = food.Id }, _client.Id);
        var pushDay = await Workouts.CreateWorkoutAsync(new WorkoutRequestDto { Name = "Push Day" }, _client.Id);
        for (var i = 0; i < 3; i++)
        {
            await Workouts.AddExerciseToWorkoutAsync(pushDay.Id, _client.Id, new WorkoutExerciseRequestDto { ExerciseId = Guid.NewGuid(), OrderPosition = i });
        }
        await Sessions.AddSetsBatchAsync(sessionEntry, _client.Id,
            [.. Enumerable.Range(1, 5).Select(n => new WorkoutSetRequestDto { Id = Guid.NewGuid(), SetNumber = n, Reps = 5, Weight = 100, IsCompleted = true })]);

        var sent = await EndRequestAsync(actor: _client.Id);

        Assert.Equal([DataAreas.Nutrition, DataAreas.Sessions, DataAreas.Weight, DataAreas.Workouts], sent.Only().Areas);
    }

    [Fact]
    public async Task ATrainersRequestTouchingTwoClientsIsOneEventAndOnePullEach()
    {
        var second = _fx.AddUser("Petra", "Lang");
        _fx.AddRelationship(_trainer.Id, second.Id, TrainerClientStatus.Active);

        await Workouts.CreateWorkoutAsync(new WorkoutRequestDto { Name = "Leg Day" }, _client.Id, assignedByTrainerId: _trainer.Id);
        await Workouts.CreateWorkoutAsync(new WorkoutRequestDto { Name = "Leg Day" }, second.Id, assignedByTrainerId: _trainer.Id);
        await Workouts.CreateWorkoutAsync(new WorkoutRequestDto { Name = "Arm Day" }, second.Id, assignedByTrainerId: _trainer.Id);
        var sent = await EndRequestAsync(actor: _trainer.Id);

        Assert.Equal(
            new[] { _client.Id, second.Id }.Order(),
            sent.Events.Select(e => ((ClientDataChangedDto)e.Args.Single()!).ClientId).Order());
        Assert.Equal(new[] { _client.Id, second.Id }.Order(), sent.Pulls.Order());
    }

    // ── Only what committed ──────────────────────────────────────────────────

    [Fact]
    public async Task ARolledBackTransactionNotifiesNobodyAndLeavesWhatCommittedBeforeIt()
    {
        var meal = _fx.AddMeal(_client.Id, Monday);
        var theirs = _fx.AddFoodToMeal(_fx.AddMeal(_otherTrainer.Id, Monday).Id, Guid.NewGuid());

        // Committed on its own.
        await LogWeightAsync(_client.Id);
        // The foods batch runs in one transaction. Its first entry saves, then the second is
        // someone else's id and the whole batch rolls back.
        await Assert.ThrowsAsync<ClientIdConflictException>(() => Meals.AddFoodsToMealBatchAsync(meal.Id, _client.Id,
        [
            new MealFoodEntryRequestDto { Id = Guid.NewGuid(), FoodItemId = Guid.NewGuid() },
            new MealFoodEntryRequestDto { Id = theirs.Id, FoodItemId = Guid.NewGuid() },
        ]));

        var sent = await EndRequestAsync(actor: _client.Id);

        // The weight, and not the meal: its save succeeded, and was undone with the
        // transaction it ran in.
        Assert.Equal([DataAreas.Weight], sent.Only().Areas);
    }

    [Fact]
    public async Task AFailedSaveIsNotReportedByTheSaveAfterIt()
    {
        var workout = _fx.AddWorkout(_client.Id);

        // The same id again, straight into the table: the insert fails on its key, outside any
        // transaction. Then the request goes on, and its next save commits. That save must
        // commit what it wrote and nothing the failed one had recorded.
        _db.Workouts.Add(new Workout { Id = workout.Id, UserId = _client.Id, Name = "Push Day" });
        await Assert.ThrowsAsync<DbUpdateException>(() => _db.SaveChangesAsync());
        _db.ChangeTracker.Clear();
        await LogWeightAsync(_client.Id);

        Assert.Equal([DataAreas.Weight], (await EndRequestAsync(actor: _client.Id)).Areas());
    }

    [Fact]
    public async Task AFailedSaveInsideATransactionIsNotReportedWhenTheTransactionCommits()
    {
        var workout = _fx.AddWorkout(_client.Id);

        await using (var transaction = await _db.Database.BeginTransactionAsync())
        {
            await LogWeightAsync(_client.Id);
            // EF rolls a failed save inside a transaction back to a savepoint, and the
            // transaction goes on. What the save before it recorded stays; what it recorded goes.
            _db.Workouts.Add(new Workout { Id = workout.Id, UserId = _client.Id, Name = "Push Day" });
            await Assert.ThrowsAsync<DbUpdateException>(() => _db.SaveChangesAsync());
            _db.ChangeTracker.Clear();
            await transaction.CommitAsync();
        }

        Assert.Equal([DataAreas.Weight], (await EndRequestAsync(actor: _client.Id)).Areas());
    }

    // ── What the change tracker never sees ───────────────────────────────────

    [Fact]
    public async Task AReplaceWithNothingIsStillReported()
    {
        // The replace deletes the list in one statement and inserts nothing: a save with no
        // tracked change for the interceptor to learn the owner from.
        var workout = _fx.AddWorkout(_client.Id);
        var entry = _fx.AddWorkoutExercise(workout.Id, Guid.NewGuid());
        await Workouts.ReplaceSetTemplatesAsync(entry.Id, _client.Id,
            [new WorkoutSetTemplateRequestDto { Id = Guid.NewGuid(), SetNumber = 1, TargetReps = "8" }]);
        await EndRequestAsync(actor: _client.Id);

        await Workouts.ReplaceSetTemplatesAsync(entry.Id, _client.Id, []);

        Assert.Equal([DataAreas.Workouts], (await EndRequestAsync(actor: _client.Id)).Areas());
    }

    [Fact]
    public async Task DeletingAPlanReportsTheSessionsItDetaches()
    {
        // ON DELETE SET NULL changes each session; only the stamp by predicate knows.
        var plan = _fx.AddPlan(_client.Id, "Block 1", isActive: true);
        _fx.AddSession(_fx.AddWorkout(_client.Id).Id, Monday, planId: plan.Id);

        await Plans.DeletePlanAsync(plan.Id, _client.Id);

        Assert.Equal([DataAreas.Sessions, DataAreas.Workouts], (await EndRequestAsync(actor: _client.Id)).Areas());
    }

    [Fact]
    public async Task DeletingAWorkoutReportsThePlaceholderSessionsItRemoves()
    {
        // The sessions go in one statement; their tombstones are written by hand.
        var workout = _fx.AddWorkout(_client.Id);
        _fx.AddSession(workout.Id, Monday);

        await Workouts.DeleteWorkoutAsync(workout.Id, _client.Id);

        Assert.Equal([DataAreas.Sessions, DataAreas.Workouts], (await EndRequestAsync(actor: _client.Id)).Areas());
    }

    [Fact]
    public async Task RemovingAnExerciseReportsTheSessionsWhosePlaceholdersGo()
    {
        // The unlogged entries go in one statement, and the sessions are stamped by id.
        var workout = _fx.AddWorkout(_client.Id);
        var entry = _fx.AddWorkoutExercise(workout.Id, Guid.NewGuid());
        var upcoming = _fx.AddSession(workout.Id, Monday);
        _fx.Db.ScheduledWorkoutExercises.Add(new ScheduledWorkoutExercise
        {
            Id = Guid.NewGuid(),
            ScheduledWorkoutId = upcoming.Id,
            WorkoutExerciseId = entry.Id,
        });
        _fx.Db.SaveChanges();

        await Workouts.DeleteWorkoutExerciseAsync(entry.Id, _client.Id);

        Assert.Equal([DataAreas.Sessions, DataAreas.Workouts], (await EndRequestAsync(actor: _client.Id)).Areas());
    }

    [Fact]
    public async Task ATrainersDeleteOfAClientsWorkoutReachesTheClient()
    {
        var console = Console(_trainer);
        var created = await console.CreateClientWorkoutAsync(_trainer.Id, _client.Id, new ClientWorkoutRequestDto { Name = "Leg Day" });
        await EndRequestAsync(actor: _trainer.Id);

        await console.DeleteClientWorkoutAsync(_trainer.Id, _client.Id, created.Workout!.Id);
        var sent = await EndRequestAsync(actor: _trainer.Id);

        Assert.Equal([_client.Id], sent.Pulls);
        Assert.Equal([DataAreas.Workouts], sent.Only().Areas);
    }

    // ── What it costs ────────────────────────────────────────────────────────

    [Fact]
    public async Task EveryOwnerIsKnownByTheTimeTheRequestEnds()
    {
        // Four writes that touch no root, each reaching its owner only through a root the
        // tracker doesn't hold. The owners were looked up after the request, one query per
        // kind of root, and then the trainers were asked for: five queries to learn what the
        // writes had already had in front of them. Resolved as each write happens, what is
        // left after the request is the one query for the owners' Active trainers.
        var workout = _fx.AddWorkout(_client.Id);
        var entry = _fx.AddWorkoutExercise(workout.Id, Guid.NewGuid());
        var session = _fx.AddSession(workout.Id, Monday);
        var set = _fx.AddLoggedSet(session.Id, entry.Id, weight: 60);
        var meal = _fx.AddMeal(_client.Id, Monday);
        var plan = _fx.AddPlan(_client.Id, "Block 1", isActive: true);
        _db.ChangeTracker.Clear();

        await Workouts.AddSetTemplateAsync(entry.Id, _client.Id, new WorkoutSetTemplateRequestDto { SetNumber = 1, TargetReps = "8" });
        _db.ChangeTracker.Clear();
        await Sessions.UpdateSetAsync(set.Id, _client.Id, new WorkoutSetRequestDto { SetNumber = 1, Reps = 8, Weight = 62.5, IsCompleted = true });
        _db.ChangeTracker.Clear();
        await Meals.AddFoodsToMealBatchAsync(meal.Id, _client.Id, [new MealFoodEntryRequestDto { Id = Guid.NewGuid(), FoodItemId = Guid.NewGuid() }]);
        _db.ChangeTracker.Clear();
        await Plans.ReplacePlanWorkoutsAsync(plan.Id, [workout.Id], _client.Id);

        _fx.Queries.Reset();
        var sent = await EndRequestAsync(actor: _client.Id);

        Assert.Equal(1, _fx.Queries.Count);
        var payload = sent.Only();
        Assert.Equal(_client.Id, payload.ClientId);
        Assert.Equal([DataAreas.Nutrition, DataAreas.Sessions, DataAreas.Workouts], payload.Areas);
    }

    [Fact]
    public async Task AUserWithNoTrainerChangingTheirOwnDataCostsOneQueryAndNothingElse()
    {
        // Nearly every write: a trainee with no trainer, or with one, syncing their own data.
        // The trainers are asked for first, and with none and nobody else's data changed there
        // is nothing to send and nobody to ask to pull.
        var loner = _fx.AddUser("Mara", "Vogel");
        await LogWeightAsync(loner.Id);
        await Settings.UpsertSettingsAsync(loner.Id, new UserSettingsRequestDto { DailyCalorieGoal = 2100 });

        _fx.Queries.Reset();
        var sent = await EndRequestAsync(actor: loner.Id);

        Assert.Equal(1, _fx.Queries.Count);
        Assert.Empty(sent.Events);
        Assert.Empty(sent.Pulls);
    }

    [Fact]
    public async Task SomebodyElsesChangeStillAsksForThePullWhenNoTrainerIsLeftToTell()
    {
        // The trainer's write committed while the relationship was Active; the client ended it
        // before the notification ran. Nobody is left to tell, but the client's data still
        // changed under them, so the early return for "nobody to tell" can't be taken.
        await Console(_trainer).CreateClientWorkoutAsync(_trainer.Id, _client.Id, new ClientWorkoutRequestDto { Name = "Leg Day" });
        var relationship = _fx.Db.TrainerClients.Single(r => r.TrainerId == _trainer.Id && r.ClientId == _client.Id);
        relationship.Status = TrainerClientStatus.Revoked;
        _fx.Db.SaveChanges();

        var sent = await EndRequestAsync(actor: _trainer.Id);

        Assert.Empty(sent.Events);
        Assert.Equal([_client.Id], sent.Pulls);
    }

    // ── Failures ─────────────────────────────────────────────────────────────

    [Fact]
    public async Task AFailedSendStillAsksForThePull()
    {
        await Console(_trainer).CreateClientWorkoutAsync(_trainer.Id, _client.Id, new ClientWorkoutRequestDto { Name = "Leg Day" });

        var sent = await EndRequestAsync(actor: _trainer.Id, hubFails: true);

        Assert.Equal([_client.Id], sent.Pulls);
    }

    [Fact]
    public async Task AFailedPushStopsNothingElse()
    {
        var second = _fx.AddUser("Petra", "Lang");
        _fx.AddRelationship(_trainer.Id, second.Id, TrainerClientStatus.Active);
        await Workouts.CreateWorkoutAsync(new WorkoutRequestDto { Name = "Leg Day" }, _client.Id);
        await Workouts.CreateWorkoutAsync(new WorkoutRequestDto { Name = "Leg Day" }, second.Id);

        var sent = await EndRequestAsync(actor: _trainer.Id, pushFails: true);

        Assert.Equal(2, sent.Events.Count);
        Assert.Equal(2, sent.Pulls.Count);
    }

    // ── The request ──────────────────────────────────────────────────────────

    [Fact]
    public async Task WhatARequestCommittedIsQueuedWhenItEnds()
    {
        var dispatcher = new RecordingDispatcher();
        var middleware = new LiveUpdateMiddleware(async _ =>
        {
            await LogWeightAsync(_client.Id);
            // Queued after the request, not at the commit: nothing yet.
            Assert.Empty(dispatcher.Queued);
            await LogWeightAsync(_client.Id);
        });

        await middleware.InvokeAsync(Request(_client.Id), _log, dispatcher);

        var (actor, changes) = Assert.Single(dispatcher.Queued);
        Assert.Equal(_client.Id, actor);
        Assert.NotEmpty(changes);
    }

    [Fact]
    public async Task ARequestThatFailsAfterCommittingStillQueuesWhatItCommitted()
    {
        var dispatcher = new RecordingDispatcher();
        var middleware = new LiveUpdateMiddleware(async _ =>
        {
            await LogWeightAsync(_client.Id);
            throw new InvalidOperationException("the answer could not be written");
        });

        await Assert.ThrowsAsync<InvalidOperationException>(() => middleware.InvokeAsync(Request(_client.Id), _log, dispatcher));

        Assert.Single(dispatcher.Queued);
    }

    [Fact]
    public async Task ARequestThatCommitsNothingQueuesNothing()
    {
        var dispatcher = new RecordingDispatcher();
        var middleware = new LiveUpdateMiddleware(_ => Workouts.GetUserWorkoutsAsync(_client.Id));

        await middleware.InvokeAsync(Request(_client.Id), _log, dispatcher);

        Assert.Empty(dispatcher.Queued);
    }

    [Fact]
    public async Task TheActorIsReadFromAnOAuthTokensSubClaimToo()
    {
        var dispatcher = new RecordingDispatcher();
        var middleware = new LiveUpdateMiddleware(_ => LogWeightAsync(_client.Id));

        await middleware.InvokeAsync(Request(_trainer.Id, claimType: "sub"), _log, dispatcher);

        Assert.Equal(_trainer.Id, Assert.Single(dispatcher.Queued).actor);
    }

    [Fact]
    public async Task AContextBuiltByDependencyInjectionRecordsIntoTheRequestsLog()
    {
        // What the API does: the request's scope holds one log, and the context it builds for
        // the controllers writes into it. A context built without it would commit changes
        // nobody is ever told of, and every other test here would still pass.
        using var connection = new SqliteConnection("DataSource=:memory:");
        connection.Open();
        var services = new ServiceCollection()
            .AddDbContext<AppDbContext>(o => o.UseSqlite(connection))
            .AddScoped<ChangedDataLog>()
            .BuildServiceProvider();
        using var scope = services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        db.Database.EnsureCreated();
        var user = new User
        {
            Id = Guid.NewGuid(),
            FirstName = "Robert",
            LastName = "Meyer",
            Email = "robert@example.com",
            UserName = "robert",
            PasswordHash = "not-a-real-hash",
            DateOfBirth = new DateTime(1990, 1, 1),
        };
        db.Users.Add(user);
        await db.SaveChangesAsync();

        db.WeightTrackings.Add(new WeightTracking { Id = Guid.NewGuid(), UserId = user.Id, Date = Monday, Weight = 80 });
        await db.SaveChangesAsync();

        var change = Assert.Single(scope.ServiceProvider.GetRequiredService<ChangedDataLog>().TakeCommitted());
        Assert.Equal(new ChangedData(user.Id, DataAreas.Weight), change);
    }

    // ── On the wire ──────────────────────────────────────────────────────────

    [Fact]
    public void TheEventReachesTheConsoleAsCamelCaseJson()
    {
        // The contract the console is written against. SignalR serialises with its own
        // options, so this goes through the hub protocol rather than JsonSerializer.
        var clientId = Guid.NewGuid();
        var buffer = new ArrayBufferWriter<byte>();

        new JsonHubProtocol().WriteMessage(
            new InvocationMessage(LiveUpdateNotifier.ClientDataChanged,
                [new ClientDataChangedDto(clientId, [DataAreas.Sessions, DataAreas.Workouts])]),
            buffer);

        // The record separator SignalR ends each message with.
        using var json = JsonDocument.Parse(buffer.WrittenMemory[..^1]);
        Assert.Equal("ClientDataChanged", json.RootElement.GetProperty("target").GetString());
        var argument = Assert.Single(json.RootElement.GetProperty("arguments").EnumerateArray());
        Assert.Equal(clientId.ToString(), argument.GetProperty("clientId").GetString());
        Assert.Equal(["sessions", "workouts"], argument.GetProperty("areas").EnumerateArray().Select(a => a.GetString()));
        Assert.Equal(2, argument.EnumerateObject().Count());
    }

    // ── Helpers and fakes ────────────────────────────────────────────────────

    private TrainerConsoleService Console(User trainer) => new(
        new ActiveRelationshipStub(trainer.Id, _client.Id),
        null!,
        Plans,
        Sessions,
        null!,
        null!,
        Exercises,
        null!,
        Workouts,
        null!);

    private static DefaultHttpContext Request(Guid userId, string claimType = ClaimTypes.NameIdentifier) => new()
    {
        User = new ClaimsPrincipal(new ClaimsIdentity([new Claim(claimType, userId.ToString())], authenticationType: "Test")),
    };

    private sealed class RecordingDispatcher : ILiveUpdateDispatcher
    {
        public List<(Guid? actor, IReadOnlyCollection<ChangedData> changes)> Queued { get; } = [];

        public void Queue(Guid? actorId, IReadOnlyCollection<ChangedData> changes) => Queued.Add((actorId, changes));
    }

    private sealed class RecordingPush : IPushNotificationService
    {
        public List<Guid> Requested { get; } = [];
        public bool Fails { get; init; }

        public Task SendSyncRequestedAsync(Guid userId)
        {
            Requested.Add(userId);
            return Fails ? throw new HttpRequestException("FCM is having a bad afternoon") : Task.CompletedTask;
        }

        public Task SendChatMessageAsync(Guid recipientId, string senderName, Guid messageId, EncryptedChatBody body, Guid threadId) =>
            throw new NotSupportedException();
    }

    /// <summary>Records what is sent to groups. Anything else — every connection, a user, a
    /// connection id — throws: live updates only ever go to trainer groups.</summary>
    private sealed class RecordingHub : IHubContext<ChatHub>
    {
        public List<(IReadOnlyList<string> Groups, string Method, object?[] Args)> Sent { get; } = [];
        public bool Fails { get; init; }

        public IHubClients Clients => new RecordingClients(this);
        public IGroupManager Groups => throw new NotSupportedException();

        private sealed class RecordingClients(RecordingHub hub) : IHubClients
        {
            public IClientProxy Group(string groupName) => new Proxy(hub, [groupName]);
            public IClientProxy Groups(IReadOnlyList<string> groupNames) => new Proxy(hub, groupNames);
            public IClientProxy GroupExcept(string groupName, IReadOnlyList<string> excludedConnectionIds) => throw new NotSupportedException();
            public IClientProxy All => throw new NotSupportedException();
            public IClientProxy AllExcept(IReadOnlyList<string> excludedConnectionIds) => throw new NotSupportedException();
            public IClientProxy Client(string connectionId) => throw new NotSupportedException();
            public IClientProxy Clients(IReadOnlyList<string> connectionIds) => throw new NotSupportedException();
            public IClientProxy User(string userId) => throw new NotSupportedException();
            public IClientProxy Users(IReadOnlyList<string> userIds) => throw new NotSupportedException();
        }

        private sealed class Proxy(RecordingHub hub, IReadOnlyList<string> groups) : IClientProxy
        {
            public Task SendCoreAsync(string method, object?[] args, CancellationToken cancellationToken = default)
            {
                hub.Sent.Add((groups, method, args));
                return hub.Fails ? throw new IOException("the socket went away") : Task.CompletedTask;
            }
        }
    }
}
