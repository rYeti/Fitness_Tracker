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
    /// <param name="weightTrackingResponseDto"></param>
    /// <param name="userId"></param>
    /// <returns></returns>
    Task<WeightTrackingResponseDto> GetWeightLog(Guid userId);
}