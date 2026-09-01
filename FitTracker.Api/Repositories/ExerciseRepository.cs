using FitTracker.Api.Data;
using FitTracker.Api.DTOs;
using FitTracker.Api.Models;
using FitTracker.Api.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace FitTracker.Api.Repositories;

/// <summary>EF Core implementation of <see cref="IExerciseRepository"/>.</summary>
public class ExerciseRepository : IExerciseRepository
{
    private readonly AppDbContext _context;
    public ExerciseRepository(AppDbContext context)
    {
        _context = context;
    }

    /// <inheritdoc/>
    public async Task<Exercise> CreateExercisesAsync(Exercise exercise)
    {
        _context.Exercise.Add(exercise);
        await _context.SaveChangesAsync();
        return exercise;
    }

    /// <inheritdoc/>
    public async Task<bool> DeleteExerciseAsync(Guid id, Guid userId)
    {
        var exercise = await _context.Exercise.FirstOrDefaultAsync(e => e.Id == id && e.UserId == userId);
        if (exercise == null)
        {
            return false;
        }

        _context.Exercise.Remove(exercise);
        await _context.SaveChangesAsync();
        return true;
    }

    /// <inheritdoc/>
    public async Task<List<Exercise>> GetUserExercisesAsync(Guid id)
    {
        return await _context.Exercise.Where(w => w.UserId == id).ToListAsync();
    }

    /// <inheritdoc/>
    public async Task<Exercise?> UpdateExerciseAsync(ExerciseRequestDto exercise, Guid userId, Guid id)
    {
        var exerciseDb = await _context.Exercise.SingleOrDefaultAsync(e => e.Id == id && e.UserId == userId);

        if (exerciseDb == null)
        {
            return null;
        }

        exerciseDb.Name = exercise.Name;
        exerciseDb.NameDe = exercise.NameDe;
        exerciseDb.IsCustom = exercise.IsCustom;
        exerciseDb.TargetMuscleGroups = exercise.TargetMuscleGroups;
        exerciseDb.Type = exercise.Type;
        exerciseDb.DescriptionDe = exercise.DescriptionDe;
        exerciseDb.Description = exercise.Description;
        await _context.SaveChangesAsync();

        return exerciseDb;
    }

    /// <inheritdoc/>
    public async Task<List<Exercise>> GetAllExercisesAsync(Guid userId)
    {
        return await _context.Exercise
            .AsNoTracking()
            .Where(e => e.UserId == null || e.UserId == userId)
            .ToListAsync();
    }

    /// <inheritdoc/>
    public async Task<Exercise?> GetByIdAsync(Guid id)
    {
        return await _context.Exercise.AsNoTracking().FirstOrDefaultAsync(e => e.Id == id);
    }

    /// <inheritdoc/>
    public async Task<Exercise?> GetCopyAsync(Guid sourceExerciseId, Guid ownerId)
    {
        return await _context.Exercise.AsNoTracking()
            .FirstOrDefaultAsync(e => e.UserId == ownerId && e.SourceExerciseId == sourceExerciseId);
    }

    /// <inheritdoc/>
    public async Task<Dictionary<Guid, string>> GetNamesByIdsAsync(IReadOnlyCollection<Guid> exerciseIds)
    {
        if (exerciseIds.Count == 0) return [];

        var ids = exerciseIds.ToList();
        var rows = await _context.Exercise
            .AsNoTracking()
            .Where(e => ids.Contains(e.Id))
            .Select(e => new { e.Id, e.Name })
            .ToListAsync();

        return rows.ToDictionary(r => r.Id, r => r.Name);
    }

    /// <inheritdoc/>
    public async Task<Dictionary<Guid, string>> GetNamesByWorkoutExerciseIdsAsync(IReadOnlyCollection<Guid> workoutExerciseIds)
    {
        if (workoutExerciseIds.Count == 0) return [];

        var ids = workoutExerciseIds.ToList();
        // An explicit join rather than a navigation: WorkoutExercise.ExerciseId carries no
        // foreign key (exercises can be seeded client-side), so there is nothing to navigate.
        var rows = await (
            from we in _context.WorkoutExercises.AsNoTracking()
            where ids.Contains(we.Id)
            join e in _context.Exercise.AsNoTracking() on we.ExerciseId equals e.Id
            select new { WorkoutExerciseId = we.Id, e.Name })
            .ToListAsync();

        // An inner join can't produce duplicate keys here — Exercise.Id is the primary key —
        // but a workout-exercise row whose ExerciseId resolves to nothing simply drops out,
        // which is what callers' GetValueOrDefault(id, "") already expects.
        return rows.ToDictionary(r => r.WorkoutExerciseId, r => r.Name);
    }

}