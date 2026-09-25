namespace FitTracker.Api.Models;

/// <summary>
/// The server's record that a synced row was deleted, so a device that missed the delete
/// is told about it instead of having to infer it from the row's absence. See
/// docs/sync-architecture.md, part three.
/// </summary>
/// <remarks>
/// Written in the same save as the delete it records, by <c>SyncChangeInterceptor</c> for a
/// tracked delete and explicitly at the one bulk delete of a root
/// (<c>WorkoutRepository.DeleteWorkoutAsync</c>). Never pruned: a device whose cursor is a
/// year old still gets every delete since, and a create naming a deleted id is refused
/// (410) for as long as the row would otherwise have come back.
/// </remarks>
public class SyncTombstone
{
    /// <summary>The tombstone's own id.</summary>
    public Guid Id { get; set; }

    /// <summary>The user whose row this was — the row's owner, not whoever deleted it (a
    /// trainer deleting a client's workout writes the client's tombstone).</summary>
    public Guid UserId { get; set; }

    /// <summary>What kind of row it was; one of <see cref="SyncEntityTypes"/>.</summary>
    public string EntityType { get; set; } = "";

    /// <summary>The deleted row's id.</summary>
    public Guid EntityId { get; set; }

    /// <summary>When the row was deleted, in UTC.</summary>
    public DateTime DeletedAt { get; set; }

    /// <summary>Navigation property to the owning user.</summary>
    public User User { get; set; } = null!;
}

/// <summary>The <see cref="SyncTombstone.EntityType"/> of each deletable synced row, as the
/// changes feed names it.</summary>
public static class SyncEntityTypes
{
    /// <summary>A user's own (custom or copied) exercise.</summary>
    public const string Exercise = "exercise";

    /// <summary>A workout.</summary>
    public const string Workout = "workout";

    /// <summary>A workout plan.</summary>
    public const string WorkoutPlan = "workoutPlan";

    /// <summary>A scheduled workout (a session).</summary>
    public const string ScheduledWorkout = "scheduledWorkout";

    /// <summary>A meal.</summary>
    public const string Meal = "meal";

    /// <summary>One food entry in a meal. The only child with tombstones of its own: a
    /// meal's foods are upserted by id from every device, so a removed entry's id is one a
    /// device that hasn't pulled can send again.</summary>
    public const string MealFood = "mealFood";

    /// <summary>A food item.</summary>
    public const string FoodItem = "foodItem";

    /// <summary>A meal template.</summary>
    public const string MealTemplate = "mealTemplate";

    /// <summary>A weight entry.</summary>
    public const string Weight = "weight";
}
