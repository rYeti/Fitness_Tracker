namespace FitTracker.Api.Models;

/// <summary>Represents a single exercise within a scheduled workout, tracking completion and any overrides.</summary>
public class ScheduledWorkoutExercise
{
    /// <summary>The unique identifier of this scheduled exercise entry.</summary>
    public Guid Id { get; set; }

    /// <summary>The unique identifier of the scheduled workout this exercise belongs to.</summary>
    public Guid ScheduledWorkoutId { get; set; }

    /// <summary>The unique identifier of the workout exercise template this entry was generated from.</summary>
    public Guid WorkoutExerciseId { get; set; }

    /// <summary>Whether the user has completed this exercise during the session.</summary>
    public bool IsCompleted { get; set; }

    /// <summary>Optional notes recorded for this exercise during the session.</summary>
    public string? Notes { get; set; }

    /// <summary>An optional override exercise ID used when the user substitutes a different exercise.</summary>
    public Guid? OverrideExerciseId { get; set; }

    /// <summary>Navigation property to the parent scheduled workout.</summary>
    public ScheduledWorkout ScheduledWorkout { get; set; } = null!;

    /// <summary>Navigation property to the workout exercise template.</summary>
    public WorkoutExercise WorkoutExercise { get; set; } = null!;

    /// <summary>The actual sets performed for this exercise during the session.</summary>
    public ICollection<WorkoutSet> Sets { get; set; } = new List<WorkoutSet>();
}
