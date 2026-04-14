using FitTracker.Api.DTOs;
using FitTracker.Api.Repositories.Interfaces;
using FitTracker.Api.Services.Interfaces;

namespace FitTracker.Api.Services;

public class WeightTrackingService : IWeightTrackingService
{
    private readonly IWeightTrackingRepository _weightRepository;

    public WeightTrackingService(IWeightTrackingRepository weightTrackingRepository)
    {
        _weightRepository = weightTrackingRepository;
    }

    public async Task<WeightTrackingResponseDto> LogWeightAsync(WeightTrackingRequestDto weightTrackingRequestDto, Guid userId)
    {
        var weightLog = new Models.WeightTracking
        {
            Id = Guid.NewGuid(),
            Weight = weightTrackingRequestDto.Weight,
            Date = weightTrackingRequestDto.Date,
            Note = weightTrackingRequestDto.Note,
            UserId = userId,
        };

        var newLog = await _weightRepository.CreateWeightTrackingAsync(weightLog);

        return new WeightTrackingResponseDto
        {
            Id = newLog.Id,
            Weight = newLog.Weight,
            Date = newLog.Date,
            Note = newLog.Note,
        };
    }

    public async Task<List<WeightTrackingResponseDto>> GetWeightLogs(Guid userId)
    {
        if (Guid.Empty == userId)
        {
            return null;
        }

        var weightLogs = await _weightRepository.GetWeightTrackingsAsync(userId);

        return weightLogs.Select(w => new WeightTrackingResponseDto
        {
            Id = w.Id,
            Date = w.Date,
            Weight = w.Weight,
            Note = w.Note
        }).ToList();
    }

    public async Task<WeightTrackingResponseDto> GetWeightLog(Guid userId)
    {
        if (Guid.Empty == userId)
        {
            return null;
        }

        var weightLog = await _weightRepository.GetWeightTrackingByIdAsync(userId);

        return new WeightTrackingResponseDto
        {
            Id = weightLog.Id,
            Weight = weightLog.Weight,
            Date = weightLog.Date,
            Note = weightLog.Note
        };
    }
}