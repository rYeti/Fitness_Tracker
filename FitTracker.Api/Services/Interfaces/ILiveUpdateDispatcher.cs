using FitTracker.Api.Data;

namespace FitTracker.Api.Services.Interfaces;

/// <summary>
/// Hands what a request committed to <c>LiveUpdateNotifier</c>, off the request.
/// </summary>
/// <remarks>
/// The same seam as <see cref="IChatPushDispatcher"/>, for the same two reasons: nothing
/// slow or third-party sits in front of the response, and a test can see what was queued
/// without a scope, a hub or a network.
/// </remarks>
public interface ILiveUpdateDispatcher
{
    /// <summary>Queues the notifications for <paramref name="changes"/>, made by
    /// <paramref name="actorId"/> (null when the request had no signed-in user). Returns
    /// immediately; delivery, failure and logging all happen elsewhere.</summary>
    void Queue(Guid? actorId, IReadOnlyCollection<ChangedData> changes);
}
