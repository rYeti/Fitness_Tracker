using System.Security.Cryptography;
using FitTracker.Api.Data;
using FitTracker.Api.Models;
using FitTracker.Api.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace FitTracker.Api.Repositories;

/// <summary>Data access for trainer-client invite/accept/removal and roster queries.</summary>
public class TrainerClientRepository(AppDbContext context) : ITrainerClientRepository
{
    private readonly AppDbContext _context = context;

    /// <summary>Counts the seats a trainer is currently occupying: active
    /// clients plus invites that are still redeemable.
    ///
    /// Outstanding invites count because otherwise a trainer could mint any
    /// number of codes while under the limit and blow straight past it when
    /// they were all redeemed.</summary>
    public async Task<int> CountSeatsUsedAsync(Guid trainerId) =>
        await _context.TrainerClients.CountAsync(t =>
            t.TrainerId == trainerId &&
            (t.Status == TrainerClientStatus.Active ||
             (t.Status == TrainerClientStatus.Pending && t.ExpiresAt > DateTime.UtcNow)));

    /// <summary>Creates a pending invite for the given trainer, valid for 7 days,
    /// provided they have a free seat.</summary>
    public async Task<CreateInviteResult> CreateInviteAsync(Guid trainerId)
    {
        var licence = await _context.TrainerLicences
            .FirstOrDefaultAsync(l => l.TrainerId == trainerId);
        if (licence == null)
        {
            return new CreateInviteResult(CreateInviteStatus.NoLicence, null, 0, 0);
        }

        if (!licence.IsEntitled)
        {
            return new CreateInviteResult(
                CreateInviteStatus.NotEntitled, null, 0, licence.SeatLimit);
        }

        var seatsUsed = await CountSeatsUsedAsync(trainerId);
        if (seatsUsed >= licence.SeatLimit)
        {
            return new CreateInviteResult(
                CreateInviteStatus.SeatLimitReached, null, seatsUsed, licence.SeatLimit);
        }

        var invite = new TrainerClient
        {
            TrainerId = trainerId,
            ClientId = null, // filled when accepted
            Status = TrainerClientStatus.Pending,
            InviteCode = GenerateCode(),
            ExpiresAt = DateTime.UtcNow.AddDays(7),
        };
        _context.TrainerClients.Add(invite);
        await _context.SaveChangesAsync();

        return new CreateInviteResult(
            CreateInviteStatus.Ok, invite, seatsUsed + 1, licence.SeatLimit);
    }

    /// <summary>Accepts a pending invite for the given client, revoking any existing
    /// active trainer relationship the client has.
    ///
    /// The seat check is repeated here rather than trusted from mint time: a code
    /// can be redeemed days later, by which point the trainer may have filled up
    /// or downgraded. Checking only when the code is issued makes the limit
    /// advisory.</summary>
    public async Task<AcceptInviteResult> AcceptInviteAsync(string inviteCode, Guid clientId)
    {
        // Deliberately *not* filtering on expiry in the query — an expired code
        // and an unknown one need to produce different messages.
        var invite = await _context.TrainerClients
            .Include(t => t.Trainer)
            .FirstOrDefaultAsync(t =>
                t.InviteCode == inviteCode &&
                t.Status == TrainerClientStatus.Pending);

        if (invite == null)
        {
            return new AcceptInviteResult(AcceptInviteStatus.NotFound, null);
        }
        if (invite.ExpiresAt <= DateTime.UtcNow)
        {
            return new AcceptInviteResult(AcceptInviteStatus.Expired, null);
        }
        if (invite.TrainerId == clientId)
        {
            return new AcceptInviteResult(AcceptInviteStatus.SelfInvite, null);
        }

        var licence = await _context.TrainerLicences
            .FirstOrDefaultAsync(l => l.TrainerId == invite.TrainerId);
        if (licence == null || !licence.IsEntitled)
        {
            return new AcceptInviteResult(AcceptInviteStatus.TrainerNotEntitled, null);
        }

        // This invite already holds one of the seats it's being counted against,
        // so compare against the limit exclusive of itself.
        var seatsUsed = await CountSeatsUsedAsync(invite.TrainerId);
        if (seatsUsed - 1 >= licence.SeatLimit)
        {
            return new AcceptInviteResult(AcceptInviteStatus.TrainerAtSeatLimit, null);
        }

        // One active trainer per client — revoke any existing relationship.
        var existing = await _context.TrainerClients
            .Where(t => t.ClientId == clientId && t.Status == TrainerClientStatus.Active)
            .ToListAsync();
        existing.ForEach(t => t.Status = TrainerClientStatus.Revoked);

        invite.ClientId = clientId;
        invite.Status = TrainerClientStatus.Active;
        invite.AcceptedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();
        return new AcceptInviteResult(AcceptInviteStatus.Ok, invite);
    }

