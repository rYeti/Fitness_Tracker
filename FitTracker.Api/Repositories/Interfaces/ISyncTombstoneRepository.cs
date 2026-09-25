using FitTracker.Api.Models;

namespace FitTracker.Api.Repositories.Interfaces;

/// <summary>Reads the server's record of deleted synced rows, for the changes feed.</summary>
public interface ISyncTombstoneRepository
{
    /// <summary>Every row of <paramref name="userId"/>'s deleted at or after
    /// <paramref name="since"/>, oldest first.</summary>
    Task<List<SyncTombstone>> GetDeletedSinceAsync(Guid userId, DateTime since);
}
