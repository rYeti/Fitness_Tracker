using FitTracker.Api.DTOs;

namespace FitTracker.Api.Services.Interfaces;

/// <summary>Business-logic contract for meal log management.</summary>
public interface IMealService
{
    /// <summary>Returns all meal entries for the specified user on the given calendar day.</summary>
    Task<List<MealResponseDto>> GetMealsForDateAsync(Guid userId, DateTime date);

    /// <summary>
    /// Returns all meal entries for the specified user across an inclusive span of
    /// calendar days, in one round trip. Callers group the result by day themselves.
    /// </summary>
    Task<List<MealResponseDto>> GetMealsInRangeAsync(Guid userId, DateTime firstDay, DateTime lastDay);

    /// <summary>Returns a single meal entry by ID, scoped to the specified user.</summary>
    Task<MealResponseDto?> GetMealByIdAsync(Guid id, Guid userId);

    /// <summary>Creates a new meal log entry for the specified user.</summary>
    Task<MealResponseDto> CreateMealAsync(MealRequestDto dto, Guid userId);

    /// <summary>Updates an existing meal entry. Returns null if not found.</summary>
    Task<MealResponseDto?> UpdateMealAsync(Guid id, Guid userId, MealRequestDto dto);

    /// <summary>Deletes a meal entry. Returns false if not found.</summary>
    Task<bool> DeleteMealAsync(Guid id, Guid userId);

    /// <summary>Adds a food item to an existing meal. Returns null if the meal is not found.</summary>
    Task<MealFoodEntryResponseDto?> AddFoodToMealAsync(Guid mealId, Guid userId, Guid foodItemId);

    /// <summary>Adds multiple food items to a meal in one call.</summary>
    Task<List<MealFoodEntryResponseDto>> AddFoodsToMealBatchAsync(Guid mealId, Guid userId, List<Guid> foodItemIds);

    /// <summary>Removes a food item from a meal. Returns false if not found.</summary>
    Task<bool> RemoveFoodFromMealAsync(Guid mealId, Guid userId, Guid foodItemId);

    /// <summary>Returns all meal entries for the specified user across all dates.</summary>
    Task<List<MealResponseDto>> GetAllMealsAsync(Guid userId);
}
