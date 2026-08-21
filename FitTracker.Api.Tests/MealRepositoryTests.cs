using FitTracker.Api.Repositories;
using Xunit;

namespace FitTracker.Api.Tests;

/// <summary>
/// Which calendar day a stored meal is returned for.
///
/// The Trainer Console's nutrition tab read the wrong day for every client not
/// sitting on UTC: meals are logged against local midnight and stored converted,
/// so a German client's "21 Aug" lives at 2026-08-20T22:00Z and a midnight-to-
/// midnight window missed it entirely. These pin the corrected attribution.
///
/// SQLite round-trips DateTime as text and does not preserve Kind, so these
/// assert on values only — Kind is covered in <see cref="MealDayWindowTests"/>.
/// </summary>
public class MealRepositoryTests : IDisposable
{
    private readonly DbFixture _fx = new();
    private readonly MealRepository _repository;

    public MealRepositoryTests()
    {
        _repository = new MealRepository(_fx.Db);
    }

    public void Dispose() => _fx.Dispose();

    [Fact]
    public async Task AMealLoggedInUtcPlusTwoBelongsToTheDayTheClientLoggedIt()
    {
        var user = _fx.AddUser();
        // 21 Aug for a client in Berlin: local midnight, uploaded as UTC.
        _fx.AddMeal(user.Id, new DateTime(2026, 8, 20, 22, 0, 0, DateTimeKind.Utc));

        var onTheTwentyFirst = await _repository.GetMealsForDateAsync(user.Id, new DateTime(2026, 8, 21));
        var onTheTwentieth = await _repository.GetMealsForDateAsync(user.Id, new DateTime(2026, 8, 20));

        // Before the fix this was exactly backwards.
        Assert.Single(onTheTwentyFirst);
        Assert.Empty(onTheTwentieth);
    }

    [Fact]
    public async Task AMealLoggedWestOfUtcAlsoBelongsToItsOwnDay()
    {
        var user = _fx.AddUser();
        // 21 Aug in New York: local midnight is 05:00Z the same morning.
        _fx.AddMeal(user.Id, new DateTime(2026, 8, 21, 5, 0, 0, DateTimeKind.Utc));

        var onTheTwentyFirst = await _repository.GetMealsForDateAsync(user.Id, new DateTime(2026, 8, 21));
        var onTheTwentySecond = await _repository.GetMealsForDateAsync(user.Id, new DateTime(2026, 8, 22));

        Assert.Single(onTheTwentyFirst);
        Assert.Empty(onTheTwentySecond);
    }

    [Fact]
    public async Task NeighbouringDaysDoNotBleedIntoEachOther()
    {
        var user = _fx.AddUser();
        _fx.AddMeal(user.Id, new DateTime(2026, 8, 19, 22, 0, 0, DateTimeKind.Utc), "breakfast"); // 20 Aug
        _fx.AddMeal(user.Id, new DateTime(2026, 8, 20, 22, 0, 0, DateTimeKind.Utc), "lunch");     // 21 Aug
        _fx.AddMeal(user.Id, new DateTime(2026, 8, 21, 22, 0, 0, DateTimeKind.Utc), "dinner");    // 22 Aug

        var meals = await _repository.GetMealsForDateAsync(user.Id, new DateTime(2026, 8, 21));

        Assert.Equal("lunch", Assert.Single(meals).Category);
    }

    [Fact]
    public async Task ARangeReturnsEveryDayInTheSpanAndNothingOutsideIt()
    {
        var user = _fx.AddUser();
        // Seven consecutive days for a UTC+2 client, plus one on either side.
        for (var i = -1; i <= 7; i++)
        {
            _fx.AddMeal(user.Id, new DateTime(2026, 8, 14, 22, 0, 0, DateTimeKind.Utc).AddDays(i));
        }

        var meals = await _repository.GetMealsInRangeAsync(
            user.Id, new DateTime(2026, 8, 15), new DateTime(2026, 8, 21));

        // The trend groups by day, so each one has to land in its own bucket.
        var days = meals.Select(m => MealDayWindow.DayOf(m.Date)).OrderBy(d => d).ToList();
        Assert.Equal(
            Enumerable.Range(0, 7).Select(i => new DateTime(2026, 8, 15, 0, 0, 0, DateTimeKind.Utc).AddDays(i)),
            days);
    }

    [Fact]
    public async Task MealsBelongingToAnotherUserAreNeverReturned()
    {
        var user = _fx.AddUser();
        var other = _fx.AddUser();
        _fx.AddMeal(other.Id, new DateTime(2026, 8, 20, 22, 0, 0, DateTimeKind.Utc));

        var meals = await _repository.GetMealsForDateAsync(user.Id, new DateTime(2026, 8, 21));

        Assert.Empty(meals);
    }
}
