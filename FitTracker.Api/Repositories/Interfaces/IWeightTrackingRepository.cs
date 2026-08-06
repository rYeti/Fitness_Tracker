using FitTracker.Api.DTOs;
using FitTracker.Api.Models;

namespace FitTracker.Api.Repositories.Interfaces;

/// <summary>Data-access contract for weight tracking entries.</summary>
public interface IWeightTrackingRepository
{
    /// <summary>Returns a single weight tracking entry by its ID.</summary>
    /// <param name="id">The ID of the entry to retrieve.</param>
    /// <returns>The matching <see cref="WeightTracking"/>, or <c>null</c> if not found.</returns>
    Task<WeightTracking?> GetWeightTrackingByIdAsync(Guid id);

    /// <summary>Returns all weight tracking entries belonging to the specified user.</summary>
    /// <param name="id">The user's ID.</param>
    Task<List<WeightTracking>> GetWeightTrackingsAsync(Guid id);

    /// <summary>Persists a new weight tracking entry.</summary>
    /// <param name="weightTracking">The entry to create.</param>
    /// <returns>The newly created entry.</returns>
    Task<WeightTracking> CreateWeightTrackingAsync(WeightTracking weightTracking);

    /// <summary>Updates the date, weight, and note of an existing entry.</summary>
    /// <param name="id">The ID of the entry to update.</param>
    /// <param name="userId">The ID of the user who owns the entry.</param>
    /// <param name="dto">The updated values.</param>
    /// <returns>The updated entry, or <c>null</c> if not found.</returns>
    Task<WeightTracking?> UpdateWeightAsync(Guid id, Guid userId, WeightTrackingRequestDto dto);

    /// <summary>Deletes a weight tracking entry owned by the specified user.</summary>
    /// <param name="id">The ID of the entry to delete.</param>
    /// <param name="userId">The ID of the user who owns the entry.</param>
    /// <returns><c>true</c> if deleted; <c>false</c> if not found.</returns>
    Task<bool> DeleteWeightAsync(Guid id, Guid userId);
}