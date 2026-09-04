namespace FitTracker.Api.Repositories.Interfaces;

/// <summary>Data access for a user's own self-managed pinned-nutrient
/// selection — the food log's "Tracked nutrients" card for a user with no
/// trainer to curate pins for them.</summary>
public interface IUserNutrientPinRepository
{
    /// <summary>The nutrient keys this user has pinned for themselves, in the
    /// order they were pinned. Empty — not the defaults — when the user has
    /// never saved a selection; applying the default selection is the
    /// caller's job, so a repository read never has to know what the default
    /// is.</summary>
    Task<List<string>> GetPinsAsync(Guid userId);

    /// <summary>Replaces the whole pinned set for this user in one
    /// transaction. Never an incremental add/remove — see
    /// <see cref="Models.UserNutrientPin"/> for why toggling a single row
    /// isn't safe here.</summary>
    Task ReplacePinsAsync(Guid userId, List<string> nutrientKeys);
}
