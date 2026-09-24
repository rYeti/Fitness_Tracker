namespace FitTracker.Api.Models;

/// <summary>Represents a single set performed within a scheduled workout exercise.</summary>
public class WorkoutSet
{
    /// <summary>The unique identifier of this workout set.</summary>
    public Guid Id { get; set; }

    /// <summary>The unique identifier of the scheduled workout exercise this set belongs to.</summary>
    public Guid ScheduledWorkoutExerciseId { get; set; }

    /// <summary>The ordinal number of this set within the exercise (e.g. 1, 2, 3).</summary>
    public int SetNumber { get; set; }

    /// <summary>The number of repetitions performed in this set, or null if not applicable.</summary>
    public int? Reps { get; set; }

    /// <summary>The weight used for this set, or null if not applicable.</summary>
    public double? Weight { get; set; }

    /// <summary>The unit of the weight value (e.g. "kg" or "lbs"), or null if no weight was recorded.</summary>
    public string? WeightUnit { get; set; }

    /// <summary>The duration of this set in seconds, or null if not a timed set.</summary>
    public int? DurationSeconds { get; set; }

    /// <summary>Rate of Perceived Exertion (1-10), or null if not recorded.</summary>
    public int? Rpe { get; set; }

    /// <summary>
    /// What kind of set this was, as the app's <c>SetType</c> ordinal:
    /// 0 normal, 1 warm-up, 2 drop set, 3 failure. Stored as the ordinal because
    /// that is what the device stores; a shipped app indexes its enum by it, so
    /// the range is fixed by <see cref="DTOs.WorkoutSetRequestDto.SetType"/>.
    /// </summary>
    public int SetType { get; set; }

    /// <summary>
    /// Which side a unilateral set was performed with, as the app's <c>SetSide</c>
    /// ordinal: 0 both, 1 left, 2 right.
    /// </summary>
    public int Side { get; set; }

    /// <summary>Whether this set has been marked as completed by the user.</summary>
    public bool IsCompleted { get; set; }

    /// <summary>Optional notes recorded for this set.</summary>
    public string? Notes { get; set; }

    /// <summary>Navigation property to the parent scheduled workout exercise.</summary>
    public ScheduledWorkoutExercise ScheduledWorkoutExercise { get; set; } = null!;
}
