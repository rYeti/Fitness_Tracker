namespace FitTracker.Api.Repositories.Interfaces;

/// <summary>Data access for a trainer's pinned-nutrient selection per client
/// — Nutrition tab "Tracked nutrients".</summary>
public interface ITrainerNutrientPinRepository
{
    /// <summary>The nutrient keys this trainer has pinned for this client, in
    /// the order they were pinned. Empty — not the defaults — when the pair
    /// has never saved a selection; applying the default selection is the
    /// caller's job, so a repository read never has to know what the default
    /// is.</summary>
    Task<List<string>> GetPinsAsync(Guid trainerId, Guid clientId);

    /// <summary>Replaces the whole pinned set for this (trainer, client) pair
    /// in one transaction. Never an incremental add/remove — see
    /// <see cref="Models.TrainerNutrientPin"/> for why toggling a single row
    /// isn't safe here.</summary>
    Task ReplacePinsAsync(Guid trainerId, Guid clientId, List<string> nutrientKeys);
}
