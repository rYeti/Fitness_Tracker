namespace FitTracker.Api.Models;

/// <summary>
/// One nutrient a trainer has chosen to track for one client on the Trainer
/// Console's Nutrition tab (and, read-only, on that client's own diary).
/// </summary>
/// <remarks>
/// Rows for a (trainer, client) pair are always replaced as a whole set, never
/// added or removed individually — see
/// <see cref="Services.TrainerConsoleService.SetClientNutrientPinsAsync"/>.
/// Replacing a set is idempotent in its side effects; toggling one row alone
/// isn't, and the trap that leaves is exactly what
/// docs/trainer-console-duplicate-rows.md is about. A trainer with no saved
/// pins for a client has no rows here at all — the default selection
/// (fibre/sugar/sodium) is applied by the reader, not persisted.
/// </remarks>
public class TrainerNutrientPin
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public Guid TrainerId { get; set; }
    public User Trainer { get; set; } = null!;

    public Guid ClientId { get; set; }
    public User Client { get; set; } = null!;

    /// <summary>Matches a <c>NutrientDef.key</c> on the Flutter side — see
    /// lib/core/nutrition/nutrient_defs.dart. Validated against that same set
    /// server-side before being stored; see <c>NutrientKeys</c>.</summary>
    public string NutrientKey { get; set; } = string.Empty;

    /// <summary>Preserves the order the trainer picked nutrients in, so the
    /// Nutrition tab's pinned list doesn't reshuffle on every reload.</summary>
    public int SortOrder { get; set; }
}
