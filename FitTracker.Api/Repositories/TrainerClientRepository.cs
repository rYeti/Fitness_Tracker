using FitTracker.Api.Data;
using FitTracker.Api.Models;
using FitTracker.Api.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace FitTracker.Api.Repositories;

public class TrainerClientRepository(AppDbContext context) : ITrainerClientRepository
{
    private readonly AppDbContext _context = context;

    public async Task<TrainerClient> CreateInviteAsync(Guid trainerId)
    {
        var invite = new TrainerClient
        {
            TrainerId = trainerId,
            ClientId = Guid.Empty, // filled when accepted
            Status = TrainerClientStatus.Pending,
            InviteCode = GenerateCode(),
        };
        _context.TrainerClients.Add(invite);
        await _context.SaveChangesAsync();
        return invite;
    }

    public async Task<TrainerClient?> AcceptInviteAsync(string inviteCode, Guid clientId)
    {
        var invite = await _context.TrainerClients
            .Include(t => t.Trainer)
            .FirstOrDefaultAsync(t =>
                t.InviteCode == inviteCode &&
                t.Status == TrainerClientStatus.Pending);

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

    public async Task<List<TrainerClient>> GetClientsAsync(Guid trainerId) =>
        await _context.TrainerClients
            .Include(t => t.Client)
            .Where(t => t.TrainerId == trainerId && t.Status == TrainerClientStatus.Active)
            .ToListAsync();

    public async Task<TrainerClient?> GetActiveRelationshipForClientAsync(Guid clientId) =>
        await _context.TrainerClients
            .Include(t => t.Trainer)
            .FirstOrDefaultAsync(t => t.ClientId == clientId && t.Status == TrainerClientStatus.Active);

    public async Task<bool> RemoveRelationshipAsync(Guid relationshipId, Guid requestingUserId)
    {
        var rel = await _context.TrainerClients.FindAsync(relationshipId);
        if (rel == null) return false;
        if (rel.TrainerId != requestingUserId && rel.ClientId != requestingUserId) return false;

        rel.Status = TrainerClientStatus.Revoked;
        await _context.SaveChangesAsync();
        return true;
    }

    private static string GenerateCode() =>
        Guid.NewGuid().ToString("N")[..8].ToUpper(); // e.g. "A3F2B891"
}
