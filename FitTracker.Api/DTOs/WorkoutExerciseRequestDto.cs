using System.ComponentModel.DataAnnotations;

namespace FitTracker.Api.DTOs;

/// <summary>Payload for adding or updating an exercise within a workout.</summary>
public class WorkoutExerciseRequestDto
{
    /// <summary>
    /// The id the app minted for this row. Only a create reads it: a repeat of the
    /// same id updates and returns the row it already made, and an id that names
    /// someone else's row is refused with 409. Apps older than client-minted ids send
    /// none, and the server mints one. See <see cref="Services.ClientIds"/>.
    /// </summary>
    public Guid? Id { get; set; }

    /// <summary>The unique identifier of the exercise definition to reference.</summary>
    public Guid ExerciseId { get; set; }

    /// <summary>The zero-based position of this exercise within the workout.</summary>
    [Range(0, int.MaxValue)]
    public int OrderPosition { get; set; }

    /// <summary>Optional notes specific to this exercise within the workout context.</summary>
    [MaxLength(2000)]
    public string? Notes { get; set; }

    /// <summary>Optional superset group identifier; exercises sharing the same value are treated as a superset.</summary>
    [Range(0, int.MaxValue)]
    public int? SupersetGroupId { get; set; }
}
