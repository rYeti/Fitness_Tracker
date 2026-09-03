using FitTracker.Api.Repositories;
using FitTracker.Api.Repositories.Interfaces;
using FitTracker.Api.Services;
using FitTracker.Api.Services.Interfaces;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace FitTracker.Api.Tests;

public class ChatAttachmentReaperTests
{
    private static (ChatAttachmentReaper reaper, InMemoryChatAttachmentStore store) NewReaper(ChatScenario ctx, int orphanGraceHours = 24)
    {
        var store = new InMemoryChatAttachmentStore();
        var services = new ServiceCollection();
        services.AddSingleton<IChatAttachmentStore>(store);
        services.AddScoped<IChatAttachmentRepository>(_ => new ChatAttachmentRepository(ctx.Db));
        var provider = services.BuildServiceProvider();

        var configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["Attachments:OrphanGraceHours"] = orphanGraceHours.ToString(),
            })
            .Build();

        var reaper = new ChatAttachmentReaper(
            provider.GetRequiredService<IServiceScopeFactory>(),
            NullLogger<ChatAttachmentReaper>.Instance,
            configuration);

        return (reaper, store);
    }

    [Fact]
    public async Task Sweeps_an_uncommitted_attachment_past_its_grace_period()
    {
        using var ctx = new ChatScenario();
        var (reaper, store) = NewReaper(ctx);
        var attachment = ctx.AddAttachment(ctx.Relationship.Id, ctx.TrainerId, createdAt: DateTime.UtcNow.AddHours(-48));
        store.SeedObject(attachment.ObjectKey, attachment.DeclaredByteLength);

        await reaper.RunOrphanSweepAsync();

        Assert.Contains(attachment.ObjectKey, store.DeletedKeys);
        Assert.Empty(ctx.Db.ChatAttachments.Where(a => a.Id == attachment.Id));
    }

    [Fact]
    public async Task Does_not_sweep_a_committed_attachment()
    {
        using var ctx = new ChatScenario();
        var (reaper, store) = NewReaper(ctx);
        var attachment = ctx.AddAttachment(
            ctx.Relationship.Id, ctx.TrainerId,
            createdAt: DateTime.UtcNow.AddHours(-48),
            committedAt: DateTime.UtcNow.AddHours(-47),
            messageId: Guid.NewGuid());
        store.SeedObject(attachment.ObjectKey, attachment.DeclaredByteLength);

        await reaper.RunOrphanSweepAsync();

        Assert.DoesNotContain(attachment.ObjectKey, store.DeletedKeys);
        Assert.Single(ctx.Db.ChatAttachments.Where(a => a.Id == attachment.Id));
    }

    [Fact]
    public async Task Does_not_sweep_an_uncommitted_attachment_still_within_its_grace_period()
    {
        using var ctx = new ChatScenario();
        var (reaper, store) = NewReaper(ctx);
        var attachment = ctx.AddAttachment(ctx.Relationship.Id, ctx.TrainerId, createdAt: DateTime.UtcNow.AddMinutes(-5));
        store.SeedObject(attachment.ObjectKey, attachment.DeclaredByteLength);

        await reaper.RunOrphanSweepAsync();

        Assert.DoesNotContain(attachment.ObjectKey, store.DeletedKeys);
        Assert.Single(ctx.Db.ChatAttachments.Where(a => a.Id == attachment.Id));
    }

    [Fact]
    public async Task Reconciliation_deletes_a_bucket_object_with_no_matching_row()
    {
        using var ctx = new ChatScenario();
        var (reaper, store) = NewReaper(ctx);
        // Simulates a blob orphaned by a TrainerClient cascade delete: the row
        // is gone, but nobody told the bucket.
        store.SeedObject($"chat/{ctx.Relationship.Id:N}/{Guid.NewGuid():N}", 1024);

        await reaper.RunReconciliationAsync();

        Assert.Empty(store.Objects);
    }

    [Fact]
    public async Task Reconciliation_leaves_a_bucket_object_that_has_a_matching_row_alone()
    {
        using var ctx = new ChatScenario();
        var (reaper, store) = NewReaper(ctx);
        var attachment = ctx.AddAttachment(ctx.Relationship.Id, ctx.TrainerId);
        store.SeedObject(attachment.ObjectKey, attachment.DeclaredByteLength);

        await reaper.RunReconciliationAsync();

        Assert.Contains(attachment.ObjectKey, store.Objects.Keys);
    }
}
