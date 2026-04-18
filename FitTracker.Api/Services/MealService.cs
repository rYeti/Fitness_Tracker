using FitTracker.Api.DTOs;
using FitTracker.Api.Models;
using FitTracker.Api.Repositories.Interfaces;
using FitTracker.Api.Services.Interfaces;

namespace FitTracker.Api.Services;

/// <summary>Implementation of <see cref="IMealService"/>.</summary>
public class MealService(IMealRepository repository) : IMealService
{
    /// <inheritdoc/>
    public async Task<List<MealResponseDto>> GetMealsForDateAsync(Guid userId, DateTime date)
    {
        var meals = await repository.GetMealsForDateAsync(userId, date);
        return meals.Select(ToDto).ToList();
    }

    /// <inheritdoc/>
    public async Task<MealResponseDto?> GetMealByIdAsync(Guid id, Guid userId)
    {
        var meal = await repository.GetMealByIdAsync(id, userId);
        return meal is null ? null : ToDto(meal);
    }

    /// <inheritdoc/>
    public async Task<MealResponseDto> CreateMealAsync(MealRequestDto dto, Guid userId)
    {
        var meal = new Meal
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Date = DateTime.SpecifyKind(dto.Date, DateTimeKind.Utc),
            Category = dto.Category,
            FoodItemId = dto.FoodItemId,
        };

        var created = await repository.CreateMealAsync(meal);
        return ToDto(created);
    }

    /// <inheritdoc/>
    public async Task<MealResponseDto?> UpdateMealAsync(Guid id, Guid userId, MealRequestDto dto)
    {
        var updated = await repository.UpdateMealAsync(id, userId, dto);
        return updated is null ? null : ToDto(updated);
    }

    /// <inheritdoc/>
    public Task<bool> DeleteMealAsync(Guid id, Guid userId) =>
        repository.DeleteMealAsync(id, userId);

    /// <inheritdoc/>
    public async Task<MealFoodEntryResponseDto?> AddFoodToMealAsync(Guid mealId, Guid userId, Guid foodItemId)
    {
        // Verify the meal belongs to this user before adding entries.
        var meal = await repository.GetMealByIdAsync(mealId, userId);
        if (meal is null) return null;

        var entry = await repository.AddFoodToMealAsync(mealId, foodItemId);
        return new MealFoodEntryResponseDto
        {
            Id = entry.Id,
            MealId = entry.MealId,
            FoodItemId = entry.FoodItemId,
        };
    }

    /// <inheritdoc/>
    public async Task<bool> RemoveFoodFromMealAsync(Guid mealId, Guid userId, Guid foodItemId)
    {
        var meal = await repository.GetMealByIdAsync(mealId, userId);
        if (meal is null) return false;

        return await repository.RemoveFoodFromMealAsync(mealId, foodItemId);
    }

    private static MealResponseDto ToDto(Meal m) => new()
    {
        Id = m.Id,
        Date = m.Date,
        Category = m.Category,
        FoodItemId = m.FoodItemId,
        FoodEntries = m.FoodEntries.Select(e => new MealFoodEntryResponseDto
        {
            Id = e.Id,
            MealId = e.MealId,
            FoodItemId = e.FoodItemId,
        }).ToList(),
    };
}
