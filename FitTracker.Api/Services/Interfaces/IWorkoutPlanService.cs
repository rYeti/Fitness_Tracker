using FitTracker.Api.DTOs;

namespace FitTracker.Api.Services.Interfaces;

/// <summary>Business-logic contract for workout plans and their workout membership.</summary>
public interface IWorkoutPlanService
{
    /// <summary>Returns all workout plans belonging to the specified user.</summary>
    /// <param name="userId">The user's ID.</param>
    Task<List<WorkoutPlanResponseDto>> GetUserPlansAsync(Guid userId);

    /// <summary>Returns a single workout plan belonging to the specified user, including its member workout IDs.</summary>
    /// <param name="id">The ID of the plan to retrieve.</param>
    /// <param name="userId">The ID of the user who owns the plan.</param>
    /// <returns>The matching plan DTO, or <c>null</c> if not found.</returns>
    Task<WorkoutPlanResponseDto?> GetPlanByIdAsync(Guid id, Guid userId);

    /// <summary>Creates a new workout plan for the specified user.</summary>
    /// <param name="dto">The plan data to create.</param>
    /// <param name="userId">The ID of the user creating the plan.</param>
    /// <returns>The newly created plan DTO.</returns>
    Task<WorkoutPlanResponseDto> CreatePlanAsync(WorkoutPlanRequestDto dto, Guid userId);

    /// <summary>Updates an existing workout plan owned by the specified user.</summary>
    /// <param name="id">The ID of the plan to update.</param>
    /// <param name="userId">The ID of the user who owns the plan.</param>
    /// <param name="dto">The updated plan data.</param>
    /// <returns>The updated plan DTO, or <c>null</c> if not found.</returns>
    Task<WorkoutPlanResponseDto?> UpdatePlanAsync(Guid id, Guid userId, WorkoutPlanRequestDto dto);

    /// <summary>Deletes a workout plan owned by the specified user.</summary>
    /// <param name="id">The ID of the plan to delete.</param>
    /// <param name="userId">The ID of the user who owns the plan.</param>
    /// <returns><c>true</c> if deleted; <c>false</c> if not found.</returns>
    Task<bool> DeletePlanAsync(Guid id, Guid userId);

    /// <summary>Adds a workout to a plan.</summary>
    /// <param name="planId">The ID of the plan.</param>
    /// <param name="workoutId">The ID of the workout to add.</param>
    Task AddWorkoutToPlanAsync(Guid planId, Guid workoutId);

    /// <summary>Removes a workout from a plan.</summary>
    /// <param name="planId">The ID of the plan.</param>
    /// <param name="workoutId">The ID of the workout to remove.</param>
    /// <returns><c>true</c> if the link was removed; <c>false</c> if not found.</returns>
    Task<bool> RemoveWorkoutFromPlanAsync(Guid planId, Guid workoutId);
}
