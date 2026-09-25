namespace FitTracker.Api.Models;

/// <summary>
/// The root of an aggregate the app syncs: the row the changes feed ships, whole, with
/// everything that hangs off it. See docs/sync-architecture.md, part three.
/// </summary>
/// <remarks>
/// <see cref="UpdatedAt"/> is never set by hand. <c>SyncChangeInterceptor</c> stamps it on
/// every save that adds or changes the root, or adds, changes or removes one of its
/// children, and a bulk write that the change tracker can't see bumps it explicitly
/// (<c>SyncChanges.TouchAsync</c>). A root whose children change without it is an
/// aggregate the feed never sends again.
/// </remarks>
public interface ISyncRoot
{
    /// <summary>The row's id — the one the app minted, for rows it created.</summary>
    Guid Id { get; }

    /// <summary>When this aggregate last changed on the server, in UTC.</summary>
    DateTime UpdatedAt { get; set; }
}
