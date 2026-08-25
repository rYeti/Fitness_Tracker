using FitTracker.Api.Data;
using FitTracker.Api.Models;
using FitTracker.Api.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace FitTracker.Api.Repositories;

public class DeviceTokenRepository(AppDbContext context) : IDeviceTokenRepository
{
    private readonly AppDbContext _context = context;

    /// <inheritdoc/>
    public async Task<DeviceToken> UpsertAsync(Guid userId, string token, DevicePlatform platform)
    {
        var existing = await _context.DeviceTokens.FirstOrDefaultAsync(d => d.Token == token);

        if (existing != null)
        {
            // Reassigned, not duplicated. The unique index would reject a second
            // row anyway; doing it explicitly is what makes signing in as
            // someone else on a shared phone stop delivering the previous user's
            // messages to it.
            existing.UserId = userId;
            existing.Platform = platform;
            existing.LastSeenAt = DateTime.UtcNow;
            await _context.SaveChangesAsync();
            return existing;
        }

        var device = new DeviceToken
        {
            UserId = userId,
            Token = token,
            Platform = platform,
        };

        _context.DeviceTokens.Add(device);
        await _context.SaveChangesAsync();
        return device;
    }

    /// <inheritdoc/>
    public Task<List<DeviceToken>> GetForUserAsync(Guid userId) =>
        _context.DeviceTokens.Where(d => d.UserId == userId).ToListAsync();

    /// <inheritdoc/>
    public async Task<bool> DeleteAsync(string token)
    {
        var existing = await _context.DeviceTokens.FirstOrDefaultAsync(d => d.Token == token);
        if (existing == null) return false;

        _context.DeviceTokens.Remove(existing);
        await _context.SaveChangesAsync();
        return true;
    }

    /// <inheritdoc/>
    public async Task DeleteManyAsync(IEnumerable<string> tokens)
    {
        var list = tokens.ToList();
        if (list.Count == 0) return;

        var rows = await _context.DeviceTokens.Where(d => list.Contains(d.Token)).ToListAsync();
        if (rows.Count == 0) return;

        _context.DeviceTokens.RemoveRange(rows);
        await _context.SaveChangesAsync();
    }
}
