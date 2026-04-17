namespace FitTracker.Api.DTOs;

/// <summary>Response payload representing a scheduled workout occurrence and its exercises.</summary>
public class ScheduledWorkoutResponseDto
{
    /// <summary>The unique identifier of this scheduled workout.</summary>
    public Guid Id { get; set; }

    /// <summary>The unique identifier of the base workout.</summary>
    public Guid WorkoutId { get; set; }

    /// <summary>The optional identifier of the workout plan that generated this scheduled workout.</summary>
    public Guid? WorkoutPlanId { get; set; }

    /// <summary>The optional identifier of the template workout used when this entry was created from a template.</summary>
    public Guid? TemplateWorkoutId { get; set; }

    /// <summary>The date on which this workout is scheduled.</summary>
    public DateTime ScheduledDate { get; set; }

    /// <summary>The date and time when this scheduled workout was created.</summary>
    public DateTime CreatedAt { get; set; }

    /// <summary>Optional notes for this scheduled occurrence.</summary>
    public string? Notes { get; set; }

    /// <summary>Whether the user has completed this scheduled workout.</summary>
    public bool IsCompleted { get; set; }

    /// <summary>Whether the user has skipped this scheduled workout.</summary>
    public bool IsSkipped { get; set; }

    /// <summary>The scheduled exercise entries within this scheduled workout.</summary>
    public List<ScheduledWorkoutExerciseResponseDto> Exercises { get; set; } = new();
}
