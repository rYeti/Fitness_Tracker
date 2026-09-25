namespace FitTracker.Api.DTOs;

/// <summary>
/// The one argument of the hub's <c>ClientDataChanged</c> event: whose data changed, and
/// which parts of it. It says nothing about what changed.
/// </summary>
/// <remarks>
/// The console answers it by fetching the named panes again through the endpoints it
/// already uses, and each of those checks the relationship for itself. An event that
/// carried the data would be a second read path into a client's data with none of those
/// checks. See docs/sync-architecture.md, part four.
/// </remarks>
/// <param name="ClientId">The user whose data changed — the owner, never whoever changed
/// it.</param>
/// <param name="Areas">Drawn from <see cref="Models.DataAreas"/>, in ordinal order.</param>
public record ClientDataChangedDto(Guid ClientId, IReadOnlyList<string> Areas);
