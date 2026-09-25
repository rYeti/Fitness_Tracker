using FitTracker.Api.DTOs;

namespace FitTracker.Api.Services.Interfaces;

/// <summary>Business-logic contract for user settings management.</summary>
public interface IUserSettingsService
{
    /// <summary>Returns the settings for the specified user, or null if none exist yet.</summary>
    /// <param name="changedSince">Only those whose aggregate changed at or after this instant, for the sync
    /// changes feed (docs/sync-architecture.md, part three); all of them when null.</param>
    Task<UserSettingsResponseDto?> GetSettingsAsync(Guid userId, DateTime? changedSince = null);

    /// <summary>Creates or fully replaces the settings for the specified user.</summary>
    Task<UserSettingsResponseDto> UpsertSettingsAsync(Guid userId, UserSettingsRequestDto dto);
}
