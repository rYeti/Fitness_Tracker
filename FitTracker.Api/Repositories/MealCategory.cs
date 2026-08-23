namespace FitTracker.Api.Repositories;

/// <summary>
/// When two meal rows describe the same meal.
///
/// <para>
/// A meal is one row per category per day everywhere the product actually
/// behaves: the app looks a meal up by day and category before adding food to
/// it, its nutrition screen renders four fixed sections, and its local
/// de-duplication keys on exactly that pair. The database has never enforced
/// it, so the comparison has to live somewhere — this is that somewhere, shared
/// by the write path (which refuses to create a second row) and the Trainer
/// Console read (which folds any that already exist back together).
/// </para>
///
/// <para>
/// Matching is normalising rather than exact for two reasons. The app writes
/// <c>"Breakfast"</c> while this API's own DTOs document <c>"breakfast"</c>, so
/// case can differ between rows written by different builds. And the snack
/// category was renamed <c>"Snack"</c> → <c>"Snacks"</c> once already —
/// <c>MealTemplateDao</c> still migrates the old spelling on read — which means
/// a client logging a snack after that rename could not see the row it wrote
/// before it, and added a second one.
/// </para>
/// </summary>
public static class MealCategory
{
    /// <summary>The value two categories are compared on. Not persisted or sent
    /// anywhere: rows keep the spelling the client authored.</summary>
    public static string Key(string? category)
    {
        var normalised = (category ?? string.Empty).Trim().ToLowerInvariant();
        return normalised == "snacks" ? "snack" : normalised;
    }

    /// <summary>Whether two stored categories name the same meal of the day.</summary>
    public static bool AreSame(string? left, string? right) => Key(left) == Key(right);
}
