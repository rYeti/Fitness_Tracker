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

    /// <summary>Whether a trainer assigned this plan, rather than the owner building it
    /// themselves. Only the assigning trainer can delete it — see
    /// <c>WorkoutPlan.AssignedByTrainerId</c>.</summary>
    public bool AssignedByTrainer { get; set; }

    /// <summary>The plan's deload weeks, sorted by week. Empty for a plan with none.</summary>
    /// <remarks>
    /// Absent from the payload entirely — rather than empty — when the reader isn't entitled
    /// to see them and the plan is their own (see <c>docs/deload-weeks.md</c> §7a). A reader
    /// must therefore treat a missing value as "not provided", never as "clear it": a
    /// reconcile that reads absence as empty deletes a lapsed subscriber's deload weeks, and
    /// re-subscribing never brings them back.
    /// <para>A deload set by a trainer is always sent, whatever the client's own
    /// entitlement. A lapsed licence must never hide a programme's own recovery week.</para>
    /// </remarks>
    [System.Text.Json.Serialization.JsonIgnore(
        Condition = System.Text.Json.Serialization.JsonIgnoreCondition.WhenWritingNull)]
    public List<Models.DeloadWeek>? DeloadWeeks { get; set; }

    /// <summary>The list of workout IDs that are part of this plan.</summary>
    public List<Guid> WorkoutIds { get; set; } = new();
}
