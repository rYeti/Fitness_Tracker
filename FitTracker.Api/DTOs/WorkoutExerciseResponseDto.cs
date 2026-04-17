namespace FitTracker.Api.DTOs;

/// <summary>Response payload representing an exercise entry within a workout.</summary>
public class WorkoutExerciseResponseDto
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

    /// <summary>Optional superset group identifier.</summary>
    public int? SupersetGroupId { get; set; }

    /// <summary>The set templates defined for this exercise.</summary>
    public List<WorkoutSetTemplateResponseDto> SetTemplates { get; set; } = new();
}
