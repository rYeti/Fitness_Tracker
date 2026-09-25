using System.ComponentModel.DataAnnotations;

namespace FitTracker.Api.DTOs;

/// <summary>Payload for creating or updating a scheduled workout occurrence.</summary>
public class ScheduledWorkoutRequestDto
{
    /// <summary>
    /// The id the app minted for this row. Only a create reads it: a repeat of the
    /// same id updates and returns the row it already made, and an id that names
    /// someone else's row is refused with 409. Apps older than client-minted ids send
    /// none, and the server mints one. See <see cref="Services.ClientIds"/>.
    /// </summary>
    public Guid? Id { get; set; }

    /// <summary>The unique identifier of the workout this scheduled entry is based on.</summary>
    public Guid WorkoutId { get; set; }

    /// <summary>The optional identifier of the workout plan that generated this scheduled workout.</summary>
    public Guid? WorkoutPlanId { get; set; }

    /// <summary>The date on which this workout is scheduled to be performed.</summary>
    public DateTime ScheduledDate { get; set; }

    /// <summary>Optional notes for this scheduled occurrence.</summary>
    [MaxLength(2000)]
    public string? Notes { get; set; }

    /// <summary>Whether this scheduled workout has been completed.</summary>
    public bool IsCompleted { get; set; }

    /// <summary>Whether this scheduled workout was skipped.</summary>
    public bool IsSkipped { get; set; }
}
