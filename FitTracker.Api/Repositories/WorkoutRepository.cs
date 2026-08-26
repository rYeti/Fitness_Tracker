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
            .AsNoTracking()
            .Where(w => w.UserId == userId)
            .Include(w => w.Exercises)
                .ThenInclude(e => e.SetTemplates)
            .ToListAsync();
    }

    /// <inheritdoc/>
    public async Task<Dictionary<Guid, string>> GetNamesByIdsAsync(IReadOnlyCollection<Guid> workoutIds)
    {
        if (workoutIds.Count == 0) return [];

        var ids = workoutIds.ToList();
        var rows = await _context.Workouts
            .AsNoTracking()
            .Where(w => ids.Contains(w.Id))
            .Select(w => new { w.Id, w.Name })
            .ToListAsync();

        return rows.ToDictionary(r => r.Id, r => r.Name);
    }

    /// <inheritdoc/>
    public async Task<List<WorkoutExercise>> GetExercisesByIdsAsync(IReadOnlyCollection<Guid> workoutExerciseIds)
    {
        if (workoutExerciseIds.Count == 0) return [];

        var ids = workoutExerciseIds.ToList();
        return await _context.WorkoutExercises
            .AsNoTracking()
            .Where(e => ids.Contains(e.Id))
            .Include(e => e.SetTemplates)
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
    public async Task<WorkoutDeleteResult> DeleteWorkoutAsync(Guid id, Guid userId)
    {
        var workout = await _context.Workouts.FirstOrDefaultAsync(w => w.Id == id && w.UserId == userId);
        if (workout == null) return WorkoutDeleteResult.NotFound;

        // Same restricted foreign key that DeleteWorkoutExerciseAsync had to learn about,
        // one level up: ScheduledWorkouts points here with Restrict, so removing a workout
        // the user had ever scheduled threw a foreign-key violation. The client saw a 500,
        // deleted its own copy anyway, and the workout stayed on the server — where a full
        // pull, which only happens once the local tables have been emptied, put it back.
        var sessions = await _context.ScheduledWorkouts
            .Where(sw => sw.WorkoutId == id)
            .Select(sw => new { sw.Id, HasLoggedSets = sw.Exercises.Any(e => e.Sets.Any()) })
            .ToListAsync();

        // A session with sets logged against it is real training history. There is no
        // RemovedAt on Workout to retire the workout behind, the way there is one level
        // down on WorkoutExercise, so the workout stays — and saying so plainly beats a
        // 500 the client retries until the end of time.
        if (sessions.Any(s => s.HasLoggedSets))
        {
            return WorkoutDeleteResult.HasLoggedHistory;
        }

        // Everything left is a placeholder — a date the plan generated, or one still in
        // the future, that nobody ever performed. Nothing is lost by dropping it, and
        // dropping it is what releases the foreign key.
        var emptySessionIds = sessions.Select(s => s.Id).ToList();
        if (emptySessionIds.Count > 0)
        {
            await _context.ScheduledWorkouts
                .Where(sw => emptySessionIds.Contains(sw.Id))
                .ExecuteDeleteAsync();

            // ExecuteDelete bypasses the change tracker, which would otherwise re-assert
            // these rows during the SaveChanges below.
            DetachTracked<ScheduledWorkout>(sw => emptySessionIds.Contains(sw.Id));
        }

        _context.Workouts.Remove(workout);
        await _context.SaveChangesAsync();
        return WorkoutDeleteResult.Deleted;
    }

    /// <inheritdoc/>
    public async Task<WorkoutExercise?> AddExerciseToWorkoutAsync(WorkoutExercise we, Guid userId)
    {
        var ownsWorkout = await _context.Workouts.AnyAsync(w => w.Id == we.WorkoutId && w.UserId == userId);
        if (!ownsWorkout) return null;

        // Adding an exercise is idempotent per slot. Every caller of this is a sync push,
        // and a push whose response was lost still committed here — so the client retried
        // with a row it thought had never arrived, and the workout grew a second copy of
        // the same exercise. Returning the row that already occupies the slot hands the
        // client the ID it was missing instead, which is what it needed all along.
        //
        // OrderPosition is part of the key because a workout may legitimately contain the
        // same movement more than once — a superset pairing it with itself — and those
        // instances are distinguishable only by position. Two entries sharing the exercise
        // *and* the slot are not. Retired entries are excluded: re-adding a movement the
        // user removed should give them a fresh row, not resurrect the old one.
        var existing = await _context.WorkoutExercises.FirstOrDefaultAsync(e =>
            e.WorkoutId == we.WorkoutId &&
            e.ExerciseId == we.ExerciseId &&
            e.OrderPosition == we.OrderPosition &&
            e.RemovedAt == null);
        if (existing != null) return existing;

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
        if (we.RemovedAt != null) return true;

        // Scheduling a workout stamps a ScheduledWorkoutExercise row per exercise, and
        // that row holds a restricted foreign key back here. Plainly removing the
        // exercise therefore failed with a foreign-key violation for any workout the
        // user had ever scheduled — the client's DELETE 500'd, the exercise stayed in
        // the workout server-side, and every session generated afterwards carried it
        // again as an entry nobody logged anything against.
        var scheduledEntries = await _context.ScheduledWorkoutExercises
            .Where(e => e.WorkoutExerciseId == weId)
            .Select(e => new { e.Id, HasLoggedSets = e.Sets.Any() })
            .ToListAsync();

        // Entries with nothing logged are placeholders for a session that was never
        // performed, or one still in the future. Nothing is lost by dropping them.
        var emptyEntryIds = scheduledEntries.Where(e => !e.HasLoggedSets).Select(e => e.Id).ToList();
        if (emptyEntryIds.Count > 0)
        {
            await _context.ScheduledWorkoutExercises
                .Where(e => emptyEntryIds.Contains(e.Id))
                .ExecuteDeleteAsync();

            // ExecuteDelete goes straight to the database and leaves the change tracker
            // believing those rows are still there. Anything already tracking one would
            // otherwise take part in the SaveChanges below and re-assert a row that no
            // longer exists.
            DetachTracked<ScheduledWorkoutExercise>(e => emptyEntryIds.Contains(e.Id));
        }

        if (scheduledEntries.Count == emptyEntryIds.Count)
        {
            // Nothing references the exercise any more, so it can go for good.
            _context.WorkoutExercises.Remove(we);
        }
        else
        {
            // Sets were logged against it in past sessions. Deleting the row would take
            // that history with it, so retire the exercise instead: it stops being part
            // of the workout, but stays resolvable for the sessions that used it.
            we.RemovedAt = DateTime.UtcNow;
        }

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
    public async Task<List<WorkoutSetTemplate>?> ReplaceSetTemplatesAsync(Guid workoutExerciseId, Guid userId, List<WorkoutSetTemplate> templates)
    {
        var ownsExercise = await _context.WorkoutExercises
            .AnyAsync(e => e.Id == workoutExerciseId && e.Workout.UserId == userId);
        if (!ownsExercise) return null;

        await _context.WorkoutSetTemplates
            .Where(t => t.WorkoutExerciseId == workoutExerciseId)
            .ExecuteDeleteAsync();
        DetachTracked<WorkoutSetTemplate>(t => t.WorkoutExerciseId == workoutExerciseId);

        _context.WorkoutSetTemplates.AddRange(templates);
        await _context.SaveChangesAsync();
        return templates;
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

    /// <summary>Drops the change tracker's copies of entities a bulk delete has already
    /// removed from the database, so a later SaveChanges doesn't act on them.</summary>
    private void DetachTracked<T>(Func<T, bool> match) where T : class
    {
        var stale = _context.ChangeTracker.Entries<T>()
            .Where(e => match(e.Entity))
            .ToList();
        foreach (var entry in stale) entry.State = EntityState.Detached;
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
