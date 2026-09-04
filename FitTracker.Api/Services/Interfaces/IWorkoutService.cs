using FitTracker.Api.DTOs;
using FitTracker.Api.Models;

namespace FitTracker.Api.Services.Interfaces;

/// <summary>Business-logic contract for workout templates, exercises, and set templates.</summary>
public interface IWorkoutService
{
    /// <summary>Returns all workouts belonging to the specified user.</summary>
    /// <param name="userId">The user's ID.</param>
    Task<List<WorkoutResponseDto>> GetUserWorkoutsAsync(Guid userId);

    /// <summary>The names of the given workouts, keyed by workout id.</summary>
    Task<Dictionary<Guid, string>> GetNamesByIdsAsync(IReadOnlyCollection<Guid> workoutIds);

    /// <summary>Returns the given workout-exercise entries, with their set templates.</summary>
    Task<List<WorkoutExerciseResponseDto>> GetExercisesByIdsAsync(IReadOnlyCollection<Guid> workoutExerciseIds);

    /// <summary>Returns a single workout belonging to the specified user, including its exercises and set templates.</summary>
    /// <param name="id">The ID of the workout to retrieve.</param>
    /// <param name="userId">The ID of the user who owns the workout.</param>
    /// <returns>The matching workout DTO, or <c>null</c> if not found.</returns>
    Task<WorkoutResponseDto?> GetWorkoutByIdAsync(Guid id, Guid userId);

    /// <summary>Creates a new workout for the specified user.</summary>
    /// <param name="dto">The workout data to create.</param>
    /// <param name="userId">The ID of the user creating the workout.</param>
    /// <param name="assignedByTrainerId">Set only when a trainer is prescribing this
    /// workout to <paramref name="userId"/> via the Trainer Console — null for the
    /// trainee's own create flow. See <c>Workout.AssignedByTrainerId</c>.</param>
    /// <returns>The newly created workout DTO.</returns>
    Task<WorkoutResponseDto> CreateWorkoutAsync(WorkoutRequestDto dto, Guid userId, Guid? assignedByTrainerId = null);

    /// <summary>Updates an existing workout owned by the specified user.</summary>
    /// <param name="id">The ID of the workout to update.</param>
    /// <param name="userId">The ID of the user who owns the workout.</param>
    /// <param name="dto">The updated workout data.</param>
    /// <returns>The updated workout DTO, or <c>null</c> if not found.</returns>
    Task<WorkoutResponseDto?> UpdateWorkoutAsync(Guid id, Guid userId, WorkoutRequestDto dto);

    /// <summary>Deletes a workout owned by the specified user.</summary>
    /// <param name="id">The ID of the workout to delete.</param>
    /// <param name="userId">The ID of the user who owns the workout.</param>
    /// <param name="actingAsTrainer">See <see cref="Repositories.Interfaces.IWorkoutRepository.DeleteWorkoutAsync"/>.</param>
    /// <returns>
    /// <see cref="WorkoutDeleteResult.Deleted"/> if the workout and any never-performed
    /// sessions of it are gone; <see cref="WorkoutDeleteResult.NotFound"/> if no such
    /// workout belongs to the user; <see cref="WorkoutDeleteResult.HasLoggedHistory"/> if
    /// sets were logged against it and it is therefore kept;
    /// <see cref="WorkoutDeleteResult.AssignedByTrainer"/> if it was assigned by a trainer
    /// and <paramref name="actingAsTrainer"/> is false.
    /// </returns>
    Task<WorkoutDeleteResult> DeleteWorkoutAsync(Guid id, Guid userId, bool actingAsTrainer = false);

    /// <summary>Adds an exercise entry to a workout owned by the specified user.</summary>
    Task<WorkoutExerciseResponseDto?> AddExerciseToWorkoutAsync(Guid workoutId, Guid userId, WorkoutExerciseRequestDto dto);

