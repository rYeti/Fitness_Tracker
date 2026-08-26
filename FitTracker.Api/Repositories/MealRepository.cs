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
    public Task<List<Meal>> GetMealsForDateAsync(Guid userId, DateTime date) =>
        GetMealsInRangeAsync(userId, date, date);

    /// <inheritdoc/>
    public Task<List<Meal>> GetMealsInRangeAsync(Guid userId, DateTime firstDay, DateTime lastDay)
    {
        // See MealDayWindow: Meal.Date is a day marker stored as an instant, so the
        // window is centred on the day rather than running midnight to midnight.
        var (start, end) = MealDayWindow.ForRange(firstDay, lastDay);
        return context.Meals
            .AsNoTracking()
            .Where(m => m.UserId == userId && m.Date >= start && m.Date < end)
            .Include(m => m.FoodEntries)
            .ToListAsync();
    }

    /// <inheritdoc/>
    public Task<Meal?> GetMealByIdAsync(Guid id, Guid userId) =>
        context.Meals
            .Include(m => m.FoodEntries)
            .FirstOrDefaultAsync(m => m.Id == id && m.UserId == userId);

    /// <inheritdoc/>
    public async Task<Meal?> FindSameDayMealAsync(Guid userId, DateTime storedDate, string category)
    {
        var (start, end) = MealDayWindow.ForDayOf(storedDate);
        var sameDay = await context.Meals
            .Where(m => m.UserId == userId && m.Date >= start && m.Date < end)
            .Include(m => m.FoodEntries)
            .OrderBy(m => m.Date)
            .ToListAsync();

        // Category matching normalises (see MealCategory) and so can't be translated
        // to SQL; a single day holds a handful of rows, so it runs here instead.
        return sameDay.FirstOrDefault(m => MealCategory.AreSame(m.Category, category));
    }

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
