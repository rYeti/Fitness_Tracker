using FitTracker.Api.Models;

namespace FitTracker.Api.Repositories.Interfaces;

/// <summary>Data-access contract for meal log management.</summary>
public interface IMealRepository
{
    /// <summary>Returns all meal entries for the specified user on the given date.</summary>
    Task<List<Meal>> GetMealsForDateAsync(Guid userId, DateTime date);

    /// <summary>Returns a single meal entry by ID, scoped to the specified user.</summary>
    Task<Meal?> GetMealByIdAsync(Guid id, Guid userId);

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
}
