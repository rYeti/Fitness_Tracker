using FitTracker.Api.Models;

namespace FitTracker.Api.Repositories.Interfaces;

/// <summary>Data-access contract for meal template management.</summary>
public interface IMealTemplateRepository
{
    /// <summary>Returns all meal templates for the specified user.</summary>
    Task<List<MealTemplate>> GetAllAsync(Guid userId);

    /// <summary>Returns a single meal template by ID, scoped to the specified user.</summary>
    Task<MealTemplate?> GetByIdAsync(Guid id, Guid userId);

    /// <summary>Creates a new meal template including its items.</summary>
    Task<MealTemplate> CreateAsync(MealTemplate template);

    /// <summary>Replaces the items of an existing template and updates its header fields. Returns null if not found.</summary>
    Task<MealTemplate?> UpdateAsync(Guid id, Guid userId, MealTemplate template);

    /// <summary>Deletes a meal template and all its items. Returns false if not found.</summary>
    Task<bool> DeleteAsync(Guid id, Guid userId);
}
