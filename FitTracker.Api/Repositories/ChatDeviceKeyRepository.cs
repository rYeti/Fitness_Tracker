using FitTracker.Api.Data;
using FitTracker.Api.Models;
using FitTracker.Api.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace FitTracker.Api.Repositories;

public class ChatDeviceKeyRepository(AppDbContext context) : IChatDeviceKeyRepository
{
    private readonly AppDbContext _context = context;

    /// <summary>
    /// How many devices' worth of key material one account keeps. Not a product
    /// limit on how many devices someone may use chat from — old rows are simply
    /// pruned, and re-registering the oldest one again just republishes it.
    /// Generous on purpose: pruning a device's row does not delete any message
    /// it already read, but it does mean that device stops receiving new ones
    /// until it reopens the app and re-registers.
    /// </summary>
    private const int MaxDevicesPerUser = 10;

    /// <inheritdoc/>
    public async Task<UserChatDeviceKey> UpsertAsync(Guid userId, string deviceId, string publicKeyJwk)
    {
        var existing = await _context.UserChatDeviceKeys
            .FirstOrDefaultAsync(k => k.UserId == userId && k.DeviceId == deviceId);

        if (existing != null)
        {
            existing.PublicKeyJwk = publicKeyJwk;
            existing.LastSeenAt = DateTime.UtcNow;
            await _context.SaveChangesAsync();
            await PruneAsync(userId);
            return existing;
        }

        var key = new UserChatDeviceKey
        {
            UserId = userId,
            DeviceId = deviceId,
            PublicKeyJwk = publicKeyJwk,
        };

        _context.UserChatDeviceKeys.Add(key);
        await _context.SaveChangesAsync();
        await PruneAsync(userId);
        return key;
    }

    /// <inheritdoc/>
    public Task<List<UserChatDeviceKey>> GetForUserAsync(Guid userId) =>
        _context.UserChatDeviceKeys
            .AsNoTracking()
            .Where(k => k.UserId == userId)
            .OrderByDescending(k => k.LastSeenAt)
            .ToListAsync();

    /// <inheritdoc/>
    public Task<UserChatDeviceKey?> GetAsync(Guid userId, string deviceId) =>
        _context.UserChatDeviceKeys
            .AsNoTracking()
            .FirstOrDefaultAsync(k => k.UserId == userId && k.DeviceId == deviceId);

    private async Task PruneAsync(Guid userId)
    {
        var stale = await _context.UserChatDeviceKeys
            .Where(k => k.UserId == userId)
            .OrderByDescending(k => k.LastSeenAt)
            .Skip(MaxDevicesPerUser)
            .ToListAsync();

        if (stale.Count == 0) return;

        _context.UserChatDeviceKeys.RemoveRange(stale);
        await _context.SaveChangesAsync();
    }
}
