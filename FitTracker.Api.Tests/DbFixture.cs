using FitTracker.Api.Data;
using FitTracker.Api.Models;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;

namespace FitTracker.Api.Tests;

/// <summary>
/// A throwaway <see cref="AppDbContext"/> backed by SQLite in-memory.
///
/// Deliberately not the InMemory provider: these tests turn on unique indexes
/// (one licence per trainer) and relational filtering, and InMemory silently
/// ignores both — a test suite that passes there would tell us nothing about
/// what Postgres will do.
///
/// The connection is held open for the fixture's lifetime because SQLite drops
/// an in-memory database as soon as its last connection closes.
/// </summary>
public sealed class DbFixture : IDisposable
{
    private readonly SqliteConnection _connection;

    public AppDbContext Db { get; }

    /// <summary>Counts the SQL commands this fixture's context issues.</summary>
    /// <remarks>Here so a test can assert the *shape* of a data-access path — "this endpoint
    /// costs the same number of queries for ten clients as for one" — rather than its speed.
    /// A timing assertion on CI is a flaky test; a query-count assertion is not, and it is the
    /// assertion that would have caught the Trainer Console's N+1 while it was being written.
    /// </remarks>
    public QueryCounter Queries { get; } = new();

    public DbFixture()
    {
        _connection = new SqliteConnection("DataSource=:memory:");
        _connection.Open();

        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseSqlite(_connection)
            .AddInterceptors(Queries)
            .Options;

        Db = new AppDbContext(options);
        Db.Database.EnsureCreated();
    }

    /// <summary>Adds a user and returns it. Names are only ever used in DTO
    /// assertions, so callers that don't care can leave them defaulted.</summary>
    public User AddUser(string firstName = "Sam", string lastName = "Reyes")
    {
        var user = new User
        {
            Id = Guid.NewGuid(),
            FirstName = firstName,
            LastName = lastName,
            Email = $"{Guid.NewGuid():N}@example.com",
            UserName = $"user_{Guid.NewGuid():N}",
            PasswordHash = "not-a-real-hash",
            DateOfBirth = new DateTime(1990, 1, 1),
        };
        Db.Users.Add(user);
        Db.SaveChanges();
        return user;
    }

    /// <summary>Gives <paramref name="trainerId"/> a licence. Defaults to the
    /// free tier so tests that only care about seats don't have to say so.</summary>
    public TrainerLicence AddLicence(
        Guid trainerId,
        LicenceTier tier = LicenceTier.Free,
        int? seatLimit = null,
        LicenceStatus status = LicenceStatus.Active,
        DateTime? graceEndsAt = null)
    {
        var licence = new TrainerLicence
        {
            TrainerId = trainerId,
            Tier = tier,
            SeatLimit = seatLimit ?? TrainerLicence.FreeSeatLimit,
            Status = status,
            GraceEndsAt = graceEndsAt,
        };
        Db.TrainerLicences.Add(licence);
        Db.SaveChanges();
        return licence;
    }

    /// <summary>Adds a relationship row directly, bypassing the invite flow, so
    /// tests can set up a roster without redeeming codes one at a time.</summary>
    public TrainerClient AddRelationship(
        Guid trainerId,
        Guid? clientId,
        TrainerClientStatus status,
        DateTime? expiresAt = null)
    {
        var rel = new TrainerClient
        {
            TrainerId = trainerId,
            ClientId = clientId,
            Status = status,
            InviteCode = Guid.NewGuid().ToString("N")[..12].ToUpperInvariant(),
            ExpiresAt = expiresAt ?? DateTime.UtcNow.AddDays(7),
            AcceptedAt = status == TrainerClientStatus.Active ? DateTime.UtcNow : null,
        };
        Db.TrainerClients.Add(rel);
        Db.SaveChanges();
        return rel;
    }

