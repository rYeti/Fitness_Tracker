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

    /// <summary>Works out which side of an Active relationship the caller is on.
    /// <paramref name="callerId"/> and <paramref name="otherPartyId"/> could be
    /// (trainer, client) or (client, trainer) — the caller doesn't know which,
    /// which is why chat's controller, hub and REST history endpoint all needed
    /// this exact check and used to each carry their own copy of it.</summary>
    Task<(Guid trainerId, Guid clientId, bool ok)> ResolvePairAsync(Guid callerId, Guid otherPartyId);

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

    /// <summary>The nutrient keys this user tracks. A linked client's trainer
    /// picks for them (read-only on the trainee side); an unlinked user with
    /// their own RevenueCat entitlement picks their own via
    /// <see cref="SetMyNutrientPinsAsync"/>. Returns
    /// <see cref="Nutrition.NutrientKeys.Defaults"/> for anyone else — no
    /// trainer and not entitled, or a trainer/entitled user who's never
    /// chosen.</summary>
    Task<List<string>> GetMyNutrientPinsAsync(Guid userId);

    /// <summary>Replaces the caller's own pinned-nutrients selection. Only
    /// for a user with no active trainer who holds the RevenueCat
    /// entitlement — a linked client's pins are their trainer's to set; see
    /// <see cref="SetMyNutrientPinsStatus"/> for the refusal reasons.</summary>
    Task<SetMyNutrientPinsResult> SetMyNutrientPinsAsync(Guid userId, List<string> nutrientKeys);
}
