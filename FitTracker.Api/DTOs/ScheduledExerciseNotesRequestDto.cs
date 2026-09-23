using System.ComponentModel.DataAnnotations;

namespace FitTracker.Api.DTOs;

/// <summary>Payload for replacing the client's note on one exercise of a session.</summary>
public class ScheduledExerciseNotesRequestDto
{
    /// <summary>The note; null or blank clears it.</summary>
    [MaxLength(2000)]
    public string? Notes { get; set; }
}
