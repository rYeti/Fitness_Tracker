using FitTracker.Api.Models;

namespace FitTracker.Api.Repositories.Interfaces;

/// <summary>Data-access contract for user settings.</summary>
public interface IUserSettingsRepository
{
    /// <summary>Returns the settings record for the specified user, or null if none exist yet.</summary>
    Task<UserSettings?> GetByUserIdAsync(Guid userId);

    /// <summary>Creates or replaces the settings record for the specified user.</summary>
    Task<UserSettings> UpsertAsync(Guid userId, UserSettings settings);
}
