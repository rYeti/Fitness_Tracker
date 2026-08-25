using FitTracker.Api.Data;
using FitTracker.Api.Services.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace FitTracker.Api.Services;

/// <summary>
/// Runs a chat push on a detached task with its own DI scope.
/// </summary>
/// <remarks>
/// <para>
/// The scope is the reason this is not a bare <c>Task.Run</c>. Everything it
/// needs — the DbContext, the repository, the service — is registered
/// <c>Scoped</c>, and the hub invocation's scope is disposed the moment
/// <c>SendMessage</c> returns. Reusing it would mean querying a disposed
/// DbContext, intermittently, only under load.
/// </para>
/// <para>
/// Fire-and-forget is safe here for a reason specific to this app: the caller is
/// a SignalR hub over a live WebSocket, so the container is inside an active
/// request for the whole connection and Cloud Run keeps the CPU allocated. The
/// same trick after an ordinary HTTP response would be throttled the instant the
/// response was written.
/// </para>
/// <para>
/// What is deliberately given up: a push in flight when an instance shuts down is
/// lost. That is the correct trade — the alternative is making every chat send
/// wait on Google, and a missed notification costs far less than a message that
/// looks like it failed to send.
/// </para>
/// </remarks>
public class ChatPushDispatcher(
    IServiceScopeFactory scopeFactory,
    ILogger<ChatPushDispatcher> logger) : IChatPushDispatcher
{
    private readonly IServiceScopeFactory _scopeFactory = scopeFactory;
    private readonly ILogger<ChatPushDispatcher> _logger = logger;

    /// <inheritdoc/>
    public void Queue(Guid recipientId, Guid senderId, string? body)
    {
        _ = Task.Run(async () =>
        {
            try
            {
                using var scope = _scopeFactory.CreateScope();
                var provider = scope.ServiceProvider;

                // Looked up here rather than passed in by the hub: the hub has
                // only ids, and a name lookup is a database round trip that has
                // no business on the ack path.
                var db = provider.GetRequiredService<AppDbContext>();
                var sender = await db.Users
                    .Where(u => u.Id == senderId)
                    .Select(u => new { u.FirstName, u.LastName })
                    .FirstOrDefaultAsync();

                var senderName = sender == null
                    ? "New message"
                    : $"{sender.FirstName} {sender.LastName}".Trim();
                if (string.IsNullOrWhiteSpace(senderName)) senderName = "New message";

                var push = provider.GetRequiredService<IPushNotificationService>();
                // threadId is the sender: from the recipient's side of the
                // conversation, the sender *is* the other party.
                await push.SendChatMessageAsync(recipientId, senderName, body, senderId);
            }
            catch (Exception ex)
            {
                // Swallowed on purpose, and logged so it is still findable. This
                // task has no caller left to throw to — an unhandled exception
                // here would surface as an unobserved-task warning at best and
                // take the process down at worst, over a notification.
                _logger.LogError(ex, "Failed to send a chat push to {RecipientId}.", recipientId);
            }
        });
    }
}
