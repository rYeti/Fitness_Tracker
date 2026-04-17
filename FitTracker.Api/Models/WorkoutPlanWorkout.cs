namespace FitTracker.Api.Models;

/// <summary>Join entity that links a <see cref="WorkoutPlan"/> to one of its member <see cref="Workout"/> entries.</summary>
public class WorkoutPlanWorkout
{
    /// <summary>The unique identifier of this plan-workout link.</summary>
    public Guid Id { get; set; }

    /// <summary>The unique identifier of the workout plan.</summary>
    public Guid PlanId { get; set; }

    /// <summary>The unique identifier of the workout that is part of the plan.</summary>
    public Guid WorkoutId { get; set; }

    /// <summary>Navigation property to the parent workout plan.</summary>
    public WorkoutPlan WorkoutPlan { get; set; } = null!;

    /// <summary>Navigation property to the workout referenced by this link.</summary>
    public Workout Workout { get; set; } = null!;
}
