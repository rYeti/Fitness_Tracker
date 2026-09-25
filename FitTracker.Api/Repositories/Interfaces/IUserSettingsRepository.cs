using FitTracker.Api.Models;

namespace FitTracker.Api.Repositories.Interfaces;

/// <summary>Data-access contract for user settings.</summary>
public interface IUserSettingsRepository
{
    /// <summary>Returns the settings record for the specified user, or null if none exist yet.</summary>
    /// <param name="changedSince">Only those whose aggregate changed at or after this instant, for the sync
    /// changes feed (docs/sync-architecture.md, part three); all of them when null.</param>
    Task<UserSettings?> GetByUserIdAsync(Guid userId, DateTime? changedSince = null);

    /// <summary>Creates or replaces the settings record for the specified user.</summary>
    Task<UserSettings> UpsertAsync(Guid userId, UserSettings settings);
}
