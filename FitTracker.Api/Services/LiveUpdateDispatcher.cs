using FitTracker.Api.Data;
using FitTracker.Api.Services.Interfaces;

namespace FitTracker.Api.Services;

/// <summary>
/// Runs <see cref="LiveUpdateNotifier"/> on a detached task with its own DI scope, after the
/// request that made the changes. See docs/sync-architecture.md, part four.
/// </summary>
/// <remarks>
/// <para>
/// The pattern is <see cref="ChatPushDispatcher"/>'s, and so is the reason for the scope: the
/// request's is disposed once it answers, and the notifier queries the database.
/// </para>
/// <para>
/// <c>docs/chat-architecture.md</c> §18 warns against copying that pattern into an ordinary
/// request, and the warning is right in general: Cloud Run only guarantees CPU while a request
/// is in flight, and work detached from one that has answered is throttled. Here it costs
/// less than it looks, and never correctness:
/// </para>
/// <list type="bullet">
///   <item>The SignalR event can only reach connections on this instance, and an instance
///   holding one — a trainer's console — has a request in flight for as long as it is open, so
///   it keeps its CPU. An instance holding none has nobody to send to.</item>
///   <item>The push goes out when a trainer changes a client's data, and a trainer does that
///   from the console, which holds such a socket.</item>
///   <item>Either one lost is an update that arrives later: the console fetches again when it
///   regains focus or reconnects, and the app pulls when it is next opened.</item>
/// </list>
/// <para>
/// Waiting instead would put a query, a hub send and a round trip to Google in front of every
/// write's answer.
/// </para>
/// </remarks>
public class LiveUpdateDispatcher(
    IServiceScopeFactory scopeFactory,
    ILogger<LiveUpdateDispatcher> logger) : ILiveUpdateDispatcher
{
    private readonly IServiceScopeFactory _scopeFactory = scopeFactory;
    private readonly ILogger<LiveUpdateDispatcher> _logger = logger;

    /// <inheritdoc/>
    public void Queue(Guid? actorId, IReadOnlyCollection<ChangedData> changes)
    {
        _ = Task.Run(async () =>
        {
            try
            {
                await using var scope = _scopeFactory.CreateAsyncScope();
                await scope.ServiceProvider.GetRequiredService<LiveUpdateNotifier>().NotifyAsync(actorId, changes);
            }
            catch (Exception ex)
            {
                // Nothing is left to throw to. Unobserved, this is a warning at best and the
                // process at worst, over a notification.
                _logger.LogError(ex, "Failed to send the live updates for a request by {ActorId}.", actorId);
            }
        });
    }
}
