using FitTracker.Api.Data;
using FitTracker.Api.Models;
using FitTracker.Api.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace FitTracker.Api.Repositories;

/// <summary>EF Core implementation of <see cref="ISyncTombstoneRepository"/>.</summary>
public class SyncTombstoneRepository(AppDbContext context) : ISyncTombstoneRepository
{
    /// <inheritdoc/>
    public Task<List<SyncTombstone>> GetDeletedSinceAsync(Guid userId, DateTime? since)
    {
        var mine = context.SyncTombstones.AsNoTracking().Where(t => t.UserId == userId);
        if (since is { } from) mine = mine.Where(t => t.DeletedAt >= from);
        return mine.OrderBy(t => t.DeletedAt).ToListAsync();
    }

    /// <inheritdoc/>
    public Task<bool> WasDeletedAsync(Guid userId, Guid id) =>
        context.SyncTombstones.AnyAsync(t => t.UserId == userId && t.EntityId == id);
}
