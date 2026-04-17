namespace FitTracker.Api.DTOs;

/// <summary>Payload for creating or updating a scheduled workout occurrence.</summary>
public class ScheduledWorkoutRequestDto
{
    /// <summary>The unique identifier of the workout this scheduled entry is based on.</summary>
    public Guid WorkoutId { get; set; }

    /// <summary>The optional identifier of the workout plan that generated this scheduled workout.</summary>
    public Guid? WorkoutPlanId { get; set; }

    /// <summary>The date on which this workout is scheduled to be performed.</summary>
    public DateTime ScheduledDate { get; set; }

    /// <summary>Optional notes for this scheduled occurrence.</summary>
    public string? Notes { get; set; }
}
