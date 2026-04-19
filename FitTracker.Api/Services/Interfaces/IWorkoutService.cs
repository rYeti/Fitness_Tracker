using FitTracker.Api.DTOs;

namespace FitTracker.Api.Services.Interfaces;

/// <summary>Business-logic contract for workout templates, exercises, and set templates.</summary>
public interface IWorkoutService
{
    /// <summary>Returns all workouts belonging to the specified user.</summary>
    /// <param name="userId">The user's ID.</param>
    Task<List<WorkoutResponseDto>> GetUserWorkoutsAsync(Guid userId);

    /// <summary>Returns a single workout belonging to the specified user, including its exercises and set templates.</summary>
    /// <param name="id">The ID of the workout to retrieve.</param>
    /// <param name="userId">The ID of the user who owns the workout.</param>
    /// <returns>The matching workout DTO, or <c>null</c> if not found.</returns>
    Task<WorkoutResponseDto?> GetWorkoutByIdAsync(Guid id, Guid userId);

    /// <summary>Creates a new workout for the specified user.</summary>
    /// <param name="dto">The workout data to create.</param>
    /// <param name="userId">The ID of the user creating the workout.</param>
    /// <returns>The newly created workout DTO.</returns>
    Task<WorkoutResponseDto> CreateWorkoutAsync(WorkoutRequestDto dto, Guid userId);

    /// <summary>Updates an existing workout owned by the specified user.</summary>
    /// <param name="id">The ID of the workout to update.</param>
    /// <param name="userId">The ID of the user who owns the workout.</param>
    /// <param name="dto">The updated workout data.</param>
    /// <returns>The updated workout DTO, or <c>null</c> if not found.</returns>
    Task<WorkoutResponseDto?> UpdateWorkoutAsync(Guid id, Guid userId, WorkoutRequestDto dto);

    /// <summary>Deletes a workout owned by the specified user.</summary>
    /// <param name="id">The ID of the workout to delete.</param>
    /// <param name="userId">The ID of the user who owns the workout.</param>
    /// <returns><c>true</c> if deleted; <c>false</c> if not found.</returns>
    Task<bool> DeleteWorkoutAsync(Guid id, Guid userId);

    /// <summary>Adds an exercise entry to a workout.</summary>
    Task<WorkoutExerciseResponseDto> AddExerciseToWorkoutAsync(Guid workoutId, WorkoutExerciseRequestDto dto);

    /// <summary>Adds multiple exercise entries to a workout in one call.</summary>
    Task<List<WorkoutExerciseResponseDto>> AddExercisesToWorkoutBatchAsync(Guid workoutId, List<WorkoutExerciseRequestDto> dtos);

    /// <summary>Updates an existing workout exercise entry.</summary>
    /// <param name="weId">The ID of the workout exercise to update.</param>
    /// <param name="dto">The updated exercise data.</param>
    /// <returns>The updated workout exercise DTO, or <c>null</c> if not found.</returns>
    Task<WorkoutExerciseResponseDto?> UpdateWorkoutExerciseAsync(Guid weId, WorkoutExerciseRequestDto dto);

    /// <summary>Deletes a workout exercise entry.</summary>
    /// <param name="weId">The ID of the workout exercise to delete.</param>
    /// <returns><c>true</c> if deleted; <c>false</c> if not found.</returns>
    Task<bool> DeleteWorkoutExerciseAsync(Guid weId);

    /// <summary>Adds a set template to a workout exercise.</summary>
    Task<WorkoutSetTemplateResponseDto> AddSetTemplateAsync(Guid workoutExerciseId, WorkoutSetTemplateRequestDto dto);

    /// <summary>Adds multiple set templates to a workout exercise in one call.</summary>
    Task<List<WorkoutSetTemplateResponseDto>> AddSetTemplatesBatchAsync(Guid workoutExerciseId, List<WorkoutSetTemplateRequestDto> dtos);

    /// <summary>Updates an existing set template.</summary>
    /// <param name="id">The ID of the set template to update.</param>
    /// <param name="dto">The updated set template data.</param>
    /// <returns>The updated set template DTO, or <c>null</c> if not found.</returns>
    Task<WorkoutSetTemplateResponseDto?> UpdateSetTemplateAsync(Guid id, WorkoutSetTemplateRequestDto dto);

    /// <summary>Deletes a set template.</summary>
    /// <param name="id">The ID of the set template to delete.</param>
    /// <returns><c>true</c> if deleted; <c>false</c> if not found.</returns>
    Task<bool> DeleteSetTemplateAsync(Guid id);
}
