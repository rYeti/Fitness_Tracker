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
    public async Task<Exercise> UpdateExerciseAsync(ExerciseRequestDto exercise, Guid userId, Guid id)
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
    public async Task<List<Exercise>> GetAllExercisesAsync()
    {
        return await _context.Exercise.ToListAsync();
    }

}