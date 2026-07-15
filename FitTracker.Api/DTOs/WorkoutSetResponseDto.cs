namespace FitTracker.Api.DTOs;

/// <summary>Response payload representing a single performed set within a scheduled workout exercise.</summary>
public class WorkoutSetResponseDto
{
    /// <summary>The unique identifier of this workout set.</summary>
    public Guid Id { get; set; }

    /// <summary>The unique identifier of the scheduled workout exercise this set belongs to.</summary>
    public Guid ScheduledWorkoutExerciseId { get; set; }

    /// <summary>The ordinal number of this set within the exercise.</summary>
    public int SetNumber { get; set; }

    /// <summary>The number of repetitions performed, or null if not applicable.</summary>
    public int? Reps { get; set; }

    /// <summary>The weight used for this set, or null if not applicable.</summary>
    public double? Weight { get; set; }

    /// <summary>The unit of the weight value, or null if no weight was recorded.</summary>
    public string? WeightUnit { get; set; }

    /// <summary>The duration of this set in seconds, or null if not a timed set.</summary>
    public int? DurationSeconds { get; set; }

    /// <summary>Rate of Perceived Exertion (1-10), or null if not recorded.</summary>
    public int? Rpe { get; set; }

    /// <summary>Whether this set has been marked as completed by the user.</summary>
    public bool IsCompleted { get; set; }

    /// <summary>Optional notes recorded for this set.</summary>
    public string? Notes { get; set; }
}
