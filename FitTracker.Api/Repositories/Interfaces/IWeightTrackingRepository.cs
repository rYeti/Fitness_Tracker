using FitTracker.Api.Models;

namespace FitTracker.Api.Repositories.Interfaces;

public interface IWeightTrackingRepository
{
    /// <summary>
    /// Retrieves a weight tracking entry by its unique identifier (ID).
    /// </summary>
    /// <param name="id"></param>
    /// <returns>WeightTracking</returns>
    Task<WeightTracking?> GetWeightTrackingByIdAsync(Guid id);

    /// <summary>
    /// Retrieves a list of weight tracking entries for a specific user by their unique identifier (ID).
    /// </summary>
    /// <param name="id"></param>
    /// <returns>List<WeightTracking></returns>
    Task<List<WeightTracking>> GetWeightTrackingsAsync(Guid id);
    /// <summary>
    /// Creates a new weight tracking entry in the database.
    /// </summary>
    /// <param name="weightTracking"></param>
    Task<WeightTracking?> CreateWeightTrackingAsync(WeightTracking weightTracking);


}