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

    /// <summary>The plan's deload weeks, as JSON: <c>[{"week":5,"volumePercent":50}]</c>.
    /// Empty array for a plan with none. See <c>docs/deload-weeks.md</c> and
    /// <see cref="DeloadSchedule"/>.</summary>
    /// <remarks>
    /// <para><c>volumePercent</c> is the share of normal volume to <em>perform</em>, not the
    /// reduction — 50 means "do half your sets". The two readings differ by the entire point
    /// of the feature, so the distinction is restated wherever this is declared.</para>
    /// <para>Deliberately <em>not</em> part of <see cref="DTOs.WorkoutPlanRequestDto"/>. The
    /// trainee's own plan sync is a full-document PUT, so carrying this field there would let
    /// a device that hasn't yet pulled a trainer's change push a stale empty set over it —
    /// last writer wins, and the loser is the trainer. It has its own endpoint instead, and
    /// <c>WorkoutPlanRepository.UpdatePlanAsync</c> structurally cannot touch it.</para>
    /// </remarks>
    public string DeloadWeeksJson { get; set; } = "[]";

    /// <summary>Navigation property to the user who owns this plan.</summary>
    public User User { get; set; } = null!;

    /// <summary>The join records linking specific workouts to this plan.</summary>
    public ICollection<WorkoutPlanWorkout> PlanWorkouts { get; set; } = new List<WorkoutPlanWorkout>();

    /// <summary>The scheduled workouts generated from this plan.</summary>
    public ICollection<ScheduledWorkout> ScheduledWorkouts { get; set; } = new List<ScheduledWorkout>();
}
