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

    /// <summary>Adds each of <paramref name="entries"/> to a meal, or — for an id the caller
    /// already holds — makes that entry the meal's again, with the food sent. Removes nothing.
    /// Returns the entries in the order sent, or null if the meal is not the caller's.</summary>
    Task<List<MealFoodEntryResponseDto>?> AddFoodsToMealBatchAsync(Guid mealId, Guid userId, List<MealFoodEntryRequestDto> entries);

    /// <summary>Removes the entry <paramref name="id"/> names — by its own id, or (shipped
    /// apps) by its food item. Returns false if the caller has no such entry.</summary>
    Task<bool> RemoveFoodFromMealAsync(Guid mealId, Guid userId, Guid id);

    /// <summary>Returns all meal entries for the specified user across all dates.</summary>
    /// <param name="changedSince">Only those whose aggregate changed at or after this instant, for the sync
    /// changes feed (docs/sync-architecture.md, part three); all of them when null.</param>
    Task<List<MealResponseDto>> GetAllMealsAsync(Guid userId, DateTime? changedSince = null);
}
