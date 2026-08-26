using FitTracker.Api.Data;
using FitTracker.Api.DTOs;
using FitTracker.Api.Models;
using FitTracker.Api.Repositories.Interfaces;
using System.Linq.Expressions;
using Microsoft.EntityFrameworkCore;

namespace FitTracker.Api.Repositories;

/// <summary>EF Core implementation of <see cref="IScheduledWorkoutRepository"/>.</summary>
public class ScheduledWorkoutRepository : IScheduledWorkoutRepository
{
    private readonly AppDbContext _context;

    /// <summary>Initialises a new instance of <see cref="ScheduledWorkoutRepository"/>.</summary>
    /// <param name="context">The database context.</param>
    public ScheduledWorkoutRepository(AppDbContext context)
    {
        _context = context;
    }

    /// <summary>Whether a scheduled workout is still part of the client's current programme.
    /// The SQL half of the rule <c>TrainerConsoleService.FilterToCurrentProgramme</c> applies
    /// in memory — the two must always say the same thing.</summary>
    /// <remarks>
    /// Moving a client onto a new plan only clears <c>IsActive</c> on the old one: every date
    /// that plan ever generated stays in ScheduledWorkouts, unstarted, forever. Counted as
    /// planned-and-not-completed they hold adherence down for work never asked of the client.
    /// A session from a dead plan is only real if the client engaged with it while the plan was
    /// live; sessions scheduled by hand carry no plan and are always current business. See
    /// docs/trainer-session-review.md.
    ///
    /// <c>sw.WorkoutPlan!.IsActive</c> stands in for the in-memory version's "is this plan in
    /// the client's active-plan set" lookup: a scheduled workout's plan always belongs to the
    /// same user (CreateScheduledWorkoutAsync verifies it), so the navigation is the join.
    ///
    /// If you change this, change FilterToCurrentProgramme with it. Two copies of one rule are
    /// exactly how the bug that doc describes came back the first time.
    /// </remarks>
    public static readonly Expression<Func<ScheduledWorkout, bool>> InCurrentProgramme =
        sw => sw.WorkoutPlanId == null
            || sw.WorkoutPlan!.IsActive
            || sw.IsCompleted
            || sw.IsSkipped
            || sw.Exercises.Any(e => e.Sets.Any());

    /// <inheritdoc/>
    public async Task<List<ScheduledWorkout>> GetUserScheduledWorkoutsAsync(Guid userId)
    {
        return await _context.ScheduledWorkouts
            .AsNoTracking()
            .Where(sw => sw.Workout.UserId == userId)
            .Include(sw => sw.Exercises)
                .ThenInclude(e => e.Sets)
            .ToListAsync();
    }

    /// <inheritdoc/>
    public async Task<List<ScheduledWorkout>> GetUserScheduledWorkoutsInRangeAsync(Guid userId, DateTime from, DateTime to)
    {
        return await _context.ScheduledWorkouts
            .AsNoTracking()
            .Where(sw => sw.Workout.UserId == userId)
            .Where(sw => sw.ScheduledDate >= from && sw.ScheduledDate < to)
            .Include(sw => sw.Exercises)
                .ThenInclude(e => e.Sets)
            // Two levels of collection include is a cartesian join; split it rather than
            // multiplying every session by its exercises by its sets on the wire.
            .AsSplitQuery()
            .ToListAsync();
    }

