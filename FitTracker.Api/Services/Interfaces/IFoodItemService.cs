using FitTracker.Api.DTOs;

namespace FitTracker.Api.Services.Interfaces;

/// <summary>Business-logic contract for food item management.</summary>
public interface IFoodItemService
{
    /// <summary>Returns all food items belonging to the specified user.</summary>
    Task<List<FoodItemResponseDto>> GetUserFoodItemsAsync(Guid userId);

    /// <summary>Returns a single food item by ID, scoped to the specified user.</summary>
    Task<FoodItemResponseDto?> GetFoodItemByIdAsync(Guid id, Guid userId);

    /// <summary>Creates a new food item for the specified user.</summary>
    Task<FoodItemResponseDto> CreateFoodItemAsync(FoodItemRequestDto dto, Guid userId);

    /// <summary>Updates an existing food item. Returns null if not found.</summary>
    Task<FoodItemResponseDto?> UpdateFoodItemAsync(Guid id, Guid userId, FoodItemRequestDto dto);

    /// <summary>Deletes a food item. Returns false if not found.</summary>
    Task<bool> DeleteFoodItemAsync(Guid id, Guid userId);
}
