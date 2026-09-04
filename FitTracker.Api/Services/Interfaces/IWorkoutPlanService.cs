using FitTracker.Api.DTOs;
using FitTracker.Api.Models;

namespace FitTracker.Api.Services.Interfaces;

/// <summary>Business-logic contract for workout plans and their workout membership.</summary>
public interface IWorkoutPlanService
{
    /// <summary>Returns all workout plans belonging to the specified user.</summary>
    /// <param name="userId">The user's ID.</param>
    Task<List<WorkoutPlanResponseDto>> GetUserPlansAsync(Guid userId);

    /// <summary>The name of each client's active plan, keyed by client id. Clients with no
    /// active plan are absent.</summary>
    Task<Dictionary<Guid, string>> GetActivePlanNamesAsync(IReadOnlyCollection<Guid> userIds);

    /// <summary>Returns a single workout plan belonging to the specified user, including its member workout IDs.</summary>
    /// <param name="id">The ID of the plan to retrieve.</param>
    /// <param name="userId">The ID of the user who owns the plan.</param>
    /// <returns>The matching plan DTO, or <c>null</c> if not found.</returns>
    Task<WorkoutPlanResponseDto?> GetPlanByIdAsync(Guid id, Guid userId);

    /// <summary>Creates a new workout plan for the specified user.</summary>
    /// <param name="dto">The plan data to create.</param>
    /// <param name="userId">The ID of the user creating the plan.</param>
    /// <param name="assignedByTrainerId">Set only when a trainer is assigning this plan to
    /// <paramref name="userId"/> via the Trainer Console — null for the trainee's own
    /// create flow. See <c>WorkoutPlan.AssignedByTrainerId</c>.</param>
    /// <returns>The newly created plan DTO.</returns>
    Task<WorkoutPlanResponseDto> CreatePlanAsync(WorkoutPlanRequestDto dto, Guid userId, Guid? assignedByTrainerId = null);

    /// <summary>Updates an existing workout plan owned by the specified user.</summary>
    /// <param name="id">The ID of the plan to update.</param>
    /// <param name="userId">The ID of the user who owns the plan.</param>
    /// <param name="dto">The updated plan data.</param>
    /// <returns>The updated plan DTO, or <c>null</c> if not found.</returns>
    Task<WorkoutPlanResponseDto?> UpdatePlanAsync(Guid id, Guid userId, WorkoutPlanRequestDto dto);

    /// <summary>Deletes a workout plan owned by the specified user. Its days are left in
    /// place — only the plan grouping goes away.</summary>
    /// <param name="id">The ID of the plan to delete.</param>
    /// <param name="userId">The ID of the user who owns the plan.</param>
    /// <param name="actingAsTrainer">See <see cref="Repositories.Interfaces.IWorkoutPlanRepository.DeletePlanAsync"/>.</param>
    /// <returns><see cref="PlanDeleteResult"/> describing the outcome.</returns>
    Task<PlanDeleteResult> DeletePlanAsync(Guid id, Guid userId, bool actingAsTrainer = false);

    /// <summary>Adds a workout to a plan owned by the specified user.</summary>
    /// <returns><c>true</c> if the link was created; <c>false</c> if the plan or workout isn't found/owned.</returns>
    Task<bool> AddWorkoutToPlanAsync(Guid planId, Guid workoutId, Guid userId);

    /// <summary>Adds multiple workouts to a plan owned by the specified user in one call.</summary>
    Task AddWorkoutsToPlanBatchAsync(Guid planId, List<Guid> workoutIds, Guid userId);

    /// <summary>Removes a workout from a plan owned by the specified user.</summary>
    /// <param name="planId">The ID of the plan.</param>
    /// <param name="workoutId">The ID of the workout to remove.</param>
    /// <param name="userId">The ID of the user who must own the plan.</param>
    /// <returns><c>true</c> if the link was removed; <c>false</c> if not found or not owned.</returns>
    Task<bool> RemoveWorkoutFromPlanAsync(Guid planId, Guid workoutId, Guid userId);
}
