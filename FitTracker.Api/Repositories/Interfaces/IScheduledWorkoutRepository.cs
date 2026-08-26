using FitTracker.Api.DTOs;
using FitTracker.Api.Models;

namespace FitTracker.Api.Repositories.Interfaces;

/// <summary>Data-access contract for scheduled workouts, their exercises, and performed sets.</summary>
public interface IScheduledWorkoutRepository
{
    /// <summary>Returns all scheduled workouts belonging to the specified user.</summary>
    /// <param name="userId">The user's ID.</param>
    Task<List<ScheduledWorkout>> GetUserScheduledWorkoutsAsync(Guid userId);

    /// <summary>Returns the specified user's scheduled workouts falling in <c>[from, to)</c>,
    /// including their exercises and sets.</summary>
    /// <remarks>Prefer this over <see cref="GetUserScheduledWorkoutsAsync"/> wherever the caller
    /// only reports on a window. The unbounded version loads every session the user has ever
    /// logged, with every exercise and every set, which is the cost the Trainer Console was
    /// paying to render a four-week adherence figure.</remarks>
    /// <param name="userId">The user's ID.</param>
    /// <param name="from">Inclusive start of the window.</param>
    /// <param name="to">Exclusive end of the window.</param>
    Task<List<ScheduledWorkout>> GetUserScheduledWorkoutsInRangeAsync(Guid userId, DateTime from, DateTime to);

    /// <summary>Aggregates session counts for several clients at once, for the Trainer Console
    /// dashboard.</summary>
    /// <remarks>
    /// One grouped query for the whole roster, rather than one full-history read per client.
    /// Only sessions in the client's current programme are counted — the same rule as
    /// <c>TrainerConsoleService.FilterToCurrentProgramme</c>, expressed in SQL here.
    ///
    /// Clients with no sessions in the window are absent from the result rather than present
    /// with zeroes; callers must treat a missing row as "no data".
    /// </remarks>
    /// <param name="clientIds">The clients to aggregate. An empty list returns an empty result
    /// without querying.</param>
    /// <param name="windowStart">Inclusive start of the adherence window.</param>
    /// <param name="windowEnd">Exclusive end of the adherence window. Pass the start of the day
    /// after the last day that counts — a session logged at 18:00 today is still today's.</param>
    /// <param name="weekStart">Inclusive start of the current week.</param>
    /// <param name="weekEnd">Exclusive end of the current week.</param>
    Task<List<ClientTrainingStats>> GetClientTrainingStatsAsync(
        IReadOnlyCollection<Guid> clientIds,
        DateTime windowStart,
        DateTime windowEnd,
        DateTime weekStart,
        DateTime weekEnd);

    /// <summary>The date of each client's most recent completed session, keyed by client id.
    /// Clients who have never completed one are absent.</summary>
    Task<Dictionary<Guid, DateTime>> GetLastCompletedSessionDatesAsync(IReadOnlyCollection<Guid> clientIds);

    /// <summary>Returns the user's most recent <paramref name="count"/> sessions that are in their
    /// current programme and start before <paramref name="notAfter"/>, newest first, with exercises
    /// and sets. Pass the start of the day after the last day that counts.</summary>
    /// <remarks>Bounding happens in SQL. Session Review used to build a full DTO graph for every
    /// session the client had ever done and then keep the newest ten.</remarks>
    Task<List<ScheduledWorkout>> GetRecentSessionsAsync(Guid userId, DateTime notAfter, int count);

    /// <summary>The heaviest completed set weight per exercise across the user's sessions strictly
    /// before <paramref name="before"/>, keyed by the exercise the set was logged against.</summary>
    /// <remarks>Seeds Session Review's personal-record detection so that reading a bounded page of
    /// sessions still compares each lift against the client's whole career, not just the page.
    /// Keyed by the effective exercise — an override where the client substituted one, otherwise
    /// the programmed exercise — matching how the session walk attributes a lift.</remarks>
    Task<Dictionary<Guid, double>> GetBestWeightsBeforeAsync(Guid userId, DateTime before);

    /// <summary>Returns a single scheduled workout owned by the specified user, including its exercises and sets.</summary>
    /// <param name="id">The ID of the scheduled workout to retrieve.</param>
    /// <param name="userId">The ID of the user who must own the underlying workout.</param>
    /// <returns>The matching scheduled workout, or <c>null</c> if not found or not owned.</returns>
    Task<ScheduledWorkout?> GetScheduledWorkoutByIdAsync(Guid id, Guid userId);

    /// <summary>Creates and persists a new scheduled workout, if the referenced workout (and plan, if any) belong to the specified user.</summary>
    /// <param name="sw">The scheduled workout entity to persist.</param>
    /// <param name="userId">The ID of the user who must own the referenced workout/plan.</param>
    /// <returns>The newly created scheduled workout, or <c>null</c> if the referenced workout/plan isn't owned by <paramref name="userId"/>.</returns>
    Task<ScheduledWorkout?> CreateScheduledWorkoutAsync(ScheduledWorkout sw, Guid userId);

    /// <summary>Updates an existing scheduled workout owned by the specified user.</summary>
    /// <param name="id">The ID of the scheduled workout to update.</param>
    /// <param name="userId">The ID of the user who must own the scheduled workout and any newly-referenced workout.</param>
    /// <param name="dto">The updated scheduled workout data.</param>
    /// <returns>The updated scheduled workout, or <c>null</c> if not found, not owned, or the new workout reference isn't owned.</returns>
    Task<ScheduledWorkout?> UpdateScheduledWorkoutAsync(Guid id, Guid userId, ScheduledWorkoutRequestDto dto);

    /// <summary>Deletes a scheduled workout owned by the specified user.</summary>
    /// <param name="id">The ID of the scheduled workout to delete.</param>
    /// <param name="userId">The ID of the user who must own the scheduled workout.</param>
    /// <returns><c>true</c> if deleted; <c>false</c> if not found or not owned.</returns>
    Task<bool> DeleteScheduledWorkoutAsync(Guid id, Guid userId);

    /// <summary>Creates scheduled workout exercise records for a set of workout exercise IDs, if the scheduled workout is owned by the specified user.</summary>
    /// <param name="scheduledWorkoutId">The scheduled workout to attach exercises to.</param>
    /// <param name="userId">The ID of the user who must own the scheduled workout.</param>
    /// <param name="workoutExerciseIds">The workout exercise template IDs to link.</param>
    /// <returns>The newly created scheduled workout exercises, or <c>null</c> if the scheduled workout isn't found/owned.</returns>
    Task<List<ScheduledWorkoutExercise>?> CreateExercisesBatchAsync(Guid scheduledWorkoutId, Guid userId, List<Guid> workoutExerciseIds);

    /// <summary>Adds a performed set to a scheduled workout exercise owned by the specified user.</summary>
    /// <param name="set">The workout set entity to persist.</param>
    /// <param name="userId">The ID of the user who must own the parent scheduled workout.</param>
    /// <returns>The newly created workout set, or <c>null</c> if the scheduled workout exercise isn't found/owned.</returns>
    Task<WorkoutSet?> AddSetAsync(WorkoutSet set, Guid userId);

    /// <summary>Updates an existing performed set owned by the specified user.</summary>
    /// <param name="setId">The ID of the set to update.</param>
    /// <param name="userId">The ID of the user who must own the parent scheduled workout.</param>
    /// <param name="dto">The updated set data.</param>
    /// <returns>The updated workout set, or <c>null</c> if not found or not owned.</returns>
    Task<WorkoutSet?> UpdateSetAsync(Guid setId, Guid userId, WorkoutSetRequestDto dto);

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
}
