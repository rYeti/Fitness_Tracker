namespace FitTracker.Api.Models;

/// <summary>Represents a workout template or scheduled workout entry owned by a user.</summary>
public class Workout
{
    /// <summary>The unique identifier of the workout.</summary>
    public Guid Id { get; set; }

    /// <summary>The unique identifier of the user who owns this workout.</summary>
    public Guid UserId { get; set; }

    /// <summary>The name of the workout.</summary>
    public string Name { get; set; } = "";

    /// <summary>An optional description of the workout.</summary>
    public string? Description { get; set; }

    /// <summary>The difficulty level of the workout represented as an integer (e.g. 1=easy, 3=hard).</summary>
    public int Difficulty { get; set; }

    /// <summary>The estimated duration of the workout in minutes. Defaults to 30.</summary>
    public int EstimatedDurationMinutes { get; set; } = 30;

    /// <summary>Whether this workout is a reusable template rather than a one-off entry. Defaults to true.</summary>
    public bool IsTemplate { get; set; } = true;

    /// <summary>The optional date on which this workout is scheduled to be performed.</summary>
    public DateTime? ScheduledDate { get; set; }

    /// <summary>The date and time when this workout was completed, or null if not yet completed.</summary>
    public DateTime? CompletedDate { get; set; }

    /// <summary>An optional colour value associated with the workout (ARGB integer).</summary>
    public int? Color { get; set; }

    /// <summary>When the workout was deleted, or null while it still exists. Set instead of
    /// deleting the row when scheduled sessions have already logged sets against it:
    /// <see cref="ScheduledWorkout"/> holds a restricted foreign key here, so removing the
    /// row would mean destroying that history. Every read that answers "which workouts does
    /// this user have" must exclude non-null values; reads that resolve logged sessions must not.</summary>
    public DateTime? RemovedAt { get; set; }

    /// <summary>Navigation property to the user who owns this workout.</summary>
    public User User { get; set; } = null!;

    /// <summary>The exercises that make up this workout.</summary>
    public ICollection<WorkoutExercise> Exercises { get; set; } = new List<WorkoutExercise>();

    /// <summary>The plan-workout join records that link this workout to workout plans.</summary>
    public ICollection<WorkoutPlanWorkout> PlanWorkouts { get; set; } = new List<WorkoutPlanWorkout>();
}
