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

    // Navigation property to the User (null for system/global exercises)
    public User? User { get; set; }

    /// <summary>The ID of the user who owns this exercise. Null for system-provided exercises.</summary>
    public Guid? UserId { get; set; }

    /// <summary>When this row is a trainer's exercise copied into a client's library (see
    /// <c>TrainerConsoleService</c>'s prescription diff), the exercise it was copied from.
    /// Null for everything else. No foreign key: like <see cref="Models.WorkoutExercise.ExerciseId"/>,
    /// this deliberately doesn't enforce referential integrity against a trainer's original —
    /// the copy is a fully independent row, and must stay resolvable even after the trainer
    /// deletes or edits their own. Existing purely so the same trainer exercise, prescribed to
    /// the same client twice, reuses one copy instead of growing their library.</summary>
    public Guid? SourceExerciseId { get; set; }

}