    /// <summary>
    /// Logs a meal at an exact instant. Callers pass the value as the app would
    /// have stored it — the client's local midnight converted to UTC — not the
    /// calendar day it represents.
    /// </summary>
    public Meal AddMeal(Guid userId, DateTime storedUtc, string category = "breakfast")
    {
        var meal = new Meal
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Date = storedUtc,
            Category = category,
            FoodItemId = Guid.NewGuid(),
        };
        Db.Meals.Add(meal);
        Db.SaveChanges();
        return meal;
    }

    /// <summary>Adds a food item to a user's catalogue. The nutrition values are
    /// what meal totals are built from, so callers that assert on kcal pass their
    /// own; the rest can leave them defaulted.</summary>
    public FoodItem AddFoodItem(
        Guid userId,
        string name = "Oats",
        int calories = 100,
        int protein = 10,
        int carbs = 20,
        int fat = 5,
        string? extendedNutrientsJson = null)
    {
        var food = new FoodItem
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Name = name,
            Calories = calories,
            Protein = protein,
            Carbs = carbs,
            Fat = fat,
            ExtendedNutrientsJson = extendedNutrientsJson,
        };
        Db.FoodItems.Add(food);
        Db.SaveChanges();
        return food;
    }

    /// <summary>Links a food item into a meal, the way the app's food-entry batch does.</summary>
    public MealFoodEntry AddFoodToMeal(Guid mealId, Guid foodItemId)
    {
        var entry = new MealFoodEntry
        {
            Id = Guid.NewGuid(),
            MealId = mealId,
            FoodItemId = foodItemId,
        };
        Db.MealFoodEntries.Add(entry);
        Db.SaveChanges();
        return entry;
    }

    /// <summary>Fills <paramref name="trainerId"/>'s roster with
    /// <paramref name="count"/> active clients.</summary>
    public void FillRoster(Guid trainerId, int count)
    {
        for (var i = 0; i < count; i++)
        {
            AddRelationship(trainerId, AddUser($"Client{i}").Id, TrainerClientStatus.Active);
        }
    }

    public void Dispose()
    {
        Db.Dispose();
        _connection.Dispose();
    }

    /// <summary>Adds a workout (the template a session is generated from) for a user.</summary>
    public Workout AddWorkout(Guid userId, string name = "Push Day")
    {
        var workout = new Workout { Id = Guid.NewGuid(), UserId = userId, Name = name };
        Db.Workouts.Add(workout);
        Db.SaveChanges();
        return workout;
    }

    /// <summary>Adds a workout plan. Only the active flag and the name matter to the roster.</summary>
    public WorkoutPlan AddPlan(Guid userId, string name, bool isActive, DateTime? createdAt = null)
    {
        var plan = new WorkoutPlan
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Name = name,
            IsActive = isActive,
            CreatedAt = createdAt ?? DateTime.UtcNow,
        };
        Db.WorkoutPlans.Add(plan);
        Db.SaveChanges();
        return plan;
    }

    /// <summary>Schedules a session against a workout on a given date.</summary>
    /// <param name="planId">The plan that generated it, or null for a hand-scheduled session.</param>
    public ScheduledWorkout AddSession(
        Guid workoutId,
        DateTime date,
        bool completed = false,
        bool skipped = false,
        Guid? planId = null)
    {
        var session = new ScheduledWorkout
        {
            Id = Guid.NewGuid(),
            WorkoutId = workoutId,
            WorkoutPlanId = planId,
            ScheduledDate = date,
            CreatedAt = DateTime.UtcNow,
            IsCompleted = completed,
            IsSkipped = skipped,
        };
        Db.ScheduledWorkouts.Add(session);
        Db.SaveChanges();
        return session;
    }

    /// <summary>Logs a set against a session, so it counts as work the client engaged with.</summary>
    public WorkoutSet AddLoggedSet(
        Guid sessionId,
        Guid workoutExerciseId,
        int setNumber = 1,
        double? weight = null,
        bool completed = true)
    {
        var entry = new ScheduledWorkoutExercise
        {
            Id = Guid.NewGuid(),
            ScheduledWorkoutId = sessionId,
            WorkoutExerciseId = workoutExerciseId,
            IsCompleted = completed,
        };
        Db.ScheduledWorkoutExercises.Add(entry);

        var set = new WorkoutSet
        {
            Id = Guid.NewGuid(),
            ScheduledWorkoutExerciseId = entry.Id,
            SetNumber = setNumber,
            Weight = weight,
            IsCompleted = completed,
        };
        Db.WorkoutSets.Add(set);
        Db.SaveChanges();
        return set;
    }

    /// <summary>Adds an exercise entry to a workout, which sessions then log sets against.</summary>
    public WorkoutExercise AddWorkoutExercise(Guid workoutId, Guid exerciseId, int orderPosition = 0)
    {
        var entry = new WorkoutExercise
        {
            Id = Guid.NewGuid(),
            WorkoutId = workoutId,
            ExerciseId = exerciseId,
            OrderPosition = orderPosition,
        };
        Db.WorkoutExercises.Add(entry);
        Db.SaveChanges();
        return entry;
    }

}
