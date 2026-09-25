using Microsoft.EntityFrameworkCore;

namespace FitTracker.Api.Services;

/// <summary>
/// A create carried an id that already names a row belonging to someone else.
/// Mapped to 409 Conflict by <see cref="Filters.ClientIdConflictFilter"/>.
/// </summary>
/// <remarks>
/// With ids minted as random v4 UUIDs this is not something an honest client
/// runs into; it is the answer that keeps a guessed or replayed id from reading
/// or overwriting another account's row. The app answers it by minting a fresh
/// id and trying again on its next push.
/// </remarks>
public sealed class ClientIdConflictException(Guid id)
    : Exception($"The id {id} is already in use.")
{
    /// <summary>The id the caller asked for.</summary>
    public Guid Id { get; } = id;
}

/// <summary>
/// A create carried an id the caller's own data once held and has since deleted.
/// Mapped to 410 Gone by <see cref="Filters.ClientIdGoneFilter"/>.
/// </summary>
/// <remarks>
/// A device that hasn't pulled a delete made elsewhere still holds the row, and a create
/// is how it sends a row it believes the server may not have. Inserting it would undo the
/// delete. The app answers 410 by deleting its own copy, unless history on the device
/// still hangs on the row, which then needs a fresh id. See docs/sync-architecture.md,
/// part three (§30, §35).
/// </remarks>
public sealed class ClientIdGoneException(Guid id)
    : Exception($"The id {id} was deleted.")
{
    /// <summary>The id the caller asked for.</summary>
    public Guid Id { get; } = id;
}

/// <summary>
/// Creates that take the row's id from the caller. See docs/sync-architecture.md,
/// parts two and three.
/// </summary>
/// <remarks>
/// The app used to learn a new row's id only from the POST response, so a response
/// lost on the way back, a retry, or two sync runs at once each wrote a second row —
/// the server could not tell a repeat from a new request. The app now mints the id
/// before the first attempt and sends it with every attempt, which turns "was this
/// already stored?" into a lookup:
///
/// | The id…                        | The create…                                   |
/// |--------------------------------|-----------------------------------------------|
/// | names one of the caller's rows | applies the sent fields to it and returns it  |
/// | names someone else's row       | throws <see cref="ClientIdConflictException"/> |
/// | names a row the caller deleted | throws <see cref="ClientIdGoneException"/>    |
/// | is new                         | inserts under it                              |
/// | was not sent                   | mints one, as before — shipped apps send none |
///
/// A repeat *applies* the fields rather than only returning the row, because the
/// repeat is the device's latest word on the row: an edit made after an attempt
/// whose response was lost goes out on the retry, and a create that returned the
/// stored row unchanged would have let the device mark that edit sent when it
/// never landed.
///
/// A deleted id is refused rather than inserted again because the only device that
/// sends one is a device that hasn't heard of the delete: its create would bring back
/// what another device, or a trainer, removed. It is checked before <c>insert</c> runs,
/// so before a create's own content check (a meal per day and category, a session per
/// workout and day) can answer it with a different row and have the stale device move
/// the deleted row's contents into that one.
/// </remarks>
public static class ClientIds
{
    /// <summary>The id a request asked for, or null when it sent none.
    /// <see cref="Guid.Empty"/> counts as none: it is what an absent field binds to.</summary>
    public static Guid? Requested(Guid? id) => id is { } g && g != Guid.Empty ? g : null;

    /// <summary>Resolves a create under a caller-chosen id.</summary>
    /// <param name="requestedId">The id from the request, if any.</param>
    /// <param name="callerId">The user the row must belong to.</param>
    /// <param name="ownerOf">The owner of the row stored under an id: null when there is no
    /// such row, <see cref="Guid.Empty"/> when it exists but belongs to no user.</param>
    /// <param name="deletedByCaller">Whether the caller's data held a row under an id and
    /// deleted it — whether a <c>SyncTombstone</c> of the caller's names it.</param>
    /// <param name="updateExisting">Applies the request to the caller's existing row.</param>
    /// <param name="insert">Inserts the row under the given id.</param>
    /// <remarks>
    /// Two requests carrying the same new id can both find it free and both insert; the
    /// second fails on the primary key. That failure is caught once and the id resolved
    /// again, which now finds the first request's row. The repositories' inserts detach
    /// what they added when a save fails (<c>SaveNewAsync</c>), so the second look is not
    /// answered from the change tracker's copy of the row that never landed.
    /// </remarks>
    public static async Task<T?> CreateOrResolveAsync<T>(
        Guid? requestedId,
        Guid callerId,
        Func<Guid, Task<Guid?>> ownerOf,
        Func<Guid, Task<bool>> deletedByCaller,
        Func<Guid, Task<T?>> updateExisting,
        Func<Guid, Task<T?>> insert)
        where T : class
    {
        if (Requested(requestedId) is not { } id) return await insert(Guid.NewGuid());

        var retried = false;
        while (true)
        {
            var owner = await ownerOf(id);
            if (owner is { } ownerId)
            {
                if (ownerId != callerId) throw new ClientIdConflictException(id);
                return await updateExisting(id);
            }

            if (await deletedByCaller(id)) throw new ClientIdGoneException(id);

            try
            {
                return await insert(id);
            }
            catch (DbUpdateException) when (!retried)
            {
                // A concurrent request with the same id inserted first: resolve again.
                // Anything else that failed the save is not ours to swallow.
                retried = true;
                if (await ownerOf(id) is null) throw;
            }
        }
    }
}
