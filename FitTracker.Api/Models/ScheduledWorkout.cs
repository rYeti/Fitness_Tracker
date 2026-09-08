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

    /// <summary>Whether this session was performed in a deload week — stamped once, when
    /// it is first completed. Null for a session nobody has done yet.</summary>
    /// <remarks>
    /// <para>A stamp rather than something derived on read, because the plan records what
    /// is true <em>now</em> and cannot answer what was true when a session was performed.
    /// Re-deriving would rewrite history every time a trainer edited the deload set,
    /// finished the plan, or let a subscription lapse — see <c>docs/deload-weeks.md</c> §9
    /// and the rule <c>docs/trainer-session-review.md</c> leaves behind.</para>
    /// <para>Null is not "no": it means the question has not been settled yet, and readers
    /// fall back to deriving from the current plan, which is correct for a session that
    /// has not happened.</para>
    /// </remarks>
    public bool? WasDeload { get; set; }

    /// <summary>Navigation property to the base workout.</summary>
    public Workout Workout { get; set; } = null!;

    /// <summary>Navigation property to the workout plan that owns this scheduled entry, if any.</summary>
    public WorkoutPlan? WorkoutPlan { get; set; }

    /// <summary>The scheduled exercise entries within this scheduled workout.</summary>
    public ICollection<ScheduledWorkoutExercise> Exercises { get; set; } = new List<ScheduledWorkoutExercise>();
}
