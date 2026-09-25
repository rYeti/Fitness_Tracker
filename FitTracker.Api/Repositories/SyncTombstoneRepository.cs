using FitTracker.Api.Data;
using FitTracker.Api.Models;
using FitTracker.Api.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace FitTracker.Api.Repositories;

/// <summary>EF Core implementation of <see cref="ISyncTombstoneRepository"/>.</summary>
public class SyncTombstoneRepository(AppDbContext context) : ISyncTombstoneRepository
{
    /// <inheritdoc/>
    public Task<List<SyncTombstone>> GetDeletedSinceAsync(Guid userId, DateTime since) =>
        context.SyncTombstones
            .AsNoTracking()
            .Where(t => t.UserId == userId && t.DeletedAt >= since)
            .OrderBy(t => t.DeletedAt)
            .ToListAsync();
}
