using FitTracker.Api.Repositories.Interfaces;
using FitTracker.Api.Services.Interfaces;

namespace FitTracker.Api.Services;

/// <summary>
/// Deletes chat attachment blobs and rows nothing references any more.
/// </summary>
/// <remarks>
/// <para>
/// Two separate passes, because they catch two different kinds of orphan.
/// <b>Orphan sweep</b> (every tick) deletes rows still uncommitted past their
/// grace period — a message that was never sent after its attachment
/// uploaded. <b>Reconciliation</b> (every <see cref="ReconciliationEveryTicks"/>
/// ticks) lists the bucket itself and deletes any object with no row at all —
/// the only thing that catches a blob orphaned by a <c>TrainerClient</c>
/// cascade delete, which removes the row and leaves the object. See
/// docs/chat-attachments.md §A.5 for why a lifecycle rule alone cannot do
/// either of these: a lifecycle rule can say "older than N days", it cannot
/// say "whose database row has a null CommittedAt".
/// </para>
/// <para>
/// Runs in its own DI scope per pass, the same reason
/// <see cref="ChatPushDispatcher"/> does: everything it needs is Scoped, and
/// a <see cref="BackgroundService"/> outlives any one request's scope.
/// </para>
/// <para>
/// Cloud Run scales to zero, so a tick can be missed entirely if no instance
/// is running. That delays deletion; it does not corrupt anything — the next
/// instance to boot picks up wherever the grace window left it. Deletes are a
/// free R2 operation (see docs/chat-attachments.md §A.9), so there is no cost
/// to sweeping often.
/// </para>
/// </remarks>
public class ChatAttachmentReaper(
    IServiceScopeFactory scopeFactory,
    ILogger<ChatAttachmentReaper> logger,
    IConfiguration configuration) : BackgroundService
{
    private readonly IServiceScopeFactory _scopeFactory = scopeFactory;
    private readonly ILogger<ChatAttachmentReaper> _logger = logger;
    private readonly IConfiguration _configuration = configuration;

    /// <summary>How often the orphan sweep runs. Reconciliation runs every
    /// <see cref="ReconciliationEveryTicks"/> of these.</summary>
    private TimeSpan SweepInterval => TimeSpan.FromHours(1);

    /// <summary>Reconciliation lists the whole bucket (Class A ops) — weekly by
    /// default is enough to catch a cascade-delete orphan without adding a
    /// meaningful cost. See docs/chat-attachments.md §A.9.</summary>
    private const int ReconciliationEveryTicks = 24 * 7;

    /// <summary>
    /// How long an uncommitted attachment survives before the orphan sweep
    /// deletes it.
    /// </summary>
    /// <remarks>
    /// A message's outbox row is always written on the client *before* its
    /// attachment is minted — see <c>ChatRepository.sendMessage</c> — so an
    /// uncommitted <c>ChatAttachment</c> almost never means "nobody intends to
    /// send this." Far more often it means the wire send itself hasn't
    /// happened yet: the device uploaded the file, then lost connectivity (or
    /// was closed) before <c>SendMessageV2</c> ever ran, and is waiting for a
    /// reconnect to replay it. The original 24-hour default treated that
    /// ordinary case as abandoned: a device offline for a day lost its
    /// attachment out from under a message its owner still meant to send, and
    /// found out only when the recipient's download 404'd on an envelope that
    /// still named it.
    ///
    /// Seven days is a real fix for the common case (an overnight-and-then-some
    /// outage, a phone left off over a weekend), not a complete one — a device
    /// offline longer than this still loses the blob, because the server has
    /// no way to distinguish "still trying" from "gave up" without the client
    /// declaring which message an upload belongs to before it commits, which
    /// nothing today does. Raising this further is cheap: deletes and storage
    /// both cost very little (docs/chat-attachments.md §A.9), so the honest
    /// tradeoff favours a long grace period over a short one wherever real
    /// message loss is the alternative.
    /// </remarks>
    private int OrphanGraceHours => _configuration.GetValue("Attachments:OrphanGraceHours", 24 * 7);

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(SweepInterval);
        var tick = 0;

        // Runs once immediately rather than waiting a full interval for the
        // first pass — an instance that only lives a few minutes (Cloud Run
        // scaling to zero) should still get one sweep in.
        do
        {
            try
            {
                await RunOrphanSweepAsync(stoppingToken);
                if (tick % ReconciliationEveryTicks == 0)
                {
                    await RunReconciliationAsync(stoppingToken);
                }
            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                // A failed pass costs a delayed deletion, not a crashed API — the
                // same posture as ChatPushDispatcher swallowing a failed push.
                _logger.LogError(ex, "Chat attachment reaper pass failed.");
            }

            tick++;
        } while (await timer.WaitForNextTickAsync(stoppingToken));
    }

    /// <summary>One orphan-sweep pass, exposed so it can be tested and
    /// triggered directly without running the background loop.</summary>
    public async Task RunOrphanSweepAsync(CancellationToken cancellationToken = default)
    {
        using var scope = _scopeFactory.CreateScope();
        var provider = scope.ServiceProvider;
        var store = provider.GetRequiredService<IChatAttachmentStore>();
        if (!store.IsConfigured) return;

        var repo = provider.GetRequiredService<IChatAttachmentRepository>();
        var cutoff = DateTime.UtcNow.AddHours(-OrphanGraceHours);
        var orphans = await repo.FindOrphanedAsync(cutoff);
        if (orphans.Count == 0) return;

        await store.DeleteManyAsync([.. orphans.Select(a => a.ObjectKey)], cancellationToken);
        await repo.DeleteRowsAsync([.. orphans.Select(a => a.Id)], cancellationToken);

        _logger.LogInformation("Chat attachment reaper: swept {Count} orphaned upload(s).", orphans.Count);
    }

    /// <summary>One reconciliation pass, exposed for the same reason as
    /// <see cref="RunOrphanSweepAsync"/>.</summary>
    public async Task RunReconciliationAsync(CancellationToken cancellationToken = default)
    {
        using var scope = _scopeFactory.CreateScope();
        var provider = scope.ServiceProvider;
        var store = provider.GetRequiredService<IChatAttachmentStore>();
        if (!store.IsConfigured) return;

        var repo = provider.GetRequiredService<IChatAttachmentRepository>();
        var bucketKeys = await store.ListKeysAsync("chat/", cancellationToken);
        if (bucketKeys.Count == 0) return;

        var knownKeys = await repo.FindKnownObjectKeysAsync(bucketKeys);
        var danglingKeys = bucketKeys.Except(knownKeys).ToList();
        if (danglingKeys.Count == 0) return;

        await store.DeleteManyAsync(danglingKeys, cancellationToken);

        _logger.LogInformation(
            "Chat attachment reaper: reconciliation deleted {Count} object(s) with no matching row.",
            danglingKeys.Count);
    }
}
