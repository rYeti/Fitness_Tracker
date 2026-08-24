using FitTracker.Api.Data;
using FitTracker.Api.DTOs;
using FitTracker.Api.Models;
using FitTracker.Api.Repositories.Interfaces;
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

    /// <inheritdoc/>
    public async Task<List<ScheduledWorkout>> GetUserScheduledWorkoutsAsync(Guid userId)
    {
        return await _context.ScheduledWorkouts
            .Where(sw => sw.Workout.UserId == userId)
            .Include(sw => sw.Exercises)
                .ThenInclude(e => e.Sets)
            .ToListAsync();
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

        // A retired workout is kept only so already-logged sessions can resolve it; it is not
        // one of the user's workouts any more, so nothing new may be scheduled from it.
        var ownsWorkout = await _context.Workouts.AnyAsync(w => w.Id == sw.WorkoutId && w.UserId == userId && w.RemovedAt == null);
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
    public async Task<List<WorkoutSet>?> ReplaceSetsAsync(Guid scheduledWorkoutExerciseId, Guid userId, List<WorkoutSet> sets)
    {
        var ownsExercise = await _context.ScheduledWorkoutExercises
            .AnyAsync(e => e.Id == scheduledWorkoutExerciseId && e.ScheduledWorkout.Workout.UserId == userId);
        if (!ownsExercise) return null;

        await _context.WorkoutSets
            .Where(s => s.ScheduledWorkoutExerciseId == scheduledWorkoutExerciseId)
            .ExecuteDeleteAsync();

        // ExecuteDelete bypasses the change tracker, which would otherwise still believe
        // those rows exist and act on them during the SaveChanges below.
        var stale = _context.ChangeTracker.Entries<WorkoutSet>()
            .Where(e => e.Entity.ScheduledWorkoutExerciseId == scheduledWorkoutExerciseId)
            .ToList();
        foreach (var entry in stale) entry.State = EntityState.Detached;

        _context.WorkoutSets.AddRange(sets);
        await _context.SaveChangesAsync();
        return sets;
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
        set.Rpe = dto.Rpe;
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
