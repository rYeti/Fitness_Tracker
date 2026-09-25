namespace FitTracker.Api.Models;

/// <summary>
/// The parts of a client's data a <c>ClientDataChanged</c> event can name. They are the
/// Trainer Console's panes, not the server's tables: an area says which panes to fetch
/// again. See docs/sync-architecture.md, part four.
/// </summary>
public static class DataAreas
{
    /// <summary>Exercises, workouts and plans.</summary>
    public const string Workouts = "workouts";

    /// <summary>Scheduled workouts, with their exercises and logged sets.</summary>
    public const string Sessions = "sessions";

    /// <summary>Meals and their foods, food items, meal templates.</summary>
    public const string Nutrition = "nutrition";

    /// <summary>Weight entries.</summary>
    public const string Weight = "weight";

    /// <summary>The area of the aggregate rooted at <paramref name="root"/>, or null when
    /// no pane shows it (a user's settings).</summary>
    public static string? Of(Type root) =>
        root == typeof(Exercise) || root == typeof(Workout) || root == typeof(WorkoutPlan) ? Workouts
        : root == typeof(ScheduledWorkout) ? Sessions
        : root == typeof(Meal) || root == typeof(FoodItem) || root == typeof(MealTemplate) ? Nutrition
        : root == typeof(WeightTracking) ? Weight
        : null;

    /// <summary>The area of a deleted row, by its tombstone's
    /// <see cref="SyncTombstone.EntityType"/>.</summary>
    /// <remarks>Null for a type added to <see cref="SyncEntityTypes"/> and not here. This runs
    /// inside the save that deletes the row, so it answers rather than throws: a missing area
    /// costs a notification, never the delete. A test checks every type has one.</remarks>
    public static string? OfTombstone(string entityType) => entityType switch
    {
        SyncEntityTypes.Exercise or SyncEntityTypes.Workout or SyncEntityTypes.WorkoutPlan => Workouts,
        SyncEntityTypes.ScheduledWorkout => Sessions,
        SyncEntityTypes.Meal or SyncEntityTypes.MealFood or SyncEntityTypes.FoodItem or SyncEntityTypes.MealTemplate => Nutrition,
        SyncEntityTypes.Weight => Weight,
        _ => null,
    };
}
