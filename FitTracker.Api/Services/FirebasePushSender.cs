using FirebaseAdmin;
using FirebaseAdmin.Messaging;
using FitTracker.Api.Services.Interfaces;

namespace FitTracker.Api.Services;

/// <summary>
/// The FCM transport. The only file in this project that references the Firebase
/// SDK — see <see cref="IPushSender"/> for why the seam is here.
/// </summary>
/// <remarks>
/// Firebase is used for Cloud Messaging and nothing else. It is not a database
/// and not an auth provider: user data stays in Postgres and identity stays with
/// our own JWTs. The only reason it is here at all is that FCM is the only route
/// to an Android app that is not running.
/// </remarks>
public class FirebasePushSender(FirebaseApp app, ILogger<FirebasePushSender> logger) : IPushSender
{
    private readonly FirebaseMessaging _messaging = FirebaseMessaging.GetMessaging(app);
    private readonly ILogger<FirebasePushSender> _logger = logger;

    public bool IsConfigured => true;

    public async Task<PushSendResult> SendAsync(
        IReadOnlyList<string> tokens,
        PushMessage message,
        CancellationToken cancellationToken = default)
    {
        if (tokens.Count == 0) return new PushSendResult([]);

        var multicast = ToMulticast(tokens, message);

        // SendEachForMulticastAsync, not the retired batch endpoint: one request
        // per token under the hood, and a per-token result, which is what makes
        // pruning possible at all.
        var response = await _messaging.SendEachForMulticastAsync(multicast, cancellationToken);

        var dead = new List<string>();
        for (var i = 0; i < response.Responses.Count; i++)
        {
            var result = response.Responses[i];
            if (result.IsSuccess) continue;

            var code = (result.Exception as FirebaseMessagingException)?.MessagingErrorCode;

            // Only these two mean "this token will never work again". Everything
            // else — quota, unavailable, an internal error — is transient, and
            // deleting a token over a transient failure silently unsubscribes a
            // device that was fine.
            if (code is MessagingErrorCode.Unregistered or MessagingErrorCode.SenderIdMismatch)
            {
                dead.Add(tokens[i]);
            }
            else
            {
                _logger.LogWarning(
                    result.Exception,
                    "Push to one device failed with {ErrorCode}; keeping the token.",
                    code?.ToString() ?? "an unknown error");
            }
        }

        return new PushSendResult(dead);
    }

    /// <summary>What FCM is sent for <paramref name="message"/>: public so a test can pin
    /// the mapping without a Firebase project.</summary>
    public static MulticastMessage ToMulticast(IReadOnlyList<string> tokens, PushMessage message) =>
        new()
        {
            Tokens = tokens.ToList(),
            // Data-only, with no `notification` block at all. This used to be the
            // other way round, and the comment here used to explain that a
            // notification payload is what lets the OS draw the message while the
            // app is closed. That is still true, and it is no longer available:
            // drawing it requires reading it, and the body is now ciphertext this
            // server has no key for. So the payload is handed to the app instead,
            // and the app decrypts it and raises the notification itself.
            //
            // The cost is real and belongs in the open. A data message is
            // delivered to the *app*, so Android may hold it under Doze or App
            // Standby, and a force-stopped app receives nothing at all. High
            // priority is what buys back most of that gap -- see
            // docs/chat-encryption.md.
            Data = new Dictionary<string, string>(message.Data),
            Android = new AndroidConfig
            {
                // A chat message is time-sensitive; normal priority lets Android
                // hold it until the next maintenance window, which can be
                // minutes on a dozing device. With no notification block to fall
                // back on, that delay would be the whole notification. A push that
                // never ends in a notification (a sync request) asks for normal:
                // Android deprioritises an app whose high-priority messages show
                // nothing, and chat would be what paid.
                Priority = message.HighPriority ? Priority.High : Priority.Normal,
                CollapseKey = message.CollapseKey,
            },
            // The same collapse on iOS, where it is an APNs header. iOS isn't built
            // yet (docs/push-notifications.md); what a data-only message needs
            // there beyond this is part of setting it up.
            Apns = message.CollapseKey is { } key
                ? new ApnsConfig { Headers = new Dictionary<string, string> { ["apns-collapse-id"] = key } }
                : null,
        };
}
