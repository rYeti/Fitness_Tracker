using FitTracker.Api.Data;
using FitTracker.Api.Models;
using FitTracker.Api.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace FitTracker.Api.Repositories;

/// <summary>EF Core implementation of <see cref="IUserSettingsRepository"/>.</summary>
public class UserSettingsRepository(AppDbContext context) : IUserSettingsRepository
{
    /// <inheritdoc/>
    public Task<UserSettings?> GetByUserIdAsync(Guid userId) =>
        context.UserSettings.FirstOrDefaultAsync(s => s.UserId == userId);

    /// <inheritdoc/>
    public async Task<UserSettings> UpsertAsync(Guid userId, UserSettings settings)
    {
        var existing = await context.UserSettings.FirstOrDefaultAsync(s => s.UserId == userId);

        if (existing == null)
        {
            settings.Id = Guid.NewGuid();
            settings.UserId = userId;
            context.UserSettings.Add(settings);
        }
        else
        {
            existing.DailyCalorieGoal = settings.DailyCalorieGoal;
            existing.ThemeMode = settings.ThemeMode;
            existing.Name = settings.Name;
            existing.Age = settings.Age;
            existing.HeightCm = settings.HeightCm;
            existing.Sex = settings.Sex;
            existing.ActivityLevel = settings.ActivityLevel;
            existing.GoalType = settings.GoalType;
            existing.StartingWeight = settings.StartingWeight;
            existing.GoalWeight = settings.GoalWeight;
            settings = existing;
        }

        await context.SaveChangesAsync();
        return settings;
    }
}
