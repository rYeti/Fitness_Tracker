namespace FitTracker.Api.DTOs;

/// <summary>Payload for creating or updating a performed set within a scheduled workout exercise.</summary>
public class WorkoutSetRequestDto
{
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

    /// <summary>Optional notes recorded for this set.</summary>
    public string? Notes { get; set; }
}
