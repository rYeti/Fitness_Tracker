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

    /// <summary>Creates a pending invite for the given trainer, valid for 7 days.</summary>
    public async Task<TrainerClient> CreateInviteAsync(Guid trainerId)
    {
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
        return invite;
    }

    /// <summary>Accepts a pending invite for the given client, revoking any existing
    /// active trainer relationship the client has. Returns null if the code is
    /// invalid, expired, or belongs to the client's own account.</summary>
    public async Task<TrainerClient?> AcceptInviteAsync(string inviteCode, Guid clientId)
    {
        var invite = await _context.TrainerClients
            .Include(t => t.Trainer)
            .FirstOrDefaultAsync(t =>
                t.InviteCode == inviteCode &&
                t.Status == TrainerClientStatus.Pending &&
                t.ExpiresAt > DateTime.UtcNow);

        if (invite == null) return null;
        if (invite.TrainerId == clientId) return null; // can't be your own client

        // One active trainer per client — revoke any existing relationship.
        var existing = await _context.TrainerClients
            .Where(t => t.ClientId == clientId && t.Status == TrainerClientStatus.Active)
            .ToListAsync();
        existing.ForEach(t => t.Status = TrainerClientStatus.Revoked);

        invite.ClientId = clientId;
        invite.Status = TrainerClientStatus.Active;
        invite.AcceptedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();
        return invite;
    }

    /// <summary>Returns the trainer's active clients.</summary>
    public async Task<List<TrainerClient>> GetClientsAsync(Guid trainerId) =>
        await _context.TrainerClients
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
        return await _context.TrainerClients.AnyAsync(t => t.Id == trainerId && t.ClientId == clientId && t.Status == TrainerClientStatus.Active);
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
