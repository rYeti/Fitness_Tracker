using FitTracker.Api.Services.Interfaces;

namespace FitTracker.Api.Services;

/// <summary>
/// What runs when no attachment store is configured. Mirrors
/// <see cref="DisabledPushSender"/>: the API boots and serves chat normally,
/// with the attachment feature simply invisible rather than broken — a client
/// checks <c>GET api/chat/attachments/capabilities</c> and disables the attach
/// affordance rather than ever reaching these methods.
/// </summary>
/// <remarks>
/// Unlike push (a fire-and-forget best-effort notification, so "disabled"
/// quietly no-ops), an attachment upload is something a caller is actively
/// waiting on — there is no sensible URL to hand back. Every method here
/// throws, on the assumption that the one caller of this interface
/// (<c>ChatAttachmentController</c>) always checks <see cref="IsConfigured"/>
/// first via the capabilities endpoint and never reaches these when it is
/// false. A throw here means that assumption broke, not that this class is
/// wrong to throw.
/// </remarks>
public class DisabledChatAttachmentStore : IChatAttachmentStore
{
    public bool IsConfigured => false;

    public Uri CreateUploadUrl(string objectKey, TimeSpan ttl) => throw NotConfigured();

    public Uri CreateDownloadUrl(string objectKey, TimeSpan ttl) => throw NotConfigured();

    public Task<long?> GetObjectLengthAsync(string objectKey, CancellationToken cancellationToken = default) =>
        throw NotConfigured();

    public Task DeleteManyAsync(IReadOnlyList<string> objectKeys, CancellationToken cancellationToken = default) =>
        throw NotConfigured();

    public Task<IReadOnlyList<string>> ListKeysAsync(string prefix, CancellationToken cancellationToken = default) =>
        throw NotConfigured();

    private static InvalidOperationException NotConfigured() =>
        new("No chat attachment store is configured (Attachments:Provider). Check IsConfigured before calling this.");
}
