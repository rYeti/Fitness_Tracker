using System.ComponentModel.DataAnnotations;

namespace FitTracker.Api.DTOs;

/// <summary>Payload for creating or updating a workout.</summary>
public class WorkoutRequestDto
{
    /// <summary>
    /// The id the app minted for this row. Only a create reads it: a repeat of the
    /// same id updates and returns the row it already made, and an id that names
    /// someone else's row is refused with 409. Apps older than client-minted ids send
    /// none, and the server mints one. See <see cref="Services.ClientIds"/>.
    /// </summary>
    public Guid? Id { get; set; }

    /// <summary>The name of the workout.</summary>
    [Required, MaxLength(200)]
    public string Name { get; set; } = "";

    /// <summary>An optional description of the workout.</summary>
    [MaxLength(2000)]
    public string? Description { get; set; }

    /// <summary>The difficulty level represented as an integer (0=beginner, 1=intermediate, 2=advanced).</summary>
    [Range(0, 2)]
    public int Difficulty { get; set; }

    /// <summary>The estimated duration of the workout in minutes.</summary>
    [Range(1, 1440)]
    public int EstimatedDurationMinutes { get; set; }

    /// <summary>Whether this workout is a reusable template.</summary>
    public bool IsTemplate { get; set; }

    /// <summary>The optional date on which this workout is scheduled.</summary>
    public DateTime? ScheduledDate { get; set; }

    /// <summary>An optional colour value associated with the workout (ARGB integer).</summary>
    public int? Color { get; set; }
}
