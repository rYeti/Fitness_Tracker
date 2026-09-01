using FitTracker.Api.DTOs;
using FitTracker.Api.Models;
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

    /// <summary>The Monday of the week containing <paramref name="today"/>.</summary>
    /// <remarks>The obvious spelling, <c>AddDays(-(int)DayOfWeek + 1)</c>, is wrong on Sunday:
    /// <see cref="DayOfWeek.Sunday"/> is 0, so it lands on tomorrow and the whole week reads as
    /// empty. Shifting by 6 first makes Monday the zero point.</remarks>
    private static DateTime WeekStartFor(DateTime today) =>
        today.Date.AddDays(-(((int)today.DayOfWeek + 6) % 7));

    /// <summary>Everything the Dashboard needs about a trainer's roster, gathered once.</summary>
    private sealed record RosterAggregate(
        List<TrainerRosterEntryDto> Roster,
        int CompletedThisWeek,
        double AvgAdherencePercent);

    /// <summary>Builds the roster rows and the KPI totals from one set of queries.</summary>
    /// <remarks>
    /// This used to be two <c>foreach</c> loops over the roster — one per endpoint — each doing
    /// two awaited round trips per client, each of which loaded every session that client had
    /// ever logged with every exercise and every set, so that a 28-day count and one MAX could be
    /// taken in memory. A dashboard paint cost 4N+2 queries and materialised the whole roster's
    /// training history twice. It is now four queries, whatever the roster's size, and the
    /// database does the counting.
    ///
    /// The two endpoints still exist separately (published clients call both, and the Dashboard
    /// wants them to resolve independently), but they are computed from one snapshot here so the
    /// two halves of one screen can never disagree about what "now" is.
    /// </remarks>
    private async Task<RosterAggregate> BuildRosterAggregateAsync(Guid trainerId)
    {
        var clients = await _trainerClientService.GetClientsAsync(trainerId);
        if (clients.Count == 0) return new RosterAggregate([], 0, 0);

        // Read the clock once. Two reads either side of midnight disagree, and the roster and
        // the KPIs beside it would then be measuring different weeks.
        var today = DateTime.UtcNow.Date;
        var weekStart = WeekStartFor(today);
        var weekEnd = weekStart.AddDays(7);
        // Trailing 4 weeks rather than the current week alone: a Monday-morning roster would
        // otherwise show every client at 0%.
        var windowStart = today.AddDays(-28);
        // Exclusive, and a day past today, so a session logged this afternoon still counts.
        var windowEnd = today.AddDays(1);

        var clientIds = clients.Select(c => c.ClientId).ToList();

        var stats = (await _scheduledWorkoutService.GetClientTrainingStatsAsync(
                clientIds, windowStart, windowEnd, weekStart, weekEnd))
            .ToDictionary(s => s.ClientId);
        var lastSessions = await _scheduledWorkoutService.GetLastCompletedSessionDatesAsync(clientIds);
        var planNames = await _workoutPlanService.GetActivePlanNamesAsync(clientIds);

        var roster = clients.Select(client =>
        {
            // A client with nothing scheduled in the window has no row in `stats` at all.
            // That is the point: no scheduled sessions means "no data", not "0% adherent".
            var hasStats = stats.TryGetValue(client.ClientId, out var s);

            return new TrainerRosterEntryDto
            {
                ClientId = client.ClientId,
                ClientName = client.ClientName,
                ProgramLabel = planNames.GetValueOrDefault(client.ClientId),
                AdherencePercent = hasStats && s.PlannedInWindow > 0
                    ? (double)s.CompletedInWindow / s.PlannedInWindow * 100
                    : null,
                LastSessionDate = lastSessions.TryGetValue(client.ClientId, out var last)
                    ? last
                    : null,
            };
        }).ToList();

        var completedThisWeek = stats.Values.Sum(s => s.CompletedThisWeek);
        // Averaged over the clients who actually had something scheduled, so a client with an
        // empty week doesn't drag the number down as if they had skipped it.
        var scheduledThisWeek = stats.Values.Where(s => s.PlannedThisWeek > 0).ToList();
        var avgAdherence = scheduledThisWeek.Count > 0
            ? scheduledThisWeek.Average(s => (double)s.CompletedThisWeek / s.PlannedThisWeek) * 100
            : 0;

        return new RosterAggregate(roster, completedThisWeek, avgAdherence);
    }

    /// <inheritdoc/>
    public async Task<TrainerDashboardKpisDto> GetDashboardKpisAsync(Guid trainerId)
    {
        var aggregate = await BuildRosterAggregateAsync(trainerId);

        return new TrainerDashboardKpisDto
        {
            ActiveClientCount = aggregate.Roster.Count,
            SessionsThisWeek = aggregate.CompletedThisWeek,
            AvgAdherencePercent = aggregate.AvgAdherencePercent,
        };
    }

    /// <inheritdoc/>
    public async Task<List<TrainerRosterEntryDto>> GetRosterAsync(Guid trainerId) =>
        (await BuildRosterAggregateAsync(trainerId)).Roster;

    /// <inheritdoc/>
    public async Task<List<WeightTrackingResponseDto>?> GetClientWeightHistoryAsync(Guid trainerId, Guid clientId)
    {
        var isTrainer = await _trainerClientService.IsActiveTrainerOfAsync(trainerId, clientId);
        if (!isTrainer) return null;

        // A year of weigh-ins is more than the trend chart can usefully draw, and far less than
        // "every weigh-in this account has ever recorded", which is what this used to return.
        return await _weightTrackingService.GetWeightLogsSince(
            clientId, DateTime.UtcNow.Date.AddDays(-WeightHistoryDays));
    }

    /// <summary>How far back the Client Detail weight trend reaches.</summary>
    private const int WeightHistoryDays = 365;

    /// <summary>How many weeks of attendance the Client Detail screen shows.</summary>
    private const int AttendanceWeeks = 12;

    /// <inheritdoc/>
    public async Task<ClientWorkoutSummaryDto?> GetClientWorkoutSummaryAsync(Guid trainerId, Guid clientId)
    {
        var isTrainer = await _trainerClientService.IsActiveTrainerOfAsync(trainerId, clientId);
        if (!isTrainer) return null;

        var today = DateTime.UtcNow.Date;
        var weekStart = WeekStartFor(today);
        // The screen reports 12 weeks, so read 12 weeks. This used to load the client's entire
        // training history — every session, exercise and set they had ever logged — and then
        // slice a quarter of a year out of it in memory.
        var rangeStart = weekStart.AddDays(-7 * (AttendanceWeeks - 1));
        var rangeEnd = weekStart.AddDays(7);

        var currentClientPlan = await _workoutPlanService.GetUserPlansAsync(clientId);
        var scheduled = FilterToCurrentProgramme(
            await _scheduledWorkoutService.GetUserScheduledWorkoutsInRangeAsync(clientId, rangeStart, rangeEnd),
            currentClientPlan);

        var attendanceWeek = new List<AttendanceWeekDto>();
        for (var i = 0; i < AttendanceWeeks; i++)
        {
            // Each iteration gets its own week window, shifted `i` weeks back from
            // the current week — i=0 is this week, i=1 is last week, etc. — instead
            // of one window that keeps growing (or, as it did briefly, has its end
            // fall before its start, making it always empty).
            var windowStart = weekStart.AddDays(-7 * i);
            var windowEnd = windowStart.AddDays(7);
            var thisWeek = scheduled.Where(w => w.ScheduledDate >= windowStart && w.ScheduledDate < windowEnd).ToList();

            attendanceWeek.Add(new AttendanceWeekDto
            {
                CompletedSessions = thisWeek.Count(w => w.IsCompleted),
                PlannedSessions = thisWeek.Count,
                WeekStart = windowStart,
            });
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

        var groupedByExercise = exerciseSetPairs.GroupBy(p => p.ExerciseId).ToList();

        // Keyed by WorkoutExercise id, because that is what a logged set is stamped against.
        // The old lookup was keyed by Exercise id and queried with a WorkoutExercise id, so it
        // never matched and every row on this chart was labelled with an empty string.
        var exerciseNamesById = await _exerciseService.GetNamesByWorkoutExerciseIdsAsync(
            [.. groupedByExercise.Select(g => g.Key)]);

        var strengthProgression = new List<StrengthProgressionDto>();
        foreach (var exercise in groupedByExercise)
        {
            var byDate = exercise.OrderByDescending(e => e.date).Select(e => e.Set.Weight).ToList();
            var lastWeight = byDate.FirstOrDefault();
            var preWeight = byDate.Skip(1).FirstOrDefault();

            strengthProgression.Add(new StrengthProgressionDto
            {
                ExerciseId = exercise.Key,
                CurrentWeight = lastWeight ?? 0,
                DeltaFromPrevious = (lastWeight - preWeight) ?? 0,
                ExerciseName = exerciseNamesById.GetValueOrDefault(exercise.Key, ""),
            });
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

        // One day asked for, one day read. This used to load every session the client had ever
        // logged and then pick the matching date out of the list.
        var day = date.Date;
        var scheduled = await _scheduledWorkoutService.GetUserScheduledWorkoutsInRangeAsync(
            clientId, day, day.AddDays(1));

        return new ClientWorkoutHistoryDto()
        {
            Date = date,
            ScheduledWorkout = scheduled.FirstOrDefault(),
        };
    }

    /// <inheritdoc/>
    public async Task<List<ClientSessionSummaryDto>?> GetClientSessionHistoryAsync(Guid trainerId, Guid clientId, int count)
    {
        var isTrainer = await _trainerClientService.IsActiveTrainerOfAsync(trainerId, clientId);
        if (!isTrainer) return null;

        // History means what's already happened — a workout scheduled for next week
        // has nothing logged against it yet and would otherwise sort to the top of a
        // newest-first list and read as an unlogged session.
        var today = DateTime.UtcNow.Date;

        // Read a bounded page, not the client's whole history: this used to load every
        // session they had ever had, build the full prescribed-vs-logged graph for each,
        // and then keep the newest ten.
        //
        // Twice `count`, because CollapseDuplicateSessions below folds sessions away and
        // a page that came back exactly `count` long would then be short. Two rows for one
        // slot is the shape duplication takes here — a repeated push, one twin per
        // device — so doubling refills the page in every case seen in production without
        // giving up the bound this path exists for.
        var page = CollapseDuplicateSessions(
            await _scheduledWorkoutService.GetRecentSessionsAsync(clientId, today.AddDays(1), count * 2))
            .Take(count)
            .ToList();
        if (page.Count == 0) return [];

        // Name and prescription lookups, fetched once for the page rather than per session.
        // WorkoutExercise entries are keyed by their own Id, which is what
        // ScheduledWorkoutExercise.WorkoutExerciseId points at.
        var workoutExerciseIds = page.SelectMany(w => w.Exercises).Select(e => e.WorkoutExerciseId).Distinct().ToList();
        var workoutNamesById = await _workoutService.GetNamesByIdsAsync(
            [.. page.Select(w => w.WorkoutId).Distinct()]);
        var workoutExercisesById = (await _workoutService.GetExercisesByIdsAsync(workoutExerciseIds))
            .ToDictionary(e => e.Id);

        // PR detection needs "best weight before this session", so walk oldest-first
        // and carry a running max per exercise.
        var chronological = page.OrderBy(w => w.ScheduledDate).ToList();

        // Seeded with the client's bests from before this page, so that reading ten sessions
        // still compares each lift against their whole career. Without it a bounded page would
        // report the first time an exercise appears *on the page* as a personal record.
        var bestWeightByExercise = await _scheduledWorkoutService.GetBestWeightsBeforeAsync(
            clientId, chronological[0].ScheduledDate);

        var effectiveExerciseIds = page
            .SelectMany(w => w.Exercises)
            .Select(e => e.OverrideExerciseId
                ?? (workoutExercisesById.TryGetValue(e.WorkoutExerciseId, out var t) ? t.ExerciseId : (Guid?)null))
            .Where(id => id.HasValue)
            .Select(id => id!.Value)
            .Distinct()
            .ToList();
        var exerciseNamesById = await _exerciseService.GetNamesByIdsAsync(effectiveExerciseIds);

        var sessions = new List<ClientSessionSummaryDto>();

        foreach (var workout in chronological)
        {
            var exerciseLogs = new List<SessionExerciseLogDto>();
            double totalVolume = 0;
            var rpes = new List<int>();
            var sessionHasPr = false;

            foreach (var scheduledExercise in CollapseDuplicateEntries(workout.Exercises, workoutExercisesById))
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
                WorkoutName = workoutNamesById.GetValueOrDefault(workout.WorkoutId, ""),
                Status = DeriveStatus(workout),
                IsPr = sessionHasPr,
                TotalVolume = totalVolume,
                AvgRpe = rpes.Count > 0 ? (double?)rpes.Average() : null,
                ClientNote = workout.Notes,
                Exercises = exerciseLogs,
            });
        }

        // The walk had to run oldest-first for the running personal-record max; the screen
        // lists newest-first.
        sessions.Reverse();
        return sessions;
    }

    /// <summary>Drops the meal rows in one day-and-category group that are re-pushes of a
    /// row already in it, so folding the group does not report the client eating
    /// everything twice.</summary>
    /// <remarks>Grouping the day's rows by category stopped the console listing two
    /// breakfasts, but it concatenated their food entries, so a client whose lunch had been
    /// pushed twice went from two lunches of five foods to one lunch of ten — and the
    /// calorie and macro totals, which are summed from the entries, doubled with it. The
    /// row count was the visible half of that defect; this is the other half.
    ///
    /// <para>The rule is exact, not a heuristic: a row is dropped only when its food items
    /// are, as a multiset, identical to those of a row already kept. Two rows listing the
    /// same foods in the same quantities for one category on one day are one meal that was
    /// sent twice — by a reconcile pass that cleared a <c>serverId</c> whose server row was
    /// never gone, by a response lost after the write committed, or by a second device
    /// pushing its own unlinked copy. Rows that differ in any item are kept and
    /// concatenated as before, because there they hold different food and the client really
    /// did eat all of it.</para>
    ///
    /// <para>What this deliberately does not do is de-duplicate <em>within</em> a row.
    /// <c>LoggedMealDto.Foods</c> documents that repeats are real — a client eating two
    /// portions of the same food logs it twice — so a repeated entry inside one meal is
    /// indistinguishable from an accident, and collapsing it would silently under-report
    /// what somebody ate. The place to stop that one is the push (see the sync client's
    /// <c>_syncNewMeal</c>, which now links its entries to the ones the server already
    /// holds before creating any).</para></remarks>
    private static List<MealResponseDto> CollapseRepushedMeals(List<MealResponseDto> sameCategory)
    {
        if (sameCategory.Count < 2) return sameCategory;

        var kept = new List<MealResponseDto>();
        var keptContents = new HashSet<string>();
        foreach (var meal in sameCategory)
        {
            // Ordered so that two rows holding the same foods match whatever order their
            // entries were written in, and counted so that "two portions" stays distinct
            // from "one portion".
            var contents = string.Join(
                ",", meal.FoodEntries.Select(e => e.FoodItemId).OrderBy(id => id));
            // An empty row carries nothing to duplicate; it is folded away regardless.
            if (keptContents.Add(contents) && contents.Length > 0) kept.Add(meal);
        }

        // Every row was empty, or every row was a repeat of the first — either way the
        // group still has to yield something for the category to render.
        return kept.Count > 0 ? kept : [sameCategory[0]];
    }

    /// <summary>Folds the repeated <c>ScheduledWorkout</c> rows a client's history has
    /// accumulated into one session per workout per day, so a trainer is shown the
    /// session the client trained rather than it and its empty twin.</summary>
    /// <remarks>Creating a session was idempotent on the client-supplied id alone, and the
    /// sync client does not supply one — so a push whose response was lost, and a second
    /// device pushing its own local row, each wrote another row for the same workout on the
    /// same day. The trainee app never showed them: its own de-duplication pass has always
    /// treated two rows for one workout and date as duplicates by definition, and merges
    /// them on the device. Nothing merged them on the server, and the console listed each
    /// one — one carrying the client's logged sets, its twins empty and so reading as a
    /// session where every exercise was skipped.
    ///
    /// <para>The entries of every row in a group are kept and handed to
    /// <see cref="CollapseDuplicateEntries"/>, rather than taking the winner's alone:
    /// which twin a set was logged against is an accident of which local row the device
    /// happened to have linked, and dropping the others would drop real training with
    /// them.</para></remarks>
    private static List<ScheduledWorkoutResponseDto> CollapseDuplicateSessions(
        List<ScheduledWorkoutResponseDto> sessions)
    {
        return sessions
            .GroupBy(sw => (sw.WorkoutId, sw.ScheduledDate.Date))
            // The group's order is the incoming order, so a fold preserves the
            // newest-first paging the caller relies on.
            .Select(group =>
            {
                var sameSession = group.ToList();
                if (sameSession.Count == 1) return sameSession[0];

                // The row the client actually used: most logged sets, then completed,
                // then the one created first, so the fold is stable between requests.
                var survivor = sameSession
                    .OrderByDescending(sw => sw.Exercises.Sum(e => e.Sets.Count))
                    .ThenByDescending(sw => sw.IsCompleted)
                    .ThenBy(sw => sw.CreatedAt)
                    .ThenBy(sw => sw.Id)
                    .First();

                return new ScheduledWorkoutResponseDto
                {
                    Id = survivor.Id,
                    WorkoutId = survivor.WorkoutId,
                    // A twin generated by a plan and one scheduled by hand are the same
                    // session; keeping the plan link means FilterToCurrentProgramme and
                    // the adherence reads still recognise it as programmed work.
                    WorkoutPlanId = survivor.WorkoutPlanId ?? sameSession.Select(sw => sw.WorkoutPlanId).FirstOrDefault(id => id is not null),
                    TemplateWorkoutId = survivor.TemplateWorkoutId,
                    ScheduledDate = survivor.ScheduledDate,
                    CreatedAt = sameSession.Min(sw => sw.CreatedAt),
                    Notes = sameSession.Select(sw => sw.Notes).FirstOrDefault(n => !string.IsNullOrWhiteSpace(n)),
                    // Completing or skipping one twin is completing or skipping the
                    // session: the flag lives on whichever row the device was holding.
                    IsCompleted = sameSession.Any(sw => sw.IsCompleted),
                    IsSkipped = sameSession.Any(sw => sw.IsSkipped) && !sameSession.Any(sw => sw.IsCompleted),
                    Exercises = [.. sameSession.SelectMany(sw => sw.Exercises)],
                };
            })
            .ToList();
    }

    /// <summary>Folds a session's exercise entries onto the workout slot each was stamped
    /// from, so a slot the workout holds twice is reported once.</summary>
    /// <remarks>Adding an exercise to a workout is idempotent per
    /// <c>(WorkoutId, ExerciseId, OrderPosition)</c> now, but every duplicate written
    /// before that is still in <c>WorkoutExercises</c>, and nothing will ever remove it:
    /// the sync client collapses duplicate exercises as it pulls a workout, so the trainee
    /// app renders the workout correctly and its user has no way to see, let alone delete,
    /// the second row. Sessions are stamped from the table, not from what the app renders,
    /// so each session carried both — the client logged against one, and the console
    /// reported the other as an exercise they skipped, prescription and all.
    ///
    /// <para>OrderPosition is part of the slot for the same reason it is part of the write
    /// path's key: a workout may legitimately hold the same movement twice — a superset
    /// pairing it with itself — and those instances differ only by position. Two entries
    /// sharing the exercise <em>and</em> the position cannot be anything but twins.</para>
    ///
    /// <para>Entries carrying logged sets are never folded away, even when several in one
    /// slot carry them. That case means the client logged against more than one twin, and
    /// there is no way to merge two sets of logs without inventing or destroying training
    /// history; showing the trainer both is the honest reading. Only the empty twins go,
    /// and only when a sibling in the same slot was actually trained.</para></remarks>
    private static List<ScheduledWorkoutExerciseResponseDto> CollapseDuplicateEntries(
        List<ScheduledWorkoutExerciseResponseDto> entries,
        Dictionary<Guid, WorkoutExerciseResponseDto> workoutExercisesById)
    {
        if (entries.Count < 2) return entries;

        // An entry whose template cannot be resolved is keyed by its own id, so it stands
        // alone rather than being folded into an unrelated slot.
        string SlotOf(ScheduledWorkoutExerciseResponseDto e) =>
            workoutExercisesById.TryGetValue(e.WorkoutExerciseId, out var template)
                ? $"{template.WorkoutId}|{template.ExerciseId}|{template.OrderPosition}"
                : e.Id.ToString();

        var keep = new HashSet<Guid>();
        foreach (var slot in entries.GroupBy(SlotOf))
        {
            var logged = slot.Where(e => e.Sets.Count > 0).ToList();
            if (logged.Count > 0)
            {
                foreach (var e in logged) keep.Add(e.Id);
            }
            else
            {
                keep.Add(slot.OrderBy(e => e.Id).First().Id);
            }
        }

        return [.. entries.Where(e => keep.Contains(e.Id))];
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
        // Fall back to the same default the model and the Flutter client use,
        // not to zero. A client who has never opened settings has no row here,
        // and `?? 0` made the console report "Target 0 kcal" for someone whose
        // own app was showing a 2000 kcal target. Neither side was wrong on its
        // own — the disagreement was the defect.
        var calorieGoal = settings?.DailyCalorieGoal
            ?? Models.UserSettings.DefaultDailyCalorieGoal;

        // One round trip for the whole trend window, bucketed by day here — the
        // seven days used to be seven sequential queries.
        var requestedDay = MealDayWindow.DayFor(date);
        var trendDays = Enumerable.Range(0, 7).Select(i => requestedDay.AddDays(-i)).ToList();
        var mealsByDay = (await _mealService.GetMealsInRangeAsync(clientId, trendDays.Last(), requestedDay))
            .GroupBy(meal => MealDayWindow.DayOf(meal.Date))
            .ToDictionary(group => group.Key, group => group.ToList());

        // MealFoodEntryResponseDto only carries a FoodItemId, not the nutrition values
        // themselves, so the entries have to be resolved against the catalogue. Fetched by id
        // once for the whole window: this used to pull the client's entire food library to
        // resolve seven days of meals.
        var referencedFoodIds = mealsByDay.Values
            .SelectMany(meals => meals)
            .SelectMany(meal => meal.FoodEntries)
            .Select(entry => entry.FoodItemId)
            .Distinct()
            .ToList();
        var foodItemsById = (await _foodItemService.GetFoodItemsByIdsAsync(clientId, referencedFoodIds))
            .ToDictionary(f => f.Id);

        // Folded by category on the way in, exactly as the day's own total is below. The
        // trend bar for the requested day sits next to the calorie ring, and a day whose
        // meals were pushed twice used to have the ring corrected and the bar not — two
        // numbers for the same day, on the same screen, disagreeing by a factor of two.
        int TotalCalories(List<MealResponseDto> meals) =>
            meals
                .GroupBy(m => MealCategory.Key(m.Category))
                .SelectMany(sameCategory => CollapseRepushedMeals([.. sameCategory.OrderBy(m => m.Date)]))
                .SelectMany(m => m.FoodEntries)
                .Sum(entry => foodItemsById.TryGetValue(entry.FoodItemId, out var food) ? food.Calories : 0);

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
                var foods = CollapseRepushedMeals([.. sameCategory.OrderBy(m => m.Date)])
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

    // ── Workout Builder: create/edit a client's workouts ────────────────────

    /// <inheritdoc/>
    public async Task<List<ClientWorkoutDto>?> GetClientWorkoutsAsync(Guid trainerId, Guid clientId)
    {
        var isTrainer = await _trainerClientService.IsActiveTrainerOfAsync(trainerId, clientId);
        if (!isTrainer) return null;

        var workouts = await _workoutService.GetUserWorkoutsAsync(clientId);
        var plans = await _workoutPlanService.GetUserPlansAsync(clientId);
        var names = await ExerciseNamesForAsync(workouts.SelectMany(w => w.Exercises));

        return [.. workouts.Select(w => ToClientWorkoutDto(w, plans, names))];
    }

    /// <inheritdoc/>
    public async Task<List<ClientExerciseOptionDto>?> GetClientExerciseLibraryAsync(Guid trainerId, Guid clientId)
    {
        var isTrainer = await _trainerClientService.IsActiveTrainerOfAsync(trainerId, clientId);
        if (!isTrainer) return null;

        // System exercises + whatever the client already owns, including any earlier copies
        // of the trainer's own exercises.
        var clientVisible = await _exerciseService.GetAllExercisesAsync(clientId);
        // The trainer's own, offered alongside so they can prescribe something they haven't
        // given this specific client yet. If they already have — a copy with a different id
        // — both the original and the copy show up; that's a minor picker duplication, not
        // an incorrect one, and resolving it needs the copy's provenance in a DTO nothing
        // else reads, which isn't worth the surface for a cosmetic dedupe.
        var trainerOwned = (await _exerciseService.GetAllExercisesAsync(trainerId))
            .Where(e => e.UserId == trainerId);

        var byId = new Dictionary<Guid, ExerciseResponseDto>();
        foreach (var e in clientVisible) byId[e.id] = e;
        foreach (var e in trainerOwned) byId.TryAdd(e.id, e);

        return [.. byId.Values
            .OrderBy(e => e.Name, StringComparer.OrdinalIgnoreCase)
            .Select(e => new ClientExerciseOptionDto
            {
                Id = e.id,
                Name = e.Name,
                NameDe = e.NameDe,
                Description = e.Description,
                DescriptionDe = e.DescriptionDe,
                Type = e.Type,
                TargetMuscleGroups = e.TargetMuscleGroups,
                ImageUrl = e.ImageUrl,
                IsTrainerOwned = e.UserId == trainerId,
            })];
    }

    /// <inheritdoc/>
    public async Task<ExerciseResponseDto?> CreateTrainerExerciseAsync(Guid trainerId, Guid clientId, ExerciseRequestDto dto)
    {
        var isTrainer = await _trainerClientService.IsActiveTrainerOfAsync(trainerId, clientId);
        if (!isTrainer) return null;

        dto.IsCustom = true;
        return await _exerciseService.CreateExercise(dto, trainerId);
    }

    /// <inheritdoc/>
    public async Task<TrainerWorkoutResult> CreateClientWorkoutAsync(Guid trainerId, Guid clientId, ClientWorkoutRequestDto dto)
    {
        var isTrainer = await _trainerClientService.IsActiveTrainerOfAsync(trainerId, clientId);
        if (!isTrainer) return new TrainerWorkoutResult(TrainerWorkoutStatus.NotPermitted);

        // Validated before anything is created, so a bad plan id can't leave an orphan
        // workout behind.
        if (dto.PlanId is Guid requestedPlanId)
        {
            var plan = await _workoutPlanService.GetPlanByIdAsync(requestedPlanId, clientId);
            if (plan == null) return new TrainerWorkoutResult(TrainerWorkoutStatus.NotFound);
        }

        var (unknownIds, resolvedExerciseIds) = await ResolvePrescribedExerciseIdsAsync(
            trainerId, clientId, dto.Exercises.Select(e => e.ExerciseId));
        if (unknownIds.Count > 0)
        {
            return new TrainerWorkoutResult(TrainerWorkoutStatus.UnknownExercise, UnknownExerciseIds: unknownIds);
        }

        var workout = await _workoutService.CreateWorkoutAsync(new WorkoutRequestDto
        {
            Name = dto.Name,
            Description = dto.Description,
            Difficulty = dto.Difficulty,
            EstimatedDurationMinutes = dto.EstimatedDurationMinutes,
            IsTemplate = true,
        }, clientId);

        if (dto.PlanId is Guid planId)
        {
            await _workoutPlanService.AddWorkoutToPlanAsync(planId, workout.Id, clientId);
        }

        await ApplyExercisePrescriptionAsync(clientId, workout.Id, [], dto.Exercises, resolvedExerciseIds);

        var saved = await LoadClientWorkoutDtoAsync(clientId, workout.Id);
        return new TrainerWorkoutResult(TrainerWorkoutStatus.Ok, saved);
    }

    /// <inheritdoc/>
    public async Task<TrainerWorkoutResult> UpdateClientWorkoutAsync(Guid trainerId, Guid clientId, Guid workoutId, ClientWorkoutRequestDto dto)
    {
        var isTrainer = await _trainerClientService.IsActiveTrainerOfAsync(trainerId, clientId);
        if (!isTrainer) return new TrainerWorkoutResult(TrainerWorkoutStatus.NotPermitted);

        var existingWorkout = await _workoutService.GetWorkoutByIdAsync(workoutId, clientId);
        if (existingWorkout == null) return new TrainerWorkoutResult(TrainerWorkoutStatus.NotFound);

        var (unknownIds, resolvedExerciseIds) = await ResolvePrescribedExerciseIdsAsync(
            trainerId, clientId, dto.Exercises.Select(e => e.ExerciseId));
        if (unknownIds.Count > 0)
        {
            return new TrainerWorkoutResult(TrainerWorkoutStatus.UnknownExercise, UnknownExerciseIds: unknownIds);
        }

        await _workoutService.UpdateWorkoutAsync(workoutId, clientId, new WorkoutRequestDto
        {
            Name = dto.Name,
            Description = dto.Description,
            Difficulty = dto.Difficulty,
            EstimatedDurationMinutes = dto.EstimatedDurationMinutes,
            IsTemplate = true,
        });

        var existingLive = existingWorkout.Exercises.Where(e => e.RemovedAt == null).ToList();
        await ApplyExercisePrescriptionAsync(clientId, workoutId, existingLive, dto.Exercises, resolvedExerciseIds);

        var saved = await LoadClientWorkoutDtoAsync(clientId, workoutId);
        return new TrainerWorkoutResult(TrainerWorkoutStatus.Ok, saved);
    }

    /// <inheritdoc/>
    public async Task<TrainerWorkoutStatus> DeleteClientWorkoutAsync(Guid trainerId, Guid clientId, Guid workoutId)
    {
        var isTrainer = await _trainerClientService.IsActiveTrainerOfAsync(trainerId, clientId);
        if (!isTrainer) return TrainerWorkoutStatus.NotPermitted;

        var result = await _workoutService.DeleteWorkoutAsync(workoutId, clientId);
        return result switch
        {
            WorkoutDeleteResult.Deleted => TrainerWorkoutStatus.Ok,
            WorkoutDeleteResult.HasLoggedHistory => TrainerWorkoutStatus.HasLoggedHistory,
            _ => TrainerWorkoutStatus.NotFound,
        };
    }

    /// <inheritdoc/>
    public async Task<int?> ScheduleClientPlanAsync(Guid trainerId, Guid clientId, Guid planId, IReadOnlyList<string> cyclePattern, int durationWeeks)
    {
        var isTrainer = await _trainerClientService.IsActiveTrainerOfAsync(trainerId, clientId);
        if (!isTrainer) return null;
        if (cyclePattern.Count == 0 || durationWeeks <= 0) return 0;

        var plan = await _workoutPlanService.GetPlanByIdAsync(planId, clientId);
        if (plan == null) return null;

        // Cycle entries that don't name one of the client's workouts are rest days: there is
        // nothing to schedule for them, so they're skipped rather than requiring a synthetic
        // "Rest Day" workout the way the trainee's own client-side create flow does.
        var workoutIdByName = (await _workoutService.GetUserWorkoutsAsync(clientId))
            .ToDictionary(w => w.Name, w => w.Id);

        var startDate = plan.StartDate.Date;
        var totalDays = durationWeeks * 7;
        var rangeEnd = startDate.AddDays(totalDays);

        // Additive only: a date already scheduled for this plan is left untouched. The
        // client's sync pull has no path for deleting a scheduled session the server stops
        // reporting, so regenerating over an existing one would either leave a duplicate or
        // silently orphan whichever copy the device already pulled.
        var alreadyScheduled = (await _scheduledWorkoutService.GetUserScheduledWorkoutsInRangeAsync(clientId, startDate, rangeEnd))
            .Where(s => s.WorkoutPlanId == planId)
            .Select(s => s.ScheduledDate.Date)
            .ToHashSet();

        var created = 0;
        for (var day = 0; day < totalDays; day++)
        {
            var date = startDate.AddDays(day);
            if (alreadyScheduled.Contains(date)) continue;

            var workoutName = cyclePattern[day % cyclePattern.Count];
            if (!workoutIdByName.TryGetValue(workoutName, out var workoutId)) continue;

            var result = await _scheduledWorkoutService.CreateScheduledWorkoutAsync(new ScheduledWorkoutRequestDto
            {
                WorkoutId = workoutId,
                WorkoutPlanId = planId,
                ScheduledDate = date,
            }, clientId);
            if (result != null) created++;
        }

        return created;
    }

    /// <summary>Resolves each prescribed exercise id to one the client will own: passed through
    /// unchanged if the client can already see it, copied in if it's the trainer's own (see
    /// <see cref="IExerciseService.CopyExerciseAsync"/>), and reported back as unknown for
    /// anything else — a third party's private exercise, or an id that doesn't exist. Ownership
    /// is checked against the trainer's own library <em>before</em> copying anything, precisely
    /// so a stranger's private exercise id can't be smuggled onto the client through this path.
    /// </summary>
    private async Task<(List<Guid> UnknownIds, Dictionary<Guid, Guid> Resolved)> ResolvePrescribedExerciseIdsAsync(
        Guid trainerId, Guid clientId, IEnumerable<Guid> exerciseIds)
    {
        var distinctIds = exerciseIds.Distinct().ToList();
        var resolved = new Dictionary<Guid, Guid>();
        var unknown = new List<Guid>();
        if (distinctIds.Count == 0) return (unknown, resolved);

        var clientLibraryIds = (await _exerciseService.GetAllExercisesAsync(clientId))
            .Select(e => e.id)
            .ToHashSet();
        var trainerOwnedIds = (await _exerciseService.GetAllExercisesAsync(trainerId))
            .Where(e => e.UserId == trainerId)
            .Select(e => e.id)
            .ToHashSet();

        foreach (var id in distinctIds)
        {
            if (clientLibraryIds.Contains(id))
            {
                resolved[id] = id;
                continue;
            }

            if (trainerOwnedIds.Contains(id))
            {
                var copy = await _exerciseService.CopyExerciseAsync(id, clientId);
                if (copy != null)
                {
                    resolved[id] = copy.id;
                    continue;
                }
            }

            unknown.Add(id);
        }

        return (unknown, resolved);
    }

    /// <summary>Applies one prescription diff onto a workout's live exercises: an incoming
    /// entry that keeps both its id and its exercise is updated in place, everything else is
    /// added fresh (a genuinely new entry, or the replacement half of a swap), and whatever
    /// was live before and isn't accounted for afterwards is removed — via
    /// <see cref="IWorkoutService.DeleteWorkoutExerciseAsync"/>, which already retires rather
    /// than deletes an entry the client has logged sets against.</summary>
    private async Task ApplyExercisePrescriptionAsync(
        Guid clientId,
        Guid workoutId,
        List<WorkoutExerciseResponseDto> existingLive,
        List<ClientWorkoutExerciseRequestDto> incoming,
        Dictionary<Guid, Guid> resolvedExerciseIds)
    {
        var existingById = existingLive.ToDictionary(e => e.Id);
        var keptIds = new HashSet<Guid>();

        for (var i = 0; i < incoming.Count; i++)
        {
            var entry = incoming[i];
            var resolvedExerciseId = resolvedExerciseIds[entry.ExerciseId];

            var isKeep = entry.Id is Guid existingWeId
                && existingById.TryGetValue(existingWeId, out var existing)
                && existing.ExerciseId == resolvedExerciseId;

            Guid targetWeId;
            if (isKeep)
            {
                targetWeId = entry.Id!.Value;
                await _workoutService.UpdateWorkoutExerciseAsync(targetWeId, clientId, new WorkoutExerciseRequestDto
                {
                    ExerciseId = resolvedExerciseId,
                    OrderPosition = i,
                    Notes = entry.Notes,
                    SupersetGroupId = entry.SupersetGroupId,
                });
            }
            else
            {
                // A brand-new entry, or the replacement half of a swap — either way the old
                // row at entry.Id (if any) is simply not added to keptIds, so the cleanup
                // pass below removes it.
                var created = await _workoutService.AddExerciseToWorkoutAsync(workoutId, clientId, new WorkoutExerciseRequestDto
                {
                    ExerciseId = resolvedExerciseId,
                    OrderPosition = i,
                    Notes = entry.Notes,
                    SupersetGroupId = entry.SupersetGroupId,
                });
                targetWeId = created!.Id;
            }

            keptIds.Add(targetWeId);

            var setDtos = entry.TargetReps.Select((reps, idx) => new WorkoutSetTemplateRequestDto
            {
                SetNumber = idx + 1,
                TargetReps = reps,
                OrderPosition = idx,
            }).ToList();
            await _workoutService.ReplaceSetTemplatesAsync(targetWeId, clientId, setDtos);
        }

        foreach (var goneId in existingById.Keys.Except(keptIds))
        {
            await _workoutService.DeleteWorkoutExerciseAsync(goneId, clientId);
        }
    }

    private async Task<ClientWorkoutDto?> LoadClientWorkoutDtoAsync(Guid clientId, Guid workoutId)
    {
        var workout = await _workoutService.GetWorkoutByIdAsync(workoutId, clientId);
        if (workout == null) return null;

        var plans = await _workoutPlanService.GetUserPlansAsync(clientId);
        var names = await ExerciseNamesForAsync(workout.Exercises);
        return ToClientWorkoutDto(workout, plans, names);
    }

    private Task<Dictionary<Guid, string>> ExerciseNamesForAsync(IEnumerable<WorkoutExerciseResponseDto> exercises) =>
        _exerciseService.GetNamesByIdsAsync(
            [.. exercises.Where(e => e.RemovedAt == null).Select(e => e.ExerciseId).Distinct()]);

    private static ClientWorkoutDto ToClientWorkoutDto(
        WorkoutResponseDto workout, List<WorkoutPlanResponseDto> plans, Dictionary<Guid, string> exerciseNames) => new()
    {
        Id = workout.Id,
        Name = workout.Name,
        Description = workout.Description,
        Difficulty = workout.Difficulty,
        EstimatedDurationMinutes = workout.EstimatedDurationMinutes,
        PlanIds = [.. plans.Where(p => p.WorkoutIds.Contains(workout.Id)).Select(p => p.Id)],
        Exercises = [.. workout.Exercises
            .Where(e => e.RemovedAt == null)
            .OrderBy(e => e.OrderPosition)
            .Select(e => new ClientWorkoutExerciseDto
            {
                Id = e.Id,
                ExerciseId = e.ExerciseId,
                ExerciseName = exerciseNames.GetValueOrDefault(e.ExerciseId, ""),
                OrderPosition = e.OrderPosition,
                Notes = e.Notes,
                SupersetGroupId = e.SupersetGroupId,
                Sets = [.. e.SetTemplates.OrderBy(s => s.OrderPosition)],
            })],
    };
}
