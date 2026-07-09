using FitTracker.Api.DTOs;
using FitTracker.Api.Repositories.Interfaces;
using FitTracker.Api.Services.Interfaces;

namespace FitTracker.Api.Services;

/// <summary>Implementation of <see cref="IWeightTrackingService"/>.</summary>
public class WeightTrackingService : IWeightTrackingService
{
    private readonly IWeightTrackingRepository _weightRepository;

    /// <summary>Initialises a new instance of <see cref="WeightTrackingService"/>.</summary>
    /// <param name="weightTrackingRepository">The weight tracking repository.</param>
    public WeightTrackingService(IWeightTrackingRepository weightTrackingRepository)
    {
        _weightRepository = weightTrackingRepository;
    }

    /// <inheritdoc/>
    public async Task<WeightTrackingResponseDto> LogWeightAsync(WeightTrackingRequestDto weightTrackingRequestDto, Guid userId)
    {
        var weightLog = new Models.WeightTracking
        {
            Id = Guid.NewGuid(),
            Weight = weightTrackingRequestDto.Weight,
            Date = DateTime.SpecifyKind(weightTrackingRequestDto.Date, DateTimeKind.Utc),
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

    /// <inheritdoc/>
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

    /// <inheritdoc/>
    public async Task<WeightTrackingResponseDto> UpdateWeightAsync(Guid id, Guid userId, WeightTrackingRequestDto weightTrackingRequestDto)
    {
        if (Guid.Empty == id)
        {
            return null;
        }

        if (Guid.Empty == userId)
        {
            return null;
        }

        var weightLog = await _weightRepository.UpdateWeightAsync(id, userId, weightTrackingRequestDto);

        if (weightLog == null)
        {
            return null!;
        }

        return new WeightTrackingResponseDto
        {
            Id = weightLog.Id,
            Weight = weightLog.Weight,
            Date = weightLog.Date,
            Note = weightLog.Note
        };
    }

    /// <inheritdoc/>
    public async Task<bool> DeleteWeightAsync(Guid id, Guid userId)
    {
        return await _weightRepository.DeleteWeightAsync(id, userId);
    }
}