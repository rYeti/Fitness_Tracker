using FitTracker.Api.DTOs;
using FitTracker.Api.Models;
using FitTracker.Api.Repositories.Interfaces;
using FitTracker.Api.Services.Interfaces;

namespace FitTracker.Api.Services;

public class TrainerClientService(ITrainerClientRepository repo) : ITrainerClientService
{
    private readonly ITrainerClientRepository _repo = repo;

    /// <inheritdoc/>
    public async Task<TrainerClientResponseDto> CreateInviteAsync(Guid trainerId)
    {
        var invite = await _repo.CreateInviteAsync(trainerId);
        return ToDto(invite);
    }

    /// <inheritdoc/>
    public async Task<TrainerClientResponseDto?> AcceptInviteAsync(string inviteCode, Guid clientId)
    {
        var rel = await _repo.AcceptInviteAsync(inviteCode, clientId);
        return rel == null ? null : ToDto(rel);
    }

    public async Task<List<TrainerClientResponseDto>> GetClientsAsync(Guid trainerId)
    {
        var clients = await _repo.GetClientsAsync(trainerId);
        return [.. clients.Select(ToDto)];
    }

    /// <inheritdoc/>
    public async Task<TrainerClientStatusDto> GetStatusAsync(Guid userId)
    {
        var asClient = await _repo.GetActiveRelationshipForClientAsync(userId);
        var asTrainer = await _repo.GetClientsAsync(userId);

        return new TrainerClientStatusDto
        {
            IsTrainerClient = asClient != null,
            IsTrainer = asTrainer.Count > 0,
            TrainerName = asClient != null
                ? $"{asClient.Trainer.FirstName} {asClient.Trainer.LastName}".Trim()
                : null,
            TrainerId = asClient?.TrainerId,
        };
    }

    /// <inheritdoc/>
    public async Task<bool> IsActiveTrainerOfAsync(Guid trainerId, Guid clientId) =>
        await _repo.IsActiveTrainerOfAsync(trainerId, clientId);

    /// <inheritdoc/>
    public async Task<bool> RemoveRelationshipAsync(Guid relationshipId, Guid requestingUserId) =>
        await _repo.RemoveRelationshipAsync(relationshipId, requestingUserId);

    /// <inheritdoc/>
    private static TrainerClientResponseDto ToDto(TrainerClient t) => new()
    {
        Id = t.Id,
        TrainerId = t.TrainerId,
        TrainerName = t.Trainer != null
            ? $"{t.Trainer.FirstName} {t.Trainer.LastName}".Trim()
            : string.Empty,
        ClientId = t.ClientId ?? Guid.Empty,
        ClientName = t.Client != null
            ? $"{t.Client.FirstName} {t.Client.LastName}".Trim()
            : string.Empty,
        Status = t.Status.ToString(),
        InviteCode = t.InviteCode,
        CreatedAt = t.CreatedAt,
        AcceptedAt = t.AcceptedAt,
    };
}