    /// <inheritdoc/>
    public async Task<List<ClientTrainingStats>> GetClientTrainingStatsAsync(
        IReadOnlyCollection<Guid> clientIds,
        DateTime windowStart,
        DateTime windowEnd,
        DateTime weekStart,
        DateTime weekEnd)
    {
        // Contains over an empty list is a full scan on some providers and an error on others.
        if (clientIds.Count == 0) return [];

        // The caller's two windows overlap — the current week sits inside the trailing
        // adherence window — so one scan of [windowStart, weekEnd) feeds both, and the
        // per-window counts are separated by the CASE expressions below.
        var ids = clientIds.ToList();
        var rows = await _context.ScheduledWorkouts
            .AsNoTracking()
            .Where(sw => ids.Contains(sw.Workout.UserId))
            .Where(InCurrentProgramme)
            .Where(sw => sw.ScheduledDate >= windowStart && sw.ScheduledDate < weekEnd)
            .GroupBy(sw => sw.Workout.UserId)
            // Sum(cond ? 1 : 0) rather than Count(cond): it becomes SUM(CASE WHEN ...), which
            // translates on both Npgsql and the SQLite provider the tests run on.
            .Select(g => new
            {
                ClientId = g.Key,
                PlannedInWindow = g.Sum(sw => sw.ScheduledDate < windowEnd ? 1 : 0),
                CompletedInWindow = g.Sum(sw => sw.ScheduledDate < windowEnd && sw.IsCompleted ? 1 : 0),
                PlannedThisWeek = g.Sum(sw => sw.ScheduledDate >= weekStart ? 1 : 0),
                CompletedThisWeek = g.Sum(sw => sw.ScheduledDate >= weekStart && sw.IsCompleted ? 1 : 0),
            })
            .ToListAsync();

        return rows
            .Select(r => new ClientTrainingStats(
                r.ClientId, r.PlannedInWindow, r.CompletedInWindow, r.PlannedThisWeek, r.CompletedThisWeek))
            .ToList();
    }

    /// <inheritdoc/>
    public async Task<Dictionary<Guid, DateTime>> GetLastCompletedSessionDatesAsync(IReadOnlyCollection<Guid> clientIds)
    {
        if (clientIds.Count == 0) return [];

        var ids = clientIds.ToList();
        // Deliberately a query of its own rather than another aggregate on the grouped
        // query above: "most recent ever" is unbounded, and folding it in would drag the
        // current-programme EXISTS across the client's entire history — the exact cost
        // this whole path exists to avoid. IsCompleted on its own already satisfies
        // InCurrentProgramme's third clause, so the two agree without the predicate.
        return await _context.ScheduledWorkouts
            .AsNoTracking()
            .Where(sw => ids.Contains(sw.Workout.UserId) && sw.IsCompleted)
            .GroupBy(sw => sw.Workout.UserId)
            .Select(g => new { ClientId = g.Key, Last = g.Max(sw => sw.ScheduledDate) })
            .ToDictionaryAsync(x => x.ClientId, x => x.Last);
    }

    /// <inheritdoc/>
    public async Task<List<ScheduledWorkout>> GetRecentSessionsAsync(Guid userId, DateTime notAfter, int count)
    {
        return await _context.ScheduledWorkouts
            .AsNoTracking()
            .Where(sw => sw.Workout.UserId == userId)
            .Where(InCurrentProgramme)
            .Where(sw => sw.ScheduledDate < notAfter)
            .Include(sw => sw.Exercises)
                .ThenInclude(e => e.Sets)
            .OrderByDescending(sw => sw.ScheduledDate)
            // Two sessions on one day used to come back in whatever order the database
            // chose; break the tie so a page is at least stable between requests.
            .ThenByDescending(sw => sw.Id)
            .Take(count)
            .AsSplitQuery()
            .ToListAsync();
    }

    /// <inheritdoc/>
    public async Task<Dictionary<Guid, double>> GetBestWeightsBeforeAsync(Guid userId, DateTime before)
    {
        // Weight > 0 rather than "has a weight": the caller treats the first weight ever
        // logged for an exercise as a baseline and not a personal record, and it only
        // records that baseline for a positive weight. Seeding a zero would invent a
        // baseline the unbounded walk never had, turning someone's first real lift into a PR.
        var best = await _context.WorkoutSets
            .AsNoTracking()
            .Where(s => s.IsCompleted && s.Weight > 0)
            .Where(s => s.ScheduledWorkoutExercise.ScheduledWorkout.Workout.UserId == userId)
            .Where(s => s.ScheduledWorkoutExercise.ScheduledWorkout.ScheduledDate < before)
            .GroupBy(s => s.ScheduledWorkoutExercise.OverrideExerciseId
                       ?? s.ScheduledWorkoutExercise.WorkoutExercise.ExerciseId)
            .Select(g => new { ExerciseId = g.Key, Best = g.Max(s => s.Weight) })
            .ToListAsync();

        return best.ToDictionary(x => x.ExerciseId, x => x.Best ?? 0);
    }

