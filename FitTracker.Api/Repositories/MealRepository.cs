using FitTracker.Api.Data;
using FitTracker.Api.DTOs;
using FitTracker.Api.Models;
using FitTracker.Api.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace FitTracker.Api.Repositories;

/// <summary>EF Core implementation of <see cref="IMealRepository"/>.</summary>
public class MealRepository(AppDbContext context) : IMealRepository
{
    /// <inheritdoc/>
    public Task<List<Meal>> GetMealsForDateAsync(Guid userId, DateTime date)
    {
        var dayStart = date.Date;
        var dayEnd = dayStart.AddDays(1);
        return context.Meals
            .Where(m => m.UserId == userId && m.Date >= dayStart && m.Date < dayEnd)
            .Include(m => m.FoodEntries)
            .ToListAsync();
    }

    /// <inheritdoc/>
    public Task<Meal?> GetMealByIdAsync(Guid id, Guid userId) =>
        context.Meals
            .Include(m => m.FoodEntries)
            .FirstOrDefaultAsync(m => m.Id == id && m.UserId == userId);

    /// <inheritdoc/>
    public async Task<Meal> CreateMealAsync(Meal meal)
    {
        context.Meals.Add(meal);
        await context.SaveChangesAsync();
        return meal;
    }

    /// <inheritdoc/>
    public async Task<Meal?> UpdateMealAsync(Guid id, Guid userId, MealRequestDto dto)
    {
        var meal = await context.Meals.FirstOrDefaultAsync(m => m.Id == id && m.UserId == userId);
        if (meal == null) return null;

        meal.Date = dto.Date;
        meal.Category = dto.Category;
        meal.FoodItemId = dto.FoodItemId;

        await context.SaveChangesAsync();
        return meal;
    }

    /// <inheritdoc/>
    public async Task<bool> DeleteMealAsync(Guid id, Guid userId)
    {
        var meal = await context.Meals.FirstOrDefaultAsync(m => m.Id == id && m.UserId == userId);
        if (meal == null) return false;

        context.Meals.Remove(meal);
        await context.SaveChangesAsync();
        return true;
    }

    /// <inheritdoc/>
    public async Task<MealFoodEntry> AddFoodToMealAsync(Guid mealId, Guid foodItemId)
    {
        var entry = new MealFoodEntry { Id = Guid.NewGuid(), MealId = mealId, FoodItemId = foodItemId };
        context.MealFoodEntries.Add(entry);
        await context.SaveChangesAsync();
        return entry;
    }

    /// <inheritdoc/>
    public Task<List<Meal>> GetAllMealsAsync(Guid userId) =>
        context.Meals
            .Where(m => m.UserId == userId)
            .Include(m => m.FoodEntries)
            .ToListAsync();

    /// <inheritdoc/>
    public async Task<bool> RemoveFoodFromMealAsync(Guid mealId, Guid foodItemId)
    {
        var entry = await context.MealFoodEntries
            .FirstOrDefaultAsync(e => e.MealId == mealId && e.FoodItemId == foodItemId);
        if (entry == null) return false;

        context.MealFoodEntries.Remove(entry);
        await context.SaveChangesAsync();
        return true;
    }
}
