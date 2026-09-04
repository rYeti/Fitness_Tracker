namespace FitTracker.Api.Models;

/// <summary>
/// Outcome of deleting a workout.
/// </summary>
/// <remarks>
/// Deleting a workout is not always possible. <c>ScheduledWorkouts</c> holds a
/// restricted foreign key back to <c>Workouts</c> (see <c>AppDbContext</c>), which
/// exists so that dropping a workout can never silently erase the sessions the user
/// trained against it. A plain <c>Remove</c> therefore threw a foreign-key violation
/// for any workout that had ever been scheduled — surfaced to the client as a 500,
/// retried forever, and the workout stayed on the server after the app had already
/// removed it locally.
///
/// A boolean cannot express that: "not deleted" had to mean both "no such workout"
/// and "this one has history and never can be", and only the first of those is a 404.
/// </remarks>
public enum WorkoutDeleteResult
{
    /// <summary>No workout with that ID belongs to the caller.</summary>
    NotFound,

    /// <summary>The workout, and any never-performed sessions of it, are gone.</summary>
    Deleted,

    /// <summary>
    /// The workout has sessions with logged sets. It is kept so that history stays
    /// resolvable; the caller should stop retrying rather than treat this as failure.
    /// </summary>
    HasLoggedHistory,

    /// <summary>The workout was assigned by a trainer (<c>Workout.AssignedByTrainerId</c>)
    /// and the caller is its owner, not the assigning trainer — only the trainer can remove
    /// their own prescription. Distinct from <see cref="HasLoggedHistory"/>: this is a
    /// permission the owner never had, not a row the server is protecting on their behalf.</summary>
    AssignedByTrainer,
}
