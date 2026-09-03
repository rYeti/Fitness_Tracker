namespace FitTracker.Api.Models;

/// <summary>Represents a structured plan that groups workouts into a repeating schedule for a user.</summary>
public class WorkoutPlan
{
    /// <summary>The unique identifier of this workout plan.</summary>
    public Guid Id { get; set; }

    /// <summary>The unique identifier of the user who owns this plan.</summary>
    public Guid UserId { get; set; }

    /// <summary>The name of the workout plan.</summary>
    public string Name { get; set; } = "";

    /// <summary>An optional description of the workout plan.</summary>
    public string? Description { get; set; }

    /// <summary>The date on which this plan begins.</summary>
    public DateTime StartDate { get; set; }

    /// <summary>The date and time when this plan was created.</summary>
    public DateTime CreatedAt { get; set; }

    /// <summary>Whether this plan is currently active for the user.</summary>
    public bool IsActive { get; set; }

    /// <summary>A JSON-encoded string describing the cycle pattern of workouts within the plan.</summary>
    public string CyclePatternJson { get; set; } = "";

    /// <summary>Whether the user may choose any workout freely rather than following the fixed cycle pattern.</summary>
    public bool IsFreeChoice { get; set; }

    /// <summary>The number of days this plan is scheduled for. Null for legacy plans.</summary>
    public int? DurationDays { get; set; }

    /// <summary>The trainer who assigned this plan, or null for one the user built
    /// themselves. No foreign key — same reasoning as <c>Workout.AssignedByTrainerId</c>.
    /// Set only by <c>TrainerConsoleService</c>; a client cannot delete a plan this is set on.</summary>
    public Guid? AssignedByTrainerId { get; set; }

    /// <summary>Navigation property to the user who owns this plan.</summary>
    public User User { get; set; } = null!;

    /// <summary>The join records linking specific workouts to this plan.</summary>
    public ICollection<WorkoutPlanWorkout> PlanWorkouts { get; set; } = new List<WorkoutPlanWorkout>();

    /// <summary>The scheduled workouts generated from this plan.</summary>
    public ICollection<ScheduledWorkout> ScheduledWorkouts { get; set; } = new List<ScheduledWorkout>();
}
