using FitTracker.Api.Data;
using FitTracker.Api.DTOs;
using FitTracker.Api.Models;
using FitTracker.Api.Repositories.Interfaces;
using FitTracker.Api.Services;
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
        await context.SaveNewAsync();
        return meal;
    }

    /// <inheritdoc/>
    public Task<bool> WasDeletedAsync(Guid userId, Guid id) => context.WasDeletedAsync(userId, id);

    /// <inheritdoc/>
    public async Task<Guid?> GetOwnerAsync(Guid id) =>
        (await context.Meals.AsNoTracking()
            .Where(m => m.Id == id)
            .Select(m => new { m.UserId })
            .FirstOrDefaultAsync())?.UserId;

    /// <inheritdoc/>
    public async Task<List<MealFoodEntry>?> UpsertFoodEntriesAsync(Guid mealId, Guid userId, IReadOnlyList<MealFoodEntryRequestDto> entries)
    {
        if (!await context.Meals.AnyAsync(m => m.Id == mealId && m.UserId == userId)) return null;

        // One entry at a time through ClientIds, which is what makes a repeat of an id — a
        // retry after a lost answer, or the whole meal sent again after an edit — land on the
        // row it made rather than beside it, and refuses an id that is someone else's.
        var stored = new List<MealFoodEntry>(entries.Count);
        foreach (var e in entries)
        {
            var entry = await ClientIds.CreateOrResolveAsync(
                e.Id,
                userId,
                GetFoodEntryOwnerAsync,
                id => context.WasDeletedAsync(userId, id),
                id => PlaceFoodEntryAsync(id, mealId, e.FoodItemId),
                async id =>
                {
                    var row = new MealFoodEntry { Id = id, MealId = mealId, FoodItemId = e.FoodItemId };
                    context.MealFoodEntries.Add(row);
                    await context.SaveNewAsync();
                    return row;
                });
            stored.Add(entry!);
        }
        return stored;
    }

    /// <summary>Who owns the meal entry stored under <paramref name="id"/>, or null when
    /// there is none.</summary>
    private async Task<Guid?> GetFoodEntryOwnerAsync(Guid id) =>
        (await context.MealFoodEntries.AsNoTracking()
            .Where(e => e.Id == id)
            .Select(e => new { e.Meal.UserId })
            .FirstOrDefaultAsync())?.UserId;

    /// <summary>Makes the caller's entry <paramref name="id"/> hold <paramref name="foodItemId"/>
    /// in <paramref name="mealId"/>. It can be in another of the caller's meals: the app's
    /// de-duplication folds a twin meal's foods into the meal it keeps, ids and all, and this
    /// is how that move reaches the server.</summary>
    private async Task<MealFoodEntry?> PlaceFoodEntryAsync(Guid id, Guid mealId, Guid foodItemId)
    {
        var entry = await context.MealFoodEntries.FirstAsync(e => e.Id == id);
        entry.MealId = mealId;
        entry.FoodItemId = foodItemId;
        await context.SaveChangesAsync();
        return entry;
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
    public Task<List<Meal>> GetAllMealsAsync(Guid userId, DateTime? changedSince = null) =>
        context.Meals
            .Where(m => m.UserId == userId)
            .ChangedSince(changedSince)
            .Include(m => m.FoodEntries)
            .ToListAsync();

    /// <inheritdoc/>
    public async Task<bool> RemoveFoodFromMealAsync(Guid mealId, Guid userId, Guid id)
    {
        var entry =
            // The entry by its own id — what current apps send.
            await context.MealFoodEntries.FirstOrDefaultAsync(e => e.Id == id && e.Meal.UserId == userId)
            // Shipped apps name the food item, which can't say which of two portions they
            // mean; they get the first one in the meal.
            ?? await context.MealFoodEntries.FirstOrDefaultAsync(e =>
                e.MealId == mealId && e.Meal.UserId == userId && e.FoodItemId == id);
        if (entry == null) return false;

        context.MealFoodEntries.Remove(entry);
        await context.SaveChangesAsync();
        return true;
    }
}
