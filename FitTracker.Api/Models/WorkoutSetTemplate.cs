namespace FitTracker.Api.Models;

/// <summary>Represents a set template associated with a workout exercise, defining target repetitions and ordering.</summary>
public class WorkoutSetTemplate
{
    /// <summary>The unique identifier of this set template.</summary>
    public Guid Id { get; set; }

    /// <summary>The unique identifier of the workout exercise this template belongs to.</summary>
    public Guid WorkoutExerciseId { get; set; }

    /// <summary>The ordinal number of this set within the exercise (e.g. 1, 2, 3).</summary>
    public int SetNumber { get; set; }

    /// <summary>The target repetitions for this set, stored as a string to support ranges (e.g. "8-12") or fixed counts.</summary>
    public string TargetReps { get; set; } = "";

    /// <summary>The zero-based position of this set template within the exercise's template list.</summary>
    public int OrderPosition { get; set; }

    /// <summary>Navigation property to the parent workout exercise.</summary>
    public WorkoutExercise WorkoutExercise { get; set; } = null!;
}
