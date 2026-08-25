using FitTracker.Api.DTOs;
using FitTracker.Api.Repositories;
using FitTracker.Api.Services;
using Xunit;

namespace FitTracker.Api.Tests;

/// <summary>
/// What happens when the app posts a meal it has already posted.
///
/// Its sync does that for reasons that have nothing to do with the user logging
/// anything twice: the reconcile pass clears a local serverId whenever the server row
/// looks gone, a second device pushes its own copy of the same day, and a response
/// lost after the row was written leaves the meal pending. Each of those used to add
/// a row. Nothing in the app could show it — it reads one meal per day and category —
/// so the rows accumulated silently until the Trainer Console listed them.
/// </summary>
public class MealCreationTests : IDisposable
{
    /// <summary>21 Aug for a client in Berlin: local midnight, stored converted.</summary>
    private static readonly DateTime StoredOnTheTwentyFirst = new(2026, 8, 20, 22, 0, 0, DateTimeKind.Utc);

    private readonly DbFixture _fx = new();
    private readonly MealService _meals;

    public MealCreationTests()
    {
        _meals = new MealService(new MealRepository(_fx.Db));
    }

    public void Dispose() => _fx.Dispose();

    private Task<MealResponseDto> Log(Guid userId, DateTime storedDate, string category) =>
        _meals.CreateMealAsync(new MealRequestDto
        {
            Date = storedDate,
            Category = category,
            FoodItemId = Guid.NewGuid(),
        }, userId);

    [Fact]
    public async Task PostingTheSameMealTwiceReturnsTheFirstRow()
    {
        var user = _fx.AddUser();

        var first = await Log(user.Id, StoredOnTheTwentyFirst, "Breakfast");
        var second = await Log(user.Id, StoredOnTheTwentyFirst, "Breakfast");

        Assert.Equal(first.Id, second.Id);
        Assert.Single(_fx.Db.Meals.ToList());
    }

    [Fact]
    public async Task ADeviceInAnotherTimezoneStillFindsTheSameDaysMeal()
    {
        var user = _fx.AddUser();

        // Same 21 Aug, logged from a phone in Berlin and a browser in New York.
        var berlin = await Log(user.Id, StoredOnTheTwentyFirst, "Breakfast");
        var newYork = await Log(user.Id, new DateTime(2026, 8, 21, 4, 0, 0, DateTimeKind.Utc), "Breakfast");

        Assert.Equal(berlin.Id, newYork.Id);
    }

    [Fact]
    public async Task TheSnackCategoryRenameDoesNotStartASecondRow()
    {
        var user = _fx.AddUser();

        var beforeRename = await Log(user.Id, StoredOnTheTwentyFirst, "Snack");
        var afterRename = await Log(user.Id, StoredOnTheTwentyFirst, "Snacks");

        Assert.Equal(beforeRename.Id, afterRename.Id);
    }

    [Fact]
    public async Task AnotherCategoryOnTheSameDayIsItsOwnMeal()
    {
        var user = _fx.AddUser();

        var breakfast = await Log(user.Id, StoredOnTheTwentyFirst, "Breakfast");
        var lunch = await Log(user.Id, StoredOnTheTwentyFirst, "Lunch");

        Assert.NotEqual(breakfast.Id, lunch.Id);
        Assert.Equal(2, _fx.Db.Meals.Count());
    }

    [Fact]
    public async Task TheSameCategoryOnTheNextDayIsItsOwnMeal()
    {
        var user = _fx.AddUser();

        var today = await Log(user.Id, StoredOnTheTwentyFirst, "Breakfast");
        var tomorrow = await Log(user.Id, StoredOnTheTwentyFirst.AddDays(1), "Breakfast");

        Assert.NotEqual(today.Id, tomorrow.Id);
    }

    [Fact]
    public async Task UpdatingAMealReturnsTheFoodItStillHolds()
    {
        var user = _fx.AddUser();
        var meal = await Log(user.Id, StoredOnTheTwentyFirst, "Breakfast");
        var oats = _fx.AddFoodItem(user.Id, "Oats");
        _fx.AddFoodToMeal(meal.Id, oats.Id);

        var updated = await _meals.UpdateMealAsync(meal.Id, user.Id, new MealRequestDto
        {
            Date = StoredOnTheTwentyFirst,
            Category = "Breakfast",
            FoodItemId = oats.Id,
        });

        // The client reconciles its own entries against this list, and an unloaded
        // collection serialises as an empty one — which reads as "the server holds
        // no food for this meal" and re-pushes every entry it already has.
        Assert.Equal(oats.Id, Assert.Single(updated!.FoodEntries).FoodItemId);
    }

    [Fact]
    public async Task AnotherUsersMealIsNeverReused()
    {
        var user = _fx.AddUser();
        var other = _fx.AddUser();

        var theirs = await Log(other.Id, StoredOnTheTwentyFirst, "Breakfast");
        var ours = await Log(user.Id, StoredOnTheTwentyFirst, "Breakfast");

        Assert.NotEqual(theirs.Id, ours.Id);
    }
}
