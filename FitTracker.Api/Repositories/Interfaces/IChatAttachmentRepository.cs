using FitTracker.Api.Models;

namespace FitTracker.Api.Repositories.Interfaces;

public interface IChatAttachmentRepository
{
    /// <summary>
    /// Inserts a new pending row, or returns the existing one when this id has
    /// already been minted for the same pair and uploader — the same
    /// idempotency shape as <c>IChatRepository.AddMessageAsync</c>, for the
    /// same reason: a client that never received a mint response cannot tell
    /// whether it landed, so it always retries with the same id.
    /// </summary>
    /// <exception cref="InvalidOperationException">
    /// The id already exists for a different pair or a different uploader.
    /// </exception>
    Task<ChatAttachment> MintOrGetAsync(ChatAttachment attachment);

    /// <summary>Null if the id doesn't exist at all.</summary>
    Task<ChatAttachment?> FindAsync(Guid id);

    /// <summary>
    /// Stamps every id in <paramref name="attachmentIds"/> that belongs to
    /// <paramref name="trainerClientId"/>, was uploaded by
    /// <paramref name="uploaderId"/>, and is not already committed, as
    /// belonging to <paramref name="messageId"/>. Anything else in the list —
    /// missing, another pair's, another uploader's, already committed — is
    /// silently skipped: bookkeeping must never cost the message it is
    /// attached to. Returns the ids actually committed, so the caller can log
    /// what was skipped without a second query.
    /// </summary>
    Task<IReadOnlyList<Guid>> CommitAsync(Guid trainerClientId, Guid uploaderId, Guid messageId, IReadOnlyList<Guid> attachmentIds);

    /// <summary>Uncommitted rows older than <paramref name="olderThan"/> — the reaper's own query.</summary>
    Task<List<ChatAttachment>> FindOrphanedAsync(DateTime olderThan);

    /// <summary>Deletes rows by id. Free operations on the store side too — see
    /// docs/chat-attachments.md §A.9 — so this is called opportunistically.</summary>
    Task DeleteRowsAsync(IReadOnlyList<Guid> ids, CancellationToken cancellationToken = default);

    /// <summary>Which of these object keys this table actually knows about —
    /// the reconciliation sweep's own query. Whatever's left over in the
    /// caller's set is a blob with no row, typically orphaned by a
    /// <c>TrainerClient</c> cascade delete.</summary>
    Task<IReadOnlyList<string>> FindKnownObjectKeysAsync(IReadOnlyList<string> objectKeys);
}
