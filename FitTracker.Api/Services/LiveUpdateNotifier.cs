using FitTracker.Api.Data;
using FitTracker.Api.DTOs;
using FitTracker.Api.Hubs;
using FitTracker.Api.Models;
using FitTracker.Api.Services.Interfaces;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;

namespace FitTracker.Api.Services;

/// <summary>
/// Tells the people who should know that a request changed someone's data. See
/// docs/sync-architecture.md, part four.
/// </summary>
/// <remarks>
/// <para>
/// Runs once per request, after it, on what the request committed
/// (<see cref="ChangedDataLog"/>), on a scope of its own (<see cref="LiveUpdateDispatcher"/>).
/// Each change arrives with its owner, resolved when it was written, so the only query here
/// is the one for the owners' Active trainers.
/// For each owner whose data changed it sends one <see cref="ClientDataChanged"/>, naming every
/// area that changed, to the groups of the trainers who have an <b>Active</b> relationship
/// with that owner — and nobody else: not a Pending invite, not an ended relationship, not
/// the owner. The event carries no data. The console fetches the named panes again through
/// its own endpoints, which check the relationship for themselves.
/// </para>
/// <para>
/// When the request was made by someone other than the owner — a trainer writing a client's
/// workout — the owner's devices are also asked to pull (<c>sync_requested</c>).
/// </para>
/// <para>
/// Every send is on its own: a hub that fails is logged and the push still goes, a push that
/// fails is logged and the next owner is still told. None of it can fail the request, which
/// finished before this began.
/// </para>
/// </remarks>
public class LiveUpdateNotifier(
    AppDbContext db,
    IHubContext<ChatHub> hub,
    IPushNotificationService push,
    ILogger<LiveUpdateNotifier> logger)
{
    /// <summary>The hub event a trainer's console receives.</summary>
    public const string ClientDataChanged = "ClientDataChanged";

    private readonly AppDbContext _db = db;
    private readonly IHubContext<ChatHub> _hub = hub;
    private readonly IPushNotificationService _push = push;
    private readonly ILogger<LiveUpdateNotifier> _logger = logger;

    /// <summary>Sends one event per owner to their Active trainers, and asks the owner's
    /// devices to pull when <paramref name="actorId"/> isn't the owner.</summary>
    /// <param name="actorId">Who made the request, or null when nobody was signed in — a
    /// request nobody made is not "someone else", so it asks for no pull.</param>
    /// <param name="changes">What the request committed, each already resolved to its owner
    /// when it was written.</param>
    public async Task NotifyAsync(Guid? actorId, IReadOnlyCollection<ChangedData> changes)
    {
        var areasByOwner = changes
            .GroupBy(c => c.Owner)
            .ToDictionary(g => g.Key, g => g.Select(c => c.Area).Distinct().Order(StringComparer.Ordinal).ToList());
        if (areasByOwner.Count == 0) return;

        // The one query, and the first thing done: whose trainers are there to tell.
        var owners = areasByOwner.Keys.ToList();
        var trainers = await _db.TrainerClients.AsNoTracking()
            .Where(r => r.Status == TrainerClientStatus.Active && r.ClientId != null && owners.Contains(r.ClientId.Value))
            .Select(r => new { ClientId = r.ClientId!.Value, r.TrainerId })
            .ToListAsync();

        // The common case, which is nearly every write: a user changing their own data with no
        // trainer watching. Nobody to send to and nobody to ask to pull.
        if (trainers.Count == 0 && owners.All(owner => owner == actorId)) return;

        foreach (var (owner, areas) in areasByOwner)
        {
            var groups = trainers
                .Where(t => t.ClientId == owner)
                .Select(t => ChatHub.TrainerGroup(t.TrainerId))
                .ToList();
            if (groups.Count > 0)
            {
                try
                {
                    await _hub.Clients.Groups(groups).SendAsync(ClientDataChanged, new ClientDataChangedDto(owner, areas));
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Could not tell the trainers of {OwnerId} that their data changed.", owner);
                }
            }

            if (actorId is { } actor && actor != owner)
            {
                try
                {
                    await _push.SendSyncRequestedAsync(owner);
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Could not ask the devices of {OwnerId} to pull.", owner);
                }
            }
        }
    }
}
