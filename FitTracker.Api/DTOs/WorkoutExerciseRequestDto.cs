using System.ComponentModel.DataAnnotations;

namespace FitTracker.Api.DTOs;

/// <summary>Payload for adding or updating an exercise within a workout.</summary>
public class WorkoutExerciseRequestDto
{
    /// <summary>The unique identifier of the exercise definition to reference.</summary>
    public Guid ExerciseId { get; set; }

    /// <summary>The zero-based position of this exercise within the workout.</summary>
    [Range(0, int.MaxValue)]
    public int OrderPosition { get; set; }

    /// <summary>Optional notes specific to this exercise within the workout context.</summary>
    [MaxLength(2000)]
    public string? Notes { get; set; }

    /// <summary>Optional superset group identifier; exercises sharing the same value are treated as a superset.</summary>
    [Range(0, int.MaxValue)]
    public int? SupersetGroupId { get; set; }
}
