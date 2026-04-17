using FitTracker.Api.DTOs;

namespace FitTracker.Api.Services.Interfaces;


/// <summary>Business-logic contract for weight tracking operations.</summary>
public interface IWeightTrackingService
{
    /// <summary>Records a new weight entry for the specified user.</summary>
    /// <param name="weightTrackingRequestDto">The weight data to log.</param>
    /// <param name="userId">The ID of the user logging the weight.</param>
    /// <returns>The newly created weight entry.</returns>
    Task<WeightTrackingResponseDto> LogWeightAsync(WeightTrackingRequestDto weightTrackingRequestDto, Guid userId);

    /// <summary>Returns all weight entries belonging to the specified user.</summary>
    /// <param name="userId">The user's ID.</param>
    Task<List<WeightTrackingResponseDto>> GetWeightLogs(Guid userId);

    /// <summary>Updates an existing weight entry owned by the specified user.</summary>
    /// <param name="id">The ID of the entry to update.</param>
    /// <param name="userId">The ID of the user who owns the entry.</param>
    /// <param name="weightTrackingRequestDto">The updated weight data.</param>
    /// <returns>The updated entry, or <c>null</c> if not found.</returns>
    Task<WeightTrackingResponseDto> UpdateWeightAsync(Guid id, Guid userId, WeightTrackingRequestDto weightTrackingRequestDto);

    /// <summary>Deletes a weight entry owned by the specified user.</summary>
    /// <param name="id">The ID of the entry to delete.</param>
    /// <param name="userId">The ID of the user who owns the entry.</param>
    /// <returns><c>true</c> if deleted; <c>false</c> if not found.</returns>
    Task<bool> DeleteWeightAsync(Guid id, Guid userId);
}