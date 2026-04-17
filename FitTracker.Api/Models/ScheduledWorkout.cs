namespace FitTracker.Api.Models;

/// <summary>Represents a concrete scheduled occurrence of a workout on a specific date.</summary>
public class ScheduledWorkout
{
    /// <summary>The unique identifier of this scheduled workout.</summary>
    public Guid Id { get; set; }

    /// <summary>The unique identifier of the workout this scheduled entry is based on.</summary>
    public Guid WorkoutId { get; set; }

    /// <summary>The optional identifier of the workout plan that generated this scheduled workout.</summary>
    public Guid? WorkoutPlanId { get; set; }

    /// <summary>The optional identifier of the template workout used when this entry was created from a template.</summary>
    public Guid? TemplateWorkoutId { get; set; }

    /// <summary>The date on which this workout is scheduled to be performed.</summary>
    public DateTime ScheduledDate { get; set; }

    /// <summary>The date and time when this scheduled workout was created.</summary>
    public DateTime CreatedAt { get; set; }

    /// <summary>Optional notes for this scheduled occurrence.</summary>
    public string? Notes { get; set; }

    /// <summary>Whether the user has completed this scheduled workout.</summary>
    public bool IsCompleted { get; set; }

    /// <summary>Whether the user has skipped this scheduled workout.</summary>
    public bool IsSkipped { get; set; }

    /// <summary>Navigation property to the base workout.</summary>
    public Workout Workout { get; set; } = null!;

    /// <summary>Navigation property to the workout plan that owns this scheduled entry, if any.</summary>
    public WorkoutPlan? WorkoutPlan { get; set; }

    /// <summary>The scheduled exercise entries within this scheduled workout.</summary>
    public ICollection<ScheduledWorkoutExercise> Exercises { get; set; } = new List<ScheduledWorkoutExercise>();
}
