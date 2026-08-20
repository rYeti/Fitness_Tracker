using FitTracker.Api.Models;

namespace FitTracker.Api.Repositories.Interfaces;

public interface ITrainerClientRepository
{
    /// <summary>Counts the seats this trainer occupies: active clients plus
    /// invites that are still redeemable.</summary>
    Task<int> CountSeatsUsedAsync(Guid trainerId);

    /// <summary>Creates a pending relationship row with a fresh invite code for the
    /// trainer, if their plan has a free seat.</summary>
    Task<CreateInviteResult> CreateInviteAsync(Guid trainerId);

    /// <summary>Looks up the pending relationship by invite code and activates it
    /// for the accepting client. The seat limit is re-checked here, not trusted
    /// from when the code was minted.</summary>
    Task<AcceptInviteResult> AcceptInviteAsync(string inviteCode, Guid clientId);

    /// <summary>Withdraws an unredeemed invite, freeing its seat.</summary>
    Task<bool> RevokeInviteAsync(Guid inviteId, Guid trainerId);

    /// <summary>Returns the trainer's outstanding, still-redeemable invites.</summary>
    Task<List<TrainerClient>> GetPendingInvitesAsync(Guid trainerId);

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
