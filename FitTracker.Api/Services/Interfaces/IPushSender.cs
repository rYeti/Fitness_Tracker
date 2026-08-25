namespace FitTracker.Api.Services.Interfaces;

/// <summary>One notification, in our vocabulary rather than a vendor's.</summary>
/// <param name="Data">
/// Key/value payload the app reads on tap to decide where to navigate. Values are
/// strings because that is all FCM carries.
/// </param>
public record PushMessage(string Title, string Body, IReadOnlyDictionary<string, string> Data);

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
