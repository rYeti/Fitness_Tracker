using FitTracker.Api.DTOs;
using FitTracker.Api.Models;

namespace FitTracker.Api.Repositories.Interfaces;

/// <summary>Data-access contract for meal log management.</summary>
public interface IMealRepository : IDeletedIdLookup
{
    /// <summary>Returns all meal entries for the specified user on the given calendar day.</summary>
    Task<List<Meal>> GetMealsForDateAsync(Guid userId, DateTime date);

    /// <summary>
    /// Returns all meal entries for the specified user across an inclusive span of
    /// calendar days. Callers group the result with <see cref="MealDayWindow.DayOf"/>.
    /// </summary>
    Task<List<Meal>> GetMealsInRangeAsync(Guid userId, DateTime firstDay, DateTime lastDay);

    /// <summary>Returns a single meal entry by ID, scoped to the specified user.</summary>
    Task<Meal?> GetMealByIdAsync(Guid id, Guid userId);

    /// <summary>
    /// The meal already recorded in <paramref name="category"/> on the day
    /// <paramref name="storedDate"/> falls in, if there is one.
    /// </summary>
    /// <param name="storedDate">An instant as meals are stored — the client's local
    /// midnight — not a calendar day. Resolved via <see cref="MealDayWindow.ForDayOf"/>.</param>
    /// <param name="category">Matched with <see cref="MealCategory.AreSame"/>, so
    /// spelling and casing differences between client builds still find the row.</param>
    Task<Meal?> FindSameDayMealAsync(Guid userId, DateTime storedDate, string category);

    /// <summary>Creates a new meal log entry.</summary>
    Task<Meal> CreateMealAsync(Meal meal);

    /// <summary>Who owns the meal stored under <paramref name="id"/>, or null when there is
    /// none. Lets a create tell a repeat of its own id from someone else's (see
    /// <c>ClientIds</c>).</summary>
    Task<Guid?> GetOwnerAsync(Guid id);

    /// <summary>Puts each of <paramref name="entries"/> in a meal owned by
    /// <paramref name="userId"/>: under the id it carries, which may already name one of the
    /// caller's entries (that entry is given the food sent and moved into this meal), or under
    /// a fresh id when it carries none. Removes nothing.</summary>
    /// <returns>The stored entries in the order sent, or <c>null</c> if the meal isn't
    /// found/owned — whether or not <paramref name="entries"/> is empty.</returns>
    /// <exception cref="Services.ClientIdConflictException">An id names someone else's entry.</exception>
    Task<List<MealFoodEntry>?> UpsertFoodEntriesAsync(Guid mealId, Guid userId, IReadOnlyList<MealFoodEntryRequestDto> entries);

    /// <summary>Updates an existing meal entry. Returns null if not found.</summary>
    Task<Meal?> UpdateMealAsync(Guid id, Guid userId, MealRequestDto dto);

    /// <summary>Deletes a meal entry. Returns false if not found.</summary>
    Task<bool> DeleteMealAsync(Guid id, Guid userId);

    /// <summary>Adds a food item to a meal via the join table.</summary>
    Task<MealFoodEntry> AddFoodToMealAsync(Guid mealId, Guid foodItemId);

    /// <summary>Removes one of the caller's meal entries: the one stored under
    /// <paramref name="id"/>, else (for shipped apps, which name the food) the first entry of
    /// food item <paramref name="id"/> in meal <paramref name="mealId"/>. Returns false if
    /// there is neither.</summary>
    Task<bool> RemoveFoodFromMealAsync(Guid mealId, Guid userId, Guid id);

    /// <summary>Returns all meal entries for the specified user across all dates.</summary>
    /// <param name="changedSince">Only those whose aggregate changed at or after this instant, for the sync
    /// changes feed (docs/sync-architecture.md, part three); all of them when null.</param>
    Task<List<Meal>> GetAllMealsAsync(Guid userId, DateTime? changedSince = null);
}
