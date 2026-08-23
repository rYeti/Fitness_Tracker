using FitTracker.Api.DTOs;
using FitTracker.Api.Models;

namespace FitTracker.Api.Repositories.Interfaces;

/// <summary>Data-access contract for meal log management.</summary>
public interface IMealRepository
{
    /// <summary>Returns all meal entries for the specified user on the given calendar day.</summary>
    Task<List<Meal>> GetMealsForDateAsync(Guid userId, DateTime date);

    /// <summary>
    /// Returns all meal entries for the specified user across an inclusive span of
    /// calendar days. Callers group the result with <see cref="MealDayWindow.DayOf"/>.
    /// </summary>
    Task<List<Meal>> GetMealsInRangeAsync(Guid userId, DateTime firstDay, DateTime lastDay);

    /// <summary>Returns a single meal entry by ID, scoped to the specified user.</summary>
    Task<Meal?> GetMealByIdAsync(Guid id, Guid userId);

    /// <summary>
    /// The meal already recorded in <paramref name="category"/> on the day
    /// <paramref name="storedDate"/> falls in, if there is one.
    /// </summary>
    /// <param name="storedDate">An instant as meals are stored — the client's local
    /// midnight — not a calendar day. Resolved via <see cref="MealDayWindow.ForDayOf"/>.</param>
    /// <param name="category">Matched with <see cref="MealCategory.AreSame"/>, so
    /// spelling and casing differences between client builds still find the row.</param>
    Task<Meal?> FindSameDayMealAsync(Guid userId, DateTime storedDate, string category);

    /// <summary>Creates a new meal log entry.</summary>
    Task<Meal> CreateMealAsync(Meal meal);

    /// <summary>Updates an existing meal entry. Returns null if not found.</summary>
    Task<Meal?> UpdateMealAsync(Guid id, Guid userId, MealRequestDto dto);

    /// <summary>Deletes a meal entry. Returns false if not found.</summary>
    Task<bool> DeleteMealAsync(Guid id, Guid userId);

    /// <summary>Adds a food item to a meal via the join table.</summary>
    Task<MealFoodEntry> AddFoodToMealAsync(Guid mealId, Guid foodItemId);

    /// <summary>Removes a food item from a meal. Returns false if not found.</summary>
    Task<bool> RemoveFoodFromMealAsync(Guid mealId, Guid foodItemId);

    /// <summary>Returns all meal entries for the specified user across all dates.</summary>
    Task<List<Meal>> GetAllMealsAsync(Guid userId);
}
