using FitTracker.Api.Data;
using FitTracker.Api.Models;
using FitTracker.Api.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace FitTracker.Api.Repositories;

public class UserChatKeyRepository(AppDbContext context) : IUserChatKeyRepository
{
    private readonly AppDbContext _context = context;

    /// <inheritdoc/>
    public async Task<UserChatKey> UpsertAsync(Guid userId, string publicKeyJwk)
    {
        var existing = await _context.UserChatKeys.FirstOrDefaultAsync(k => k.UserId == userId);

        if (existing != null)
        {
            existing.PublicKeyJwk = publicKeyJwk;
            existing.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync();
            return existing;
        }

        var key = new UserChatKey
        {
            UserId = userId,
            PublicKeyJwk = publicKeyJwk,
        };

        _context.UserChatKeys.Add(key);
        await _context.SaveChangesAsync();
        return key;
    }

    /// <inheritdoc/>
    public Task<UserChatKey?> GetAsync(Guid userId) =>
        _context.UserChatKeys.AsNoTracking().FirstOrDefaultAsync(k => k.UserId == userId);
}
