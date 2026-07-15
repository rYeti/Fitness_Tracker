using FitTracker.Api.DTOs;

namespace FitTracker.Api.Services.Interfaces;

/// <summary>Business-logic contract for trainer-facing reads/writes on a client's data.
/// Every method must be gated on <see cref="ITrainerClientService.IsActiveTrainerOfAsync"/>
/// before touching the client's data — see CLAUDE.md.</summary>
public interface ITrainerConsoleService
{
    Task<TrainerDashboardKpisDto> GetDashboardKpisAsync(Guid trainerId);

    Task<List<WeightTrackingResponseDto>?> GetClientWeightHistoryAsync(Guid trainerId, Guid clientId);

    Task<ClientWorkoutSummaryDto?> GetClientWorkoutSummaryAsync(Guid trainerId, Guid clientId);

    Task<ClientWorkoutHistoryDto?> GetClientWorkoutHistoryAsync(Guid trainerId, Guid clientId, DateTime date);

    Task<ClientNutritionSummaryDto?> GetClientNutritionSummaryAsync(Guid trainerId, Guid clientId, DateTime date);

    Task<WorkoutPlanResponseDto?> CreateClientWorkoutPlanAsync(Guid trainerId, Guid clientId, WorkoutPlanRequestDto dto);

    Task<WorkoutPlanResponseDto?> UpdateClientWorkoutPlanAsync(Guid trainerId, Guid clientId, Guid planId, WorkoutPlanRequestDto dto);
}
