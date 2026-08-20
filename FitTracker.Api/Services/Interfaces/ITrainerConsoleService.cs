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
}
