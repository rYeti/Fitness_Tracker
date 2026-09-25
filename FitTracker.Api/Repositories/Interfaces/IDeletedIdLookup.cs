namespace FitTracker.Api.Repositories.Interfaces;

/// <summary>
/// Whether a user's synced row was deleted — what a create asks before inserting under an
/// id the app chose (<c>ClientIds.CreateOrResolveAsync</c>). Every repository with a create
/// that takes a client id implements it.
/// </summary>
public interface IDeletedIdLookup
{
    /// <summary>Whether <paramref name="userId"/>'s data held a row under
    /// <paramref name="id"/> that the server has since deleted.</summary>
    Task<bool> WasDeletedAsync(Guid userId, Guid id);
}