    /// <summary>Withdraws an unredeemed invite, freeing its seat. Only the trainer
    /// who issued it may do this.</summary>
    public async Task<bool> RevokeInviteAsync(Guid inviteId, Guid trainerId)
    {
        var invite = await _context.TrainerClients.FirstOrDefaultAsync(t =>
            t.Id == inviteId &&
            t.TrainerId == trainerId &&
            t.Status == TrainerClientStatus.Pending);
        if (invite == null) return false;

        invite.Status = TrainerClientStatus.Revoked;
        await _context.SaveChangesAsync();
        return true;
    }

    /// <summary>Returns the trainer's outstanding, still-redeemable invites.</summary>
    public async Task<List<TrainerClient>> GetPendingInvitesAsync(Guid trainerId) =>
        await _context.TrainerClients
            .Where(t =>
                t.TrainerId == trainerId &&
                t.Status == TrainerClientStatus.Pending &&
                t.ExpiresAt > DateTime.UtcNow)
            .OrderByDescending(t => t.CreatedAt)
            .ToListAsync();

    /// <summary>Returns the trainer's active clients.</summary>
    public async Task<List<TrainerClient>> GetClientsAsync(Guid trainerId) =>
        await _context.TrainerClients
            .AsNoTracking()
            .Include(t => t.Client)
            .Where(t => t.TrainerId == trainerId && t.Status == TrainerClientStatus.Active)
            .ToListAsync();

    /// <summary>Returns the client's active trainer relationship, if any.</summary>
    public async Task<TrainerClient?> GetActiveRelationshipForClientAsync(Guid clientId) =>
        await _context.TrainerClients
            .Include(t => t.Trainer)
            .FirstOrDefaultAsync(t => t.ClientId == clientId && t.Status == TrainerClientStatus.Active);

    /// <summary>Checks whether an active trainer-client relationship exists between the two.</summary>
    public async Task<bool> IsActiveTrainerOfAsync(Guid trainerId, Guid clientId)
    {
        return await _context.TrainerClients.AnyAsync(t => t.TrainerId == trainerId && t.ClientId == clientId && t.Status == TrainerClientStatus.Active);
    }

    public async Task<TrainerClient?> GetActiveRelationshipAsync(Guid trainerId, Guid clientId)
    {
        return await _context.TrainerClients.FirstOrDefaultAsync(t => t.TrainerId == trainerId && t.ClientId == clientId && t.Status == TrainerClientStatus.Active);

    }

    /// <summary>Revokes a relationship. Only the trainer or client in that relationship
    /// may do this; returns false if the relationship doesn't exist or the requester
    /// isn't a party to it.</summary>
    public async Task<bool> RemoveRelationshipAsync(Guid relationshipId, Guid requestingUserId)
    {
        var rel = await _context.TrainerClients.FindAsync(relationshipId);
        if (rel == null) return false;
        if (rel.TrainerId != requestingUserId && rel.ClientId != requestingUserId) return false;

        rel.Status = TrainerClientStatus.Revoked;
        await _context.SaveChangesAsync();
        return true;
    }

    // 12 hex chars from a CSPRNG (48 bits of entropy) — long enough that
    // combined with rate limiting and the 7-day expiry, brute-forcing a
    // pending invite is infeasible. e.g. "A3F2B891C7E4"
    private static string GenerateCode() =>
        Convert.ToHexString(RandomNumberGenerator.GetBytes(6));
}
