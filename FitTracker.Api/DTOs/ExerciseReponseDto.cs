namespace FitTracker.Api.DTOs;

/// <summary>Response payload returned when reading exercise data.</summary>
public class ExerciseResponseDto
{
    /// <summary>The unique identifier of the exercise.</summary>
    public Guid id { get; set; }

    /// <summary>The English name of the exercise.</summary>
    public string Name { get; set; } = "";

    /// <summary>The English description of the exercise.</summary>
    public string Description { get; set; } = "";

    /// <summary>The exercise type (e.g. strength, cardio) represented as an integer enum value.</summary>
    public int Type { get; set; }

    /// <summary>Comma-separated list of targeted muscle group enum indices (matches Flutter's targetMuscleGroups CSV format).</summary>
    public string TargetMuscleGroups { get; set; } = "";

    /// <summary>URL of the exercise's preview image.</summary>
    public string ImageUrl { get; set; } = "";

    /// <summary>Whether this is a user-created custom exercise rather than a system exercise.</summary>
    public bool IsCustom { get; set; }

    /// <summary>The German name of the exercise.</summary>
    public string NameDe { get; set; } = "";

    /// <summary>The German description of the exercise.</summary>
    public string DescriptionDe { get; set; } = "";

    /// <summary>The owner of this exercise, or null for a system-provided one. Present so
    /// the Trainer Console's exercise picker can tell a trainer's own exercise apart from
    /// the caller's — every other consumer of this DTO only ever sees their own id here or
    /// null, so nothing already reading it is exposed to anyone else's.</summary>
    public Guid? UserId { get; set; }
}