using FitTracker.Api.DTOs;

namespace FitTracker.Api.Services.Interfaces;

/// <summary>Business-logic contract for food item management.</summary>
public interface IFoodItemService
{
    /// <summary>Returns all food items belonging to the specified user.</summary>
    /// <param name="changedSince">Only those whose aggregate changed at or after this instant, for the sync
    /// changes feed (docs/sync-architecture.md, part three); all of them when null.</param>
    Task<List<FoodItemResponseDto>> GetUserFoodItemsAsync(Guid userId, DateTime? changedSince = null);

    /// <summary>Returns the user's food items with the given ids. Ids that don't resolve are
    /// absent from the result.</summary>
    Task<List<FoodItemResponseDto>> GetFoodItemsByIdsAsync(Guid userId, IReadOnlyCollection<Guid> ids);

    /// <summary>Returns a single food item by ID, scoped to the specified user.</summary>
    Task<FoodItemResponseDto?> GetFoodItemByIdAsync(Guid id, Guid userId);

    /// <summary>Creates a new food item for the specified user.</summary>
    Task<FoodItemResponseDto> CreateFoodItemAsync(FoodItemRequestDto dto, Guid userId);

    /// <summary>Updates an existing food item. Returns null if not found.</summary>
    Task<FoodItemResponseDto?> UpdateFoodItemAsync(Guid id, Guid userId, FoodItemRequestDto dto);

    /// <summary>Deletes a food item. Returns false if not found.</summary>
    Task<bool> DeleteFoodItemAsync(Guid id, Guid userId);
}
