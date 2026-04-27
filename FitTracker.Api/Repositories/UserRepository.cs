using FitTracker.Api.Data;
using FitTracker.Api.Models;
using Microsoft.EntityFrameworkCore;
using FitTracker.Api.Repositories.Interfaces;

namespace FitTracker.Api.Repositories;

/// <summary>EF Core implementation of <see cref="IUserRepository"/>.</summary>
public class UserRepository(AppDbContext context) : IUserRepository
{
    private readonly AppDbContext _context = context;

    /// <inheritdoc/>
    public async Task<User?> GetUserByIdAsync(Guid id)
    {
        return await _context.Users.FindAsync(id);
    }

    /// <inheritdoc/>
    public async Task<User?> GetUserByEmailAsync(string email)
    {
        return await _context.Users.FirstOrDefaultAsync(u => u.Email == email);
    }

    /// <inheritdoc/>
    public async Task<User?> GetUserByUsernameAsync(string username)
    {
        return await _context.Users.FirstOrDefaultAsync(u => u.UserName == username);
    }

    /// <inheritdoc/>
    public async Task CreateUserAsync(User user)
    {
        _context.Users.Add(user);
        await _context.SaveChangesAsync();
    }

    /// <inheritdoc/>
    public async Task UpdateUserAsync(User user)
    {
        _context.Users.Update(user);
        await _context.SaveChangesAsync();
    }

    /// <inheritdoc/>
    public async Task DeleteUserAsync(Guid id)
    {
        // Must delete in order to satisfy RESTRICT foreign keys before cascades run.

        // 1. ScheduledWorkoutExercises referencing WorkoutExercises owned by this user
        var scheduledExercises = _context.ScheduledWorkoutExercises
            .Where(se => se.ScheduledWorkout.Workout.UserId == id);
        _context.ScheduledWorkoutExercises.RemoveRange(scheduledExercises);

        // 2. ScheduledWorkouts referencing Workouts owned by this user
        var scheduledWorkouts = _context.ScheduledWorkouts
            .Where(sw => sw.Workout.UserId == id);
        _context.ScheduledWorkouts.RemoveRange(scheduledWorkouts);

        // 3. TrainerClient rows (RESTRICT on ClientId)
        var trainerClientRows = _context.TrainerClients
            .Where(tc => tc.ClientId == id || tc.TrainerId == id);
        _context.TrainerClients.RemoveRange(trainerClientRows);

        // 4. Delete the user — EF cascades handle the rest
        var user = await _context.Users.FindAsync(id);
        if (user != null)
            _context.Users.Remove(user);

        await _context.SaveChangesAsync();
    }
}