using FitTracker.Api.DTOs;
using FitTracker.Api.Models;
using FitTracker.Api.Repositories.Interfaces;
using FitTracker.Api.Services.Interfaces;

namespace FitTracker.Api.Services;

/// <summary>Implementation of <see cref="IMealService"/>.</summary>
public class MealService(IMealRepository repository, ISyncTombstoneRepository tombstones) : IMealService
{
    /// <inheritdoc/>
    public async Task<List<MealResponseDto>> GetMealsForDateAsync(Guid userId, DateTime date)
    {
        var meals = await repository.GetMealsForDateAsync(userId, date);
        return meals.Select(ToDto).ToList();
    }

    /// <inheritdoc/>
    public async Task<List<MealResponseDto>> GetMealsInRangeAsync(Guid userId, DateTime firstDay, DateTime lastDay)
    {
        var meals = await repository.GetMealsInRangeAsync(userId, firstDay, lastDay);
        return meals.Select(ToDto).ToList();
    }

    /// <inheritdoc/>
    public async Task<MealResponseDto?> GetMealByIdAsync(Guid id, Guid userId)
    {
        var meal = await repository.GetMealByIdAsync(id, userId);
        return meal is null ? null : ToDto(meal);
    }

    /// <inheritdoc/>
    /// <remarks>
    /// Creating is idempotent per user, day and category: a client that posts a meal
    /// it has already posted gets that meal back rather than a second row. The app
    /// only ever wants one — it looks a meal up by day and category before adding
    /// food to it — but its sync can genuinely repeat the POST: a reconcile pass
    /// clears the local serverId when a server row looks gone, a second device pushes
    /// its own copy, or the response is lost after the row was written. Those extra
    /// rows are invisible in the app (it renders four fixed categories and reads the
    /// first row of each) and were listed one by one in the Trainer Console.
    /// </remarks>
    public async Task<MealResponseDto> CreateMealAsync(MealRequestDto dto, Guid userId)
    {
        var date = DateTime.SpecifyKind(dto.Date, DateTimeKind.Utc);

        // The id comes first, then the day. A repeat of the app's own id is its own meal;
        // an id the server has never seen may still name a day and category that already
        // has one — a second device's, or this device's before a reinstall — and that meal
        // is the answer, under its id, which is the one the app must keep. The app then
        // merges its foods with the ones that meal already holds rather than replacing them.
        var result = await ClientIds.CreateOrResolveAsync(
            dto.Id,
            userId,
            repository.GetOwnerAsync,
            id => tombstones.WasDeletedAsync(userId, id),
            id => UpdateMealAsync(id, userId, dto),
            async id =>
            {
                var existing = await repository.FindSameDayMealAsync(userId, date, dto.Category);
                if (existing is not null) return ToDto(existing);

                return ToDto(await repository.CreateMealAsync(new Meal
                {
                    Id = id,
                    UserId = userId,
                    Date = date,
                    Category = dto.Category,
                    FoodItemId = dto.FoodItemId,
                }));
            });
        return result!;
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

        return ToEntryDto(await repository.AddFoodToMealAsync(mealId, foodItemId));
    }

    /// <inheritdoc/>
    /// <remarks>
    /// The meal's owner is checked once, by the repository, which answers null for a meal
    /// that isn't the caller's — an empty batch included. This used to check here first and
    /// then again for every entry, loading the meal and all its entries each time.
    /// </remarks>
    public async Task<List<MealFoodEntryResponseDto>?> AddFoodsToMealBatchAsync(Guid mealId, Guid userId, List<MealFoodEntryRequestDto> entries)
    {
        var stored = await repository.UpsertFoodEntriesAsync(mealId, userId, entries);
        return stored?.Select(ToEntryDto).ToList();
    }

    /// <inheritdoc/>
    public Task<bool> RemoveFoodFromMealAsync(Guid mealId, Guid userId, Guid id) =>
        repository.RemoveFoodFromMealAsync(mealId, userId, id);

    /// <inheritdoc/>
    public async Task<List<MealResponseDto>> GetAllMealsAsync(Guid userId, DateTime? changedSince = null)
    {
        var meals = await repository.GetAllMealsAsync(userId, changedSince);
        return meals.Select(ToDto).ToList();
    }

    private static MealResponseDto ToDto(Meal m) => new()
    {
        Id = m.Id,
        Date = m.Date,
        Category = m.Category,
        FoodItemId = m.FoodItemId,
        FoodEntries = m.FoodEntries.Select(ToEntryDto).ToList(),
    };

    private static MealFoodEntryResponseDto ToEntryDto(MealFoodEntry e) => new()
    {
        Id = e.Id,
        MealId = e.MealId,
        FoodItemId = e.FoodItemId,
    };
}
