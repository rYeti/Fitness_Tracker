using FitTracker.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace FitTracker.Api.Data;

/// <summary>
/// What a write that <see cref="SyncChangeInterceptor"/> can't see has to do by hand. See
/// docs/sync-architecture.md, part three.
/// </summary>
/// <remarks>
/// The interceptor reads the change tracker, so it sees every row a save adds, changes or
/// removes. It does not see <c>ExecuteDelete</c>/<c>ExecuteUpdate</c>, which go straight to
/// the database, or what the database itself does on a delete (<c>ON DELETE CASCADE</c>,
/// <c>SET NULL</c>). A call site doing either to synced data bumps the roots it changed
/// (<see cref="TouchAsync{TRoot}"/>) and records the roots it deleted
/// (<see cref="Bury"/>) — inside the same transaction as the write, or the feed can see one
/// without the other.
/// </remarks>
internal static class SyncChanges
{
    /// <summary>The roots that changed at or after <paramref name="since"/> — what the
    /// changes feed asks each list endpoint's query for — or all of them when it is null,
    /// which is what the list endpoints themselves ask for.</summary>
    public static IQueryable<T> ChangedSince<T>(this IQueryable<T> roots, DateTime? since)
        where T : class, ISyncRoot =>
        since is { } from
            ? roots.Where(r => EF.Property<DateTime>(r, nameof(ISyncRoot.UpdatedAt)) >= from)
            : roots;

    /// <summary>Whether <paramref name="userId"/>'s data held a row under
    /// <paramref name="id"/> that the server has deleted.</summary>
    public static Task<bool> WasDeletedAsync(this AppDbContext context, Guid userId, Guid id) =>
        context.SyncTombstones.AnyAsync(t => t.UserId == userId && t.EntityId == id);

    /// <summary>Marks the given roots changed now, in one statement.</summary>
    public static async Task TouchAsync<TRoot>(this AppDbContext context, IReadOnlyCollection<Guid> ids)
        where TRoot : class, ISyncRoot
    {
        if (ids.Count == 0) return;

        var wanted = ids.Distinct().ToList();
        var now = DateTime.UtcNow;
        await context.Set<TRoot>()
            .Where(r => wanted.Contains(EF.Property<Guid>(r, nameof(ISyncRoot.Id))))
            .ExecuteUpdateAsync(s => s.SetProperty(
                r => EF.Property<DateTime>(r, nameof(ISyncRoot.UpdatedAt)), now));
    }

    /// <summary>Records that <paramref name="userId"/>'s rows <paramref name="ids"/> were
    /// deleted. The tombstones are saved by the caller's next save.</summary>
    public static void Bury(this AppDbContext context, Guid userId, string entityType, IEnumerable<Guid> ids)
    {
        var now = DateTime.UtcNow;
        foreach (var id in ids.Distinct())
        {
            context.SyncTombstones.Add(new SyncTombstone
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                EntityType = entityType,
                EntityId = id,
                DeletedAt = now,
            });
        }
    }
}
