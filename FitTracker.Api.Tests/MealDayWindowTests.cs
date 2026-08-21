using FitTracker.Api.Repositories;
using Xunit;

namespace FitTracker.Api.Tests;

/// <summary>
/// How a calendar day maps onto the instants <c>Meal.Date</c> is stored as.
///
/// These are regression tests for a bug that shipped: the Trainer Console's
/// nutrition tab returned 500 for every client and every date, because the day
/// bounds reached Npgsql with <see cref="DateTimeKind.Unspecified"/> — which it
/// refuses to write to a <c>timestamp with time zone</c> column. The SQLite test
/// fixture accepts Unspecified happily, so nothing below a direct assertion on
/// Kind can catch that; hence <see cref="BoundsAreAlwaysUtc"/>.
/// </summary>
public class MealDayWindowTests
{
    // ── The 500 ─────────────────────────────────────────────────────────────

    [Theory]
    [InlineData(DateTimeKind.Unspecified)] // what [FromQuery] DateTime binds to
    [InlineData(DateTimeKind.Local)]
    [InlineData(DateTimeKind.Utc)]
    public void BoundsAreAlwaysUtc(DateTimeKind kind)
    {
        var day = DateTime.SpecifyKind(new DateTime(2026, 8, 21), kind);

        var (start, end) = MealDayWindow.ForRange(day, day);

        Assert.Equal(DateTimeKind.Utc, start.Kind);
        Assert.Equal(DateTimeKind.Utc, end.Kind);
    }

    [Fact]
    public void BoundsIgnoreTheCallersOffset()
    {
        // .Date on a Local value truncates in local time, which would slide the
        // window by however far the server happens to be from UTC.
        var asLocal = DateTime.SpecifyKind(new DateTime(2026, 8, 21, 23, 30, 0), DateTimeKind.Local);
        var asUnspecified = new DateTime(2026, 8, 21, 4, 15, 0);

        Assert.Equal(MealDayWindow.ForRange(asUnspecified, asUnspecified), MealDayWindow.ForRange(asLocal, asLocal));
    }

    [Fact]
    public void ADayIsTwentyFourHoursCentredOnItsUtcMidnight()
    {
        var (start, end) = MealDayWindow.ForRange(new DateTime(2026, 8, 21), new DateTime(2026, 8, 21));

        Assert.Equal(new DateTime(2026, 8, 20, 12, 0, 0, DateTimeKind.Utc), start);
        Assert.Equal(new DateTime(2026, 8, 21, 12, 0, 0, DateTimeKind.Utc), end);
    }

    [Fact]
    public void ARangeSpansFromTheFirstDaysStartToTheLastDaysEnd()
    {
        var (start, end) = MealDayWindow.ForRange(new DateTime(2026, 8, 15), new DateTime(2026, 8, 21));

        Assert.Equal(new DateTime(2026, 8, 14, 12, 0, 0, DateTimeKind.Utc), start);
        Assert.Equal(new DateTime(2026, 8, 21, 12, 0, 0, DateTimeKind.Utc), end);
    }

    // ── Which day a stored meal belongs to ──────────────────────────────────

    [Theory]
    // The app logs against local midnight and uploads it as UTC, so the stored
    // instant is the day's midnight shifted by the client's offset. Each row is
    // "21 Aug" as it lands in the column for a client at that offset.
    [InlineData(20, 22, 0)]  // UTC+2 — Germany, the reported case
    [InlineData(20, 23, 0)]  // UTC+1
    [InlineData(21, 0, 0)]   // UTC
    [InlineData(21, 5, 0)]   // UTC-5
    [InlineData(21, 5, 30)]  // UTC-5:30 — half-hour offsets exist too
    [InlineData(20, 12, 0)]  // UTC+12 — the far edge that still resolves
    [InlineData(21, 11, 0)]  // UTC-11 — the other far edge
    public void AStoredInstantResolvesToTheDayItWasLoggedAgainst(int day, int hour, int minute)
    {
        var stored = new DateTime(2026, 8, day, hour, minute, 0, DateTimeKind.Utc);

        Assert.Equal(new DateTime(2026, 8, 21, 0, 0, 0, DateTimeKind.Utc), MealDayWindow.DayOf(stored));
    }

    [Fact]
    public void ARequestedDayNormalisesToTheKeyItsMealsAreBucketedUnder()
    {
        // DayFor and DayOf have to agree, or the summary looks up an empty bucket.
        var requested = new DateTime(2026, 8, 21); // as [FromQuery] binds "2026-08-21"
        var storedForThatDay = new DateTime(2026, 8, 20, 22, 0, 0, DateTimeKind.Utc);

        Assert.Equal(MealDayWindow.DayOf(storedForThatDay), MealDayWindow.DayFor(requested));
    }

    [Fact]
    public void TheWindowStartBelongsToItsOwnDayAndTheEndToTheNext()
    {
        var (start, end) = MealDayWindow.ForRange(new DateTime(2026, 8, 21), new DateTime(2026, 8, 21));

        Assert.Equal(new DateTime(2026, 8, 21, 0, 0, 0, DateTimeKind.Utc), MealDayWindow.DayOf(start));
        Assert.Equal(new DateTime(2026, 8, 22, 0, 0, 0, DateTimeKind.Utc), MealDayWindow.DayOf(end));
    }

    [Fact]
    public void UtcPlusThirteenIsAttributedToThePreviousDay()
    {
        // Documenting the known gap rather than pretending it isn't there: New
        // Zealand during DST, Samoa and Kiribati land a day early. Closing it
        // means storing the date as a `date` column instead of a timestamp.
        var loggedInAuckland = new DateTime(2026, 8, 20, 11, 0, 0, DateTimeKind.Utc);

        Assert.Equal(new DateTime(2026, 8, 20, 0, 0, 0, DateTimeKind.Utc), MealDayWindow.DayOf(loggedInAuckland));
    }
}
