using FitTracker.Api.Models;

namespace FitTracker.Api.Repositories.Interfaces;

public interface ITrainerClientRepository
{
    /// <summary>Creates a pending relationship row with a fresh invite code for the trainer.</summary>
    Task<TrainerClient> CreateInviteAsync(Guid trainerId);

    /// <summary>Looks up the pending relationship by invite code and activates it for the accepting client. Returns null if the code doesn't match a pending invite.</summary>
    Task<TrainerClient?> AcceptInviteAsync(string inviteCode, Guid clientId);

    /// <summary>Returns all relationships (any status) for the given trainer.</summary>
    Task<List<TrainerClient>> GetClientsAsync(Guid trainerId);

    /// <summary>Returns the client's current Active relationship, if any.</summary>
    Task<TrainerClient?> GetActiveRelationshipForClientAsync(Guid clientId);

    /// <summary>Ends a relationship. Requires the requesting user to be a party to it.</summary>
    Task<bool> RemoveRelationshipAsync(Guid relationshipId, Guid requestingUserId);

    /// <summary>Checks whether an Active relationship exists between this trainer and client.</summary>
    Task<bool> IsActiveTrainerOfAsync(Guid trainerId, Guid clientId);

    Task<TrainerClient?> GetActiveRelationshipAsync(Guid treinerId, Guid clientId);
}
