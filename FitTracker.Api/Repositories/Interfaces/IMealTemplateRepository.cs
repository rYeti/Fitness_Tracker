using FitTracker.Api.Models;

namespace FitTracker.Api.Repositories.Interfaces;

/// <summary>Data-access contract for meal template management.</summary>
public interface IMealTemplateRepository : IDeletedIdLookup
{
    /// <summary>Returns all meal templates for the specified user.</summary>
    /// <param name="changedSince">Only those whose aggregate changed at or after this instant, for the sync
    /// changes feed (docs/sync-architecture.md, part three); all of them when null.</param>
    Task<List<MealTemplate>> GetAllAsync(Guid userId, DateTime? changedSince = null);

    /// <summary>Returns a single meal template by ID, scoped to the specified user.</summary>
    Task<MealTemplate?> GetByIdAsync(Guid id, Guid userId);

    /// <summary>Creates a new meal template including its items.</summary>
    Task<MealTemplate> CreateAsync(MealTemplate template);

    /// <summary>Who owns the meal template stored under <paramref name="id"/>, or null when there is
    /// none. Lets a create tell a repeat of its own id from someone else's (see
    /// <c>ClientIds</c>).</summary>
    Task<Guid?> GetOwnerAsync(Guid id);

    /// <summary>Replaces the items of an existing template and updates its header fields. Returns null if not found.</summary>
    Task<MealTemplate?> UpdateAsync(Guid id, Guid userId, MealTemplate template);

    /// <summary>Deletes a meal template and all its items. Returns false if not found.</summary>
    Task<bool> DeleteAsync(Guid id, Guid userId);
}
