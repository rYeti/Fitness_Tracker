using FitTracker.Api.Models;

namespace FitTracker.Api.Repositories.Interfaces;

/// <summary>Data-access contract for food item management.</summary>
public interface IFoodItemRepository
{
    /// <summary>Returns all food items belonging to the specified user.</summary>
    Task<List<FoodItem>> GetUserFoodItemsAsync(Guid userId);

    /// <summary>Returns a single food item by ID, scoped to the specified user.</summary>
    Task<FoodItem?> GetFoodItemByIdAsync(Guid id, Guid userId);

    /// <summary>Creates a new food item.</summary>
    Task<FoodItem> CreateFoodItemAsync(FoodItem item);

    /// <summary>Updates an existing food item. Returns null if not found.</summary>
    Task<FoodItem?> UpdateFoodItemAsync(Guid id, Guid userId, FoodItem item);

    /// <summary>Deletes a food item. Returns false if not found.</summary>
    Task<bool> DeleteFoodItemAsync(Guid id, Guid userId);
}
