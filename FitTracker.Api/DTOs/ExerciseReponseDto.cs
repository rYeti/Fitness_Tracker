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

    /// <summary>The primary muscle group targeted by the exercise.</summary>
    public string TargetMuscle { get; set; } = "";

    /// <summary>URL of the exercise's preview image.</summary>
    public string ImageUrl { get; set; } = "";

    /// <summary>Whether this is a user-created custom exercise rather than a system exercise.</summary>
    public bool IsCustom { get; set; }

    /// <summary>The German name of the exercise.</summary>
    public string NameDe { get; set; } = "";

    /// <summary>The German description of the exercise.</summary>
    public string DescriptionDe { get; set; } = "";
}