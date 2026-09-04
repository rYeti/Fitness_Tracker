using FitTracker.Api.DTOs;
using FitTracker.Api.Models;

namespace FitTracker.Api.Repositories.Interfaces;

/// <summary>Data-access contract for workout plans and their workout membership records.</summary>
public interface IWorkoutPlanRepository
{
    /// <summary>Returns all workout plans belonging to the specified user.</summary>
    /// <param name="userId">The user's ID.</param>
    Task<List<WorkoutPlan>> GetUserPlansAsync(Guid userId);

    /// <summary>The name of each client's active plan, keyed by client id. Clients with no
    /// active plan are absent.</summary>
    /// <remarks>Where a client somehow holds more than one active plan, the most recently
    /// created wins. Picking the first row the database happened to return, as the roster
    /// used to, meant the label could change between two identical requests.</remarks>
    Task<Dictionary<Guid, string>> GetActivePlanNamesAsync(IReadOnlyCollection<Guid> userIds);

    /// <summary>Returns a single workout plan belonging to the specified user, including its member workouts.</summary>
    /// <param name="id">The ID of the plan to retrieve.</param>
    /// <param name="userId">The ID of the user who owns the plan.</param>
    /// <returns>The matching plan, or <c>null</c> if not found.</returns>
    Task<WorkoutPlan?> GetPlanByIdAsync(Guid id, Guid userId);

    /// <summary>Creates and persists a new workout plan.</summary>
    /// <param name="plan">The workout plan entity to persist.</param>
    /// <returns>The newly created workout plan.</returns>
    Task<WorkoutPlan> CreatePlanAsync(WorkoutPlan plan);

    /// <summary>Updates an existing workout plan owned by the specified user.</summary>
    /// <param name="id">The ID of the plan to update.</param>
    /// <param name="userId">The ID of the user who owns the plan.</param>
    /// <param name="dto">The updated plan data.</param>
    /// <returns>The updated workout plan, or <c>null</c> if not found.</returns>
    Task<WorkoutPlan?> UpdatePlanAsync(Guid id, Guid userId, WorkoutPlanRequestDto dto);

    /// <summary>Deletes a workout plan owned by the specified user. Its days are left in
    /// place — see <c>WorkoutPlanRepository.DeletePlanAsync</c>.</summary>
    /// <param name="id">The ID of the plan to delete.</param>
    /// <param name="userId">The ID of the user who owns the plan.</param>
    /// <param name="actingAsTrainer">True only when the caller is the trainer who assigned
    /// this plan, deleting it via the Trainer Console. False (the default) is every
    /// self-service call, where a plan with a non-null <c>AssignedByTrainerId</c> is not
    /// the caller's to delete.</param>
    /// <returns><see cref="PlanDeleteResult"/> describing the outcome.</returns>
    Task<PlanDeleteResult> DeletePlanAsync(Guid id, Guid userId, bool actingAsTrainer = false);

    /// <summary>Adds a workout to a plan by persisting the join record, if both are owned by the specified user.</summary>
    /// <param name="link">The plan-workout join entity to persist.</param>
    /// <param name="userId">The ID of the user who must own both the plan and the workout.</param>
    /// <returns><c>true</c> if the link was created; <c>false</c> if the plan or workout isn't found/owned.</returns>
    Task<bool> AddWorkoutToPlanAsync(WorkoutPlanWorkout link, Guid userId);

    /// <summary>Removes a workout from a plan owned by the specified user by deleting the join record.</summary>
    /// <param name="planId">The ID of the plan.</param>
    /// <param name="workoutId">The ID of the workout to remove.</param>
    /// <param name="userId">The ID of the user who must own the plan.</param>
    /// <returns><c>true</c> if the link was deleted; <c>false</c> if not found or not owned.</returns>
    Task<bool> RemoveWorkoutFromPlanAsync(Guid planId, Guid workoutId, Guid userId);
}
