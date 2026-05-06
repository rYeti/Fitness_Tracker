namespace FitTracker.Api.DTOs;

/// <summary>Response payload representing a workout plan and its member workout IDs.</summary>
public class WorkoutPlanResponseDto
{
    /// <summary>The unique identifier of the workout plan.</summary>
    public Guid Id { get; set; }

    /// <summary>The unique identifier of the user who owns this plan.</summary>
    public Guid UserId { get; set; }

    /// <summary>The name of the workout plan.</summary>
    public string Name { get; set; } = "";

    /// <summary>An optional description of the workout plan.</summary>
    public string? Description { get; set; }

    /// <summary>The date on which this plan begins.</summary>
    public DateTime StartDate { get; set; }

    /// <summary>The date and time when this plan was created.</summary>
    public DateTime CreatedAt { get; set; }

    /// <summary>Whether this plan is currently active for the user.</summary>
    public bool IsActive { get; set; }

    /// <summary>A JSON-encoded string describing the cycle pattern of workouts within the plan.</summary>
    public string CyclePatternJson { get; set; } = "";

    /// <summary>Whether the user may choose any workout freely rather than following the fixed cycle pattern.</summary>
    public bool IsFreeChoice { get; set; }

    /// <summary>The number of days this plan is scheduled for. Null for free-choice plans.</summary>
    public int? DurationDays { get; set; }

    /// <summary>The list of workout IDs that are part of this plan.</summary>
    public List<Guid> WorkoutIds { get; set; } = new();
}
