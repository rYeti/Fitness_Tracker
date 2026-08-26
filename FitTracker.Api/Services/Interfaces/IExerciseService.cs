using FitTracker.Api.DTOs;

namespace FitTracker.Api.Services.Interfaces;

/// <summary>Business-logic contract for exercise management.</summary>
public interface IExerciseService
{
    /// <summary>Creates a new exercise for the specified user.</summary>
    /// <param name="exercise">The exercise data to create.</param>
    /// <param name="userId">The ID of the user creating the exercise.</param>
    /// <returns>The newly created exercise.</returns>
    Task<ExerciseResponseDto> CreateExercise(ExerciseRequestDto  exercise, Guid userId);

    /// <summary>Returns all exercises — both system-provided and user-created — visible to the specified user.</summary>
    /// <param name="userId">The ID of the requesting user.</param>
    Task<List<ExerciseResponseDto>> GetAllExercisesAsync(Guid userId);

    /// <summary>The names of the given exercises, keyed by exercise id.</summary>
    Task<Dictionary<Guid, string>> GetNamesByIdsAsync(IReadOnlyCollection<Guid> exerciseIds);

    /// <summary>The exercise name behind each of the given <c>WorkoutExercise</c> ids.</summary>
    Task<Dictionary<Guid, string>> GetNamesByWorkoutExerciseIdsAsync(IReadOnlyCollection<Guid> workoutExerciseIds);

    /// <summary>Updates an existing exercise owned by the specified user.</summary>
    /// <param name="id">The ID of the exercise to update.</param>
    /// <param name="userId">The ID of the user who owns the exercise.</param>
    /// <param name="exercise">The updated exercise data.</param>
    /// <returns>The updated exercise.</returns>
    Task<ExerciseResponseDto?> UpdateExercise(Guid id, Guid userId, ExerciseRequestDto  exercise);

    /// <summary>Deletes an exercise owned by the specified user.</summary>
    /// <param name="id">The ID of the exercise to delete.</param>
    /// <param name="userId">The ID of the user who owns the exercise.</param>
    /// <returns><c>true</c> if deleted; <c>false</c> if not found.</returns>
    Task<bool> DeleteExercise(Guid id, Guid userId);

    /// <summary>Returns exercises created by the specified user.</summary>
    /// <param name="id">The user's ID.</param>
    Task<List<ExerciseResponseDto>> GetUserExercisesAsync(Guid id);

}