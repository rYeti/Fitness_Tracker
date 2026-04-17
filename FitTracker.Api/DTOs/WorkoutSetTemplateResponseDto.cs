namespace FitTracker.Api.DTOs;

/// <summary>Response payload representing a set template for a workout exercise.</summary>
public class WorkoutSetTemplateResponseDto
{
    /// <summary>The unique identifier of this set template.</summary>
    public Guid Id { get; set; }

    /// <summary>The unique identifier of the workout exercise this template belongs to.</summary>
    public Guid WorkoutExerciseId { get; set; }

    /// <summary>The ordinal number of this set within the exercise.</summary>
    public int SetNumber { get; set; }

    /// <summary>The target repetitions for this set (e.g. "8-12" or "10").</summary>
    public string TargetReps { get; set; } = "";

    /// <summary>The zero-based position of this set template within the exercise's template list.</summary>
    public int OrderPosition { get; set; }
}
