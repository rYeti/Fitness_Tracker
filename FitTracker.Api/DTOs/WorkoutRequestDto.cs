using System.ComponentModel.DataAnnotations;

namespace FitTracker.Api.DTOs;

/// <summary>Payload for creating or updating a workout.</summary>
public class WorkoutRequestDto
{
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
