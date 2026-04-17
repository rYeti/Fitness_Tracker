namespace FitTracker.Api.DTOs;

/// <summary>Response payload representing a workout and its exercises.</summary>
public class WorkoutResponseDto
{
    /// <summary>The unique identifier of the workout.</summary>
    public Guid Id { get; set; }

    /// <summary>The unique identifier of the user who owns this workout.</summary>
    public Guid UserId { get; set; }

    /// <summary>The name of the workout.</summary>
    public string Name { get; set; } = "";

    /// <summary>An optional description of the workout.</summary>
    public string? Description { get; set; }

    /// <summary>The difficulty level represented as an integer.</summary>
    public int Difficulty { get; set; }

    /// <summary>The estimated duration of the workout in minutes.</summary>
    public int EstimatedDurationMinutes { get; set; }

    /// <summary>Whether this workout is a reusable template.</summary>
    public bool IsTemplate { get; set; }

    /// <summary>The optional date on which this workout is scheduled.</summary>
    public DateTime? ScheduledDate { get; set; }

    /// <summary>The date and time when this workout was completed, or null if not yet completed.</summary>
    public DateTime? CompletedDate { get; set; }

    /// <summary>An optional colour value associated with the workout (ARGB integer).</summary>
    public int? Color { get; set; }

    /// <summary>The list of exercises that make up this workout.</summary>
    public List<WorkoutExerciseResponseDto> Exercises { get; set; } = new();
}
