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
    public async Task<ScheduledWorkout?> GetScheduledWorkoutByIdAsync(Guid id)
    {
        return await _context.ScheduledWorkouts
            .Where(sw => sw.Id == id)
            .Include(sw => sw.Exercises)
                .ThenInclude(e => e.Sets)
            .FirstOrDefaultAsync();
    }

    /// <inheritdoc/>
    public async Task<ScheduledWorkout> CreateScheduledWorkoutAsync(ScheduledWorkout sw)
    {
        var workoutExercises = await _context.WorkoutExercises
            .Where(we => we.WorkoutId == sw.WorkoutId)
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
    public async Task<ScheduledWorkout?> UpdateScheduledWorkoutAsync(Guid id, ScheduledWorkoutRequestDto dto)
    {
        var sw = await _context.ScheduledWorkouts.FirstOrDefaultAsync(s => s.Id == id);
        if (sw == null) return null;

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
    public async Task<bool> DeleteScheduledWorkoutAsync(Guid id)
    {
        var sw = await _context.ScheduledWorkouts.FirstOrDefaultAsync(s => s.Id == id);
        if (sw == null) return false;

        _context.ScheduledWorkouts.Remove(sw);
        await _context.SaveChangesAsync();
        return true;
    }

    /// <inheritdoc/>
    public async Task<ScheduledWorkoutExercise?> GetScheduledExerciseAsync(Guid id)
    {
        return await _context.ScheduledWorkoutExercises.FirstOrDefaultAsync(e => e.Id == id);
    }

    /// <inheritdoc/>
    public async Task<List<ScheduledWorkoutExercise>> CreateExercisesBatchAsync(Guid scheduledWorkoutId, List<Guid> workoutExerciseIds)
    {
        var created = workoutExerciseIds.Select(weId => new ScheduledWorkoutExercise
        {
            Id = Guid.NewGuid(),
            ScheduledWorkoutId = scheduledWorkoutId,
            WorkoutExerciseId = weId,
            IsCompleted = false,
        }).ToList();

        _context.ScheduledWorkoutExercises.AddRange(created);
        await _context.SaveChangesAsync();
        return created;
    }

    /// <inheritdoc/>
    public async Task<WorkoutSet> AddSetAsync(WorkoutSet set)
    {
        _context.WorkoutSets.Add(set);
        await _context.SaveChangesAsync();
        return set;
    }

    /// <inheritdoc/>
    public async Task<WorkoutSet?> UpdateSetAsync(Guid setId, WorkoutSetRequestDto dto)
    {
        var set = await _context.WorkoutSets.FirstOrDefaultAsync(s => s.Id == setId);
        if (set == null) return null;

        set.SetNumber = dto.SetNumber;
        set.Reps = dto.Reps;
        set.Weight = dto.Weight;
        set.WeightUnit = dto.WeightUnit;
        set.DurationSeconds = dto.DurationSeconds;
        set.Notes = dto.Notes;

        await _context.SaveChangesAsync();
        return set;
    }

    /// <inheritdoc/>
    public async Task<bool> DeleteSetAsync(Guid setId)
    {
        var set = await _context.WorkoutSets.FirstOrDefaultAsync(s => s.Id == setId);
        if (set == null) return false;

        _context.WorkoutSets.Remove(set);
        await _context.SaveChangesAsync();
        return true;
    }

    /// <inheritdoc/>
    public async Task<bool> CompleteExerciseAsync(Guid scheduledExerciseId)
    {
        var exercise = await _context.ScheduledWorkoutExercises.FirstOrDefaultAsync(e => e.Id == scheduledExerciseId);
        if (exercise == null) return false;

        exercise.IsCompleted = true;
        await _context.SaveChangesAsync();
        return true;
    }

    /// <inheritdoc/>
    public async Task<bool> CompleteWorkoutAsync(Guid scheduledWorkoutId)
    {
        var sw = await _context.ScheduledWorkouts.FirstOrDefaultAsync(s => s.Id == scheduledWorkoutId);
        if (sw == null) return false;

        sw.IsCompleted = true;
        await _context.SaveChangesAsync();
        return true;
    }
}
