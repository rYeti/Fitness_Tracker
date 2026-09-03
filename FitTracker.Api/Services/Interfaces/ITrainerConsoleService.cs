using FitTracker.Api.DTOs;

namespace FitTracker.Api.Services.Interfaces;

/// <summary>Business-logic contract for trainer-facing reads/writes on a client's data.
/// Every method must be gated on <see cref="ITrainerClientService.IsActiveTrainerOfAsync"/>
/// before touching the client's data — see CLAUDE.md.</summary>
public interface ITrainerConsoleService
{
    Task<TrainerDashboardKpisDto> GetDashboardKpisAsync(Guid trainerId);

    /// <summary>The trainer's active clients with the training stats the Dashboard
    /// roster shows (program, adherence, last session).</summary>
    Task<List<TrainerRosterEntryDto>> GetRosterAsync(Guid trainerId);

    Task<List<WeightTrackingResponseDto>?> GetClientWeightHistoryAsync(Guid trainerId, Guid clientId);

    Task<ClientWorkoutSummaryDto?> GetClientWorkoutSummaryAsync(Guid trainerId, Guid clientId);

    Task<ClientWorkoutHistoryDto?> GetClientWorkoutHistoryAsync(Guid trainerId, Guid clientId, DateTime date);

    /// <summary>Returns the client's most recent sessions, newest first, each with its
    /// prescribed-vs-logged detail — backs the Session Review screen.</summary>
    /// <param name="count">Maximum sessions to return.</param>
    /// <returns>The sessions, or <c>null</c> if <paramref name="trainerId"/> isn't an
    /// active trainer of <paramref name="clientId"/>.</returns>
    Task<List<ClientSessionSummaryDto>?> GetClientSessionHistoryAsync(Guid trainerId, Guid clientId, int count);

    Task<ClientNutritionSummaryDto?> GetClientNutritionSummaryAsync(Guid trainerId, Guid clientId, DateTime date);

    Task<WorkoutPlanResponseDto?> CreateClientWorkoutPlanAsync(Guid trainerId, Guid clientId, WorkoutPlanRequestDto dto);

    Task<WorkoutPlanResponseDto?> UpdateClientWorkoutPlanAsync(Guid trainerId, Guid clientId, Guid planId, WorkoutPlanRequestDto dto);

    /// <summary>Removes one of the client's workout plans. The plan's days (and any logged
    /// history under them) are left in place — only the plan grouping goes away; see
    /// <c>WorkoutPlanRepository.DeletePlanAsync</c>.</summary>
    /// <returns><see cref="TrainerWorkoutStatus.Ok"/> on success,
    /// <see cref="TrainerWorkoutStatus.NotPermitted"/> if the caller isn't an active trainer
    /// of the client, or <see cref="TrainerWorkoutStatus.NotFound"/> if the plan isn't the
    /// client's.</returns>
    Task<TrainerWorkoutStatus> DeleteClientWorkoutPlanAsync(Guid trainerId, Guid clientId, Guid planId);

    /// <summary>The client's workouts — the days a trainer builds and edits — each with its
    /// exercises in order and the sets prescribed for them. Retired exercise entries are
    /// filtered out: they are history, not prescription.</summary>
    /// <returns>The workouts, or <c>null</c> if <paramref name="trainerId"/> isn't an active
    /// trainer of <paramref name="clientId"/>.</returns>
    Task<List<ClientWorkoutDto>?> GetClientWorkoutsAsync(Guid trainerId, Guid clientId);

    /// <summary>The exercises available to prescribe: system exercises, the client's own,
    /// and the trainer's own — the last flagged via <see cref="ClientExerciseOptionDto.IsTrainerOwned"/>
    /// so the picker can say prescribing it will share a copy with this client.</summary>
    /// <remarks>Not scoped to the client alone: a trainer must be able to invent an exercise
    /// (<see cref="CreateTrainerExerciseAsync"/>) and prescribe it, and the prescription path
    /// copies a trainer-owned exercise into the client's library rather than referencing the
    /// trainer's row directly — see the "own it" note on <c>TrainerConsoleService</c>'s
    /// prescription diff for why a shared reference would dangle the moment the relationship
    /// ends.</remarks>
    Task<List<ClientExerciseOptionDto>?> GetClientExerciseLibraryAsync(Guid trainerId, Guid clientId);

    /// <summary>Adds an exercise to the trainer's own library — reusable across their whole
    /// roster, and copied into a specific client's library only once actually prescribed.</summary>
    /// <remarks>Takes a <paramref name="clientId"/> purely to gate on an active relationship,
    /// the same way every other method here does — the created exercise itself belongs to
    /// the trainer, not to this client. It's reached from inside a client's builder session,
    /// so a trainer always has one to pass by the time they'd call this.</remarks>
    /// <returns>The created exercise, or <c>null</c> if the caller isn't an active trainer of
    /// <paramref name="clientId"/>.</returns>
    Task<ExerciseResponseDto?> CreateTrainerExerciseAsync(Guid trainerId, Guid clientId, ExerciseRequestDto dto);

    /// <summary>Creates a workout for the client, optionally as a day of one of their plans.</summary>
    Task<TrainerWorkoutResult> CreateClientWorkoutAsync(Guid trainerId, Guid clientId, ClientWorkoutRequestDto dto);

    /// <summary>Rewrites one of the client's workouts to match <paramref name="dto"/>, exercises
    /// and sets included. Exercises absent from the payload are taken out of the workout.</summary>
    Task<TrainerWorkoutResult> UpdateClientWorkoutAsync(Guid trainerId, Guid clientId, Guid workoutId, ClientWorkoutRequestDto dto);

    /// <summary>Removes one of the client's workouts. Kept, not deleted, when the client has
    /// logged sets against it.</summary>
    Task<TrainerWorkoutStatus> DeleteClientWorkoutAsync(Guid trainerId, Guid clientId, Guid workoutId);

    /// <summary>Generates dated sessions for a plan from a weekly cycle pattern, the way the
    /// trainee's own free-choice-vs-cycle create flow does client-side. Additive only: a date
    /// that already has a session for this plan is left alone, because the client's own sync
    /// pull has no path for deleting a scheduled session the server no longer reports.</summary>
    /// <returns><c>null</c> if the caller isn't an active trainer of the client, or the plan
    /// isn't the client's.</returns>
    Task<int?> ScheduleClientPlanAsync(Guid trainerId, Guid clientId, Guid planId, IReadOnlyList<string> cyclePattern, int durationWeeks);
}
