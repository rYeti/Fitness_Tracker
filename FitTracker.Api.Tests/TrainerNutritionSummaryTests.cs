using FitTracker.Api.Models;
using FitTracker.Api.Repositories;
using FitTracker.Api.Services;
using Xunit;

namespace FitTracker.Api.Tests;

/// <summary>
/// What the Trainer Console's Nutrition tab shows a client ate, and specifically why
/// it showed two of every meal.
///
/// Nothing here is a query or a type error: every row is a legitimate meal row with a
/// valid owner. The mistake is that "one meal per category per day" was only ever an
/// assumption held by the client app — it looks a meal up by day and category before
/// adding food to it, and renders four fixed sections — while the database happily
/// stored a second row for the same pair, and the console listed rows raw. The client
/// could not see its own duplicates; the trainer saw nothing else.
/// </summary>
public class TrainerNutritionSummaryTests : IDisposable
{
    /// <summary>21 Aug for a client in Berlin: local midnight, stored converted.</summary>
    private static readonly DateTime StoredOnTheTwentyFirst = new(2026, 8, 20, 22, 0, 0, DateTimeKind.Utc);
    private static readonly DateTime TheTwentyFirst = new(2026, 8, 21);

    private readonly DbFixture _fx = new();
    private readonly TrainerConsoleService _console;
    private readonly Guid _trainerId;
    private readonly Guid _clientId;

    public TrainerNutritionSummaryTests()
    {
        _trainerId = _fx.AddUser("Dana", "Whitfield").Id;
        _clientId = _fx.AddUser("Marco", "Fenn").Id;
        _fx.AddRelationship(_trainerId, _clientId, TrainerClientStatus.Active);

        _console = new TrainerConsoleService(
            new ActiveRelationshipStub(_trainerId, _clientId),
            null!,
            null!,
            null!,
            new MealService(new MealRepository(_fx.Db)),
            new UserSettingsService(new UserSettingsRepository(_fx.Db)),
            null!,
            new FoodItemService(new FoodItemRepository(_fx.Db)),
            null!);
    }

    public void Dispose() => _fx.Dispose();

    [Fact]
    public async Task TwoRowsForTheSameCategoryAreOneMeal()
    {
        var oats = _fx.AddFoodItem(_clientId, "Oats", calories: 320);
        var berries = _fx.AddFoodItem(_clientId, "Blueberries", calories: 80);

        // The shape a re-pushed meal leaves behind: same day, same category, the
        // foods split across the two rows.
        var first = _fx.AddMeal(_clientId, StoredOnTheTwentyFirst, "Breakfast");
        var repushed = _fx.AddMeal(_clientId, StoredOnTheTwentyFirst, "Breakfast");
        _fx.AddFoodToMeal(first.Id, oats.Id);
        _fx.AddFoodToMeal(repushed.Id, berries.Id);

        var summary = await _console.GetClientNutritionSummaryAsync(_trainerId, _clientId, TheTwentyFirst);

        var meal = Assert.Single(summary!.LoggedMeals);
        // Order across two folded rows isn't meaningful — that both foods survive is.
        Assert.Equal(new[] { "Blueberries", "Oats" }, meal.FoodNames.OrderBy(n => n).ToArray());
        Assert.Equal(400, meal.Calories);
    }

    [Fact]
    public async Task TheSnackCategoryRenameIsStillOneMeal()
    {
        var nuts = _fx.AddFoodItem(_clientId, "Almonds", calories: 180);
        var yoghurt = _fx.AddFoodItem(_clientId, "Yoghurt", calories: 120);

        // "Snack" is what the app wrote before the category was renamed "Snacks";
        // rows from either side of that rename are the same meal of the day.
        var old = _fx.AddMeal(_clientId, StoredOnTheTwentyFirst, "Snack");
        var current = _fx.AddMeal(_clientId, StoredOnTheTwentyFirst, "Snacks");
        _fx.AddFoodToMeal(old.Id, nuts.Id);
        _fx.AddFoodToMeal(current.Id, yoghurt.Id);

        var summary = await _console.GetClientNutritionSummaryAsync(_trainerId, _clientId, TheTwentyFirst);

        Assert.Equal(300, Assert.Single(summary!.LoggedMeals).Calories);
    }

    [Fact]
    public async Task DifferentCategoriesAreStillDifferentMeals()
    {
        var oats = _fx.AddFoodItem(_clientId, "Oats", calories: 320);
        var salmon = _fx.AddFoodItem(_clientId, "Salmon", calories: 480);

        _fx.AddFoodToMeal(_fx.AddMeal(_clientId, StoredOnTheTwentyFirst, "Breakfast").Id, oats.Id);
        _fx.AddFoodToMeal(_fx.AddMeal(_clientId, StoredOnTheTwentyFirst, "Dinner").Id, salmon.Id);

        var summary = await _console.GetClientNutritionSummaryAsync(_trainerId, _clientId, TheTwentyFirst);

        Assert.Equal(2, summary!.LoggedMeals.Count);
    }

    [Fact]
    public async Task FoldingTheRowsTogetherDoesNotChangeTheDayTotal()
    {
        var oats = _fx.AddFoodItem(_clientId, "Oats", calories: 320, protein: 12, carbs: 54, fat: 6);
        var eggs = _fx.AddFoodItem(_clientId, "Eggs", calories: 160, protein: 14, carbs: 1, fat: 11);

        _fx.AddFoodToMeal(_fx.AddMeal(_clientId, StoredOnTheTwentyFirst, "Breakfast").Id, oats.Id);
        _fx.AddFoodToMeal(_fx.AddMeal(_clientId, StoredOnTheTwentyFirst, "Breakfast").Id, eggs.Id);

        var summary = await _console.GetClientNutritionSummaryAsync(_trainerId, _clientId, TheTwentyFirst);

        // The duplicate rows never inflated the totals, and folding them must not
        // deflate them either: both foods were eaten.
        Assert.Equal(480, summary!.TotalCalories);
        Assert.Equal(26, summary.Macros.Protein);
        Assert.Equal(55, summary.Macros.Carbs);
        Assert.Equal(17, summary.Macros.Fat);
    }

    [Fact]
    public async Task TheSameCategoryOnTheNextDayIsItsOwnMeal()
    {
        var oats = _fx.AddFoodItem(_clientId, "Oats", calories: 320);

        _fx.AddFoodToMeal(_fx.AddMeal(_clientId, StoredOnTheTwentyFirst, "Breakfast").Id, oats.Id);
        _fx.AddFoodToMeal(_fx.AddMeal(_clientId, StoredOnTheTwentyFirst.AddDays(1), "Breakfast").Id, oats.Id);

        var summary = await _console.GetClientNutritionSummaryAsync(_trainerId, _clientId, TheTwentyFirst);

        Assert.Equal(320, Assert.Single(summary!.LoggedMeals).Calories);
    }

    [Fact]
    public async Task AClientTheTrainerDoesNotTrainIsRefused()
    {
        var stranger = _fx.AddUser().Id;

        Assert.Null(await _console.GetClientNutritionSummaryAsync(_trainerId, stranger, TheTwentyFirst));
    }
}
