using FitTracker.Api.DTOs;

namespace FitTracker.Api.Services.Interfaces;

/// <summary>Business-logic contract for meal log management.</summary>
public interface IMealService
{
    /// <summary>Returns all meal entries for the specified user on the given date.</summary>
    Task<List<MealResponseDto>> GetMealsForDateAsync(Guid userId, DateTime date);

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

    /// <summary>Removes a food item from a meal. Returns false if not found.</summary>
    Task<bool> RemoveFoodFromMealAsync(Guid mealId, Guid userId, Guid foodItemId);
}
