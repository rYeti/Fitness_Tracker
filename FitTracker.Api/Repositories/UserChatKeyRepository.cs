using FitTracker.Api.Data;
using FitTracker.Api.Models;
using FitTracker.Api.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace FitTracker.Api.Repositories;

public class UserChatKeyRepository(AppDbContext context) : IUserChatKeyRepository
{
    /// <summary>
    /// How many devices a user may have published a key for at once. A
    /// generous number, not a plan seat limit: real multi-device use is a
    /// phone, a tablet, maybe a desktop and a browser or two — this exists so
    /// a user who never signs out anywhere (the ordinary case; see
    /// docs/chat-encryption.md on why sign-out doesn't touch the key) doesn't
    /// accumulate rows forever, particularly on the web, where "clear site
    /// data" mints a brand new device identity every time.
    /// </summary>
    private const int MaxDevicesPerUser = 5;

    private readonly AppDbContext _context = context;

    /// <inheritdoc/>
    public async Task<UserChatKey> UpsertAsync(Guid userId, string deviceId, string publicKeyJwk)
    {
        var existing = await _context.UserChatKeys
            .FirstOrDefaultAsync(k => k.UserId == userId && k.DeviceId == deviceId);

        var now = DateTime.UtcNow;

        if (existing != null)
        {
            existing.PublicKeyJwk = publicKeyJwk;
            existing.UpdatedAt = now;
            existing.LastSeenAt = now;
            await _context.SaveChangesAsync();
            return existing;
        }

        // A genuinely new device. Evict the least-recently-seen one first if
        // this user is already at the cap, so the insert below never leaves
        // more than MaxDevicesPerUser rows behind.
        var deviceCount = await _context.UserChatKeys.CountAsync(k => k.UserId == userId);
        if (deviceCount >= MaxDevicesPerUser)
        {
            var oldest = await _context.UserChatKeys
                .Where(k => k.UserId == userId)
                .OrderBy(k => k.LastSeenAt)
                .FirstAsync();
            _context.UserChatKeys.Remove(oldest);
        }

        var key = new UserChatKey
        {
            UserId = userId,
            DeviceId = deviceId,
            PublicKeyJwk = publicKeyJwk,
            CreatedAt = now,
            UpdatedAt = now,
            LastSeenAt = now,
        };

        _context.UserChatKeys.Add(key);
        await _context.SaveChangesAsync();
        return key;
    }

    /// <inheritdoc/>
    public async Task<IReadOnlyList<UserChatKey>> GetAllAsync(Guid userId) =>
        await _context.UserChatKeys
            .AsNoTracking()
            .Where(k => k.UserId == userId)
            .OrderByDescending(k => k.LastSeenAt)
            .ToListAsync();
}
