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
            null!,
            new TrainerNutrientPinRepository(_fx.Db));
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
    public async Task ARowThatIsAnExactRepushIsDropped()
    {
        var oats = _fx.AddFoodItem(_clientId, "Oats", calories: 320);
        var berries = _fx.AddFoodItem(_clientId, "Blueberries", calories: 80);

        // Not the split-foods shape above — a second row holding the *same* foods as
        // the first, the shape a reconcile pass or a second device leaves behind.
        var first = _fx.AddMeal(_clientId, StoredOnTheTwentyFirst, "Breakfast");
        _fx.AddFoodToMeal(first.Id, oats.Id);
        _fx.AddFoodToMeal(first.Id, berries.Id);
        var repushed = _fx.AddMeal(_clientId, StoredOnTheTwentyFirst, "Breakfast");
        _fx.AddFoodToMeal(repushed.Id, oats.Id);
        _fx.AddFoodToMeal(repushed.Id, berries.Id);

        var summary = await _console.GetClientNutritionSummaryAsync(_trainerId, _clientId, TheTwentyFirst);

        var meal = Assert.Single(summary!.LoggedMeals);
        // The repushed row is dropped whole, not merged food-by-food — merging would
        // have doubled the totals right back up.
        Assert.Equal(new[] { "Blueberries", "Oats" }, meal.FoodNames.OrderBy(n => n).ToArray());
        Assert.Equal(400, meal.Calories);
        Assert.Equal(400, summary.TotalCalories);
    }

    [Fact]
    public async Task ARealSecondPortionInOneRowIsNeverCollapsed()
    {
        var oats = _fx.AddFoodItem(_clientId, "Oats", calories: 320);

        // Two entries for the same food in one row is a client logging two portions —
        // real, and never something the fold is allowed to treat as a duplicate.
        var meal = _fx.AddMeal(_clientId, StoredOnTheTwentyFirst, "Breakfast");
        _fx.AddFoodToMeal(meal.Id, oats.Id);
        _fx.AddFoodToMeal(meal.Id, oats.Id);

        var summary = await _console.GetClientNutritionSummaryAsync(_trainerId, _clientId, TheTwentyFirst);

        var logged = Assert.Single(summary!.LoggedMeals);
        Assert.Equal(2, logged.Foods.Count);
        Assert.Equal(640, logged.Calories);
    }

    [Fact]
    public async Task TheTrendBarForTheRequestedDayMatchesTheFoldedTotal()
    {
        var oats = _fx.AddFoodItem(_clientId, "Oats", calories: 320);

        var first = _fx.AddMeal(_clientId, StoredOnTheTwentyFirst, "Breakfast");
        _fx.AddFoodToMeal(first.Id, oats.Id);
        var repushed = _fx.AddMeal(_clientId, StoredOnTheTwentyFirst, "Breakfast");
        _fx.AddFoodToMeal(repushed.Id, oats.Id);

        var summary = await _console.GetClientNutritionSummaryAsync(_trainerId, _clientId, TheTwentyFirst);

        // The ring (TotalCalories) and the trend bar for the same day are built from
        // two different code paths; a fix that only touched one used to leave them
        // disagreeing by exactly the duplicate's worth of calories.
        var todaysBar = summary!.SevenDayTrend.Single(d => d.Date == TheTwentyFirst);
        Assert.Equal(320, summary.TotalCalories);
        Assert.Equal(320, todaysBar.TotalCalories);
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

    // ── Micronutrients ────────────────────────────────────────────────────

    [Fact]
    public async Task MicronutrientsSumAcrossFoodsInAMealAndAcrossMeals()
    {
        var oats = _fx.AddFoodItem(_clientId, "Oats", calories: 320,
            extendedNutrientsJson: """{"fiber":0.0093,"iron":0.00516}""");
        var berries = _fx.AddFoodItem(_clientId, "Blueberries", calories: 80,
            extendedNutrientsJson: """{"fiber":0.0024,"vitaminC":0.0098}""");
        var salad = _fx.AddFoodItem(_clientId, "Salad", calories: 60,
            extendedNutrientsJson: """{"vitaminC":0.018}""");

        var breakfast = _fx.AddMeal(_clientId, StoredOnTheTwentyFirst, "Breakfast");
        _fx.AddFoodToMeal(breakfast.Id, oats.Id);
        _fx.AddFoodToMeal(breakfast.Id, berries.Id);
        _fx.AddFoodToMeal(_fx.AddMeal(_clientId, StoredOnTheTwentyFirst, "Lunch").Id, salad.Id);

        var summary = await _console.GetClientNutritionSummaryAsync(_trainerId, _clientId, TheTwentyFirst);

        Assert.False(summary!.MicronutrientsLocked);
        // Breakfast: oats' fibre + blueberries' fibre; lunch never reported any.
        Assert.Equal(0.0117, summary.Micronutrients!.Fiber!.Value, precision: 6);
        // Blueberries' vitamin C + salad's, across two different meals.
        Assert.Equal(0.0278, summary.Micronutrients.VitaminC!.Value, precision: 6);
        Assert.Equal(0.00516, summary.Micronutrients.Iron!.Value, precision: 6);
    }

    [Fact]
    public async Task AnUnreportedNutrientStaysNullNotZero()
    {
        // Not one food today reports zinc — the day total must say "unknown",
        // not "0 mg", or a trainer reads a real deficiency signal into a food
        // catalogue gap.
        var oats = _fx.AddFoodItem(_clientId, "Oats", calories: 320,
            extendedNutrientsJson: """{"fiber":0.0093}""");
        _fx.AddFoodToMeal(_fx.AddMeal(_clientId, StoredOnTheTwentyFirst, "Breakfast").Id, oats.Id);

        var summary = await _console.GetClientNutritionSummaryAsync(_trainerId, _clientId, TheTwentyFirst);

        Assert.NotNull(summary!.Micronutrients);
        Assert.Null(summary.Micronutrients!.Zinc);
    }

    [Fact]
    public async Task ADayWithNoMicronutrientDataAtAllIsNullNotAnEmptyObject()
    {
        var oats = _fx.AddFoodItem(_clientId, "Oats", calories: 320); // no blob at all
        _fx.AddFoodToMeal(_fx.AddMeal(_clientId, StoredOnTheTwentyFirst, "Breakfast").Id, oats.Id);

        var summary = await _console.GetClientNutritionSummaryAsync(_trainerId, _clientId, TheTwentyFirst);

        Assert.Null(summary!.Micronutrients);
        Assert.Null(Assert.Single(summary.LoggedMeals).Micronutrients);
        Assert.Null(Assert.Single(Assert.Single(summary.LoggedMeals).Foods).Micronutrients);
    }

    [Fact]
    public async Task AMalformedBlobIsSkippedNotFatal()
    {
        var good = _fx.AddFoodItem(_clientId, "Oats", calories: 320,
            extendedNutrientsJson: """{"fiber":0.0093}""");
        var bad = _fx.AddFoodItem(_clientId, "Mystery bar", calories: 200,
            extendedNutrientsJson: "{not valid json");

        var breakfast = _fx.AddMeal(_clientId, StoredOnTheTwentyFirst, "Breakfast");
        _fx.AddFoodToMeal(breakfast.Id, good.Id);
        _fx.AddFoodToMeal(breakfast.Id, bad.Id);

        // Must not throw, and the good food's data must still come through.
        var summary = await _console.GetClientNutritionSummaryAsync(_trainerId, _clientId, TheTwentyFirst);

        Assert.Equal(0.0093, summary!.Micronutrients!.Fiber!.Value, precision: 6);
    }

    [Fact]
    public async Task RepushedMealRowsDoNotDoubleTheMicronutrientTotal()
    {
        var oats = _fx.AddFoodItem(_clientId, "Oats", calories: 320,
            extendedNutrientsJson: """{"fiber":0.0093}""");
        var berries = _fx.AddFoodItem(_clientId, "Blueberries", calories: 80,
            extendedNutrientsJson: """{"fiber":0.0024}""");

        // Same shape as TwoRowsForTheSameCategoryAreOneMeal: a re-pushed meal,
        // foods split across the two rows for the same category and day.
        var first = _fx.AddMeal(_clientId, StoredOnTheTwentyFirst, "Breakfast");
        var repushed = _fx.AddMeal(_clientId, StoredOnTheTwentyFirst, "Breakfast");
        _fx.AddFoodToMeal(first.Id, oats.Id);
        _fx.AddFoodToMeal(repushed.Id, berries.Id);

        var summary = await _console.GetClientNutritionSummaryAsync(_trainerId, _clientId, TheTwentyFirst);

        // 0.0093 + 0.0024, once each — never doubled by the fold.
        Assert.Equal(0.0117, summary!.Micronutrients!.Fiber!.Value, precision: 6);
    }

    [Fact]
    public async Task LockedWhenTheTrainerIsNotEntitled()
    {
        var oats = _fx.AddFoodItem(_clientId, "Oats", calories: 320,
            extendedNutrientsJson: """{"fiber":0.0093}""");
        _fx.AddFoodToMeal(_fx.AddMeal(_clientId, StoredOnTheTwentyFirst, "Breakfast").Id, oats.Id);

        var lockedConsole = new TrainerConsoleService(
            new ActiveRelationshipStub(_trainerId, _clientId, grantsPro: false),
            null!, null!, null!,
            new MealService(new MealRepository(_fx.Db)),
            new UserSettingsService(new UserSettingsRepository(_fx.Db)),
            null!,
            new FoodItemService(new FoodItemRepository(_fx.Db)),
            null!,
            new TrainerNutrientPinRepository(_fx.Db));

        var summary = await lockedConsole.GetClientNutritionSummaryAsync(_trainerId, _clientId, TheTwentyFirst);

        Assert.True(summary!.MicronutrientsLocked);
        // Absent from the payload, not merely a hint the client should hide it.
        Assert.Null(summary.Micronutrients);
        Assert.Null(Assert.Single(summary.LoggedMeals).Micronutrients);
        Assert.Null(Assert.Single(Assert.Single(summary.LoggedMeals).Foods).Micronutrients);
    }

    [Fact]
    public async Task PinnedNutrientsDefaultWhenNoneAreSaved()
    {
        var summary = await _console.GetClientNutritionSummaryAsync(_trainerId, _clientId, TheTwentyFirst);

        Assert.Equal(new[] { "fibre", "sugar", "sodium" }, summary!.PinnedNutrients);
    }
}
