using System.ComponentModel.DataAnnotations;
using FitTracker.Api.DTOs.Validation;

namespace FitTracker.Api.DTOs;

/// <summary>Request payload for creating or updating an exercise.</summary>
public class ExerciseRequestDto
{
    /// <summary>The English name of the exercise.</summary>
    public string Name { get; set; } = "";

    /// <summary>The English description of the exercise.</summary>
    public string Description { get; set; } = "";

    /// <summary>The exercise type (e.g. strength, cardio) represented as an integer enum value.</summary>
    public int Type { get; set; }

    /// <summary>Comma-separated list of targeted muscle group enum indices (matches Flutter's targetMuscleGroups CSV format).</summary>
    public string TargetMuscleGroups { get; set; } = "";

    /// <summary>URL of the exercise's preview image.</summary>
    [MaxLength(2048), HttpsUrl]
    public string ImageUrl { get; set; } = "";

    /// <summary>Whether this is a user-created custom exercise rather than a system exercise.</summary>
    public bool IsCustom { get; set; }

    /// <summary>The German name of the exercise.</summary>
    public string NameDe { get; set; } = "";

    /// <summary>The German description of the exercise.</summary>
    public string DescriptionDe { get; set; } = "";
}