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

    public async Task<TrainerDashboardKpisDto> GetDashboardKpisAsync(Guid trainerId)
    {
        var clients = await _trainerClientService.GetClientsAsync(trainerId);
        var weekStart = DateTime.UtcNow.Date.AddDays(-(int)DateTime.UtcNow.DayOfWeek + 1); // Monday
        int totalCompletedThisWeek = 0;
        double adherenceSum = 0;
        int clientsWithPlannedSessions = 0;

        foreach (var client in clients)
        {
            var scheduled = await _scheduledWorkoutService.GetUserScheduledWorkoutsAsync(client.ClientId);
            var thisWeek = scheduled.Where(w => w.ScheduledDate >= weekStart && w.ScheduledDate < weekStart.AddDays(7)).ToList();
            var planned = thisWeek.Count;
            var completed = thisWeek.Count(w => w.IsCompleted);

            totalCompletedThisWeek += completed;
            if (planned > 0)
            {
                adherenceSum += (double)completed / planned;
                clientsWithPlannedSessions++;
            }
        }

        var kpis = new TrainerDashboardKpisDto()
        {
            ActiveClientCount = clients.Count,
            SessionsThisWeek = totalCompletedThisWeek,
            AvgAdherencePercent = clientsWithPlannedSessions > 0 ? (adherenceSum / clientsWithPlannedSessions) * 100 : 0,
        };

        return kpis;
    }

    public async Task<List<WeightTrackingResponseDto>?> GetClientWeightHistoryAsync(Guid trainerId, Guid clientId)
    {
        var isTrainer = await _trainerClientService.IsActiveTrainerOfAsync(trainerId, clientId);
        if (!isTrainer) return null;
        return await _weightTrackingService.GetWeightLogs(clientId);

    }

    public async Task<ClientWorkoutSummaryDto?> GetClientWorkoutSummaryAsync(Guid trainerId, Guid clientId)
    {
        var isTrainer = await _trainerClientService.IsActiveTrainerOfAsync(trainerId, clientId);
        if (!isTrainer) return null;
        var weekStart = DateTime.UtcNow.Date.AddDays(-(int)DateTime.UtcNow.DayOfWeek + 1);
        var attendanceWeek = new List<AttendanceWeekDto>();
        var scheduled = await _scheduledWorkoutService.GetUserScheduledWorkoutsAsync(clientId);
        for (var i = 0; i < 12; i++)
        {
            // Each iteration gets its own week window, shifted `i` weeks back from
            // the current week — i=0 is this week, i=1 is last week, etc. — instead
            // of one window that keeps growing (or, as it did briefly, has its end
            // fall before its start, making it always empty).
            var windowStart = weekStart.AddDays(-7 * i);
            var windowEnd = windowStart.AddDays(7);
            var thisWeek = scheduled.Where(w => w.ScheduledDate >= windowStart && w.ScheduledDate < windowEnd).ToList();
            var planned = thisWeek.Count;
            var completed = thisWeek.Count(w => w.IsCompleted);
            var attendance = new AttendanceWeekDto
            {
                CompletedSessions = completed,
                PlannedSessions = planned,
                WeekStart = windowStart
            };
            attendanceWeek.Add(attendance);
        }
        var currentClientPlan = await _workoutPlanService.GetUserPlansAsync(clientId);
        var activePlan = currentClientPlan.FirstOrDefault(p => p.IsActive == true);

        // TODO: StrengthProgression — for each key lift (design mock uses Bench
        // Press/Squat/Deadlift), find the client's most recent best WorkoutSet.Weight.
        // `scheduled` (already fetched above) has each ScheduledWorkoutResponseDto's
        // .Exercises, which in turn have their sets — filter down to the exercises
        // matching those key lifts, then take the max Weight per exercise. For
        // DeltaFromPrevious you need a second, earlier "best" to diff against (e.g.
        // best from before the most recent session vs. the most recent session's
        // best) — there's no single query for this, it has to be derived from the
        // scheduled workouts' sets directly.

        return new ClientWorkoutSummaryDto
        {
            CurrentPlan = activePlan,
            Attendance = attendanceWeek,
            StrengthProgression = [],
        };
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
