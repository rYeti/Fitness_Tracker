using FitTracker.Api.Models;

namespace FitTracker.Api.Repositories.Interfaces;

/// <summary>Data-access contract for food item management.</summary>
public interface IFoodItemRepository
{
    /// <summary>Returns all food items belonging to the specified user.</summary>
    Task<List<FoodItem>> GetUserFoodItemsAsync(Guid userId);

    /// <summary>Returns the specified user's food items with the given ids.</summary>
    /// <remarks>Resolving a day of meals used to load the user's entire food library. The ids
    /// are opaque client-side references with no foreign key behind them, so any that don't
    /// resolve are simply absent from the result.</remarks>
    Task<List<FoodItem>> GetFoodItemsByIdsAsync(Guid userId, IReadOnlyCollection<Guid> ids);

    /// <summary>Returns a single food item by ID, scoped to the specified user.</summary>
    Task<FoodItem?> GetFoodItemByIdAsync(Guid id, Guid userId);

    /// <summary>Creates a new food item.</summary>
    Task<FoodItem> CreateFoodItemAsync(FoodItem item);

    /// <summary>Updates an existing food item. Returns null if not found.</summary>
    Task<FoodItem?> UpdateFoodItemAsync(Guid id, Guid userId, FoodItem item);

    /// <summary>Deletes a food item. Returns false if not found.</summary>
    Task<bool> DeleteFoodItemAsync(Guid id, Guid userId);
}
