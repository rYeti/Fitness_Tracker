using System.Data.Common;
using Microsoft.EntityFrameworkCore.Diagnostics;

namespace FitTracker.Api.Tests;

/// <summary>
/// Plays another request that commits in the middle of the one under test: runs
/// <paramref name="sql"/> once, on the request's own connection and transaction, just before
/// its first write — the first <c>INSERT</c>, <c>UPDATE</c> or <c>DELETE</c> it sends.
/// </summary>
/// <remarks>
/// Everything a request reads before that point was read before the other request's
/// commit, and everything it writes from there on runs after it. That is the window a
/// check-then-write race lives in: a test that injects its row here fails if the code
/// decided what to write from a read, and passes if it asks again as it writes.
/// </remarks>
public sealed class InterleavedCommit(string sql) : DbCommandInterceptor
{
    private bool _done;

    /// <inheritdoc/>
    public override async ValueTask<InterceptionResult<int>> NonQueryExecutingAsync(
        DbCommand command, CommandEventData eventData, InterceptionResult<int> result, CancellationToken cancellationToken = default)
    {
        await BeforeAsync(command, cancellationToken);
        return await base.NonQueryExecutingAsync(command, eventData, result, cancellationToken);
    }

    /// <inheritdoc/>
    public override async ValueTask<InterceptionResult<DbDataReader>> ReaderExecutingAsync(
        DbCommand command, CommandEventData eventData, InterceptionResult<DbDataReader> result, CancellationToken cancellationToken = default)
    {
        await BeforeAsync(command, cancellationToken);
        return await base.ReaderExecutingAsync(command, eventData, result, cancellationToken);
    }

    private async Task BeforeAsync(DbCommand command, CancellationToken ct)
    {
        if (_done || !IsWrite(command.CommandText)) return;
        _done = true;
        await using var other = command.Connection!.CreateCommand();
        other.Transaction = command.Transaction;
        other.CommandText = sql;
        await other.ExecuteNonQueryAsync(ct);
    }

    private static bool IsWrite(string sql)
    {
        var text = sql.TrimStart();
        return text.StartsWith("INSERT", StringComparison.OrdinalIgnoreCase)
            || text.StartsWith("UPDATE", StringComparison.OrdinalIgnoreCase)
            || text.StartsWith("DELETE", StringComparison.OrdinalIgnoreCase);
    }

    /// <summary>A GUID as SQLite stores it, for writing into <paramref name="sql"/>.</summary>
    public static string Sql(Guid id) => $"'{id.ToString().ToUpperInvariant()}'";
}

/// <summary>Records the text of every command a context sends.</summary>
public sealed class CommandLog : DbCommandInterceptor
{
    private readonly List<string> _commands = [];

    /// <summary>Every command sent since the last <see cref="Clear"/>.</summary>
    public IReadOnlyList<string> Commands => _commands;

    /// <summary>Forgets what was sent so far, so an arrange step isn't counted.</summary>
    public void Clear() => _commands.Clear();

    /// <summary>How many commands updated <paramref name="table"/>.</summary>
    public int UpdatesOf(string table) =>
        _commands.Count(c => c.TrimStart().StartsWith($"UPDATE \"{table}\"", StringComparison.Ordinal));

    /// <inheritdoc/>
    public override ValueTask<InterceptionResult<int>> NonQueryExecutingAsync(
        DbCommand command, CommandEventData eventData, InterceptionResult<int> result, CancellationToken cancellationToken = default)
    {
        _commands.Add(command.CommandText);
        return base.NonQueryExecutingAsync(command, eventData, result, cancellationToken);
    }

    /// <inheritdoc/>
    public override ValueTask<InterceptionResult<DbDataReader>> ReaderExecutingAsync(
        DbCommand command, CommandEventData eventData, InterceptionResult<DbDataReader> result, CancellationToken cancellationToken = default)
    {
        _commands.Add(command.CommandText);
        return base.ReaderExecutingAsync(command, eventData, result, cancellationToken);
    }

    /// <inheritdoc/>
    public override ValueTask<InterceptionResult<object>> ScalarExecutingAsync(
        DbCommand command, CommandEventData eventData, InterceptionResult<object> result, CancellationToken cancellationToken = default)
    {
        _commands.Add(command.CommandText);
        return base.ScalarExecutingAsync(command, eventData, result, cancellationToken);
    }
}
