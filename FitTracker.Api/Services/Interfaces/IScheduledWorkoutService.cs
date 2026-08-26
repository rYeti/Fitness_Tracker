using FitTracker.Api.DTOs;
using FitTracker.Api.Repositories;

namespace FitTracker.Api.Services.Interfaces;

/// <summary>Business-logic contract for scheduled workouts, exercises, and performed sets.</summary>
public interface IScheduledWorkoutService
{
    /// <summary>Returns all scheduled workouts belonging to the specified user.</summary>
    /// <param name="userId">The user's ID.</param>
    Task<List<ScheduledWorkoutResponseDto>> GetUserScheduledWorkoutsAsync(Guid userId);

    /// <summary>Returns the user's scheduled workouts falling in <c>[from, to)</c>.</summary>
    /// <remarks>Prefer this to <see cref="GetUserScheduledWorkoutsAsync"/> whenever the caller
    /// only reports on a window — the unbounded read loads every session the user has ever
    /// logged, with every exercise and set.</remarks>
    Task<List<ScheduledWorkoutResponseDto>> GetUserScheduledWorkoutsInRangeAsync(Guid userId, DateTime from, DateTime to);

    /// <summary>Aggregates several clients' session counts for the Trainer Console dashboard,
    /// in one grouped query. Clients with nothing scheduled in the window are absent.</summary>
    Task<List<ClientTrainingStats>> GetClientTrainingStatsAsync(
        IReadOnlyCollection<Guid> clientIds,
        DateTime windowStart,
        DateTime windowEnd,
        DateTime weekStart,
        DateTime weekEnd);

    /// <summary>The date of each client's most recent completed session, keyed by client id.</summary>
    Task<Dictionary<Guid, DateTime>> GetLastCompletedSessionDatesAsync(IReadOnlyCollection<Guid> clientIds);

    /// <summary>The user's most recent <paramref name="count"/> current-programme sessions starting
    /// before <paramref name="notAfter"/> (exclusive), newest first.</summary>
    Task<List<ScheduledWorkoutResponseDto>> GetRecentSessionsAsync(Guid userId, DateTime notAfter, int count);

    /// <summary>The heaviest completed set weight per exercise before <paramref name="before"/>,
    /// used to seed personal-record detection over a bounded page of sessions.</summary>
    Task<Dictionary<Guid, double>> GetBestWeightsBeforeAsync(Guid userId, DateTime before);

    /// <summary>Returns a single scheduled workout owned by the specified user, including its exercises and sets.</summary>
    /// <param name="id">The ID of the scheduled workout to retrieve.</param>
    /// <param name="userId">The ID of the user who must own the underlying workout.</param>
    /// <returns>The matching scheduled workout DTO, or <c>null</c> if not found or not owned.</returns>
    Task<ScheduledWorkoutResponseDto?> GetScheduledWorkoutByIdAsync(Guid id, Guid userId);

    /// <summary>Creates a new scheduled workout for the specified user.</summary>
    /// <param name="dto">The scheduled workout data to create.</param>
    /// <param name="userId">The ID of the user creating the entry.</param>
    /// <returns>The newly created scheduled workout DTO, or <c>null</c> if the referenced workout/plan isn't owned by <paramref name="userId"/>.</returns>
    Task<ScheduledWorkoutResponseDto?> CreateScheduledWorkoutAsync(ScheduledWorkoutRequestDto dto, Guid userId);

    /// <summary>Updates an existing scheduled workout owned by the specified user.</summary>
    /// <param name="id">The ID of the scheduled workout to update.</param>
    /// <param name="userId">The ID of the user who must own the scheduled workout.</param>
    /// <param name="dto">The updated scheduled workout data.</param>
    /// <returns>The updated scheduled workout DTO, or <c>null</c> if not found or not owned.</returns>
    Task<ScheduledWorkoutResponseDto?> UpdateScheduledWorkoutAsync(Guid id, Guid userId, ScheduledWorkoutRequestDto dto);

    /// <summary>Deletes a scheduled workout owned by the specified user.</summary>
    /// <param name="id">The ID of the scheduled workout to delete.</param>
    /// <param name="userId">The ID of the user who must own the scheduled workout.</param>
    /// <returns><c>true</c> if deleted; <c>false</c> if not found or not owned.</returns>
    Task<bool> DeleteScheduledWorkoutAsync(Guid id, Guid userId);

    /// <summary>Adds a performed set to a scheduled workout exercise owned by the specified user.</summary>
    Task<WorkoutSetResponseDto?> AddSetAsync(Guid scheduledWorkoutExerciseId, Guid userId, WorkoutSetRequestDto dto);

    /// <summary>Adds multiple performed sets to a scheduled workout exercise owned by the specified user in one call.</summary>
    Task<List<WorkoutSetResponseDto>> AddSetsBatchAsync(Guid scheduledWorkoutExerciseId, Guid userId, List<WorkoutSetRequestDto> dtos);

    /// <summary>Updates an existing performed set owned by the specified user.</summary>
    /// <param name="setId">The ID of the set to update.</param>
    /// <param name="userId">The ID of the user who must own the parent scheduled workout.</param>
    /// <param name="dto">The updated set data.</param>
    /// <returns>The updated workout set DTO, or <c>null</c> if not found or not owned.</returns>
    Task<WorkoutSetResponseDto?> UpdateSetAsync(Guid setId, Guid userId, WorkoutSetRequestDto dto);

    /// <summary>Deletes a performed set owned by the specified user.</summary>
    /// <param name="setId">The ID of the set to delete.</param>
    /// <param name="userId">The ID of the user who must own the parent scheduled workout.</param>
    /// <returns><c>true</c> if deleted; <c>false</c> if not found or not owned.</returns>
    Task<bool> DeleteSetAsync(Guid setId, Guid userId);

    /// <summary>Marks a scheduled exercise as completed, if owned by the specified user.</summary>
    /// <param name="scheduledExerciseId">The ID of the scheduled exercise to complete.</param>
    /// <param name="userId">The ID of the user who must own the parent scheduled workout.</param>
    /// <returns><c>true</c> if updated; <c>false</c> if not found or not owned.</returns>
    Task<bool> CompleteExerciseAsync(Guid scheduledExerciseId, Guid userId);

    /// <summary>Marks a scheduled workout as completed, if owned by the specified user.</summary>
    /// <param name="scheduledWorkoutId">The ID of the scheduled workout to complete.</param>
    /// <param name="userId">The ID of the user who must own the scheduled workout.</param>
    /// <returns><c>true</c> if updated; <c>false</c> if not found or not owned.</returns>
    Task<bool> CompleteWorkoutAsync(Guid scheduledWorkoutId, Guid userId);

    /// <summary>Creates scheduled workout exercise entries for the given workout exercise IDs, if the scheduled workout is owned by the specified user.</summary>
    /// <param name="scheduledWorkoutId">The scheduled workout to attach exercises to.</param>
    /// <param name="userId">The ID of the user who must own the scheduled workout.</param>
    /// <param name="workoutExerciseIds">The workout exercise template IDs to link.</param>
    /// <returns>The newly created scheduled exercise DTOs, or <c>null</c> if the scheduled workout isn't found/owned.</returns>
    Task<List<ScheduledWorkoutExerciseResponseDto>?> CreateExercisesBatchAsync(Guid scheduledWorkoutId, Guid userId, List<Guid> workoutExerciseIds);
}
