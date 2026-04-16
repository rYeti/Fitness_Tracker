using FitTracker.Api.DTOs;

namespace FitTracker.Api.Services.Interfaces;


public interface IWeightTrackingService
{
    /// <summary>
    /// 
    /// </summary>
    /// <param name="weightTrackingRequestDto"></param>
    /// <param name="userId"></param>
    /// <returns></returns>
    Task<WeightTrackingResponseDto> LogWeightAsync(WeightTrackingRequestDto weightTrackingRequestDto, Guid userId);

    /// <summary>
    /// 
    /// </summary>
    /// <param name="weightTrackingResponseDto"></param>
    /// <param name="userId"></param>
    /// <returns></returns>
    Task<List<WeightTrackingResponseDto>> GetWeightLogs(Guid userId);

    /// <summary>
    /// 
    /// </summary>
    /// <param name="id"></param>
    /// <param name="userId"></param>
    /// <param name="weightTrackingRequestDto"></param>
    /// <returns></returns>
    Task<WeightTrackingResponseDto> UpdateWeightAsync(Guid id, Guid userId, WeightTrackingRequestDto weightTrackingRequestDto);

    /// <summary>
    /// 
    /// </summary>
    /// <param name="id"></param>
    /// <param name="userId"></param>
    /// <returns></returns>
    Task<bool> DeleteWeightAsync(Guid id, Guid userId);
}