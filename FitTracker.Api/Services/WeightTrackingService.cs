using FitTracker.Api.DTOs;
using FitTracker.Api.Repositories.Interfaces;
using FitTracker.Api.Services.Interfaces;

namespace FitTracker.Api.Services;

/// <summary>Implementation of <see cref="IWeightTrackingService"/>.</summary>
public class WeightTrackingService : IWeightTrackingService
{
    private readonly IWeightTrackingRepository _weightRepository;
    private readonly ISyncTombstoneRepository _tombstones;

    /// <summary>Initialises a new instance of <see cref="WeightTrackingService"/>.</summary>
    /// <param name="tombstones">Which of the caller's ids were deleted.</param>
    /// <param name="weightTrackingRepository">The weight tracking repository.</param>
    public WeightTrackingService(IWeightTrackingRepository weightTrackingRepository, ISyncTombstoneRepository tombstones)
    {
        _weightRepository = weightTrackingRepository;
        _tombstones = tombstones;
    }

    /// <inheritdoc/>
    public async Task<WeightTrackingResponseDto> LogWeightAsync(WeightTrackingRequestDto weightTrackingRequestDto, Guid userId)
    {
        var result = await ClientIds.CreateOrResolveAsync(
            weightTrackingRequestDto.Id,
            userId,
            _weightRepository.GetOwnerAsync,
            id => _tombstones.WasDeletedAsync(userId, id),
            id => UpdateWeightAsync(id, userId, weightTrackingRequestDto),
            async id =>
            {
                var newLog = await _weightRepository.CreateWeightTrackingAsync(new Models.WeightTracking
                {
                    Id = id,
                    Weight = weightTrackingRequestDto.Weight,
                    Date = DateTime.SpecifyKind(weightTrackingRequestDto.Date, DateTimeKind.Utc),
                    Note = weightTrackingRequestDto.Note,
                    UserId = userId,
                });
                return new WeightTrackingResponseDto
                {
                    Id = newLog.Id,
                    Weight = newLog.Weight,
                    Date = newLog.Date,
                    Note = newLog.Note,
                };
            });
        return result!;
    }

    /// <inheritdoc/>
    public async Task<List<WeightTrackingResponseDto>?> GetWeightLogs(Guid userId, DateTime? changedSince = null)
    {
        if (Guid.Empty == userId)
        {
            return null;
        }

        var weightLogs = await _weightRepository.GetWeightTrackingsAsync(userId, changedSince);

        return weightLogs.Select(w => new WeightTrackingResponseDto
        {
            Id = w.Id,
            Date = w.Date,
            Weight = w.Weight,
            Note = w.Note
        }).ToList();
    }

    /// <inheritdoc/>
    public async Task<List<WeightTrackingResponseDto>?> GetWeightLogsSince(Guid userId, DateTime from)
    {
        if (Guid.Empty == userId)
        {
            return null;
        }

        var weightLogs = await _weightRepository.GetWeightTrackingsSinceAsync(userId, from);

        return weightLogs.Select(w => new WeightTrackingResponseDto
        {
            Id = w.Id,
            Date = w.Date,
            Weight = w.Weight,
            Note = w.Note
        }).ToList();
    }

    /// <inheritdoc/>
    public async Task<WeightTrackingResponseDto?> UpdateWeightAsync(Guid id, Guid userId, WeightTrackingRequestDto weightTrackingRequestDto)
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
            return null;
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