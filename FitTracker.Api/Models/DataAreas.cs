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

    /// <summary>Meals and their foods, food items, meal templates, and settings, which hold
    /// the calorie goal.</summary>
    public const string Nutrition = "nutrition";

    /// <summary>Weight entries.</summary>
    public const string Weight = "weight";

    /// <summary>
    /// Every synced type a change is recorded against, once: the type, the
    /// <see cref="SyncTombstone.EntityType"/> its deletes are buried under, and its area.
    /// </summary>
    /// <remarks>
    /// One table, not a switch per question, so a new synced root is one row here and can't be
    /// given an area for its changes and forgotten for its deletes. A test checks that every
    /// <see cref="ISyncRoot"/> and every tombstone type has a row.
    /// </remarks>
    private static readonly (Type Type, string? Tombstone, string Area)[] Table =
    [
        (typeof(Exercise), SyncEntityTypes.Exercise, Workouts),
        (typeof(Workout), SyncEntityTypes.Workout, Workouts),
        (typeof(WorkoutPlan), SyncEntityTypes.WorkoutPlan, Workouts),
        (typeof(ScheduledWorkout), SyncEntityTypes.ScheduledWorkout, Sessions),
        (typeof(Meal), SyncEntityTypes.Meal, Nutrition),
        // Not a root: the one child with tombstones of its own. A change to it is its meal's.
        (typeof(MealFoodEntry), SyncEntityTypes.MealFood, Nutrition),
        (typeof(FoodItem), SyncEntityTypes.FoodItem, Nutrition),
        (typeof(MealTemplate), SyncEntityTypes.MealTemplate, Nutrition),
        // The calorie goal the Nutrition pane and Client Detail's intake are measured against is
        // a setting. Settings are one row per user and never deleted on their own: no tombstone.
        (typeof(UserSettings), null, Nutrition),
        (typeof(WeightTracking), SyncEntityTypes.Weight, Weight),
    ];

    private static readonly Dictionary<Type, string> ByType = Table.ToDictionary(r => r.Type, r => r.Area);

    private static readonly Dictionary<string, string> ByTombstone = Table
        .Where(r => r.Tombstone != null)
        .ToDictionary(r => r.Tombstone!, r => r.Area);

    /// <summary>The area of the aggregate rooted at <paramref name="root"/>; null for a type
    /// that isn't in the table.</summary>
    public static string? Of(Type root) => ByType.GetValueOrDefault(root);

    /// <summary>The area of a deleted row, by its tombstone's
    /// <see cref="SyncTombstone.EntityType"/>.</summary>
    /// <remarks>Null for a type added to <see cref="SyncEntityTypes"/> and not to the table.
    /// This runs inside the save that deletes the row, so it answers rather than throws: a
    /// missing area costs a notification, never the delete.</remarks>
    public static string? OfTombstone(string entityType) => ByTombstone.GetValueOrDefault(entityType);
}
