namespace FitTracker.Api.Models;

/// <summary>Outcome of deleting a workout plan. See <see cref="WorkoutDeleteResult"/> for
/// the equivalent one level down — a plan has no logged-history case of its own (it is
/// pure grouping metadata; the days it groups carry the history), so this only needs to
/// distinguish "not found" from "not yours to remove".</summary>
public enum PlanDeleteResult
{
    /// <summary>No plan with that ID belongs to the caller.</summary>
    NotFound,

    /// <summary>The plan is gone. Its days are left in place — see
    /// <c>WorkoutPlanRepository.DeletePlanAsync</c>.</summary>
    Deleted,

    /// <summary>The plan was assigned by a trainer (<c>WorkoutPlan.AssignedByTrainerId</c>)
    /// and the caller is its owner, not the assigning trainer.</summary>
    AssignedByTrainer,
}
