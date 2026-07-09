using FitTracker.Api.Data;
using FitTracker.Api.DTOs;
using FitTracker.Api.Models;
using FitTracker.Api.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace FitTracker.Api.Repositories;

/// <summary>EF Core implementation of <see cref="IWorkoutRepository"/>.</summary>
public class WorkoutRepository : IWorkoutRepository
{
    private readonly AppDbContext _context;

    /// <summary>Initialises a new instance of <see cref="WorkoutRepository"/>.</summary>
    /// <param name="context">The database context.</param>
    public WorkoutRepository(AppDbContext context)
    {
        _context = context;
    }

    /// <inheritdoc/>
    public async Task<List<Workout>> GetUserWorkoutsAsync(Guid userId)
    {
        return await _context.Workouts
            .Where(w => w.UserId == userId)
            .Include(w => w.Exercises)
                .ThenInclude(e => e.SetTemplates)
            .ToListAsync();
    }

    /// <inheritdoc/>
    public async Task<Workout?> GetWorkoutByIdAsync(Guid id, Guid userId)
    {
        return await _context.Workouts
            .Where(w => w.Id == id && w.UserId == userId)
            .Include(w => w.Exercises)
                .ThenInclude(e => e.SetTemplates)
            .FirstOrDefaultAsync();
    }

    /// <inheritdoc/>
    public async Task<Workout> CreateWorkoutAsync(Workout workout)
    {
        _context.Workouts.Add(workout);
        await _context.SaveChangesAsync();
        return workout;
    }

    /// <inheritdoc/>
    public async Task<Workout?> UpdateWorkoutAsync(Guid id, Guid userId, WorkoutRequestDto dto)
    {
        var workout = await _context.Workouts.FirstOrDefaultAsync(w => w.Id == id && w.UserId == userId);
        if (workout == null) return null;

        workout.Name = dto.Name;
        workout.Description = dto.Description;
        workout.Difficulty = dto.Difficulty;
        workout.EstimatedDurationMinutes = dto.EstimatedDurationMinutes;
        workout.IsTemplate = dto.IsTemplate;
        workout.ScheduledDate = dto.ScheduledDate;
        workout.Color = dto.Color;

        await _context.SaveChangesAsync();
        return workout;
    }

    /// <inheritdoc/>
    public async Task<bool> DeleteWorkoutAsync(Guid id, Guid userId)
    {
        var workout = await _context.Workouts.FirstOrDefaultAsync(w => w.Id == id && w.UserId == userId);
        if (workout == null) return false;

        _context.Workouts.Remove(workout);
        await _context.SaveChangesAsync();
        return true;
    }

    /// <inheritdoc/>
    public async Task<WorkoutExercise?> AddExerciseToWorkoutAsync(WorkoutExercise we, Guid userId)
    {
        var ownsWorkout = await _context.Workouts.AnyAsync(w => w.Id == we.WorkoutId && w.UserId == userId);
        if (!ownsWorkout) return null;

        _context.WorkoutExercises.Add(we);
        await _context.SaveChangesAsync();
        return we;
    }

    /// <inheritdoc/>
    public async Task<WorkoutExercise?> UpdateWorkoutExerciseAsync(Guid weId, Guid userId, WorkoutExerciseRequestDto dto)
    {
        var we = await _context.WorkoutExercises
            .Include(e => e.Workout)
            .FirstOrDefaultAsync(e => e.Id == weId && e.Workout.UserId == userId);
        if (we == null) return null;

        we.ExerciseId = dto.ExerciseId;
        we.OrderPosition = dto.OrderPosition;
        we.Notes = dto.Notes;
        we.SupersetGroupId = dto.SupersetGroupId;

        await _context.SaveChangesAsync();
        return we;
    }

    /// <inheritdoc/>
    public async Task<bool> DeleteWorkoutExerciseAsync(Guid weId, Guid userId)
    {
        var we = await _context.WorkoutExercises
            .Include(e => e.Workout)
            .FirstOrDefaultAsync(e => e.Id == weId && e.Workout.UserId == userId);
        if (we == null) return false;

        _context.WorkoutExercises.Remove(we);
        await _context.SaveChangesAsync();
        return true;
    }

    /// <inheritdoc/>
    public async Task<WorkoutSetTemplate?> AddSetTemplateAsync(WorkoutSetTemplate t, Guid userId)
    {
        var ownsExercise = await _context.WorkoutExercises
            .AnyAsync(e => e.Id == t.WorkoutExerciseId && e.Workout.UserId == userId);
        if (!ownsExercise) return null;

        _context.WorkoutSetTemplates.Add(t);
        await _context.SaveChangesAsync();
        return t;
    }

    /// <inheritdoc/>
    public async Task<WorkoutSetTemplate?> UpdateSetTemplateAsync(Guid id, Guid userId, WorkoutSetTemplateRequestDto dto)
    {
        var template = await _context.WorkoutSetTemplates
            .Include(t => t.WorkoutExercise)
                .ThenInclude(e => e.Workout)
            .FirstOrDefaultAsync(t => t.Id == id && t.WorkoutExercise.Workout.UserId == userId);
        if (template == null) return null;

        template.SetNumber = dto.SetNumber;
        template.TargetReps = dto.TargetReps;
        template.OrderPosition = dto.OrderPosition;

        await _context.SaveChangesAsync();
        return template;
    }

    /// <inheritdoc/>
    public async Task<bool> DeleteSetTemplateAsync(Guid id, Guid userId)
    {
        var template = await _context.WorkoutSetTemplates
            .Include(t => t.WorkoutExercise)
                .ThenInclude(e => e.Workout)
            .FirstOrDefaultAsync(t => t.Id == id && t.WorkoutExercise.Workout.UserId == userId);
        if (template == null) return false;

        _context.WorkoutSetTemplates.Remove(template);
        await _context.SaveChangesAsync();
        return true;
    }
}
