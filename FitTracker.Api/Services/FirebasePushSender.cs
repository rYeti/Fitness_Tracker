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

    /// <summary>The Android notification channel the client creates at startup. Must match.</summary>
    public const string ChatChannelId = "chat_messages";

    public bool IsConfigured => true;

    public async Task<PushSendResult> SendAsync(
        IReadOnlyList<string> tokens,
        PushMessage message,
        CancellationToken cancellationToken = default)
    {
        if (tokens.Count == 0) return new PushSendResult([]);

        var multicast = new MulticastMessage
        {
            Tokens = tokens.ToList(),
            // A `notification` payload rather than data-only: it is what lets the
            // OS display the message itself while the app is closed. Data-only
            // messages require the app to be running to render anything, which
            // is exactly the case this feature exists for.
            Notification = new Notification { Title = message.Title, Body = message.Body },
            Data = new Dictionary<string, string>(message.Data),
            Android = new AndroidConfig
            {
                // A chat message is time-sensitive; normal priority lets Android
                // hold it until the next maintenance window, which can be
                // minutes on a dozing device.
                Priority = Priority.High,
                Notification = new AndroidNotification { ChannelId = ChatChannelId },
            },
        };

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
}
