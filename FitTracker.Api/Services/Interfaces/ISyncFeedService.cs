using FitTracker.Api.DTOs;

namespace FitTracker.Api.Services.Interfaces;

/// <summary>The changes feed behind <c>GET api/Sync/changes</c>. See
/// docs/sync-architecture.md, part three.</summary>
public interface ISyncFeedService
{
    /// <summary>Everything of <paramref name="userId"/>'s that changed at or after
    /// <paramref name="since"/>, or everything they have when it is null.</summary>
    Task<SyncChangesDto> GetChangesAsync(Guid userId, DateTime? since);
}
