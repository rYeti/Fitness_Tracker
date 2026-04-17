namespace FitTracker.Api.Models;

/// <summary>Represents an exercise definition, either system-provided or user-created.</summary>
public class Exercise
{
    /// <summary>The unique identifier of the exercise.</summary>
    public Guid Id { get; set; }

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

    // Navigation property to the User
    public User User { get; set; } = null!;

    /// <summary>The ID of the user who owns this exercise.</summary>
    public Guid UserId { get; set; }

}