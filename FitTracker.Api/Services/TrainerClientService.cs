using FitTracker.Api.DTOs;
using FitTracker.Api.Models;
using FitTracker.Api.Nutrition;
using FitTracker.Api.Repositories.Interfaces;
using FitTracker.Api.Services.Interfaces;

namespace FitTracker.Api.Services;

public class TrainerClientService(
    ITrainerClientRepository repo,
    ITrainerLicenceRepository licences,
    ITrainerNutrientPinRepository nutrientPins,
    IUserNutrientPinRepository userNutrientPins,
    IRevenueCatSubscriptionRepository revenueCat) : ITrainerClientService
{
    private readonly ITrainerClientRepository _repo = repo;
    private readonly ITrainerLicenceRepository _licences = licences;
    private readonly ITrainerNutrientPinRepository _nutrientPins = nutrientPins;
    private readonly IUserNutrientPinRepository _userNutrientPins = userNutrientPins;
    private readonly IRevenueCatSubscriptionRepository _revenueCat = revenueCat;

    /// <inheritdoc/>
    public async Task<CreateInviteOutcome> CreateInviteAsync(Guid trainerId)
    {
        var result = await _repo.CreateInviteAsync(trainerId);
        return new CreateInviteOutcome
        {
            Status = result.Status,
            Invite = result.Invite == null ? null : ToDto(result.Invite),
            SeatsUsed = result.SeatsUsed,
            SeatLimit = result.SeatLimit,
        };
    }

    /// <inheritdoc/>
    public async Task<AcceptInviteOutcome> AcceptInviteAsync(string inviteCode, Guid clientId)
    {
        var result = await _repo.AcceptInviteAsync(inviteCode, clientId);
        return new AcceptInviteOutcome
        {
            Status = result.Status,
            Relationship = result.Relationship == null ? null : ToDto(result.Relationship),
        };
    }

    /// <inheritdoc/>
    public Task<bool> RevokeInviteAsync(Guid inviteId, Guid trainerId) =>
        _repo.RevokeInviteAsync(inviteId, trainerId);

    /// <inheritdoc/>
    public async Task<List<PendingInviteDto>> GetPendingInvitesAsync(Guid trainerId)
    {
        var invites = await _repo.GetPendingInvitesAsync(trainerId);
        return [.. invites.Select(i => new PendingInviteDto
        {
            Id = i.Id,
            InviteCode = i.InviteCode,
            CreatedAt = i.CreatedAt,
            ExpiresAt = i.ExpiresAt,
        })];
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
        var ownLicence = await _licences.GetByTrainerAsync(userId);

        // Pro flows from a *paid, current* licence and nothing else — either the
        // caller's own, or that of the trainer they belong to. The relationship
        // alone grants nothing, which is the whole point: an invite code is free
        // to mint, so if redeeming one granted Pro, Pro would be free.
        var trainersLicence = asClient == null
            ? null
            : await _licences.GetByTrainerAsync(asClient.TrainerId);

        var proFromTrainer = trainersLicence?.GrantsPro ?? false;
        var proFromOwn = ownLicence?.GrantsPro ?? false;

        return new TrainerClientStatusDto
        {
            IsTrainerClient = asClient != null,

            // Licence-based, not roster-based. A trainer who has just signed up
            // has no clients yet and still needs the console to invite their
            // first one.
            IsTrainer = ownLicence != null,

            TrainerName = asClient != null
                ? $"{asClient.Trainer.FirstName} {asClient.Trainer.LastName}".Trim()
                : null,
            TrainerId = asClient?.TrainerId,

            ProFromLicence = proFromTrainer || proFromOwn,
            ProEndsAt = ProExpiryFor(trainersLicence, ownLicence),

            Licence = ownLicence == null
                ? null
                : TrainerLicenceDto.From(
                    ownLicence, await _repo.CountSeatsUsedAsync(userId)),
        };
    }

    /// <summary>When the caller's derived Pro runs out, if it is running out.
    ///
    /// Only meaningful while a licence is in its grace window: that's the period
    /// where Pro still works but is about to stop, and the trainee needs warning
    /// before a feature silently locks. Their own licence takes precedence,
    /// since it survives their trainer's.</summary>
    private static DateTime? ProExpiryFor(TrainerLicence? trainersLicence, TrainerLicence? ownLicence)
    {
        if (ownLicence?.GrantsPro == true) return ownLicence.GraceEndsAt;
        if (trainersLicence?.GrantsPro == true) return trainersLicence.GraceEndsAt;
        return null;
    }

    /// <inheritdoc/>
    public async Task<bool> IsActiveTrainerOfAsync(Guid trainerId, Guid clientId) =>
        await _repo.IsActiveTrainerOfAsync(trainerId, clientId);

    /// <inheritdoc/>
    public async Task<bool> RemoveRelationshipAsync(Guid relationshipId, Guid requestingUserId) =>
        await _repo.RemoveRelationshipAsync(relationshipId, requestingUserId);

    public async Task<TrainerClient?> GetActiveRelationshipAsync(Guid trainerId, Guid clientId)
    {
        return await _repo.GetActiveRelationshipAsync(trainerId, clientId);
    }

    /// <inheritdoc/>
    public async Task<(Guid trainerId, Guid clientId, bool ok)> ResolvePairAsync(Guid callerId, Guid otherPartyId)
    {
        if (await IsActiveTrainerOfAsync(callerId, otherPartyId))
            return (callerId, otherPartyId, true);

        // caller might be the client, not the trainer — swap and re-check
        if (await IsActiveTrainerOfAsync(otherPartyId, callerId))
            return (otherPartyId, callerId, true);

        return (default, default, false);
    }

    /// <inheritdoc/>
    public async Task<bool> DerivesProAsync(Guid userId)
    {
        var asClient = await _repo.GetActiveRelationshipForClientAsync(userId);
        var ownLicence = await _licences.GetByTrainerAsync(userId);
        var trainersLicence = asClient == null
            ? null
            : await _licences.GetByTrainerAsync(asClient.TrainerId);

        return (ownLicence?.GrantsPro ?? false) || (trainersLicence?.GrantsPro ?? false);
    }

    /// <inheritdoc/>
    public async Task<List<string>> GetMyNutrientPinsAsync(Guid userId)
    {
        var asClient = await _repo.GetActiveRelationshipForClientAsync(userId);
        if (asClient != null)
        {
            var trainerPins = await _nutrientPins.GetPinsAsync(asClient.TrainerId, userId);
            return trainerPins.Count == 0 ? [.. NutrientKeys.Defaults] : trainerPins;
        }

        if (await _revenueCat.IsEntitledAsync(userId))
        {
            var ownPins = await _userNutrientPins.GetPinsAsync(userId);
            return ownPins.Count == 0 ? [.. NutrientKeys.Defaults] : ownPins;
        }

        return [.. NutrientKeys.Defaults];
    }

    /// <inheritdoc/>
    public async Task<SetMyNutrientPinsResult> SetMyNutrientPinsAsync(Guid userId, List<string> nutrientKeys)
    {
        var asClient = await _repo.GetActiveRelationshipForClientAsync(userId);
        if (asClient != null)
        {
            return new SetMyNutrientPinsResult { Status = SetMyNutrientPinsStatus.HasActiveTrainer };
        }

        if (!await _revenueCat.IsEntitledAsync(userId))
        {
            return new SetMyNutrientPinsResult { Status = SetMyNutrientPinsStatus.NotEntitled };
        }

        if (nutrientKeys.Any(key => !NutrientKeys.IsValid(key)))
        {
            return new SetMyNutrientPinsResult { Status = SetMyNutrientPinsStatus.InvalidNutrientKey };
        }

        await _userNutrientPins.ReplacePinsAsync(userId, nutrientKeys);
        return new SetMyNutrientPinsResult
        {
            Status = SetMyNutrientPinsStatus.Ok,
            PinnedNutrients = nutrientKeys,
        };
    }

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
