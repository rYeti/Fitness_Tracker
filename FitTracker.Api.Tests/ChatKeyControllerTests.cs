using System.Security.Claims;
using FitTracker.Api.Controllers;
using FitTracker.Api.DTOs;
using FitTracker.Api.Models;
using FitTracker.Api.Repositories;
using FitTracker.Api.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Xunit;

namespace FitTracker.Api.Tests;

/// <summary>
/// Covers the one endpoint that decides who may hold whose public key.
/// </summary>
/// <remarks>
/// A public key is not secret, and it is tempting to serve this route to anyone
/// who asks. The reason it is gated anyway is that "does this user id exist"
/// is an answer this API does not hand to strangers on any other route either —
/// and an ungated key lookup is a user-enumeration oracle with a nice name.
/// </remarks>
public class ChatKeyControllerTests
{
    private const string AliceJwk =
        """{"kty":"EC","crv":"P-256","x":"alice-x","y":"alice-y"}""";
    private const string BobJwk =
        """{"kty":"EC","crv":"P-256","x":"bob-x","y":"bob-y"}""";

    private static ChatKeyController NewController(ChatScenario ctx, Guid callerId)
    {
        var trainerClientRepo = new TrainerClientRepository(ctx.Db);
        return new ChatKeyController(
            new UserChatKeyRepository(ctx.Db),
            new TrainerClientService(
                trainerClientRepo, new TrainerLicenceRepository(ctx.Db), new TrainerNutrientPinRepository(ctx.Db)))
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
    }

    private static T OkValue<T>(IActionResult result)
    {
        var ok = Assert.IsType<OkObjectResult>(result);
        return Assert.IsAssignableFrom<T>(ok.Value!);
    }

    [Fact]
    public async Task A_published_key_comes_back_to_the_other_party()
    {
        using var ctx = new ChatScenario();

        await NewController(ctx, ctx.TrainerId)
            .Publish(new PublishChatKeyRequestDto { PublicKeyJwk = AliceJwk });

        var key = OkValue<ChatKeyDto>(
            await NewController(ctx, ctx.ClientId).Peer(ctx.TrainerId));

        Assert.Equal(ctx.TrainerId, key.UserId);
        Assert.Equal(AliceJwk, key.PublicKeyJwk);
    }

    [Fact]
    public async Task Me_reports_the_callers_own_id()
    {
        // The load-bearing half of this response. The Flutter client has no user
        // id of its own, and the key store needs one to tell its own identity
        // key from the one belonging to whoever used this device last.
        using var ctx = new ChatScenario();

        var me = OkValue<ChatKeyDto>(await NewController(ctx, ctx.TrainerId).Me());

        Assert.Equal(ctx.TrainerId, me.UserId);
        Assert.Null(me.PublicKeyJwk);
    }

    [Fact]
    public async Task Me_reports_a_key_once_one_is_published()
    {
        using var ctx = new ChatScenario();
        var controller = NewController(ctx, ctx.TrainerId);

        await controller.Publish(new PublishChatKeyRequestDto { PublicKeyJwk = AliceJwk });

        Assert.Equal(AliceJwk, OkValue<ChatKeyDto>(await controller.Me()).PublicKeyJwk);
    }

    [Fact]
    public async Task Republishing_replaces_the_previous_key()
    {
        // A reinstall cannot recover its old private key, so refusing the new
        // public key would leave that user permanently unable to send anything
        // the other side could read. The cost is that their older messages stop
        // being decryptable, which is the documented price of no key backup.
        using var ctx = new ChatScenario();
        var controller = NewController(ctx, ctx.TrainerId);

        await controller.Publish(new PublishChatKeyRequestDto { PublicKeyJwk = AliceJwk });
        await controller.Publish(new PublishChatKeyRequestDto { PublicKeyJwk = BobJwk });

        Assert.Single(ctx.Db.UserChatKeys);
        Assert.Equal(BobJwk, OkValue<ChatKeyDto>(await controller.Me()).PublicKeyJwk);
    }

    [Fact]
    public async Task A_user_with_no_relationship_cannot_read_a_key()
    {
        using var ctx = new ChatScenario();
        var stranger = ctx.AddUser("Ivy", "Stone");
        await NewController(ctx, ctx.TrainerId)
            .Publish(new PublishChatKeyRequestDto { PublicKeyJwk = AliceJwk });

        var result = await NewController(ctx, stranger.Id).Peer(ctx.TrainerId);

        Assert.IsType<UnauthorizedResult>(result);
    }

    [Fact]
    public async Task A_revoked_relationship_cannot_read_a_key()
    {
        using var ctx = new ChatScenario();
        var former = ctx.AddUser("Ivy", "Stone");
        ctx.AddRelationship(ctx.TrainerId, former.Id, TrainerClientStatus.Revoked);
        await NewController(ctx, ctx.TrainerId)
            .Publish(new PublishChatKeyRequestDto { PublicKeyJwk = AliceJwk });

        var result = await NewController(ctx, former.Id).Peer(ctx.TrainerId);

        Assert.IsType<UnauthorizedResult>(result);
    }

    [Fact]
    public async Task A_party_who_has_never_published_a_key_is_a_404()
    {
        // An ordinary state, not a failure: they simply have not opened the app
        // since encryption shipped. The client says so rather than failing the
        // thread.
        using var ctx = new ChatScenario();

        var result = await NewController(ctx, ctx.ClientId).Peer(ctx.TrainerId);

        Assert.IsType<NotFoundResult>(result);
    }

    [Fact]
    public async Task An_empty_key_is_rejected()
    {
        using var ctx = new ChatScenario();

        var result = await NewController(ctx, ctx.TrainerId)
            .Publish(new PublishChatKeyRequestDto { PublicKeyJwk = "   " });

        Assert.IsType<BadRequestObjectResult>(result);
        Assert.Empty(ctx.Db.UserChatKeys);
    }

    [Fact]
    public async Task Either_side_of_the_pair_can_read_the_other()
    {
        // One code path serves both roles, the same two-probe resolution
        // ChatController and ChatHub use.
        using var ctx = new ChatScenario();
        await NewController(ctx, ctx.ClientId)
            .Publish(new PublishChatKeyRequestDto { PublicKeyJwk = BobJwk });

        var key = OkValue<ChatKeyDto>(
            await NewController(ctx, ctx.TrainerId).Peer(ctx.ClientId));

        Assert.Equal(BobJwk, key.PublicKeyJwk);
    }
}
