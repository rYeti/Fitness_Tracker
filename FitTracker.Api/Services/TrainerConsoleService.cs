using FitTracker.Api.DTOs;
using FitTracker.Api.Models;
using FitTracker.Api.Services.Interfaces;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.VisualBasic;

namespace FitTracker.Api.Services;

public class TrainerConsoleService(
    ITrainerClientService trainerClientService,
    IWeightTrackingService weightTrackingService,
    IWorkoutPlanService workoutPlanService,
    IScheduledWorkoutService scheduledWorkoutService,
    IMealService mealService,
    IUserSettingsService userSettingsService,
    IFoodItemService foodItemService) : ITrainerConsoleService
{
    private readonly ITrainerClientService _trainerClientService = trainerClientService;
    private readonly IWeightTrackingService _weightTrackingService = weightTrackingService;
    private readonly IWorkoutPlanService _workoutPlanService = workoutPlanService;
    private readonly IScheduledWorkoutService _scheduledWorkoutService = scheduledWorkoutService;
    private readonly IMealService _mealService = mealService;
    private readonly IUserSettingsService _userSettingsService = userSettingsService;
    private readonly IFoodItemService _foodItemService = foodItemService;

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

        // Two-argument SelectMany overloads carry the outer item along as you
        // flatten, instead of losing it — first flatten carries ScheduledDate
        // into each exercise, second flatten carries the (exercise, date) pair
        // into each set.
        var exerciseSetPairs = scheduled
            .SelectMany(w => w.Exercises, (w, e) => new { Workout = w, Exercise = e })
            .Where(x => x.Exercise.IsCompleted)
            .SelectMany(
                x => x.Exercise.Sets,
                (x, set) => (ExerciseId: x.Exercise.WorkoutExerciseId, Set: set, date: x.Workout.ScheduledDate))
            .Where(p => p.Set.IsCompleted)
            .ToList();

        var groupedByExercise = exerciseSetPairs.GroupBy(p => p.ExerciseId);
        var maxWeights = new List<(Guid ExerciseId, double? Weight)>();
        var strengthProgression = new List<StrengthProgressionDto>();

        foreach (var exercise in groupedByExercise)
        {
            var exerciseId = exercise.Key;
            var lastWeight = exercise
            .OrderByDescending(e => e.date)
            .Select(e => e.Set.Weight)
            .FirstOrDefault();

            var preWeight = exercise
            .OrderByDescending(e => e.date)
            .Select(e => e.Set.Weight)
            .Skip(1)
            .FirstOrDefault();

            maxWeights.Add((exerciseId, lastWeight));
            var strenght = new StrengthProgressionDto()
            {
                ExerciseId = exerciseId,
                CurrentWeight = lastWeight ?? 0,
                DeltaFromPrevious = (lastWeight - preWeight) ?? 0,
                ExerciseName = exerciseId.ToString(),
            };
            strengthProgression.Add(strenght);
        }

        return new ClientWorkoutSummaryDto
        {
            CurrentPlan = activePlan,
            Attendance = attendanceWeek,
            StrengthProgression = strengthProgression,
        };
    }

    public async Task<ClientWorkoutHistoryDto?> GetClientWorkoutHistoryAsync(Guid trainerId, Guid clientId, DateTime date)
    {
        var isTrainer = await _trainerClientService.IsActiveTrainerOfAsync(trainerId, clientId);
        if (!isTrainer) return null;
        var scheduled = await _scheduledWorkoutService.GetUserScheduledWorkoutsAsync(clientId);
        var scheduledDate = scheduled.FirstOrDefault(s => s.ScheduledDate.Date == date.Date);
        return new ClientWorkoutHistoryDto()
        {
            Date = date,
            ScheduledWorkout = scheduledDate,
        };
    }

    public async Task<ClientNutritionSummaryDto?> GetClientNutritionSummaryAsync(Guid trainerId, Guid clientId, DateTime date)
    {
        var isTrainer = await _trainerClientService.IsActiveTrainerOfAsync(trainerId, clientId);
        if (!isTrainer) return null;

        var settings = await _userSettingsService.GetSettingsAsync(clientId);
        var calorieGoal = settings?.DailyCalorieGoal ?? 0;

        // MealFoodEntryResponseDto only carries a FoodItemId, not the calorie
        // value itself — build a lookup once so we're not re-fetching the
        // client's whole food-item catalog for every meal we total up below.
        var foodItems = await _foodItemService.GetUserFoodItemsAsync(clientId);
        var caloriesByFoodItemId = foodItems.ToDictionary(f => f.Id, f => f.Calories);

        int TotalCalories(List<MealResponseDto> meals) =>
            meals
                .SelectMany(m => m.FoodEntries)
                .Sum(entry => caloriesByFoodItemId.TryGetValue(entry.FoodItemId, out var cal) ? cal : 0);

        var todaysMeals = await _mealService.GetMealsForDateAsync(clientId, date);

        var sevenDayTrend = new List<DailyCalorieTotalDto>();
        for (var i = 0; i < 7; i++)
        {
            var day = date.Date.AddDays(-i);
            // Reuse the already-fetched list for `date` itself instead of
            // hitting the service again for the same day.
            var dayMeals = i == 0 ? todaysMeals : await _mealService.GetMealsForDateAsync(clientId, day);
            sevenDayTrend.Add(new DailyCalorieTotalDto
            {
                Date = day,
                TotalCalories = TotalCalories(dayMeals),
                Goal = calorieGoal,
            });
        }

        return new ClientNutritionSummaryDto
        {
            Date = date,
            Meals = todaysMeals,
            CalorieGoal = calorieGoal,
            SevenDayTrend = sevenDayTrend,
        };
    }

    public async Task<WorkoutPlanResponseDto?> CreateClientWorkoutPlanAsync(Guid trainerId, Guid clientId, WorkoutPlanRequestDto dto)
    {
        // TODO: gate, then _workoutPlanService.CreatePlanAsync(dto, clientId) —
        // plan is owned by clientId, not trainerId.
        var isTrainer = await _trainerClientService.IsActiveTrainerOfAsync(trainerId, clientId);
        if (!isTrainer) return null;
        return await _workoutPlanService.CreatePlanAsync(dto, clientId);
    }

    public async Task<WorkoutPlanResponseDto?> UpdateClientWorkoutPlanAsync(Guid trainerId, Guid clientId, Guid planId, WorkoutPlanRequestDto dto)
    {
        // TODO: gate, then _workoutPlanService.UpdatePlanAsync(planId, clientId, dto).
        var isTrainer = await _trainerClientService.IsActiveTrainerOfAsync(trainerId, clientId);
        if (!isTrainer) return null;
        return await _workoutPlanService.UpdatePlanAsync(planId, clientId, dto);
    }
}
