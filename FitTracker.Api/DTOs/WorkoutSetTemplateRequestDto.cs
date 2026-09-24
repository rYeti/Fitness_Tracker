using System.ComponentModel.DataAnnotations;

namespace FitTracker.Api.DTOs;

/// <summary>Payload for creating or updating a set template within a workout exercise.</summary>
public class WorkoutSetTemplateRequestDto
{
    /// <summary>
    /// The id the app minted for this row. Read by the batch, which replaces the whole
    /// list and keeps each id it is given, so the row the app holds and the row the
    /// server stores are the same row. Absent from older apps, in which case the server
    /// mints one. The single-row create ignores it.
    /// </summary>
    public Guid? Id { get; set; }

    /// <summary>The ordinal number of this set within the exercise (e.g. 1, 2, 3).</summary>
    [Range(1, 100)]
    public int SetNumber { get; set; }

    /// <summary>The target repetitions for this set (e.g. "8-12" or "10").</summary>
    [Required, MaxLength(20)]
    public string TargetReps { get; set; } = "";

    /// <summary>The zero-based position of this set template within the exercise's template list.</summary>
    [Range(0, int.MaxValue)]
    public int OrderPosition { get; set; }
}
