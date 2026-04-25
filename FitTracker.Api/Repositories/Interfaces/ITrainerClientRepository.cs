using FitTracker.Api.Models;

namespace FitTracker.Api.Repositories.Interfaces;

public interface ITrainerClientRepository
{
    Task<TrainerClient> CreateInviteAsync(Guid trainerId);
    Task<TrainerClient?> AcceptInviteAsync(string inviteCode, Guid clientId);
    Task<List<TrainerClient>> GetClientsAsync(Guid trainerId);
    Task<TrainerClient?> GetActiveRelationshipForClientAsync(Guid clientId);
    Task<bool> RemoveRelationshipAsync(Guid relationshipId, Guid requestingUserId);
}
