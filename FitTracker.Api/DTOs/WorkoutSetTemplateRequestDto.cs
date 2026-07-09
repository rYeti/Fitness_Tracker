using System.ComponentModel.DataAnnotations;

namespace FitTracker.Api.DTOs;

/// <summary>Payload for creating or updating a set template within a workout exercise.</summary>
public class WorkoutSetTemplateRequestDto
{
    /// <summary>The ordinal number of this set within the exercise (e.g. 1, 2, 3).</summary>
    [Range(1, 100)]
    public int SetNumber { get; set; }

    /// <summary>The target repetitions for this set (e.g. "8-12" or "10").</summary>
    [Required, MaxLength(20)]
    public string TargetReps { get; set; } = "";

    /// <summary>The zero-based position of this set template within the exercise's template list.</summary>
    [Range(0, int.MaxValue)]
    public int OrderPosition { get; set; }
}
