using FitTracker.Api.DTOs;
using FitTracker.Api.Models;
using FitTracker.Api.Nutrition;

namespace FitTracker.Api.Services.Interfaces;

public interface ITrainerClientService
{
    /// <summary>Generates a new invite code a trainer can share with a prospective
    /// client, if their plan has a free seat.</summary>
    Task<CreateInviteOutcome> CreateInviteAsync(Guid trainerId);

    /// <summary>Redeems an invite code, linking the client to the trainer who
    /// created it. The outcome distinguishes an unknown code from an expired one
    /// and from a trainer who has run out of seats.</summary>
    Task<AcceptInviteOutcome> AcceptInviteAsync(string inviteCode, Guid clientId);

    /// <summary>Withdraws an unredeemed invite, freeing its seat.</summary>
    Task<bool> RevokeInviteAsync(Guid inviteId, Guid trainerId);

    /// <summary>The trainer's outstanding, still-redeemable invites.</summary>
    Task<List<PendingInviteDto>> GetPendingInvitesAsync(Guid trainerId);

    /// <summary>Returns all clients (any relationship status) linked to the given trainer.</summary>
    Task<List<TrainerClientResponseDto>> GetClientsAsync(Guid trainerId);

    /// <summary>Returns the trainer/client relationship status for a given user,
    /// including where their premium access comes from.</summary>
    Task<TrainerClientStatusDto> GetStatusAsync(Guid userId);

    /// <summary>Ends a trainer/client relationship. Requires the requesting user to be a party to it.</summary>
    Task<bool> RemoveRelationshipAsync(Guid relationshipId, Guid requestingUserId);

    /// <summary>Gates every Trainer Console read/write — a trainer may only
    /// access a client's data while that relationship is Active.</summary>
    Task<bool> IsActiveTrainerOfAsync(Guid trainerId, Guid clientId);

    Task<TrainerClient?> GetActiveRelationshipAsync(Guid trainerId, Guid clientId);

    /// <summary>Whether this user's premium is licence-derived Pro: either
    /// their own trainer licence, or their trainer's — the same rule
    /// <see cref="GetStatusAsync"/> computes as <c>ProFromLicence</c>, exposed
    /// as a plain bool for callers (micronutrient entitlement) that only need
    /// the yes/no and not the rest of the status payload.
    ///
    /// Deliberately does not know about device-side IAP premium
    /// (<c>AccessProvider._isPremium</c> on the client) — that state is never
    /// visible to the server. See docs/trainer-console-micronutrients.md.</summary>
    Task<bool> DerivesProAsync(Guid userId);

    /// <summary>The nutrient keys this user's trainer has pinned for them —
    /// read-only on the trainee side. Returns <see cref="Nutrition.NutrientKeys.Defaults"/>
    /// for a user with no active trainer, or whose trainer never chose.</summary>
    Task<List<string>> GetMyNutrientPinsAsync(Guid userId);
}
