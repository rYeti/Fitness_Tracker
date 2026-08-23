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

    public DbFixture()
    {
        _connection = new SqliteConnection("DataSource=:memory:");
        _connection.Open();

        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseSqlite(_connection)
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
        int fat = 5)
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
}
