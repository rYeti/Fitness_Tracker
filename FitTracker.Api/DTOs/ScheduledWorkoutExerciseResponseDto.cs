namespace FitTracker.Api.DTOs;

/// <summary>Response payload representing a single exercise within a scheduled workout session.</summary>
public class ScheduledWorkoutExerciseResponseDto
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

    /// <summary>The actual sets performed for this exercise during the session.</summary>
    public List<WorkoutSetResponseDto> Sets { get; set; } = new();
}