    /// <summary>Adds multiple exercise entries to a workout owned by the specified user in one call.</summary>
    Task<List<WorkoutExerciseResponseDto>> AddExercisesToWorkoutBatchAsync(Guid workoutId, Guid userId, List<WorkoutExerciseRequestDto> dtos);

    /// <summary>Updates an existing workout exercise entry owned by the specified user.</summary>
    /// <param name="weId">The ID of the workout exercise to update.</param>
    /// <param name="userId">The ID of the user who must own the parent workout.</param>
    /// <param name="dto">The updated exercise data.</param>
    /// <returns>The updated workout exercise DTO, or <c>null</c> if not found or not owned.</returns>
    Task<WorkoutExerciseResponseDto?> UpdateWorkoutExerciseAsync(Guid weId, Guid userId, WorkoutExerciseRequestDto dto);

    /// <summary>Deletes a workout exercise entry owned by the specified user.</summary>
    /// <param name="weId">The ID of the workout exercise to delete.</param>
    /// <param name="userId">The ID of the user who must own the parent workout.</param>
    /// <returns><c>true</c> if deleted; <c>false</c> if not found or not owned.</returns>
    Task<bool> DeleteWorkoutExerciseAsync(Guid weId, Guid userId);

    /// <summary>Adds a set template to a workout exercise owned by the specified user.</summary>
    Task<WorkoutSetTemplateResponseDto?> AddSetTemplateAsync(Guid workoutExerciseId, Guid userId, WorkoutSetTemplateRequestDto dto);

    /// <summary>Adds multiple set templates to a workout exercise owned by the specified user in one call.</summary>
    Task<List<WorkoutSetTemplateResponseDto>> AddSetTemplatesBatchAsync(Guid workoutExerciseId, Guid userId, List<WorkoutSetTemplateRequestDto> dtos);

    /// <summary>Replaces every set template on a workout exercise owned by the specified user
    /// with <paramref name="dtos"/>, including replacing them with nothing.</summary>
    /// <remarks><see cref="AddSetTemplatesBatchAsync"/> can't do this: it early-returns on an
    /// empty list because it serves the trainee's push, where an empty batch means "nothing
    /// new to send" — not "this exercise now has no prescribed sets". The Trainer Console's
    /// builder needs to be able to say the second thing, so it gets its own method rather
    /// than that early return being changed out from under the push.</remarks>
    /// <returns>The new set templates, or <c>null</c> if the exercise isn't found/owned.</returns>
    Task<List<WorkoutSetTemplateResponseDto>?> ReplaceSetTemplatesAsync(Guid workoutExerciseId, Guid userId, List<WorkoutSetTemplateRequestDto> dtos);

    /// <summary>Which of the given workout-exercise ids have at least one logged set against
    /// them. See <see cref="Repositories.Interfaces.IWorkoutRepository.GetWorkoutExerciseIdsWithLoggedSetsAsync"/>.</summary>
    Task<HashSet<Guid>> GetWorkoutExerciseIdsWithLoggedSetsAsync(IReadOnlyCollection<Guid> workoutExerciseIds);

    /// <summary>Updates an existing set template owned by the specified user.</summary>
    /// <param name="id">The ID of the set template to update.</param>
    /// <param name="userId">The ID of the user who must own the parent workout.</param>
    /// <param name="dto">The updated set template data.</param>
    /// <returns>The updated set template DTO, or <c>null</c> if not found or not owned.</returns>
    Task<WorkoutSetTemplateResponseDto?> UpdateSetTemplateAsync(Guid id, Guid userId, WorkoutSetTemplateRequestDto dto);

    /// <summary>Deletes a set template owned by the specified user.</summary>
    /// <param name="id">The ID of the set template to delete.</param>
    /// <param name="userId">The ID of the user who must own the parent workout.</param>
    /// <returns><c>true</c> if deleted; <c>false</c> if not found or not owned.</returns>
    Task<bool> DeleteSetTemplateAsync(Guid id, Guid userId);
}