    /// <inheritdoc/>
    public async Task<ScheduledWorkout?> GetScheduledWorkoutByIdAsync(Guid id, Guid userId)
    {
        return await _context.ScheduledWorkouts
            .Where(sw => sw.Id == id && sw.Workout.UserId == userId)
            .Include(sw => sw.Exercises)
                .ThenInclude(e => e.Sets)
            .FirstOrDefaultAsync();
    }

    /// <inheritdoc/>
    public async Task<ScheduledWorkout?> CreateScheduledWorkoutAsync(ScheduledWorkout sw, Guid userId)
    {
        var existing = await _context.ScheduledWorkouts
            .Include(s => s.Exercises)
                .ThenInclude(e => e.Sets)
            .FirstOrDefaultAsync(s => s.Id == sw.Id);

        if (existing != null)
            return existing;

        var ownsWorkout = await _context.Workouts.AnyAsync(w => w.Id == sw.WorkoutId && w.UserId == userId);
        if (!ownsWorkout) return null;

        if (sw.WorkoutPlanId != null)
        {
            var ownsPlan = await _context.WorkoutPlans.AnyAsync(p => p.Id == sw.WorkoutPlanId && p.UserId == userId);
            if (!ownsPlan) return null;
        }

        // Retired exercises are kept only so already-logged sessions can still resolve
        // them; they are not part of the workout any more, so a new session must not be
        // stamped with one. Skipping that check is what put entries nobody could log
        // against into every session generated after an exercise was dropped.
        var workoutExercises = await _context.WorkoutExercises
            .Where(we => we.WorkoutId == sw.WorkoutId && we.RemovedAt == null)
            .OrderBy(we => we.OrderPosition)
            .ToListAsync();

        foreach (var we in workoutExercises)
        {
            sw.Exercises.Add(new ScheduledWorkoutExercise
            {
                Id = Guid.NewGuid(),
                ScheduledWorkoutId = sw.Id,
                WorkoutExerciseId = we.Id,
                IsCompleted = false,
            });
        }

        _context.ScheduledWorkouts.Add(sw);
        await _context.SaveChangesAsync();
        return sw;
    }

    /// <inheritdoc/>
    public async Task<ScheduledWorkout?> UpdateScheduledWorkoutAsync(Guid id, Guid userId, ScheduledWorkoutRequestDto dto)
    {
        var sw = await _context.ScheduledWorkouts
            .Include(s => s.Exercises)
                .ThenInclude(e => e.Sets)
            .FirstOrDefaultAsync(s => s.Id == id && s.Workout.UserId == userId);
        if (sw == null) return null;

        var ownsWorkout = await _context.Workouts.AnyAsync(w => w.Id == dto.WorkoutId && w.UserId == userId);
        if (!ownsWorkout) return null;

        if (dto.WorkoutPlanId != null)
        {
            var ownsPlan = await _context.WorkoutPlans.AnyAsync(p => p.Id == dto.WorkoutPlanId && p.UserId == userId);
            if (!ownsPlan) return null;
        }

        sw.WorkoutId = dto.WorkoutId;
        sw.WorkoutPlanId = dto.WorkoutPlanId;
        sw.ScheduledDate = dto.ScheduledDate;
        sw.Notes = dto.Notes;
        sw.IsCompleted = dto.IsCompleted;
        sw.IsSkipped = dto.IsSkipped;

        await _context.SaveChangesAsync();
        return sw;
    }

    /// <inheritdoc/>
    public async Task<bool> DeleteScheduledWorkoutAsync(Guid id, Guid userId)
    {
        var sw = await _context.ScheduledWorkouts.FirstOrDefaultAsync(s => s.Id == id && s.Workout.UserId == userId);
        if (sw == null) return false;

        _context.ScheduledWorkouts.Remove(sw);
        await _context.SaveChangesAsync();
        return true;
    }

