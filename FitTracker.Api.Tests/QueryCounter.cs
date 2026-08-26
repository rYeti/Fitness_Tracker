using System.Data.Common;
using Microsoft.EntityFrameworkCore.Diagnostics;

namespace FitTracker.Api.Tests;

/// <summary>
/// Counts the SQL commands a <see cref="DbFixture"/>'s context issues.
/// </summary>
/// <remarks>
/// Exists so a test can assert the *shape* of a data-access path rather than its speed:
/// "this endpoint costs the same number of queries for ten clients as for one." That is the
/// assertion the Trainer Console's roster needed and never had — an N+1 is correct code that
/// returns the right answer, so nothing else in the suite could see it, and at the two-client
/// scale the tests run at it is not even slow.
///
/// A query-count assertion is deterministic; a timing assertion on CI is a flaky test.
/// </remarks>
public sealed class QueryCounter : DbCommandInterceptor
{
    private int _count;

    /// <summary>Commands issued since the last <see cref="Reset"/>.</summary>
    public int Count => Volatile.Read(ref _count);

    /// <summary>Zeroes the counter. Call it immediately before the call under test, so the
    /// arrange step's inserts aren't counted as part of it.</summary>
    public void Reset() => Volatile.Write(ref _count, 0);

    /// <inheritdoc/>
    public override InterceptionResult<DbDataReader> ReaderExecuting(
        DbCommand command,
        CommandEventData eventData,
        InterceptionResult<DbDataReader> result)
    {
        Interlocked.Increment(ref _count);
        return base.ReaderExecuting(command, eventData, result);
    }

    /// <inheritdoc/>
    public override ValueTask<InterceptionResult<DbDataReader>> ReaderExecutingAsync(
        DbCommand command,
        CommandEventData eventData,
        InterceptionResult<DbDataReader> result,
        CancellationToken cancellationToken = default)
    {
        Interlocked.Increment(ref _count);
        return base.ReaderExecutingAsync(command, eventData, result, cancellationToken);
    }

    /// <inheritdoc/>
    public override InterceptionResult<object> ScalarExecuting(
        DbCommand command,
        CommandEventData eventData,
        InterceptionResult<object> result)
    {
        Interlocked.Increment(ref _count);
        return base.ScalarExecuting(command, eventData, result);
    }

    /// <inheritdoc/>
    public override ValueTask<InterceptionResult<object>> ScalarExecutingAsync(
        DbCommand command,
        CommandEventData eventData,
        InterceptionResult<object> result,
        CancellationToken cancellationToken = default)
    {
        Interlocked.Increment(ref _count);
        return base.ScalarExecutingAsync(command, eventData, result, cancellationToken);
    }

    /// <inheritdoc/>
    public override InterceptionResult<int> NonQueryExecuting(
        DbCommand command,
        CommandEventData eventData,
        InterceptionResult<int> result)
    {
        Interlocked.Increment(ref _count);
        return base.NonQueryExecuting(command, eventData, result);
    }

    /// <inheritdoc/>
    public override ValueTask<InterceptionResult<int>> NonQueryExecutingAsync(
        DbCommand command,
        CommandEventData eventData,
        InterceptionResult<int> result,
        CancellationToken cancellationToken = default)
    {
        Interlocked.Increment(ref _count);
        return base.NonQueryExecutingAsync(command, eventData, result, cancellationToken);
    }
}
