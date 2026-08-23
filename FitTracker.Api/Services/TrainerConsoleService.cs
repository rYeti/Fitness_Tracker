using FitTracker.Api.DTOs;
using FitTracker.Api.Repositories;
using FitTracker.Api.Services.Interfaces;

namespace FitTracker.Api.Services;

public class TrainerConsoleService(
    ITrainerClientService trainerClientService,
    IWeightTrackingService weightTrackingService,
    IWorkoutPlanService workoutPlanService,
    IScheduledWorkoutService scheduledWorkoutService,
    IMealService mealService,
    IUserSettingsService userSettingsService,
    IExerciseService exerciseService,
    IFoodItemService foodItemService,
    IWorkoutService workoutService) : ITrainerConsoleService
{
    private readonly ITrainerClientService _trainerClientService = trainerClientService;
    private readonly IWeightTrackingService _weightTrackingService = weightTrackingService;
    private readonly IWorkoutPlanService _workoutPlanService = workoutPlanService;
    private readonly IScheduledWorkoutService _scheduledWorkoutService = scheduledWorkoutService;
    private readonly IMealService _mealService = mealService;
    private readonly IUserSettingsService _userSettingsService = userSettingsService;
    private readonly IFoodItemService _foodItemService = foodItemService;
    private readonly IWorkoutService _workoutService = workoutService;

    private readonly IExerciseService _exerciseService = exerciseService;

    /// <inheritdoc/>
    public async Task<TrainerDashboardKpisDto> GetDashboardKpisAsync(Guid trainerId)
    {
        var clients = await _trainerClientService.GetClientsAsync(trainerId);
        var weekStart = DateTime.UtcNow.Date.AddDays(-(int)DateTime.UtcNow.DayOfWeek + 1); // Monday
        int totalCompletedThisWeek = 0;
        double adherenceSum = 0;
        int clientsWithPlannedSessions = 0;

        foreach (var client in clients)
        {
            var scheduled = await GetCurrentProgrammeSessionsAsync(client.ClientId);
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

    /// <inheritdoc/>
    public async Task<List<TrainerRosterEntryDto>> GetRosterAsync(Guid trainerId)
    {
        var clients = await _trainerClientService.GetClientsAsync(trainerId);
        // Trailing 4 weeks rather than the current week alone: a Monday-morning
        // roster would otherwise show every client at 0%.
        var windowStart = DateTime.UtcNow.Date.AddDays(-28);

        var roster = new List<TrainerRosterEntryDto>();
        foreach (var client in clients)
        {
            var plans = await _workoutPlanService.GetUserPlansAsync(client.ClientId);
            var activePlan = plans.FirstOrDefault(p => p.IsActive);

            var scheduled = FilterToCurrentProgramme(
                await _scheduledWorkoutService.GetUserScheduledWorkoutsAsync(client.ClientId),
                plans);
            var window = scheduled
                .Where(w => w.ScheduledDate >= windowStart && w.ScheduledDate.Date <= DateTime.UtcNow.Date)
                .ToList();
            var completed = window.Count(w => w.IsCompleted);

            roster.Add(new TrainerRosterEntryDto
            {
                ClientId = client.ClientId,
                ClientName = client.ClientName,
                ProgramLabel = activePlan?.Name,
                // No scheduled sessions means "no data", not "0% adherent".
                AdherencePercent = window.Count > 0
                    ? (double)completed / window.Count * 100
                    : null,
                LastSessionDate = scheduled
                    .Where(w => w.IsCompleted)
                    .OrderByDescending(w => w.ScheduledDate)
                    .Select(w => (DateTime?)w.ScheduledDate)
                    .FirstOrDefault(),
            });
        }

        return roster;
    }

    /// <inheritdoc/>
    public async Task<List<WeightTrackingResponseDto>?> GetClientWeightHistoryAsync(Guid trainerId, Guid clientId)
    {
        var isTrainer = await _trainerClientService.IsActiveTrainerOfAsync(trainerId, clientId);
        if (!isTrainer) return null;
        return await _weightTrackingService.GetWeightLogs(clientId);

    }

    /// <inheritdoc/>
    public async Task<ClientWorkoutSummaryDto?> GetClientWorkoutSummaryAsync(Guid trainerId, Guid clientId)
    {
        var isTrainer = await _trainerClientService.IsActiveTrainerOfAsync(trainerId, clientId);
        if (!isTrainer) return null;
        var weekStart = DateTime.UtcNow.Date.AddDays(-(int)DateTime.UtcNow.DayOfWeek + 1);
        var attendanceWeek = new List<AttendanceWeekDto>();
        var currentClientPlan = await _workoutPlanService.GetUserPlansAsync(clientId);
        var scheduled = FilterToCurrentProgramme(
            await _scheduledWorkoutService.GetUserScheduledWorkoutsAsync(clientId),
            currentClientPlan);
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
        var exerciseNamesById = (await _exerciseService.GetAllExercisesAsync(clientId)).ToDictionary(e => e.id, e => e.Name);

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
            var exerciseName = exerciseNamesById.GetValueOrDefault(exerciseId, "");


            maxWeights.Add((exerciseId, lastWeight));
            var strenght = new StrengthProgressionDto()
            {
                ExerciseId = exerciseId,
                CurrentWeight = lastWeight ?? 0,
                DeltaFromPrevious = (lastWeight - preWeight) ?? 0,
                ExerciseName = exerciseName ,
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

    /// <inheritdoc/>
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

    /// <inheritdoc/>
    public async Task<List<ClientSessionSummaryDto>?> GetClientSessionHistoryAsync(Guid trainerId, Guid clientId, int count)
    {
        var isTrainer = await _trainerClientService.IsActiveTrainerOfAsync(trainerId, clientId);
        if (!isTrainer) return null;

        var scheduled = await GetCurrentProgrammeSessionsAsync(clientId);
        if (scheduled.Count == 0) return [];

        // Name lookups, fetched once rather than per session/exercise.
        // WorkoutExercise entries are keyed by their own Id, which is what
        // ScheduledWorkoutExercise.WorkoutExerciseId points at.
        var workouts = await _workoutService.GetUserWorkoutsAsync(clientId);
        var workoutsById = workouts.ToDictionary(w => w.Id);
        var workoutExercisesById = workouts
            .SelectMany(w => w.Exercises)
            .ToDictionary(e => e.Id);
        var exerciseNamesById = (await _exerciseService.GetAllExercisesAsync(clientId))
            .ToDictionary(e => e.id, e => e.Name);

        // History means what's already happened — a workout scheduled for next week
        // has nothing logged against it yet and would otherwise sort to the top of a
        // newest-first list and read as an unlogged session.
        var today = DateTime.UtcNow.Date;

        // PR detection needs "best weight before this session", so walk oldest-first
        // and carry a running max per exercise. Reversed to newest-first at the end.
        var chronological = scheduled
            .Where(w => w.ScheduledDate.Date <= today)
            .OrderBy(w => w.ScheduledDate)
            .ToList();
        var bestWeightByExercise = new Dictionary<Guid, double>();
        var sessions = new List<ClientSessionSummaryDto>();

        foreach (var workout in chronological)
        {
            workoutsById.TryGetValue(workout.WorkoutId, out var template);

            var exerciseLogs = new List<SessionExerciseLogDto>();
            double totalVolume = 0;
            var rpes = new List<int>();
            var sessionHasPr = false;

            foreach (var scheduledExercise in workout.Exercises)
            {
                workoutExercisesById.TryGetValue(scheduledExercise.WorkoutExerciseId, out var exerciseTemplate);

                var loggedSets = scheduledExercise.Sets.OrderBy(s => s.SetNumber).ToList();

                // Whether this entry is still part of the workout the session was built
                // from. It stops being so when the exercise is retired out of the workout,
                // and when the scheduled workout is later pointed at a different workout —
                // neither of which clears the entries already stamped against it.
                var stillProgrammed = exerciseTemplate is not null
                    && exerciseTemplate.RemovedAt is null
                    && exerciseTemplate.WorkoutId == workout.WorkoutId;

                // An entry that is no longer programmed and that the client never logged
                // anything against describes nothing that ever happened. Reporting it as a
                // skipped exercise blamed the client for missing work that was not in
                // their workout. Where sets *were* logged it is real history and stays,
                // without a prescription, since there is no longer one to compare against.
                if (!stillProgrammed && loggedSets.Count == 0) continue;

                // A substituted exercise reports under what the client actually did,
                // not what was originally programmed.
                var exerciseId = scheduledExercise.OverrideExerciseId ?? exerciseTemplate?.ExerciseId;

                // One template per set number. Re-saving a workout used to append a fresh
                // copy of the whole prescription server-side instead of replacing it, so
                // the raw rows can hold several generations of the same three sets and
                // counting them reported an exercise as having nine.
                var setTemplates = new List<WorkoutSetTemplateResponseDto>();
                if (stillProgrammed)
                {
                    setTemplates = exerciseTemplate!.SetTemplates
                        .GroupBy(t => t.SetNumber)
                        .OrderBy(g => g.Key)
                        .Select(g => g.OrderBy(t => t.OrderPosition).First())
                        .ToList();
                }

                // Targets are per set, not per exercise — a 12/10/8 pyramid must compare
                // each logged set against its own target, not all of them against the first.
                var targetsBySetNumber = setTemplates.ToDictionary(t => t.SetNumber, t => t.TargetReps);

                var prescribed = stillProgrammed ? new PrescribedSetsDto
                {
                    SetCount = setTemplates.Count,
                    TargetRepsPerSet = [.. setTemplates.Select(t => t.TargetReps)],
                } : null;

                var setLogs = new List<SessionSetLogDto>();
                var exerciseHasPr = false;

                foreach (var set in loggedSets)
                {
                    var targetReps = ParseTargetRepsFloor(
                        targetsBySetNumber.GetValueOrDefault(set.SetNumber));

                    setLogs.Add(new SessionSetLogDto
                    {
                        SetNumber = set.SetNumber,
                        Reps = set.Reps,
                        Weight = set.Weight,
                        WeightUnit = set.WeightUnit,
                        Rpe = set.Rpe,
                        // No target, or an unparseable one, counts as hit — don't
                        // flag an unprogrammed exercise as a miss.
                        HitTarget = targetReps is null || set.Reps is null || set.Reps >= targetReps,
                    });

                    if (!set.IsCompleted) continue;

                    totalVolume += (set.Reps ?? 0) * (set.Weight ?? 0);
                    if (set.Rpe is int rpe) rpes.Add(rpe);

                    if (exerciseId is Guid id && set.Weight is double weight)
                    {
                        var previousBest = bestWeightByExercise.GetValueOrDefault(id, 0);
                        if (weight > previousBest)
                        {
                            // Only counts as a PR if there was a prior baseline —
                            // the very first time an exercise is ever logged isn't one.
                            if (bestWeightByExercise.ContainsKey(id)) exerciseHasPr = true;
                            bestWeightByExercise[id] = weight;
                        }
                    }
                }

                if (exerciseHasPr) sessionHasPr = true;

                exerciseLogs.Add(new SessionExerciseLogDto
                {
                    WorkoutExerciseId = scheduledExercise.WorkoutExerciseId,
                    ExerciseName = exerciseId is Guid nameId
                        ? exerciseNamesById.GetValueOrDefault(nameId, "")
                        : "",
                    Prescribed = prescribed,
                    Skipped = loggedSets.Count == 0,
                    IsPr = exerciseHasPr,
                    Sets = setLogs,
                });
            }

            sessions.Add(new ClientSessionSummaryDto
            {
                ScheduledWorkoutId = workout.Id,
                Date = workout.ScheduledDate,
                WorkoutName = template?.Name ?? "",
                Status = DeriveStatus(workout),
                IsPr = sessionHasPr,
                TotalVolume = totalVolume,
                AvgRpe = rpes.Count > 0 ? (double?)rpes.Average() : null,
                ClientNote = workout.Notes,
                Exercises = exerciseLogs,
            });
        }

        sessions.Reverse();
        return sessions.Take(count).ToList();
    }

    /// <summary>A client's scheduled sessions with the leftovers of abandoned plans removed —
    /// see <see cref="FilterToCurrentProgramme"/>.</summary>
    private async Task<List<ScheduledWorkoutResponseDto>> GetCurrentProgrammeSessionsAsync(Guid clientId)
    {
        var scheduled = await _scheduledWorkoutService.GetUserScheduledWorkoutsAsync(clientId);
        if (scheduled.Count == 0) return scheduled;

        var plans = await _workoutPlanService.GetUserPlansAsync(clientId);
        return FilterToCurrentProgramme(scheduled, plans);
    }

    /// <summary>Drops the sessions a client is no longer on the hook for, so that every
    /// trainer-facing count and list is drawn from the same set of sessions.</summary>
    /// <remarks>Moving a client onto a new plan only clears <c>IsActive</c> on the old one:
    /// every date that plan ever generated stays in ScheduledWorkouts, unstarted, forever.
    /// Counted as planned-and-not-completed they hold adherence down for work that was never
    /// asked of the client, and listed in Session Review they read as a client who stopped
    /// turning up. A session from a dead plan is only real if the client engaged with it
    /// while the plan was live; sessions scheduled by hand carry no plan and are always the
    /// client's current business.</remarks>
    private static List<ScheduledWorkoutResponseDto> FilterToCurrentProgramme(
        List<ScheduledWorkoutResponseDto> scheduled,
        List<WorkoutPlanResponseDto> plans)
    {
        var activePlanIds = plans.Where(p => p.IsActive).Select(p => p.Id).ToHashSet();

        return scheduled.Where(w =>
            w.WorkoutPlanId is not Guid planId
            || activePlanIds.Contains(planId)
            || w.IsCompleted
            || w.IsSkipped
            || w.Exercises.Any(e => e.Sets.Count > 0)).ToList();
    }

    /// <summary>Classifies a session for Session Review: an explicit skip, or a session
    /// with nothing logged at all, is <c>Missed</c>; one the client marked complete is
    /// <c>Done</c>; sets logged without a completion flag is <c>Partial</c>.</summary>
    /// <remarks>Callers must have already excluded future-dated workouts — this treats
    /// "nothing logged" as Missed, which is only true for a session whose day has passed.</remarks>
    private static SessionStatusDto DeriveStatus(ScheduledWorkoutResponseDto workout)
    {
        if (workout.IsSkipped) return SessionStatusDto.Missed;
        if (workout.IsCompleted) return SessionStatusDto.Done;

        var loggedAnything = workout.Exercises.Any(e => e.Sets.Count > 0);
        return loggedAnything ? SessionStatusDto.Partial : SessionStatusDto.Missed;
    }

    /// <summary>Reads the low end of a target-reps string — "10" gives 10, "8-12" gives 8 —
    /// so a logged set can be compared against it. Returns null when there's nothing
    /// parseable, which callers treat as "no target to miss".</summary>
    private static int? ParseTargetRepsFloor(string? targetReps)
    {
        if (string.IsNullOrWhiteSpace(targetReps)) return null;

        var low = targetReps.Split('-', StringSplitOptions.TrimEntries)[0];
        return int.TryParse(low, out var reps) ? (int?)reps : null;
    }

    /// <inheritdoc/>
    public async Task<ClientNutritionSummaryDto?> GetClientNutritionSummaryAsync(Guid trainerId, Guid clientId, DateTime date)
    {
        var isTrainer = await _trainerClientService.IsActiveTrainerOfAsync(trainerId, clientId);
        if (!isTrainer) return null;

        var settings = await _userSettingsService.GetSettingsAsync(clientId);
        var calorieGoal = settings?.DailyCalorieGoal ?? 0;

        // MealFoodEntryResponseDto only carries a FoodItemId, not the nutrition
        // values themselves — build a lookup once so we're not re-fetching the
        // client's whole food-item catalog for every meal we total up below.
        var foodItems = await _foodItemService.GetUserFoodItemsAsync(clientId);
        var foodItemsById = foodItems.ToDictionary(f => f.Id);

        int TotalCalories(List<MealResponseDto> meals) =>
            meals
                .SelectMany(m => m.FoodEntries)
                .Sum(entry => foodItemsById.TryGetValue(entry.FoodItemId, out var food) ? food.Calories : 0);

        // One round trip for the whole trend window, bucketed by day here — the
        // seven days used to be seven sequential queries.
        var requestedDay = MealDayWindow.DayFor(date);
        var trendDays = Enumerable.Range(0, 7).Select(i => requestedDay.AddDays(-i)).ToList();
        var mealsByDay = (await _mealService.GetMealsInRangeAsync(clientId, trendDays.Last(), requestedDay))
            .GroupBy(meal => MealDayWindow.DayOf(meal.Date))
            .ToDictionary(group => group.Key, group => group.ToList());

        var noMeals = new List<MealResponseDto>();
        var todaysMeals = mealsByDay.GetValueOrDefault(requestedDay, noMeals);

        // Resolve each meal against the catalogue here rather than shipping bare
        // food-item ids: the trainer has no route to the client's food catalogue,
        // so an unresolved id would be unrenderable on their side.
        //
        // Grouped by category, because a day can hold more than one row for the same
        // one and a client only ever ate one breakfast. The app writes at most one
        // row per day and category and reads the first of each, so a duplicate is
        // invisible there; this screen listed the rows raw and showed the trainer two
        // of every meal. Creating is idempotent now (see MealService.CreateMealAsync),
        // but rows written before that stay in the database, so the read folds them.
        var loggedMeals = todaysMeals
            .GroupBy(meal => MealCategory.Key(meal.Category))
            .Select(sameCategory =>
            {
                var meal = sameCategory.First();
                var foods = sameCategory
                    .OrderBy(m => m.Date)
                    .SelectMany(m => m.FoodEntries)
                    .Select(entry => foodItemsById.GetValueOrDefault(entry.FoodItemId))
                    .Where(food => food is not null)
                    .Select(food => food!)
                    .ToList();

                return new LoggedMealDto
                {
                    MealId = meal.Id,
                    Category = meal.Category,
                    FoodNames = foods.Select(f => f.Name).ToList(),
                    Foods = foods.Select(f => new LoggedFoodDto
                    {
                        FoodItemId = f.Id,
                        Name = f.Name,
                        Grams = f.Gramm,
                        Calories = f.Calories,
                        Macros = new MacroTotalsDto
                        {
                            Protein = f.Protein,
                            Carbs = f.Carbs,
                            Fat = f.Fat,
                        },
                    }).ToList(),
                    Calories = foods.Sum(f => f.Calories),
                    Macros = new MacroTotalsDto
                    {
                        Protein = foods.Sum(f => f.Protein),
                        Carbs = foods.Sum(f => f.Carbs),
                        Fat = foods.Sum(f => f.Fat),
                    },
                };
            })
            .ToList();

        // Days with nothing logged still get an entry, so the chart keeps seven bars.
        var sevenDayTrend = trendDays.Select(day => new DailyCalorieTotalDto
        {
            Date = day,
            TotalCalories = TotalCalories(mealsByDay.GetValueOrDefault(day, noMeals)),
            Goal = calorieGoal,
        }).ToList();

        // Oldest-first reads naturally as a left-to-right bar chart; trendDays
        // walks backwards from `date`.
        sevenDayTrend.Reverse();

        return new ClientNutritionSummaryDto
        {
            Date = date,
            Meals = todaysMeals,
            LoggedMeals = loggedMeals,
            TotalCalories = loggedMeals.Sum(m => m.Calories),
            Macros = new MacroTotalsDto
            {
                Protein = loggedMeals.Sum(m => m.Macros.Protein),
                Carbs = loggedMeals.Sum(m => m.Macros.Carbs),
                Fat = loggedMeals.Sum(m => m.Macros.Fat),
            },
            CalorieGoal = calorieGoal,
            SevenDayTrend = sevenDayTrend,
        };
    }

    /// <inheritdoc/>
    public async Task<WorkoutPlanResponseDto?> CreateClientWorkoutPlanAsync(Guid trainerId, Guid clientId, WorkoutPlanRequestDto dto)
    {
        var isTrainer = await _trainerClientService.IsActiveTrainerOfAsync(trainerId, clientId);
        if (!isTrainer) return null;
        return await _workoutPlanService.CreatePlanAsync(dto, clientId);
    }

    /// <inheritdoc/>
    public async Task<WorkoutPlanResponseDto?> UpdateClientWorkoutPlanAsync(Guid trainerId, Guid clientId, Guid planId, WorkoutPlanRequestDto dto)
    {
        var isTrainer = await _trainerClientService.IsActiveTrainerOfAsync(trainerId, clientId);
        if (!isTrainer) return null;
        return await _workoutPlanService.UpdatePlanAsync(planId, clientId, dto);
    }
}
