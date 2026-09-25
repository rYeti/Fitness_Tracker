using System.Linq.Expressions;
using System.Runtime.CompilerServices;
using FitTracker.Api.Models;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.ChangeTracking;
using Microsoft.EntityFrameworkCore.Query;
using Microsoft.EntityFrameworkCore.Storage;

namespace FitTracker.Api.Data;

/// <summary>
/// What a write that <see cref="SyncChangeInterceptor"/> can't see has to do by hand, and
/// the one way a root is stamped. See docs/sync-architecture.md, part three.
/// </summary>
/// <remarks>
/// The interceptor reads the change tracker, so it sees every row a save adds, changes or
/// removes. It does not see <c>ExecuteDelete</c>/<c>ExecuteUpdate</c>, which go straight to
/// the database, or what the database itself does on a delete (<c>ON DELETE CASCADE</c>,
/// <c>SET NULL</c>). A call site doing either to synced data bumps the roots it changed
/// (<see cref="TouchAsync{TRoot}(AppDbContext, IReadOnlyCollection{Guid}, Guid)"/>, or
/// <see cref="TouchWhereAsync{TRoot}"/> when the roots are whichever ones a predicate
/// matches at that moment) and records the roots it deleted (<see cref="Bury"/>) — inside
/// the same transaction as the write, or the feed can see one without the other.
///
/// A root is stamped at most once per transaction. A batch that saves once per entry, or a
/// replace that stamps before its delete and then saves its inserts, would otherwise write
/// the same root row once per save; inside one transaction the first stamp is already the
/// one every later reader sees, since none of them sees anything before the commit.
///
/// The same two helpers record whose data they changed, for the live updates (part four), by
/// the owner their caller names: every call site already has it, and looking it up from the
/// roots would be a query in the write's transaction to learn what the caller knew.
/// <see cref="Bury"/> needs nothing extra: its tombstones are rows of the next save, which
/// records them like its own.
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

    /// <summary>Marks the given roots changed now, in one statement that writes only their
    /// <c>UpdatedAt</c> — skipping any this transaction has already stamped.</summary>
    /// <param name="owner">Whose roots they are. Required for the reason
    /// <see cref="TouchWhereAsync{TRoot}"/>'s is.</param>
    public static async Task TouchAsync<TRoot>(this AppDbContext context, IReadOnlyCollection<Guid> ids, Guid owner)
        where TRoot : class, ISyncRoot
    {
        if (ids.Count == 0) return;
        await StampAsync<TRoot>(context, ids, DateTime.UtcNow, async: true, default);
        Recorded<TRoot>(context, owner);
    }

    /// <summary>Marks changed now every root <paramref name="which"/> matches when the
    /// statement runs.</summary>
    /// <remarks>
    /// For a root found through rows a later statement deletes: a list of ids read first
    /// is already stale when the delete runs, and a row committed in between is deleted
    /// without its root being stamped. Issued immediately before the delete, in its
    /// transaction, the predicate is evaluated as late as it can be — and the row lock the
    /// update takes on each root holds back any other writer of that root's children,
    /// which stamps the same row, until this transaction ends.
    ///
    /// The roots it stamps aren't known here, so the once-per-transaction record can't
    /// include them; a later save in the same transaction may stamp one of them again.
    ///
    /// For the same reason the caller names their owner. Every call site has it — the user
    /// whose row it is deleting or replacing — and the stamped roots are that user's too. It is
    /// a required parameter because a bulk statement that records nobody commits, answers 200,
    /// and is never told to anyone watching; the one thing the compiler can hold here is
    /// that nobody calls this without saying whose it is.
    /// </remarks>
    public static async Task TouchWhereAsync<TRoot>(this AppDbContext context, Expression<Func<TRoot, bool>> which, Guid owner)
        where TRoot : class, ISyncRoot
    {
        var now = DateTime.UtcNow;
        var stamped = await context.Set<TRoot>()
            .Where(which)
            .ExecuteUpdateAsync(s => s.SetProperty(r => EF.Property<DateTime>(r, nameof(ISyncRoot.UpdatedAt)), now));
        if (stamped > 0) Recorded<TRoot>(context, owner);
    }

    /// <summary>Records in the request's log that a statement changed <paramref name="owner"/>'s
    /// <typeparamref name="TRoot"/>s; it counts once the statement's transaction commits.</summary>
    private static void Recorded<TRoot>(AppDbContext context, Guid owner)
    {
        if (context.ChangedData is { } log && DataAreas.Of(typeof(TRoot)) is { } area)
        {
            log.RecordStatement(context.Database.CurrentTransaction?.TransactionId, new ChangedData(owner, area));
        }
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

    /// <summary>Stamps the roots <paramref name="ids"/> this transaction hasn't stamped yet:
    /// tracked ones through their entry, so the stamp goes out with the save; the rest in
    /// one <c>UPDATE</c> of the one column, without loading them.</summary>
    /// <remarks>
    /// Outside an explicit transaction the <c>UPDATE</c> commits on its own, before the save
    /// it runs ahead of. If that save then fails the root has been stamped for nothing, and
    /// the feed sends it once more than it needed to — the harmless direction. The other
    /// order, a save that commits with a stamp that doesn't, is a change nobody hears of.
    /// </remarks>
    internal static async Task StampAsync<TRoot>(
        AppDbContext context,
        IReadOnlyCollection<Guid> ids,
        DateTime now,
        bool async,
        CancellationToken ct,
        IEnumerable<EntityEntry>? tracked = null)
        where TRoot : class, ISyncRoot
    {
        if (ids.Count == 0) return;

        var stamped = StampedInTransaction(context);
        var pending = new HashSet<Guid>(ids);
        if (stamped != null) pending.RemoveWhere(id => stamped.Contains((typeof(TRoot), id)));
        if (pending.Count == 0) return;

        foreach (var entry in tracked ?? context.ChangeTracker.Entries<TRoot>())
        {
            if (entry.Entity is not TRoot root || !pending.Remove(root.Id)) continue;
            // A root being added is stamped already; one being deleted is not coming back.
            if (entry.State is EntityState.Unchanged or EntityState.Modified)
            {
                entry.Property(nameof(ISyncRoot.UpdatedAt)).CurrentValue = now;
            }
            stamped?.Add((typeof(TRoot), root.Id));
        }
        if (pending.Count == 0) return;

        var wanted = pending.ToList();
        var query = context.Set<TRoot>().Where(r => wanted.Contains(EF.Property<Guid>(r, nameof(ISyncRoot.Id))));
        Expression<Func<SetPropertyCalls<TRoot>, SetPropertyCalls<TRoot>>> set =
            s => s.SetProperty(r => EF.Property<DateTime>(r, nameof(ISyncRoot.UpdatedAt)), now);
        if (async) await query.ExecuteUpdateAsync(set, ct);
        else query.ExecuteUpdate(set);
        stamped?.UnionWith(wanted.Select(id => (typeof(TRoot), id)));
    }

    /// <summary>Records that the root <paramref name="id"/> was stamped in this transaction
    /// by a statement that couldn't record it itself (<see cref="TouchWhereAsync{TRoot}"/>).</summary>
    internal static void MarkStamped<TRoot>(this AppDbContext context, Guid id)
        where TRoot : class, ISyncRoot =>
        StampedInTransaction(context)?.Add((typeof(TRoot), id));

    /// <summary>The roots already stamped in the context's current transaction, or null
    /// outside one — where every save is its own transaction and stamps what it touches.</summary>
    private static HashSet<(Type, Guid)>? StampedInTransaction(AppDbContext context)
    {
        if (context.Database.CurrentTransaction is not { } transaction) return null;
        var record = Records.GetOrCreateValue(context);
        if (!ReferenceEquals(record.Transaction, transaction))
        {
            record.Transaction = transaction;
            record.Roots.Clear();
        }
        return record.Roots;
    }

    /// <summary>Per context, not per request scope or thread: a context is one unit of
    /// work, and the table lets it go with the context.</summary>
    private static readonly ConditionalWeakTable<AppDbContext, StampRecord> Records = new();

    private sealed class StampRecord
    {
        public IDbContextTransaction? Transaction { get; set; }
        public HashSet<(Type, Guid)> Roots { get; } = [];
    }
}
