using FitTracker.Api.DTOs;
using FitTracker.Api.Enums;
using FitTracker.Api.Models;
using FitTracker.Api.Repositories.Interfaces;
using FitTracker.Api.Services.Interfaces;
using Microsoft.Extensions.Logging;

namespace FitTracker.Api.Services;

public class ChatAttachmentService(
    IChatAttachmentStore store,
    IChatAttachmentRepository repo,
    ITrainerClientService trainerClientService,
    IConfiguration configuration,
    ILogger<ChatAttachmentService> logger) : IChatAttachmentService
{
    private readonly IChatAttachmentStore _store = store;
    private readonly IChatAttachmentRepository _repo = repo;
    private readonly ITrainerClientService _trainerClientService = trainerClientService;
    private readonly IConfiguration _configuration = configuration;
    private readonly ILogger<ChatAttachmentService> _logger = logger;

    // WhatsApp-sized caps, per docs/chat-attachments.md's "Size caps" decision:
    // video is the one kind large enough to need its own ceiling; every other
    // kind (image, audio, document, voice note) shares the smaller one.
    private long MaxImageBytes => _configuration.GetValue("Attachments:MaxImageBytes", 8L * 1024 * 1024);
    private long MaxVideoBytes => _configuration.GetValue("Attachments:MaxVideoBytes", 16L * 1024 * 1024);
    private int UploadUrlSeconds => _configuration.GetValue("Attachments:UploadUrlSeconds", 600);
    private int DownloadUrlSeconds => _configuration.GetValue("Attachments:DownloadUrlSeconds", 900);

    // Matches whatever the R2 bucket's own lifecycle rule is actually
    // configured to (see docs/chat-attachments.md §A.8) — this value doesn't
    // enforce anything itself, it only tells the client when to stop asking.
    private int RetentionDays => _configuration.GetValue("Attachments:RetentionDays", 45);

    /// <inheritdoc/>
    public ChatAttachmentCapabilitiesDto GetCapabilities() => new(
        Enabled: _store.IsConfigured,
        MaxImageBytes: MaxImageBytes,
        MaxVideoBytes: MaxVideoBytes,
        UploadUrlSeconds: UploadUrlSeconds,
        DownloadUrlSeconds: DownloadUrlSeconds,
        RetentionDays: RetentionDays);

    /// <inheritdoc/>
    public async Task<MintUploadResult> MintUploadAsync(Guid callerId, Guid otherPartyId, Guid attachmentId, long byteLength, Media kind)
    {
        var (trainerId, clientId, ok) = await _trainerClientService.ResolvePairAsync(callerId, otherPartyId);
        if (!ok) return new MintUploadResult(MintUploadOutcome.NotAuthorized, null);

        var cap = kind == Media.Video ? MaxVideoBytes : MaxImageBytes;
        if (byteLength > cap) return new MintUploadResult(MintUploadOutcome.TooLarge, null);

        var relationship = await _trainerClientService.GetActiveRelationshipAsync(trainerId, clientId)
            ?? throw new InvalidOperationException("No active trainer-client relationship exists for this pair.");

        var objectKey = $"chat/{relationship.Id:N}/{attachmentId:N}";

        ChatAttachment stored;
        try
        {
            stored = await _repo.MintOrGetAsync(new ChatAttachment
            {
                Id = attachmentId,
                TrainerClientId = relationship.Id,
                UploaderId = callerId,
                ObjectKey = objectKey,
                DeclaredByteLength = byteLength,
            });
        }
        catch (InvalidOperationException)
        {
            return new MintUploadResult(MintUploadOutcome.IdBelongsElsewhere, null);
        }

        var ttl = TimeSpan.FromSeconds(UploadUrlSeconds);
        var url = _store.CreateUploadUrl(stored.ObjectKey, ttl);

        return new MintUploadResult(MintUploadOutcome.Ok, new MintUploadResponseDto(url, DateTime.UtcNow.Add(ttl)));
    }

    /// <inheritdoc/>
    public async Task<MintDownloadResult> MintDownloadAsync(Guid callerId, Guid attachmentId)
    {
        var attachment = await _repo.FindAsync(attachmentId);
        if (attachment == null) return new MintDownloadResult(MintDownloadOutcome.Missing, null);

        var relationship = attachment.TrainerClient;
        var isMember = relationship.TrainerId == callerId || relationship.ClientId == callerId;
        if (!isMember || relationship.Status != TrainerClientStatus.Active)
            return new MintDownloadResult(MintDownloadOutcome.NotAuthorized, null);

        var realLength = await _store.GetObjectLengthAsync(attachment.ObjectKey);
        if (realLength == null)
            return new MintDownloadResult(MintDownloadOutcome.Missing, null);

        if (realLength > attachment.DeclaredByteLength)
        {
            _logger.LogWarning(
                "Attachment {AttachmentId} real size {RealLength} exceeds its declared {DeclaredLength}; deleting.",
                attachmentId, realLength, attachment.DeclaredByteLength);
            await _store.DeleteManyAsync([attachment.ObjectKey]);
            await _repo.DeleteRowsAsync([attachmentId]);
            return new MintDownloadResult(MintDownloadOutcome.Rejected, null);
        }

        var ttl = TimeSpan.FromSeconds(DownloadUrlSeconds);
        var url = _store.CreateDownloadUrl(attachment.ObjectKey, ttl);

        return new MintDownloadResult(MintDownloadOutcome.Ok, new MintDownloadResponseDto(url, DateTime.UtcNow.Add(ttl)));
    }

    /// <inheritdoc/>
    public async Task CommitAsync(Guid trainerClientId, Guid uploaderId, Guid messageId, IReadOnlyList<Guid> attachmentIds)
    {
        if (attachmentIds.Count == 0) return;

        var committed = await _repo.CommitAsync(trainerClientId, uploaderId, messageId, attachmentIds);

        if (committed.Count < attachmentIds.Count)
        {
            var skipped = attachmentIds.Except(committed).ToList();
            _logger.LogWarning(
                "Message {MessageId} referenced {Skipped} attachment id(s) that could not be committed (missing, wrong pair, wrong uploader, or already committed): {Ids}",
                messageId, skipped.Count, string.Join(",", skipped));
        }
    }
}
