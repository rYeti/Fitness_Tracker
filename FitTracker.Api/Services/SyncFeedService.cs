using FitTracker.Api.DTOs;
using FitTracker.Api.Repositories.Interfaces;
using FitTracker.Api.Services.Interfaces;

namespace FitTracker.Api.Services;

/// <summary>
/// The changes feed: everything of a user's that changed since a cursor, in the shapes the
/// list endpoints already return, plus what was deleted. See docs/sync-architecture.md,
/// part three.
/// </summary>
/// <remarks>
/// Each list comes from the service behind the matching list endpoint, asked for the rows
/// changed since the cursor. There is no second query and no second mapper: a field added
/// to a DTO reaches the feed by being added to the list endpoint, and the feed can never
/// send a shape the app's existing pull code doesn't already read.
/// </remarks>
public class SyncFeedService(
    IExerciseService exercises,
    IWorkoutService workouts,
    IWorkoutPlanService plans,
    IScheduledWorkoutService sessions,
    IFoodItemService foodItems,
    IMealService meals,
    IMealTemplateService mealTemplates,
    IWeightTrackingService weights,
    IUserSettingsService settings,
    ISyncTombstoneRepository tombstones) : ISyncFeedService
{
    /// <summary>How far before this answer began the returned cursor points.</summary>
    /// <remarks>
    /// A row's <c>UpdatedAt</c> is stamped when its save starts, and the row becomes
    /// visible when that save commits. A save that stamped a row just before this answer's
    /// queries ran and committed just after is invisible now, and would be skipped for good
    /// by a cursor of "now". Cloud Run instances' clocks also differ slightly. Two minutes
    /// covers both; the price is that rows changed in those two minutes are sent twice, and
    /// applying one twice is harmless.
    /// </remarks>
    public static readonly TimeSpan Overlap = TimeSpan.FromMinutes(2);

    /// <inheritdoc/>
    /// <param name="userId">Whose data.</param>
    /// <param name="since">The cursor a previous answer returned, in UTC, or null for
    /// everything.</param>
    public async Task<SyncChangesDto> GetChangesAsync(Guid userId, DateTime? since)
    {
        // Taken before the first query, so nothing committed while the queries run can fall
        // between this answer and the next.
        var cursor = DateTime.UtcNow - Overlap;

        return new SyncChangesDto
        {
            Exercises = await exercises.GetUserExercisesAsync(userId, since),
            Workouts = await workouts.GetUserWorkoutsAsync(userId, since),
            WorkoutPlans = await plans.GetUserPlansAsync(userId, since),
            ScheduledWorkouts = await sessions.GetUserScheduledWorkoutsAsync(userId, since),
            FoodItems = await foodItems.GetUserFoodItemsAsync(userId, since),
            Meals = await meals.GetAllMealsAsync(userId, since),
            MealTemplates = await mealTemplates.GetAllAsync(userId, since),
            Weights = await weights.GetWeightLogs(userId, since) ?? [],
            Settings = await settings.GetSettingsAsync(userId, since),
            // A full answer lists what exists; a device starting from nothing has nothing a
            // tombstone could remove.
            Deleted = since is { } from
                ? [.. (await tombstones.GetDeletedSinceAsync(userId, from)).Select(t => new SyncTombstoneDto
                {
                    EntityType = t.EntityType,
                    EntityId = t.EntityId,
                    DeletedAt = t.DeletedAt,
                })]
                : [],
            Cursor = cursor,
        };
    }
}
