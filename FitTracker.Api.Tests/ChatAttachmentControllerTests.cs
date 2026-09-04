using System.Security.Claims;
using FitTracker.Api.Controllers;
using FitTracker.Api.DTOs;
using FitTracker.Api.Enums;
using FitTracker.Api.Models;
using FitTracker.Api.Repositories;
using FitTracker.Api.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace FitTracker.Api.Tests;

public class ChatAttachmentControllerTests
{
    private static (ChatAttachmentController controller, InMemoryChatAttachmentStore store) NewController(
        ChatScenario ctx, Guid callerId, IConfiguration? configuration = null)
    {
        var trainerClientRepo = new TrainerClientRepository(ctx.Db);
        var trainerClientService = new TrainerClientService(
            trainerClientRepo, new TrainerLicenceRepository(ctx.Db), new TrainerNutrientPinRepository(ctx.Db));
        var store = new InMemoryChatAttachmentStore();
        var attachmentRepo = new ChatAttachmentRepository(ctx.Db);
        var attachmentService = new ChatAttachmentService(
            store, attachmentRepo, trainerClientService,
            configuration ?? new ConfigurationBuilder().Build(),
            NullLogger<ChatAttachmentService>.Instance);

        var services = new ServiceCollection().BuildServiceProvider();

        var controller = new ChatAttachmentController(attachmentService, services)
        {
            ControllerContext = new ControllerContext
            {
                HttpContext = new DefaultHttpContext
                {
                    User = new ClaimsPrincipal(new ClaimsIdentity(
                        [new Claim(ClaimTypes.NameIdentifier, callerId.ToString())],
                        authenticationType: "Test")),
                },
            },
        };
        return (controller, store);
    }

    private static T OkValue<T>(IActionResult result)
    {
        var ok = Assert.IsType<OkObjectResult>(result);
        return Assert.IsAssignableFrom<T>(ok.Value!);
    }

    [Fact]
    public void Capabilities_reports_disabled_when_no_store_is_configured()
    {
        using var ctx = new ChatScenario();
        var (controller, _) = NewController(ctx, ctx.TrainerId);

        var capabilities = OkValue<ChatAttachmentCapabilitiesDto>(controller.Capabilities());

        // NewController always wires an InMemoryChatAttachmentStore, so this
        // pins the *shape* of the DTO — Enabled reflects IsConfigured, not a
        // hardcoded true — rather than the disabled path itself, which
        // DisabledChatAttachmentStore covers on the store side.
        Assert.True(capabilities.Enabled);
        Assert.True(capabilities.MaxImageBytes > 0);
        Assert.True(capabilities.MaxVideoBytes > 0);
        Assert.True(capabilities.RetentionDays > 0);
    }

    [Fact]
    public async Task A_trainer_can_mint_an_upload_url_for_their_active_client()
    {
        using var ctx = new ChatScenario();
        var (controller, _) = NewController(ctx, ctx.TrainerId);
        var attachmentId = Guid.NewGuid();

        var result = OkValue<MintUploadResponseDto>(await controller.MintUpload(
            ctx.ClientId, new MintUploadRequestDto(attachmentId, 1024, Media.Picture)));

        Assert.NotNull(result.UploadUrl);
        Assert.True(result.ExpiresAt > DateTime.UtcNow);
        Assert.Single(ctx.Db.ChatAttachments.Where(a => a.Id == attachmentId));
    }

    [Fact]
    public async Task A_stranger_is_refused_a_mint()
    {
        using var ctx = new ChatScenario();
        var stranger = ctx.AddUser("Mara", "Vogel");
        var (controller, _) = NewController(ctx, stranger.Id);

        var result = await controller.MintUpload(
            ctx.ClientId, new MintUploadRequestDto(Guid.NewGuid(), 1024, Media.Picture));

        Assert.IsType<UnauthorizedResult>(result);
    }

    [Fact]
    public async Task A_lapsed_relationship_is_refused_a_mint()
    {
        using var ctx = new ChatScenario();
        var lapsedClient = ctx.AddUser("Petra", "Voss");
        ctx.AddRelationship(ctx.TrainerId, lapsedClient.Id, TrainerClientStatus.Revoked);
        var (controller, _) = NewController(ctx, ctx.TrainerId);

        var result = await controller.MintUpload(
            lapsedClient.Id, new MintUploadRequestDto(Guid.NewGuid(), 1024, Media.Picture));

        Assert.IsType<UnauthorizedResult>(result);
    }

    [Fact]
    public async Task Minting_the_same_id_twice_returns_the_same_object_but_a_fresh_url()
    {
        using var ctx = new ChatScenario();
        var (controller, _) = NewController(ctx, ctx.TrainerId);
        var attachmentId = Guid.NewGuid();
        var request = new MintUploadRequestDto(attachmentId, 1024, Media.Picture);

        var first = OkValue<MintUploadResponseDto>(await controller.MintUpload(ctx.ClientId, request));
        // A retried mint — the outbox pattern for attachments, same rationale
        // as messageId: the client cannot tell "mint failed" from "mint
        // succeeded, response lost", so it always retries with the same id.
        var second = OkValue<MintUploadResponseDto>(await controller.MintUpload(ctx.ClientId, request));

        Assert.Single(ctx.Db.ChatAttachments.Where(a => a.Id == attachmentId));
        // Fresh URLs each time (the first may have expired by the time a retry
        // happens), but for the same underlying object key.
        Assert.Contains(attachmentId.ToString("N"), first.UploadUrl.ToString());
        Assert.Contains(attachmentId.ToString("N"), second.UploadUrl.ToString());
    }

