namespace FitTracker.Api.Models;

/// <summary>
/// One uploaded blob's metadata — never its bytes, and never anything that
/// describes what it is. See docs/chat-attachments.md for what deliberately
/// is not a column here and why.
/// </summary>
public class ChatAttachment
{
    /// <summary>
    /// Client-generated, same rationale as <see cref="ChatMessage.Id"/>
    /// (docs/chat-architecture.md §2): the client cannot tell "mint failed"
    /// from "mint succeeded, response lost", so it always retries with the
    /// same id, and a server-generated id would turn that retry into a second
    /// orphaned object.
    /// </summary>
    public Guid Id { get; set; }

    public TrainerClient TrainerClient { get; set; } = null!;

    public Guid TrainerClientId { get; set; }

    /// <summary>Only this user may PUT to <see cref="ObjectKey"/>. Either
    /// party in the relationship may GET it.</summary>
    public Guid UploaderId { get; set; }

    /// <summary>Server-derived, never client-supplied — see
    /// <c>ChatAttachmentService</c>. A client-chosen key is a path-traversal
    /// and a cross-tenant overwrite in one field.</summary>
    public string ObjectKey { get; set; } = null!;

    /// <summary>The ciphertext length the client declared at mint time. A
    /// presigned PUT cannot enforce a byte cap itself, so this is what the
    /// download-mint path verifies the real object against.</summary>
    public long DeclaredByteLength { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    /// <summary>Null until a <c>SendMessage</c> call actually references this
    /// attachment. The reaper deletes anything still null past its grace
    /// period — see docs/chat-attachments.md §A.5.</summary>
    public DateTime? CommittedAt { get; set; }

    public Guid? MessageId { get; set; }
}
