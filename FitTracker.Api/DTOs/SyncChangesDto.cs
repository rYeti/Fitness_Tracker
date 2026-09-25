namespace FitTracker.Api.DTOs;

/// <summary>
/// The answer to <c>GET api/Sync/changes</c>: every aggregate of the caller's that changed
/// since the cursor they sent, what was deleted since, and the cursor to send next time.
/// See docs/sync-architecture.md, part three.
/// </summary>
/// <remarks>
/// Each list holds exactly what the matching list endpoint returns, in the same DTO, for
/// the rows that changed — the feed calls those endpoints' own services with a filter, so
/// the two cannot drift apart. A row can arrive in two answers in a row (the cursor
/// overlaps), and applying it twice must be harmless.
/// </remarks>
public class SyncChangesDto
{
    /// <summary>The caller's own exercises, as <c>GET api/Exercise/UserExercise</c>. Built-in
    /// exercises are not the caller's data and never appear here.</summary>
    public List<ExerciseResponseDto> Exercises { get; set; } = [];

    /// <summary>As <c>GET api/Workout</c>: each with all its exercise entries, retired ones
    /// (<c>removedAt</c> set) included, and their set templates.</summary>
    public List<WorkoutResponseDto> Workouts { get; set; } = [];

    /// <summary>As <c>GET api/WorkoutPlan</c>, each with its whole list of workout ids.</summary>
    public List<WorkoutPlanResponseDto> WorkoutPlans { get; set; } = [];

    /// <summary>As <c>GET api/ScheduledWorkout</c>, each with its exercises and their logged sets.</summary>
    public List<ScheduledWorkoutResponseDto> ScheduledWorkouts { get; set; } = [];

    /// <summary>As <c>GET api/FoodItem</c>.</summary>
    public List<FoodItemResponseDto> FoodItems { get; set; } = [];

    /// <summary>As <c>GET api/Meal/all</c>, each with all its food entries.</summary>
    public List<MealResponseDto> Meals { get; set; } = [];

    /// <summary>As <c>GET api/MealTemplate</c>, each with all its items.</summary>
    public List<MealTemplateResponseDto> MealTemplates { get; set; } = [];

    /// <summary>As <c>GET api/WeightTracking/TrackWeight</c>.</summary>
    public List<WeightTrackingResponseDto> Weights { get; set; } = [];

    /// <summary>As <c>GET api/UserSettings</c>, or null when they haven't changed (or the
    /// caller has never saved any).</summary>
    public UserSettingsResponseDto? Settings { get; set; }

    /// <summary>Every row of the caller's deleted since the cursor. Empty when no cursor was
    /// sent: a full answer lists what exists, and a device starting from nothing has nothing
    /// to delete.</summary>
    public List<SyncTombstoneDto> Deleted { get; set; } = [];

    /// <summary>What to send as <c>since</c> next time: when this answer began, minus an
    /// overlap. UTC.</summary>
    public DateTime Cursor { get; set; }
}

/// <summary>One deleted row.</summary>
public class SyncTombstoneDto
{
    /// <summary>What kind of row it was: one of <c>SyncEntityTypes</c> — <c>exercise</c>,
    /// <c>workout</c>, <c>workoutPlan</c>, <c>scheduledWorkout</c>, <c>meal</c>,
    /// <c>mealFood</c>, <c>foodItem</c>, <c>mealTemplate</c> or <c>weight</c>.</summary>
    public string EntityType { get; set; } = "";

    /// <summary>The deleted row's id.</summary>
    public Guid EntityId { get; set; }

    /// <summary>When it was deleted, in UTC.</summary>
    public DateTime DeletedAt { get; set; }
}