    /// <inheritdoc/>
    public async Task<List<ScheduledWorkoutExercise>?> CreateExercisesBatchAsync(Guid scheduledWorkoutId, Guid userId, List<Guid> workoutExerciseIds)
    {
        var ownsScheduledWorkout = await _context.ScheduledWorkouts
            .AnyAsync(s => s.Id == scheduledWorkoutId && s.Workout.UserId == userId);
        if (!ownsScheduledWorkout) return null;

        var existingWeIds = await _context.ScheduledWorkoutExercises
            .Where(e => e.ScheduledWorkoutId == scheduledWorkoutId)
            .Select(e => e.WorkoutExerciseId)
            .ToListAsync();

        var toCreate = workoutExerciseIds
            .Where(weId => !existingWeIds.Contains(weId))
            .Select(weId => new ScheduledWorkoutExercise
            {
                Id = Guid.NewGuid(),
                ScheduledWorkoutId = scheduledWorkoutId,
                WorkoutExerciseId = weId,
                IsCompleted = false,
            }).ToList();

        if (toCreate.Count > 0)
        {
            _context.ScheduledWorkoutExercises.AddRange(toCreate);
            await _context.SaveChangesAsync();
        }

        return await _context.ScheduledWorkoutExercises
            .Where(e => e.ScheduledWorkoutId == scheduledWorkoutId)
            .ToListAsync();
    }

    /// <inheritdoc/>
    public async Task<WorkoutSet?> AddSetAsync(WorkoutSet set, Guid userId)
    {
        var ownsExercise = await _context.ScheduledWorkoutExercises
            .AnyAsync(e => e.Id == set.ScheduledWorkoutExerciseId && e.ScheduledWorkout.Workout.UserId == userId);
        if (!ownsExercise) return null;

        _context.WorkoutSets.Add(set);
        await _context.SaveChangesAsync();
        return set;
    }

    /// <inheritdoc/>
    public async Task<WorkoutSet?> UpdateSetAsync(Guid setId, Guid userId, WorkoutSetRequestDto dto)
    {
        var set = await _context.WorkoutSets
            .FirstOrDefaultAsync(s => s.Id == setId && s.ScheduledWorkoutExercise.ScheduledWorkout.Workout.UserId == userId);
        if (set == null) return null;

        set.SetNumber = dto.SetNumber;
        set.Reps = dto.Reps;
        set.Weight = dto.Weight;
        set.WeightUnit = dto.WeightUnit;
        set.DurationSeconds = dto.DurationSeconds;
        set.IsCompleted = dto.IsCompleted;
        set.Notes = dto.Notes;

        await _context.SaveChangesAsync();
        return set;
    }

    /// <inheritdoc/>
    public async Task<bool> DeleteSetAsync(Guid setId, Guid userId)
    {
        var set = await _context.WorkoutSets
            .FirstOrDefaultAsync(s => s.Id == setId && s.ScheduledWorkoutExercise.ScheduledWorkout.Workout.UserId == userId);
        if (set == null) return false;

        _context.WorkoutSets.Remove(set);
        await _context.SaveChangesAsync();
        return true;
    }

    /// <inheritdoc/>
    public async Task<bool> CompleteExerciseAsync(Guid scheduledExerciseId, Guid userId)
    {
        var exercise = await _context.ScheduledWorkoutExercises
            .FirstOrDefaultAsync(e => e.Id == scheduledExerciseId && e.ScheduledWorkout.Workout.UserId == userId);
        if (exercise == null) return false;

        exercise.IsCompleted = true;
        await _context.SaveChangesAsync();
        return true;
    }

    /// <inheritdoc/>
    public async Task<bool> CompleteWorkoutAsync(Guid scheduledWorkoutId, Guid userId)
    {
        var sw = await _context.ScheduledWorkouts
            .FirstOrDefaultAsync(s => s.Id == scheduledWorkoutId && s.Workout.UserId == userId);
        if (sw == null) return false;

        sw.IsCompleted = true;
        await _context.SaveChangesAsync();
        return true;
    }
}
