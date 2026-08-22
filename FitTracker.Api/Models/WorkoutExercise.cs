namespace FitTracker.Api.Models;

/// <summary>Represents an exercise entry within a workout, including ordering and optional grouping information.</summary>
public class WorkoutExercise
{
    /// <summary>The unique identifier of this workout-exercise link.</summary>
    public Guid Id { get; set; }

    /// <summary>The unique identifier of the workout this entry belongs to.</summary>
    public Guid WorkoutId { get; set; }

    /// <summary>The unique identifier of the exercise definition referenced by this entry.</summary>
    public Guid ExerciseId { get; set; }

    /// <summary>The zero-based position of this exercise within the workout.</summary>
    public int OrderPosition { get; set; }

    /// <summary>Optional notes specific to this exercise within the workout context.</summary>
    public string? Notes { get; set; }

    /// <summary>Optional superset group identifier; exercises sharing the same value are treated as a superset.</summary>
    public int? SupersetGroupId { get; set; }

    /// <summary>When the exercise was taken out of the workout, or null while it is still
    /// part of it. Set instead of deleting the row when scheduled sessions have already
    /// logged sets against this entry: <see cref="ScheduledWorkoutExercise"/> holds a
    /// restricted foreign key here, so removing the row would mean destroying that
    /// history. Every read that answers "what is in this workout" must exclude
    /// non-null values; reads that resolve historical logs must not.</summary>
    public DateTime? RemovedAt { get; set; }

    /// <summary>Navigation property to the parent workout.</summary>
    public Workout Workout { get; set; } = null!;

    /// <summary>The set templates defined for this exercise within the workout.</summary>
    public ICollection<WorkoutSetTemplate> SetTemplates { get; set; } = new List<WorkoutSetTemplate>();

    /// <summary>The scheduled exercise records that reference this workout-exercise entry.</summary>
    public ICollection<ScheduledWorkoutExercise> ScheduledExercises { get; set; } = new List<ScheduledWorkoutExercise>();
}
