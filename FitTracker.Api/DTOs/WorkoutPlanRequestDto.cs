using System.ComponentModel.DataAnnotations;

namespace FitTracker.Api.DTOs;

/// <summary>Payload for creating or updating a workout plan.</summary>
public class WorkoutPlanRequestDto
{
    /// <summary>The name of the workout plan.</summary>
    [Required, MaxLength(200)]
    public string Name { get; set; } = "";

    /// <summary>An optional description of the workout plan.</summary>
    [MaxLength(2000)]
    public string? Description { get; set; }

    /// <summary>The date on which this plan begins.</summary>
    public DateTime StartDate { get; set; }

    /// <summary>A JSON-encoded string describing the cycle pattern of workouts within the plan.</summary>
    [MaxLength(20000)]
    public string CyclePatternJson { get; set; } = "";

    /// <summary>Whether the user may choose any workout freely rather than following the fixed cycle pattern.</summary>
    public bool IsFreeChoice { get; set; }

    /// <summary>The number of days this plan is scheduled for. Null for free-choice plans.</summary>
    [Range(1, 3650)]
    public int? DurationDays { get; set; }
}
