using FitTracker.Api.DTOs;
using FitTracker.Api.Models;
using FitTracker.Api.Repositories.Interfaces;
using FitTracker.Api.Services.Interfaces;

namespace FitTracker.Api.Services;

/// <summary>Implementation of <see cref="IUserSettingsService"/>.</summary>
public class UserSettingsService(IUserSettingsRepository repository) : IUserSettingsService
{
    /// <inheritdoc/>
    public async Task<UserSettingsResponseDto?> GetSettingsAsync(Guid userId)
    {
        var settings = await repository.GetByUserIdAsync(userId);
        return settings is null ? null : ToDto(settings);
    }

    /// <inheritdoc/>
    public async Task<UserSettingsResponseDto> UpsertSettingsAsync(Guid userId, UserSettingsRequestDto dto)
    {
        var settings = new UserSettings
        {
            UserId = userId,
            DailyCalorieGoal = dto.DailyCalorieGoal,
            ThemeMode = dto.ThemeMode,
            Name = dto.Name,
            Age = dto.Age,
            HeightCm = dto.HeightCm,
            Sex = dto.Sex,
            ActivityLevel = dto.ActivityLevel,
            GoalType = dto.GoalType,
            StartingWeight = dto.StartingWeight,
            GoalWeight = dto.GoalWeight,
        };

        var upserted = await repository.UpsertAsync(userId, settings);
        return ToDto(upserted);
    }

    private static UserSettingsResponseDto ToDto(UserSettings s) => new()
    {
        Id = s.Id,
        DailyCalorieGoal = s.DailyCalorieGoal,
        ThemeMode = s.ThemeMode,
        Name = s.Name,
        Age = s.Age,
        HeightCm = s.HeightCm,
        Sex = s.Sex,
        ActivityLevel = s.ActivityLevel,
        GoalType = s.GoalType,
        StartingWeight = s.StartingWeight,
        GoalWeight = s.GoalWeight,
    };
}