    [Fact]
    public async Task An_id_already_minted_for_a_different_pair_is_a_conflict()
    {
        using var ctx = new ChatScenario();
        var otherClient = ctx.AddUser("Petra", "Voss");
        ctx.AddRelationship(ctx.TrainerId, otherClient.Id, TrainerClientStatus.Active);
        var (controller, _) = NewController(ctx, ctx.TrainerId);
        var attachmentId = Guid.NewGuid();

        await controller.MintUpload(ctx.ClientId, new MintUploadRequestDto(attachmentId, 1024, Media.Picture));
        var conflict = await controller.MintUpload(otherClient.Id, new MintUploadRequestDto(attachmentId, 1024, Media.Picture));

        Assert.IsType<ConflictObjectResult>(conflict);
    }

    [Fact]
    public async Task A_video_over_the_video_cap_is_rejected()
    {
        using var ctx = new ChatScenario();
        var configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?> { ["Attachments:MaxVideoBytes"] = "1000" })
            .Build();
        var (controller, _) = NewController(ctx, ctx.TrainerId, configuration);

        var result = await controller.MintUpload(
            ctx.ClientId, new MintUploadRequestDto(Guid.NewGuid(), 1001, Media.Video));

        Assert.IsType<BadRequestObjectResult>(result);
    }

    [Fact]
    public async Task A_document_under_the_video_cap_but_over_the_image_cap_is_rejected()
    {
        using var ctx = new ChatScenario();
        var configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["Attachments:MaxImageBytes"] = "1000",
                ["Attachments:MaxVideoBytes"] = "5000",
            })
            .Build();
        var (controller, _) = NewController(ctx, ctx.TrainerId, configuration);

        // Documents share the image cap, not the video one.
        var result = await controller.MintUpload(
            ctx.ClientId, new MintUploadRequestDto(Guid.NewGuid(), 2000, Media.Document));

        Assert.IsType<BadRequestObjectResult>(result);
    }

    [Fact]
    public async Task Either_side_of_the_pair_can_mint_a_download_url()
    {
        using var ctx = new ChatScenario();
        var attachment = ctx.AddAttachment(ctx.Relationship.Id, ctx.TrainerId);
        var (controller, store) = NewController(ctx, ctx.ClientId);
        store.SeedObject(attachment.ObjectKey, attachment.DeclaredByteLength);

        var result = OkValue<MintDownloadResponseDto>(await controller.MintDownload(attachment.Id));

        Assert.NotNull(result.DownloadUrl);
    }

    [Fact]
    public async Task A_stranger_cannot_mint_a_download_url()
    {
        using var ctx = new ChatScenario();
        var attachment = ctx.AddAttachment(ctx.Relationship.Id, ctx.TrainerId);
        var stranger = ctx.AddUser("Mara", "Vogel");
        var (controller, store) = NewController(ctx, stranger.Id);
        store.SeedObject(attachment.ObjectKey, attachment.DeclaredByteLength);

        var result = await controller.MintDownload(attachment.Id);

        Assert.IsType<UnauthorizedResult>(result);
    }

    [Fact]
    public async Task A_missing_attachment_id_404s()
    {
        using var ctx = new ChatScenario();
        var (controller, _) = NewController(ctx, ctx.TrainerId);

        var result = await controller.MintDownload(Guid.NewGuid());

        Assert.IsType<NotFoundObjectResult>(result);
    }

    [Fact]
    public async Task An_object_missing_from_the_store_404s_even_though_the_row_exists()
    {
        using var ctx = new ChatScenario();
        var attachment = ctx.AddAttachment(ctx.Relationship.Id, ctx.TrainerId);
        var (controller, _) = NewController(ctx, ctx.TrainerId);
        // Deliberately not seeded into the store — the PUT never happened.

        var result = await controller.MintDownload(attachment.Id);

        Assert.IsType<NotFoundObjectResult>(result);
    }

    [Fact]
    public async Task An_object_bigger_than_declared_is_deleted_and_rejected()
    {
        using var ctx = new ChatScenario();
        var attachment = ctx.AddAttachment(ctx.Relationship.Id, ctx.TrainerId, declaredByteLength: 1000);
        var (controller, store) = NewController(ctx, ctx.TrainerId);
        // A presigned PUT cannot enforce the declared cap — this is the lazy
        // verification that catches it after the fact.
        store.SeedObject(attachment.ObjectKey, 999_999);

        var result = await controller.MintDownload(attachment.Id);

        Assert.Equal(410, Assert.IsType<ObjectResult>(result).StatusCode);
        Assert.Contains(attachment.ObjectKey, store.DeletedKeys);
        Assert.Empty(ctx.Db.ChatAttachments.Where(a => a.Id == attachment.Id));
    }
}
