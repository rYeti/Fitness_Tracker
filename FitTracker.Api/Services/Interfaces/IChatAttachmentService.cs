using FitTracker.Api.DTOs;
using FitTracker.Api.Enums;

namespace FitTracker.Api.Services.Interfaces;

/// <param name="Disabled">
/// No blob store is configured, so there is no URL to hand back. A distinct
/// outcome rather than an exception because it is an ordinary, expected
/// deployment state — <see cref="DisabledChatAttachmentStore"/> is what the
/// API registers when the R2 settings are absent — and because a caller that
/// reaches this needs to be told to stop asking, not handed a 500 that looks
/// like a transient fault worth retrying.
/// </param>
public enum MintUploadOutcome { Ok, NotAuthorized, TooLarge, IdBelongsElsewhere, Disabled }

public record MintUploadResult(MintUploadOutcome Outcome, MintUploadResponseDto? Response);

public enum MintDownloadOutcome { Ok, NotAuthorized, Missing, Rejected, Disabled }

public record MintDownloadResult(MintDownloadOutcome Outcome, MintDownloadResponseDto? Response);

public interface IChatAttachmentService
{
    /// <summary>Whether a client should show the attach affordance at all.</summary>
    ChatAttachmentCapabilitiesDto GetCapabilities();

    /// <summary>
    /// Mints a presigned upload URL for a new (or already-minted — see
    /// <c>IChatAttachmentRepository.MintOrGetAsync</c>) attachment in the
    /// caller's thread with <paramref name="otherPartyId"/>.
    /// </summary>
    Task<MintUploadResult> MintUploadAsync(Guid callerId, Guid otherPartyId, Guid attachmentId, long byteLength, Media kind);

    /// <summary>
    /// Mints a presigned download URL for an attachment the caller can name by
    /// id alone — the attachment already records which pair it belongs to, so
    /// unlike minting an upload this doesn't need the caller to also state
    /// <c>otherPartyId</c>. Also verifies the object actually in the store
    /// doesn't exceed what was declared at mint time — a presigned PUT cannot
    /// enforce that itself, only a POST policy can, and R2 doesn't support
    /// presigned POST. An object that fails this check is deleted and reported
    /// as <see cref="MintDownloadOutcome.Rejected"/> rather than handed out.
    /// See docs/chat-attachments.md §0.2.
    /// </summary>
    Task<MintDownloadResult> MintDownloadAsync(Guid callerId, Guid attachmentId);

    /// <summary>
    /// Attaches every attachment in <paramref name="attachmentIds"/> that
    /// actually belongs to this pair and uploader to
    /// <paramref name="messageId"/>. Called from <c>ChatHub.SendMessageV2</c>
    /// after the message itself is stored and before the ack — never awaits
    /// anything that could fail the send over bookkeeping. See
    /// docs/chat-attachments.md §A.4.
    /// </summary>
    Task CommitAsync(Guid trainerClientId, Guid uploaderId, Guid messageId, IReadOnlyList<Guid> attachmentIds);
}
