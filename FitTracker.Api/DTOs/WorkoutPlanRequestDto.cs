namespace FitTracker.Api.DTOs;

/// <summary>Payload for creating or updating a workout plan.</summary>
public class WorkoutPlanRequestDto
{
    /// <summary>The name of the workout plan.</summary>
    public string Name { get; set; } = "";

    /// <summary>An optional description of the workout plan.</summary>
    public string? Description { get; set; }

    /// <summary>The date on which this plan begins.</summary>
    public DateTime StartDate { get; set; }

    /// <summary>A JSON-encoded string describing the cycle pattern of workouts within the plan.</summary>
    public string CyclePatternJson { get; set; } = "";

    /// <summary>Whether the user may choose any workout freely rather than following the fixed cycle pattern.</summary>
    public bool IsFreeChoice { get; set; }
}
