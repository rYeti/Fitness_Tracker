namespace FitTracker.Api.Repositories;

/// <summary>
/// Translates between a calendar day and the instants <see cref="Models.Meal.Date"/>
/// is actually stored as.
///
/// <para>
/// A meal's date is a <em>day marker</em>, not a moment: the app logs against local
/// midnight and uploads it converted to UTC, so "21 Aug" for a client in UTC+2 lands
/// in the column as <c>2026-08-20T22:00:00Z</c>. Selecting
/// <c>[day 00:00Z, day+1 00:00Z)</c> therefore misses that meal and picks up the
/// following day's instead — wrong by a full day for anyone not sitting on UTC.
/// </para>
///
/// <para>
/// Since the stored value is always some zone's midnight, centring the window on the
/// day — <c>[day 00:00Z − 12h, day 00:00Z + 12h)</c> — is equivalent to rounding the
/// stored instant to the nearest UTC midnight, and recovers the intended day for every
/// UTC offset from −11:59 through +12:00. It attributes UTC+13/+14 (New Zealand during
/// DST, Samoa, Kiribati) to the previous day; removing that last gap means storing the
/// date as a real <c>date</c> column rather than a timestamp.
/// </para>
///
/// <para>
/// Both bounds are returned with <see cref="DateTimeKind.Utc"/> deliberately. Npgsql
/// refuses to write a <see cref="DateTimeKind.Unspecified"/> value to a
/// <c>timestamp with time zone</c> column, so a query built from a raw
/// <c>[FromQuery] DateTime</c> throws at execution time.
/// </para>
/// </summary>
public static class MealDayWindow
{
    /// <summary>Half-width of the window: the largest UTC offset it can recover.</summary>
    private const int OffsetToleranceHours = 12;

    /// <summary>
    /// Normalises a requested day — a bound <c>[FromQuery] DateTime</c>, say — to the
    /// UTC midnight the buckets from <see cref="DayOf"/> are keyed on.
    /// </summary>
    public static DateTime DayFor(DateTime day) => MidnightUtc(day);

    /// <summary>
    /// The half-open instant range holding the meals logged between
    /// <paramref name="firstDay"/> and <paramref name="lastDay"/>, both inclusive.
    /// </summary>
    public static (DateTime Start, DateTime End) ForRange(DateTime firstDay, DateTime lastDay) =>
        (MidnightUtc(firstDay).AddHours(-OffsetToleranceHours),
         MidnightUtc(lastDay).AddHours(OffsetToleranceHours));

    /// <summary>
    /// The calendar day a stored meal instant belongs to — the inverse of
    /// <see cref="ForRange"/>, for bucketing a range query back into days.
    /// </summary>
    public static DateTime DayOf(DateTime storedDate) =>
        MidnightUtc(storedDate.AddHours(OffsetToleranceHours));

    // Takes the calendar fields rather than DateTime.Date so the result doesn't depend
    // on the caller's Kind: .Date on a Local value truncates in local time, which would
    // shift the window by the server's own offset.
    private static DateTime MidnightUtc(DateTime value) =>
        new(value.Year, value.Month, value.Day, 0, 0, 0, DateTimeKind.Utc);
}
