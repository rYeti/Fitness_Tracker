using FitTracker.Api.DTOs;

namespace FitTracker.Api.Services.Interfaces;

/// <summary>Business-logic contract for user settings management.</summary>
public interface IUserSettingsService
{
    /// <summary>Returns the settings for the specified user, or null if none exist yet.</summary>
    Task<UserSettingsResponseDto?> GetSettingsAsync(Guid userId);

    /// <summary>Creates or fully replaces the settings for the specified user.</summary>
    Task<UserSettingsResponseDto> UpsertSettingsAsync(Guid userId, UserSettingsRequestDto dto);
}
