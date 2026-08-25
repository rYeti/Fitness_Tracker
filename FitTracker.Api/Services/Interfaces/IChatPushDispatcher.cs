namespace FitTracker.Api.Services.Interfaces;

/// <summary>
/// Hands a chat push off to happen *after* the hub has answered its caller.
/// </summary>
/// <remarks>
/// An interface with one void method looks like ceremony until you see what it
/// buys. <c>ChatHub.SendMessage</c>'s return value is load-bearing — the client
/// blocks on it and reads its absence as "not delivered" (docs/chat-architecture.md
/// §12) — so nothing that talks to Google may sit between persisting the message
/// and returning it. Queueing behind this seam is what guarantees that, and it is
/// also what lets <c>ChatHubTests</c> assert a push was raised without a network,
/// a scope, or a mocking library.
/// </remarks>
public interface IChatPushDispatcher
{
    /// <summary>
    /// Queues a notification to <paramref name="recipientId"/>. Returns
    /// immediately; delivery, failure and logging all happen elsewhere.
    /// </summary>
    void Queue(Guid recipientId, Guid senderId, string? body);
}
