using System.Text.Json.Serialization;

namespace FitTracker.Api.DTOs;

/// <summary>Response payload representing a single exercise within a scheduled workout session.</summary>
public class ScheduledWorkoutExerciseResponseDto
{
    /// <summary>The unique identifier of this scheduled exercise entry.</summary>
    public Guid Id { get; set; }

    /// <summary>
    /// In a batch's answer, the id the item this entry answers was sent with; absent
    /// everywhere else. It differs from <see cref="Id"/> when the server answered with an
    /// entry it already held (its content de-duplication) or had to mint a fresh id, and is
    /// what the app pairs the answer with its request by — never position, which is not
    /// an identity. Apps that predate it ignore a field they don't read.
    /// </summary>
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public Guid? RequestedId { get; set; }

    /// <summary>The unique identifier of the scheduled workout this exercise belongs to.</summary>
    public Guid ScheduledWorkoutId { get; set; }

    /// <summary>The unique identifier of the workout exercise template this entry was generated from.</summary>
    public Guid WorkoutExerciseId { get; set; }

    /// <summary>Whether the user has completed this exercise during the session.</summary>
    public bool IsCompleted { get; set; }

    /// <summary>Optional notes recorded for this exercise during the session.</summary>
    public string? Notes { get; set; }

    /// <summary>An optional override exercise ID used when the user substitutes a different exercise.</summary>
    public Guid? OverrideExerciseId { get; set; }

    /// <summary>The actual sets performed for this exercise during the session.</summary>
    public List<WorkoutSetResponseDto> Sets { get; set; } = new();
}
