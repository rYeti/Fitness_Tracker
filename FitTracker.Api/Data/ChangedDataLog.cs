using FitTracker.Api.Models;

namespace FitTracker.Api.Data;

/// <summary>
/// A change a write made to <paramref name="Owner"/>'s data, in <paramref name="Area"/> (one of
/// <see cref="DataAreas"/>).
/// </summary>
/// <remarks>
/// The owner is resolved when the write happens, where the write already knows or can cheaply
/// find it (<see cref="SyncChangeInterceptor"/>, <see cref="SyncChanges"/>). A change whose owner
/// can't be found there is never recorded, so what reaches the notifier is only ever owners:
/// nothing is left to look up after the commit, and nothing unresolved can hold up anyone else.
/// </remarks>
public readonly record struct ChangedData(Guid Owner, string Area);

/// <summary>
/// Whose data one request changed, held until the change commits. See
/// docs/sync-architecture.md, part four.
/// </summary>
/// <remarks>
/// <para>
/// Registered per request, and given to the request's <see cref="AppDbContext"/>. The writes
/// record into it — <see cref="SyncChangeInterceptor"/> for everything a save changes, and
/// <see cref="SyncChanges"/> for the bulk statements it can't see — and
/// <c>LiveUpdateMiddleware</c> takes what committed once the request is done.
/// </para>
/// <para>
/// A change is recorded when it is written, which is before anyone knows whether it will
/// commit. So each one is held with the transaction it was written in, and moves to the
/// committed set only when that transaction commits:
/// </para>
/// <list type="table">
///   <listheader><term>Written</term><description>Committed when</description></listheader>
///   <item><term>by a save outside a transaction</term><description>the save succeeds (EF's
///   own transaction for it, if it opened one, has committed by then)</description></item>
///   <item><term>by a save or statement inside a transaction</term><description>that
///   transaction commits — never, if it rolls back or is disposed</description></item>
///   <item><term>by a statement outside a transaction</term><description>at once: it
///   committed by itself</description></item>
/// </list>
/// <para>
/// A save that fails takes back what it recorded, whether or not a transaction goes on after
/// it (EF rolls a failed save inside a transaction back to a savepoint, and the transaction
/// continues).
/// </para>
/// </remarks>
public sealed class ChangedDataLog
{
    private readonly List<(Guid? Transaction, ChangedData Change)> _pending = [];
    private readonly HashSet<ChangedData> _committed = [];
    private int _saveMark;

    /// <summary>Records a change a save is writing, in <paramref name="transaction"/> (null:
    /// the save's own).</summary>
    internal void Record(Guid? transaction, ChangedData change) => _pending.Add((transaction, change));

    /// <summary>Records a change a statement has just written outside any save.</summary>
    internal void RecordStatement(Guid? transaction, ChangedData change)
    {
        if (transaction == null) _committed.Add(change);
        else _pending.Add((transaction, change));
    }

    /// <summary>A save is about to record what it writes.</summary>
    internal void SaveStarting() => _saveMark = _pending.Count;

    /// <summary>A save succeeded. Outside a transaction, what it recorded is committed.</summary>
    internal void SaveSucceeded(Guid? transaction)
    {
        if (transaction == null) Commit(null);
    }

    /// <summary>A save failed: what it recorded was never written.</summary>
    internal void SaveFailed()
    {
        if (_saveMark < _pending.Count) _pending.RemoveRange(_saveMark, _pending.Count - _saveMark);
    }

    /// <summary>The transaction <paramref name="transaction"/> committed.</summary>
    internal void Committed(Guid transaction) => Commit(transaction);

    private void Commit(Guid? transaction)
    {
        foreach (var (_, change) in _pending.Where(p => p.Transaction == transaction)) _committed.Add(change);
        _pending.RemoveAll(p => p.Transaction == transaction);
    }

    /// <summary>Everything the request has committed so far, once each; and forgets it.</summary>
    public IReadOnlyCollection<ChangedData> TakeCommitted()
    {
        var taken = _committed.ToList();
        _committed.Clear();
        return taken;
    }
}
