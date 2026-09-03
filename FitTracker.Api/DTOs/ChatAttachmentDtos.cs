using FitTracker.Api.Enums;

namespace FitTracker.Api.DTOs;

/// <summary>What a client checks before showing the attach affordance at all — the
/// same posture <c>IPushSender.IsConfigured</c> established for push.</summary>
/// <param name="RetentionDays">
/// How long an uploaded blob survives before the bucket's own lifecycle rule
/// expires it (the rule itself is R2-side config, not something this API
/// enforces — see docs/chat-attachments.md §A.8). Told to the client so a
/// bubble older than this can render "no longer available" from its own
/// timestamp alone, without spending a request finding out the object is gone.
/// </param>
public record ChatAttachmentCapabilitiesDto(
    bool Enabled,
    long MaxImageBytes,
    long MaxVideoBytes,
    int UploadUrlSeconds,
    int DownloadUrlSeconds,
    int RetentionDays);

/// <param name="AttachmentId">Client-generated — see <see cref="Models.ChatAttachment.Id"/>.</param>
/// <param name="ByteLength">The ciphertext length this device is about to PUT.</param>
/// <param name="Kind">Selects which cap (<see cref="ChatAttachmentCapabilitiesDto.MaxImageBytes"/>
/// or <see cref="ChatAttachmentCapabilitiesDto.MaxVideoBytes"/>) applies. Not stored — see
/// docs/chat-attachments.md §0.1 for why the server never persists a media kind.</param>
public record MintUploadRequestDto(Guid AttachmentId, long ByteLength, Media Kind);

public record MintUploadResponseDto(Uri UploadUrl, DateTime ExpiresAt);

public record MintDownloadResponseDto(Uri DownloadUrl, DateTime ExpiresAt);
