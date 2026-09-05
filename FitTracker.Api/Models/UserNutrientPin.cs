namespace FitTracker.Api.Models;

/// <summary>
/// One nutrient a user has chosen to track for themselves, on the food log's
/// "Tracked nutrients" card — the self-service counterpart to
/// <see cref="TrainerNutrientPin"/> for a user with no trainer to curate pins
/// for them.
/// </summary>
/// <remarks>
/// Rows for a user are always replaced as a whole set, never added or removed
/// individually — see <see cref="Services.TrainerClientService.SetMyNutrientPinsAsync"/>
/// and <see cref="TrainerNutrientPin"/>'s own remarks for why toggling one row
/// at a time isn't safe here (docs/trainer-console-duplicate-rows.md). A user
/// with no saved pins has no rows here at all — the default selection
/// (fibre/sugar/sodium) is applied by the reader, not persisted.
/// </remarks>
public class UserNutrientPin
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public Guid UserId { get; set; }
    public User User { get; set; } = null!;

    /// <summary>Matches a <c>NutrientDef.key</c> on the Flutter side — see
    /// lib/core/nutrition/nutrient_defs.dart. Validated against
    /// <see cref="Nutrition.NutrientKeys"/> before being stored.</summary>
    public string NutrientKey { get; set; } = string.Empty;

    /// <summary>Preserves the order the user picked nutrients in, so the
    /// pinned list doesn't reshuffle on every reload.</summary>
    public int SortOrder { get; set; }
}
