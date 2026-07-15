using System.ComponentModel.DataAnnotations;

namespace FitTracker.Api.DTOs;

/// <summary>Payload for creating or updating a performed set within a scheduled workout exercise.</summary>
public class WorkoutSetRequestDto
{
    /// <summary>The ordinal number of this set within the exercise (e.g. 1, 2, 3).</summary>
    [Range(1, 100)]
    public int SetNumber { get; set; }

    /// <summary>The number of repetitions performed in this set, or null if not applicable.</summary>
    [Range(0, 10000)]
    public int? Reps { get; set; }

    /// <summary>The weight used for this set, or null if not applicable.</summary>
    [Range(0, 2000)]
    public double? Weight { get; set; }

    /// <summary>The unit of the weight value (e.g. "kg" or "lbs"), or null if no weight was recorded.</summary>
    [MaxLength(10)]
    public string? WeightUnit { get; set; }

    /// <summary>The duration of this set in seconds, or null if not a timed set.</summary>
    [Range(0, 86400)]
    public int? DurationSeconds { get; set; }

    /// <summary>Rate of Perceived Exertion (1-10), or null if not recorded.</summary>
    [Range(1, 10)]
    public int? Rpe { get; set; }

    /// <summary>Whether this set has been marked as completed by the user.</summary>
    public bool IsCompleted { get; set; }

    /// <summary>Optional notes recorded for this set.</summary>
    [MaxLength(2000)]
    public string? Notes { get; set; }
}
