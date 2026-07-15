using FitTracker.Api.DTOs;
using FitTracker.Api.Models;
using FitTracker.Api.Services.Interfaces;

namespace FitTracker.Api.Services;

public class TrainerConsoleService(
    ITrainerClientService trainerClientService,
    IWeightTrackingService weightTrackingService,
    IWorkoutPlanService workoutPlanService,
    IScheduledWorkoutService scheduledWorkoutService,
    IMealService mealService) : ITrainerConsoleService
{
    private readonly ITrainerClientService _trainerClientService = trainerClientService;
    private readonly IWeightTrackingService _weightTrackingService = weightTrackingService;
    private readonly IWorkoutPlanService _workoutPlanService = workoutPlanService;
    private readonly IScheduledWorkoutService _scheduledWorkoutService = scheduledWorkoutService;
    private readonly IMealService _mealService = mealService;

    public Task<TrainerDashboardKpisDto> GetDashboardKpisAsync(Guid trainerId)
    {
        // TODO: aggregate over _trainerClientService.GetClientsAsync(trainerId) —
        // active count, avg adherence, sessions this week, alert count.
        throw new NotImplementedException();
    }

    public async Task<List<WeightTrackingResponseDto>?> GetClientWeightHistoryAsync(Guid trainerId, Guid clientId)
    {
        // TODO: gate on _trainerClientService.IsActiveTrainerOfAsync(trainerId, clientId),
        // then _weightTrackingService.GetWeightLogs(clientId).
        var isTrainer = await _trainerClientService.IsActiveTrainerOfAsync(trainerId, clientId);
        if (!isTrainer) return null;
        return await _weightTrackingService.GetWeightLogs(clientId);

    }

    public Task<ClientWorkoutSummaryDto?> GetClientWorkoutSummaryAsync(Guid trainerId, Guid clientId)
    {
        // TODO: gate, then build current plan (via _workoutPlanService), attendance
        // (planned vs completed ScheduledWorkouts per week), and strength progression
        // (best WorkoutSet.weight per key Exercise) for clientId.
        throw new NotImplementedException();
    }

    public Task<ClientWorkoutHistoryDto?> GetClientWorkoutHistoryAsync(Guid trainerId, Guid clientId, DateTime date)
    {
        // TODO: gate, then find clientId's ScheduledWorkout for `date` via
        // _scheduledWorkoutService and return its full exercise/set breakdown.
        throw new NotImplementedException();
    }

    public Task<ClientNutritionSummaryDto?> GetClientNutritionSummaryAsync(Guid trainerId, Guid clientId, DateTime date)
    {
        // TODO: gate, then _mealService.GetMealsForDateAsync(clientId, date) for the
        // day view, plus a 7-day trend ending on `date`.
        throw new NotImplementedException();
    }

    public Task<WorkoutPlanResponseDto?> CreateClientWorkoutPlanAsync(Guid trainerId, Guid clientId, WorkoutPlanRequestDto dto)
    {
        // TODO: gate, then _workoutPlanService.CreatePlanAsync(dto, clientId) —
        // plan is owned by clientId, not trainerId.
        throw new NotImplementedException();
    }

    public Task<WorkoutPlanResponseDto?> UpdateClientWorkoutPlanAsync(Guid trainerId, Guid clientId, Guid planId, WorkoutPlanRequestDto dto)
    {
        // TODO: gate, then _workoutPlanService.UpdatePlanAsync(planId, clientId, dto).
        throw new NotImplementedException();
    }
}
