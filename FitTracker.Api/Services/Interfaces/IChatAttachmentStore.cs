namespace FitTracker.Api.Services.Interfaces;

/// <summary>
/// The attachment blob store, kept behind an interface for the same reason
/// <see cref="IPushSender"/> is (docs/chat-architecture.md §8): this is the
/// boundary where an external service enters the system, and everything unsafe
/// or unreliable about it stays on this side of it.
/// </summary>
/// <remarks>
/// Every object this store ever holds is ciphertext — a per-attachment key that
/// never reaches this server. See docs/chat-encryption.md and
/// docs/chat-attachments.md.
/// </remarks>
public interface IChatAttachmentStore
{
    /// <summary>Whether a real store is actually configured. False makes the
    /// attachment feature invisible rather than broken — the same posture
    /// <see cref="IPushSender.IsConfigured"/> already established for push.</summary>
    bool IsConfigured { get; }

    /// <summary>
    /// A presigned URL the caller may PUT the ciphertext to, directly, with no
    /// further involvement from this API.
    /// </summary>
    /// <remarks>
    /// **Synchronous, deliberately.** Presigning is an offline SigV4
    /// computation — no request leaves this process to produce one. A
    /// <c>Task</c>-returning signature here would invite exactly the mistake
    /// docs/chat-architecture.md §18 already paid for once: something slow or
    /// third-party sitting in front of a path that has to stay fast. If this
    /// method is ever made <c>async</c>, that is a sign the implementation
    /// underneath it has stopped being a local computation.
    /// </remarks>
    Uri CreateUploadUrl(string objectKey, TimeSpan ttl);

    /// <summary>A presigned URL the caller may GET the ciphertext from. Synchronous for the same reason as <see cref="CreateUploadUrl"/>.</summary>
    Uri CreateDownloadUrl(string objectKey, TimeSpan ttl);

    /// <summary>The object's real length, or null if it does not exist. Used
    /// to catch an upload that exceeded what was declared at mint time — a
    /// presigned PUT cannot enforce a byte cap itself, only a POST policy can,
    /// and this store never issues one. See docs/chat-attachments.md.</summary>
    Task<long?> GetObjectLengthAsync(string objectKey, CancellationToken cancellationToken = default);

    /// <summary>Deletes objects. A no-op for any key that does not exist —
    /// callers (the reaper, retention sweeps) delete opportunistically and
    /// should never have to check existence first.</summary>
    Task DeleteManyAsync(IReadOnlyList<string> objectKeys, CancellationToken cancellationToken = default);

    /// <summary>Every key under a prefix. Used only by the weekly
    /// bucket-reconciliation sweep — the one thing that catches an object
    /// orphaned by a cascade delete rather than a failed send. Not a hot path.</summary>
    Task<IReadOnlyList<string>> ListKeysAsync(string prefix, CancellationToken cancellationToken = default);
}
