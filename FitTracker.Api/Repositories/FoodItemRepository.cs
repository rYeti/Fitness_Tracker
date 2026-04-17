using FitTracker.Api.Data;
using FitTracker.Api.Models;
using FitTracker.Api.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace FitTracker.Api.Repositories;

/// <summary>EF Core implementation of <see cref="IFoodItemRepository"/>.</summary>
public class FoodItemRepository(AppDbContext context) : IFoodItemRepository
{
    /// <inheritdoc/>
    public Task<List<FoodItem>> GetUserFoodItemsAsync(Guid userId) =>
        context.FoodItems.Where(f => f.UserId == userId).ToListAsync();

    /// <inheritdoc/>
    public Task<FoodItem?> GetFoodItemByIdAsync(Guid id, Guid userId) =>
        context.FoodItems.FirstOrDefaultAsync(f => f.Id == id && f.UserId == userId);

    /// <inheritdoc/>
    public async Task<FoodItem> CreateFoodItemAsync(FoodItem item)
    {
        context.FoodItems.Add(item);
        await context.SaveChangesAsync();
        return item;
    }

    /// <inheritdoc/>
    public async Task<FoodItem?> UpdateFoodItemAsync(Guid id, Guid userId, FoodItem item)
    {
        var existing = await context.FoodItems.FirstOrDefaultAsync(f => f.Id == id && f.UserId == userId);
        if (existing == null) return null;

        existing.Name = item.Name;
        existing.Calories = item.Calories;
        existing.Protein = item.Protein;
        existing.Carbs = item.Carbs;
        existing.Fat = item.Fat;
        existing.Gramm = item.Gramm;
        existing.HiddenFromRecent = item.HiddenFromRecent;
        existing.ExtendedNutrientsJson = item.ExtendedNutrientsJson;

        await context.SaveChangesAsync();
        return existing;
    }

    /// <inheritdoc/>
    public async Task<bool> DeleteFoodItemAsync(Guid id, Guid userId)
    {
        var item = await context.FoodItems.FirstOrDefaultAsync(f => f.Id == id && f.UserId == userId);
        if (item == null) return false;

        context.FoodItems.Remove(item);
        await context.SaveChangesAsync();
        return true;
    }
}
