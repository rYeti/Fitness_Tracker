namespace FitTracker.Api.Services.Interfaces;

/// <summary>One push, in our vocabulary rather than a vendor's.</summary>
/// <param name="Data">
/// The entire payload. Values are strings because that is all FCM carries.
/// </param>
/// <remarks>
/// There is no Title or Body any more, and their absence is the point. A push
/// used to carry a rendered notification, which meant this server had to be able
/// to read the message to write one. It cannot, so it does not: the payload is
/// data the recipient's own device decrypts and renders. See
/// docs/chat-encryption.md for what that costs.
/// </remarks>
public record PushMessage(IReadOnlyDictionary<string, string> Data)
{
    /// <summary>Messages sharing a key replace one another while they wait for a device
    /// that is offline or dozing, so a burst reaches it as one. Null keeps every message:
    /// right for chat, where each one is its own content.</summary>
    public string? CollapseKey { get; init; }

    /// <summary>Delivered at once even to a dozing device. Only for a push that ends in
    /// something the user sees: Android lowers the priority of an app whose high-priority
    /// messages don't, and chat is what would pay for it.</summary>
    public bool HighPriority { get; init; } = true;
}

/// <param name="DeadTokens">
/// Tokens the transport rejected as permanently invalid — an uninstalled app or a
/// reissued token. The caller deletes these; a transient failure is not in here.
/// </param>
public record PushSendResult(IReadOnlyList<string> DeadTokens);

/// <summary>
/// The push transport, kept behind an interface for the same reason
/// <c>ChatSignalRClient</c> is (docs/chat-architecture.md §8): this is the
/// boundary where an external service, and everything unreliable about it,
/// enters the system.
/// </summary>
/// <remarks>
/// Only <c>FirebasePushSender</c> references the FCM SDK. That keeps the rest of
/// the codebase — and every test — free of it, and means a token being rejected
/// is a value this app understands rather than a vendor exception type leaking
/// upward.
/// </remarks>
public interface IPushSender
{
    /// <summary>Whether a transport is actually configured. False makes every send a no-op.</summary>
    bool IsConfigured { get; }

    Task<PushSendResult> SendAsync(IReadOnlyList<string> tokens, PushMessage message, CancellationToken cancellationToken = default);
}
