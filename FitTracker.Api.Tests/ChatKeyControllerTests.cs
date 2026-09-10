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
                trainerClientRepo, new TrainerLicenceRepository(ctx.Db), new TrainerNutrientPinRepository(ctx.Db),
                new UserNutrientPinRepository(ctx.Db), new RevenueCatSubscriptionRepository(ctx.Db)))
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
    public async Task Republishing_the_same_device_replaces_only_its_own_key()
    {
        // A reinstall cannot recover its old private key, so refusing the new
        // public key would leave that device permanently unable to send
        // anything the other side could read. The cost is that its older
        // messages stop being decryptable, which is the documented price of no
        // key backup. Both publishes here name no device id, so both land on
        // the same legacy row — reproducing the original single-key behaviour
        // exactly for a client that predates device ids.
        using var ctx = new ChatScenario();
        var controller = NewController(ctx, ctx.TrainerId);

        await controller.Publish(new PublishChatKeyRequestDto { PublicKeyJwk = AliceJwk });
        await controller.Publish(new PublishChatKeyRequestDto { PublicKeyJwk = BobJwk });

        Assert.Single(ctx.Db.UserChatKeys);
        Assert.Equal(BobJwk, OkValue<ChatKeyDto>(await controller.Me()).PublicKeyJwk);
    }

    [Fact]
    public async Task A_second_device_does_not_displace_the_first()
    {
        // This is the fix for the actual production incident: signing in on a
        // second device used to overwrite the only row this user's chat key
        // lived in, so the first device could no longer read anything —
        // including its own messages read back — and kept sending unreadably
        // to the peer. Two distinct device ids must both survive.
        using var ctx = new ChatScenario();
        var controller = NewController(ctx, ctx.TrainerId);

        await controller.Publish(
            new PublishChatKeyRequestDto { PublicKeyJwk = AliceJwk, DeviceId = "phone" });
        await controller.Publish(
            new PublishChatKeyRequestDto { PublicKeyJwk = BobJwk, DeviceId = "laptop" });

        Assert.Equal(2, ctx.Db.UserChatKeys.Count());

        var me = OkValue<ChatKeyDto>(await controller.Me());
        Assert.Equal(2, me.Devices.Count);
        Assert.Contains(me.Devices, d => d.DeviceId == "phone" && d.PublicKeyJwk == AliceJwk);
        Assert.Contains(me.Devices, d => d.DeviceId == "laptop" && d.PublicKeyJwk == BobJwk);
    }

    [Fact]
    public async Task Republishing_one_devices_key_leaves_the_others_untouched()
    {
        using var ctx = new ChatScenario();
        var controller = NewController(ctx, ctx.TrainerId);

        await controller.Publish(
            new PublishChatKeyRequestDto { PublicKeyJwk = AliceJwk, DeviceId = "phone" });
        await controller.Publish(
            new PublishChatKeyRequestDto { PublicKeyJwk = BobJwk, DeviceId = "laptop" });

        const string alicePhoneRotated =
            """{"kty":"EC","crv":"P-256","x":"alice-x2","y":"alice-y2"}""";
        await controller.Publish(
            new PublishChatKeyRequestDto { PublicKeyJwk = alicePhoneRotated, DeviceId = "phone" });

        var me = OkValue<ChatKeyDto>(await controller.Me());
        Assert.Equal(2, me.Devices.Count);
        Assert.Contains(me.Devices, d => d.DeviceId == "phone" && d.PublicKeyJwk == alicePhoneRotated);
        Assert.Contains(me.Devices, d => d.DeviceId == "laptop" && d.PublicKeyJwk == BobJwk);
    }

    [Fact]
    public async Task A_peer_lookup_reports_every_device()
    {
        using var ctx = new ChatScenario();
        await NewController(ctx, ctx.TrainerId).Publish(
            new PublishChatKeyRequestDto { PublicKeyJwk = AliceJwk, DeviceId = "phone" });
        await NewController(ctx, ctx.TrainerId).Publish(
            new PublishChatKeyRequestDto { PublicKeyJwk = BobJwk, DeviceId = "laptop" });

        var key = OkValue<ChatKeyDto>(
            await NewController(ctx, ctx.ClientId).Peer(ctx.TrainerId));

        Assert.Equal(2, key.Devices.Count);
        // The most-recently-seen device's key, for a client that predates
        // multi-device keys and only ever reads this field.
        Assert.Equal(BobJwk, key.PublicKeyJwk);
    }

    [Fact]
    public async Task A_sixth_device_evicts_the_least_recently_seen()
    {
        using var ctx = new ChatScenario();
        var controller = NewController(ctx, ctx.TrainerId);

        for (var i = 0; i < 5; i++)
        {
            await controller.Publish(new PublishChatKeyRequestDto
            {
                PublicKeyJwk = $$"""{"kty":"EC","crv":"P-256","x":"x{{i}}","y":"y{{i}}"}""",
                DeviceId = $"device-{i}",
            });
        }

        // Backdated directly rather than relying on real elapsed time between
        // five awaited round trips actually separating their timestamps —
        // real, but not something a test should depend on. This is what makes
        // device-0 unambiguously the least-recently-seen.
        var device0 = ctx.Db.UserChatKeys.Single(k => k.DeviceId == "device-0");
        device0.LastSeenAt = DateTime.UtcNow.AddDays(-30);
        await ctx.Db.SaveChangesAsync();

        await controller.Publish(new PublishChatKeyRequestDto
        {
            PublicKeyJwk = """{"kty":"EC","crv":"P-256","x":"x5","y":"y5"}""",
            DeviceId = "device-5",
        });

        var me = OkValue<ChatKeyDto>(await controller.Me());
        Assert.Equal(5, me.Devices.Count);
        Assert.DoesNotContain(me.Devices, d => d.DeviceId == "device-0");
        Assert.Contains(me.Devices, d => d.DeviceId == "device-5");
    }

    [Fact]
    public async Task An_old_client_with_no_device_id_writes_the_legacy_row_only()
    {
        // A build that predates device ids must not disturb a device-specific
        // row an updated client already published.
        using var ctx = new ChatScenario();
        var controller = NewController(ctx, ctx.TrainerId);

        await controller.Publish(
            new PublishChatKeyRequestDto { PublicKeyJwk = AliceJwk, DeviceId = "phone" });
        await controller.Publish(new PublishChatKeyRequestDto { PublicKeyJwk = BobJwk });

        var me = OkValue<ChatKeyDto>(await controller.Me());
        Assert.Equal(2, me.Devices.Count);
        Assert.Contains(me.Devices, d => d.DeviceId == "phone" && d.PublicKeyJwk == AliceJwk);
        Assert.Contains(
            me.Devices,
            d => d.DeviceId == UserChatKey.LegacyDeviceId && d.PublicKeyJwk == BobJwk);
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
