using FitTracker.Api.Models;

namespace FitTracker.Api.Repositories.Interfaces;

/// <summary>
/// Reads the server's record of deleted synced rows: for the changes feed, and for a create
/// asking whether the id it was sent is one the caller deleted
/// (<c>ClientIds.CreateOrResolveAsync</c>).
/// </summary>
public interface ISyncTombstoneRepository
{
    /// <summary>Every row of <paramref name="userId"/>'s deleted at or after
    /// <paramref name="since"/> — or ever, when it is null — oldest first.</summary>
    Task<List<SyncTombstone>> GetDeletedSinceAsync(Guid userId, DateTime? since);

    /// <summary>Whether <paramref name="userId"/>'s data held a row under
    /// <paramref name="id"/> that the server has since deleted.</summary>
    Task<bool> WasDeletedAsync(Guid userId, Guid id);
}
