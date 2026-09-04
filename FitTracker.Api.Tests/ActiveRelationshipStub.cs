using FitTracker.Api.DTOs;
using FitTracker.Api.Models;
using FitTracker.Api.Services.Interfaces;

namespace FitTracker.Api.Tests;

/// <summary>Stands in for the relationship gate, which the console tests using it are
/// not about — it is covered by TrainerClientServiceTests.</summary>
internal sealed class ActiveRelationshipStub(Guid expectedTrainer, Guid expectedClient, bool grantsPro = true)
    : ITrainerClientService
{
    public Task<bool> IsActiveTrainerOfAsync(Guid trainer, Guid client) =>
        Task.FromResult(trainer == expectedTrainer && client == expectedClient);

    /// <summary>Defaults to true so every existing nutrition test — none of which
    /// is about entitlement — keeps seeing an unlocked summary. Tests of the
    /// lock itself pass <c>grantsPro: false</c> explicitly.</summary>
    public Task<bool> DerivesProAsync(Guid userId) => Task.FromResult(grantsPro);

    public Task<List<string>> GetMyNutrientPinsAsync(Guid userId) => throw new NotSupportedException();

    public Task<List<TrainerClientResponseDto>> GetClientsAsync(Guid trainer)
    {
        var clients = new List<TrainerClientResponseDto>();
        if (trainer == expectedTrainer)
        {
            clients.Add(new TrainerClientResponseDto { ClientId = expectedClient });
        }
        return Task.FromResult(clients);
    }

    public Task<CreateInviteOutcome> CreateInviteAsync(Guid trainerId) => throw new NotSupportedException();
    public Task<AcceptInviteOutcome> AcceptInviteAsync(string inviteCode, Guid clientId) => throw new NotSupportedException();
    public Task<bool> RevokeInviteAsync(Guid inviteId, Guid trainerId) => throw new NotSupportedException();
    public Task<List<PendingInviteDto>> GetPendingInvitesAsync(Guid trainerId) => throw new NotSupportedException();
    public Task<TrainerClientStatusDto> GetStatusAsync(Guid userId) => throw new NotSupportedException();
    public Task<bool> RemoveRelationshipAsync(Guid relationshipId, Guid requestingUserId) => throw new NotSupportedException();
    public Task<TrainerClient?> GetActiveRelationshipAsync(Guid trainerId, Guid clientId) => throw new NotSupportedException();

    public async Task<(Guid trainerId, Guid clientId, bool ok)> ResolvePairAsync(Guid callerId, Guid otherPartyId)
    {
        if (await IsActiveTrainerOfAsync(callerId, otherPartyId))
            return (callerId, otherPartyId, true);

        if (await IsActiveTrainerOfAsync(otherPartyId, callerId))
            return (otherPartyId, callerId, true);

        return (default, default, false);
    }
}
