using System.Linq.Expressions;
using FitTracker.Api.Data;
using FitTracker.Api.Models;
using FitTracker.Api.Services;
using Microsoft.EntityFrameworkCore;

namespace FitTracker.Api.Repositories;

/// <summary>Saving rows inserted under an id the client chose.</summary>
internal static class DbContextExtensions
{
    /// <summary>
    /// Saves pending inserts. If the save fails, whatever it was inserting stops being
    /// tracked before the exception goes on.
    /// </summary>
    /// <remarks>
    /// A client-chosen id can lose a race to a concurrent request carrying the same id
    /// (see <c>ClientIds.CreateOrResolveAsync</c>), which then looks the id up again. Left
    /// tracked, the row that failed to insert would answer that lookup itself — a tracking
    /// query returns the instance already in the identity map, not the stored one — and
    /// the next save in the request would try to insert it a second time.
    /// </remarks>
    public static async Task SaveNewAsync(this AppDbContext context)
    {
        try
        {
            await context.SaveChangesAsync();
        }
        catch (DbUpdateException)
        {
            foreach (var entry in context.ChangeTracker.Entries()
                         .Where(e => e.State == EntityState.Added)
                         .ToList())
            {
                entry.State = EntityState.Detached;
            }
            throw;
        }
    }

    /// <summary>
    /// Makes one parent's list — the rows <paramref name="inList"/> selects — exactly
    /// <paramref name="rows"/>, each stored under the id it carries.
    /// </summary>
    /// <remarks>
    /// The one procedure behind every list the app sends whole (a session exercise's logged
    /// sets, a workout exercise's set templates). It used to be written out once per list,
    /// and the copies had drifted: one detached through a helper, one pruned a loaded
    /// navigation, and none of them checked for foreign ids inside the transaction or kept
    /// the bulk delete to the caller's rows. In one transaction — the caller's, if one is
    /// running — it:
    ///
    /// 1. refuses (<see cref="ClientIdConflictException"/>, answered 409) if any id is
    ///    stored under someone else's parent;
    /// 2. deletes the list's current rows, and the caller's rows stored elsewhere under the
    ///    ids sent — the app moves rows between twin parents, ids and all, when it folds a
    ///    duplicate — never a row <paramref name="ownedByCaller"/> doesn't select, so a row
    ///    another account stored under one of those ids after step 1 survives, and the
    ///    insert below fails on its key rather than taking it;
    /// 3. marks changed the root (<typeparamref name="TRoot"/>) of every row step 2 deleted —
    ///    the bulk delete goes straight to the database, so the change tracking the sync feed
    ///    reads never sees it, and a list replaced with nothing, or a row moved away from
    ///    another parent, would otherwise never reach another device
    ///    (docs/sync-architecture.md, part three);
    /// 4. stops tracking the deleted rows, including in the parent's already-loaded list
    ///    (<paramref name="loadedList"/>), which fixup never prunes — a request that read the
    ///    parent, replaced its list and read it again would see both generations;
    /// 5. inserts <paramref name="rows"/> and commits.
    ///
    /// The caller checks that the parent is the caller's before calling this.
    /// </remarks>
    /// <param name="rows">The list's new contents, each carrying its final id.</param>
    /// <param name="idOf">A row's id.</param>
    /// <param name="inList">Selects the rows currently in the list.</param>
    /// <param name="ownedByCaller">Selects the rows that belong to the caller.</param>
    /// <param name="rootOf">The id of a row's sync root — the aggregate the feed ships it in.</param>
    /// <param name="loadedList">The parent's list navigation, if the context has it loaded.</param>
    public static async Task ReplaceListAsync<T, TRoot>(
        this AppDbContext context,
        List<T> rows,
        Func<T, Guid> idOf,
        Expression<Func<T, bool>> inList,
        Expression<Func<T, bool>> ownedByCaller,
        Expression<Func<T, Guid>> rootOf,
        Func<ICollection<T>?> loadedList)
        where T : class
        where TRoot : class, ISyncRoot
    {
        var ids = rows.Select(idOf).ToList();
        Expression<Func<T, bool>> sentId = e => ids.Contains(EF.Property<Guid>(e, "Id"));

        await using var transaction = context.Database.CurrentTransaction == null
            ? await context.Database.BeginTransactionAsync()
            : null;

        var foreign = await context.Set<T>()
            .Where(sentId)
            .Where(Not(ownedByCaller))
            .Select(e => EF.Property<Guid>(e, "Id"))
            .FirstOrDefaultAsync();
        if (foreign != Guid.Empty) throw new ClientIdConflictException(foreign);

        var replaced = context.Set<T>()
            .Where(ownedByCaller)
            .Where(OrElse(inList, sentId));
        var emptied = await replaced.Select(rootOf).Distinct().ToListAsync();
        await replaced.ExecuteDeleteAsync();
        await context.TouchAsync<TRoot>(emptied);

        // The bulk delete bypasses the change tracker, so its copies of the deleted rows go
        // by hand; left tracked, the insert below would clash with them on the key.
        var deleted = inList.Compile();
        foreach (var entry in context.ChangeTracker.Entries<T>()
                     .Where(e => deleted(e.Entity) || ids.Contains(idOf(e.Entity)))
                     .ToList())
        {
            entry.State = EntityState.Detached;
        }
        loadedList()?.Clear();

        context.Set<T>().AddRange(rows);
        await context.SaveNewAsync();
        if (transaction != null) await transaction.CommitAsync();
    }

    private static Expression<Func<T, bool>> Not<T>(Expression<Func<T, bool>> predicate) =>
        Expression.Lambda<Func<T, bool>>(Expression.Not(predicate.Body), predicate.Parameters);

    private static Expression<Func<T, bool>> OrElse<T>(
        Expression<Func<T, bool>> left, Expression<Func<T, bool>> right) =>
        Expression.Lambda<Func<T, bool>>(
            Expression.OrElse(
                left.Body,
                new Rebind(right.Parameters[0], left.Parameters[0]).Visit(right.Body)),
            left.Parameters);

    /// <summary>Points one lambda's parameter at another's, so their bodies can be combined
    /// into one expression the provider can translate.</summary>
    private sealed class Rebind(ParameterExpression from, ParameterExpression to) : ExpressionVisitor
    {
        protected override Expression VisitParameter(ParameterExpression node) =>
            node == from ? to : node;
    }
}
