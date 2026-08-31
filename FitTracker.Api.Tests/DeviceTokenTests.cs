using FitTracker.Api.DTOs;
using FitTracker.Api.Models;
using FitTracker.Api.Repositories;
using FitTracker.Api.Services;
using FitTracker.Api.Services.Interfaces;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace FitTracker.Api.Tests;

/// <summary>
/// The token table's one interesting rule and the send path's one destructive
/// one: a token moves between users, and a token FCM rejects is deleted.
/// </summary>
public class DeviceTokenTests
{
    [Fact]
    public async Task Registering_a_token_a_second_user_now_holds_moves_it()
    {
        using var ctx = new ChatScenario();
        var repo = new DeviceTokenRepository(ctx.Db);
        const string token = "fcm-token-from-one-phone";

        await repo.UpsertAsync(ctx.TrainerId, token, DevicePlatform.Android);
        await repo.UpsertAsync(ctx.ClientId, token, DevicePlatform.Android);

        // One row, reassigned. A second row would mean the phone kept receiving
        // the previous user's messages after somebody else signed in on it —
        // the worst outcome this table can produce.
        Assert.Empty(await repo.GetForUserAsync(ctx.TrainerId));
        var moved = Assert.Single(await repo.GetForUserAsync(ctx.ClientId));
        Assert.Equal(token, moved.Token);
    }

    [Fact]
    public async Task A_user_can_be_registered_on_several_devices()
    {
        using var ctx = new ChatScenario();
        var repo = new DeviceTokenRepository(ctx.Db);

        await repo.UpsertAsync(ctx.TrainerId, "phone", DevicePlatform.Android);
        await repo.UpsertAsync(ctx.TrainerId, "tablet", DevicePlatform.Android);

        Assert.Equal(2, (await repo.GetForUserAsync(ctx.TrainerId)).Count);
    }

    [Fact]
    public async Task Unregistering_removes_the_token()
    {
        using var ctx = new ChatScenario();
        var repo = new DeviceTokenRepository(ctx.Db);
        await repo.UpsertAsync(ctx.TrainerId, "phone", DevicePlatform.Android);

        Assert.True(await repo.DeleteAsync("phone"));
        Assert.False(await repo.DeleteAsync("phone"));
        Assert.Empty(await repo.GetForUserAsync(ctx.TrainerId));
    }

    [Fact]
    public async Task Dead_tokens_are_pruned_and_live_ones_kept()
    {
        using var ctx = new ChatScenario();
        var repo = new DeviceTokenRepository(ctx.Db);
        await repo.UpsertAsync(ctx.ClientId, "uninstalled", DevicePlatform.Android);
        await repo.UpsertAsync(ctx.ClientId, "still-here", DevicePlatform.Android);

        var sender = new RecordingPushSender { Dead = ["uninstalled"] };
        var service = new PushNotificationService(
            repo, sender, NullLogger<PushNotificationService>.Instance);

        await service.SendChatMessageAsync(
            ctx.ClientId, "Dana Ruiz", Guid.NewGuid(), Encrypted("how did it go?"), ctx.TrainerId);

        // Left in place, a token for an uninstalled app is retried on every
        // message to that user forever.
        var remaining = await repo.GetForUserAsync(ctx.ClientId);
        Assert.Equal("still-here", Assert.Single(remaining).Token);
    }

    /// <summary>A body as a current client hands it over.</summary>
    private static EncryptedChatBody Encrypted(string body) => new(body, "iv-1", 1);

    [Fact]
    public async Task The_notification_carries_the_sender_and_the_thread()
    {
        using var ctx = new ChatScenario();
        var repo = new DeviceTokenRepository(ctx.Db);
        await repo.UpsertAsync(ctx.ClientId, "phone", DevicePlatform.Android);

        var sender = new RecordingPushSender();
        var service = new PushNotificationService(
            repo, sender, NullLogger<PushNotificationService>.Instance);

        await service.SendChatMessageAsync(
            ctx.ClientId, "Dana Ruiz", Guid.NewGuid(), Encrypted("how did it go?"), ctx.TrainerId);

        var (tokens, message) = Assert.Single(sender.Sent);
        Assert.Equal(["phone"], tokens);
        Assert.Equal("chat_message", message.Data["type"]);
        // A display name is not message content, so it still travels in the
        // clear and a notification can say who it is from.
        Assert.Equal("Dana Ruiz", message.Data["senderName"]);
        // The ciphertext, forwarded untouched. The recipient's device is the
        // only thing that turns this into words.
        Assert.Equal("how did it go?", message.Data["ciphertext"]);
        Assert.Equal("iv-1", message.Data["iv"]);
        Assert.Equal("1", message.Data["encryptionVersion"]);
        // The thread is the sender: from the recipient's side of the
        // conversation, the sender is the other party.
        Assert.Equal(ctx.TrainerId.ToString(), message.Data["threadId"]);
    }

    [Fact]
    public async Task A_body_too_large_for_the_payload_is_dropped_rather_than_truncated()
    {
        using var ctx = new ChatScenario();
        var repo = new DeviceTokenRepository(ctx.Db);
        await repo.UpsertAsync(ctx.ClientId, "phone", DevicePlatform.Android);

        var sender = new RecordingPushSender();
        var service = new PushNotificationService(
            repo, sender, NullLogger<PushNotificationService>.Instance);

        await service.SendChatMessageAsync(
            ctx.ClientId,
            "Dana Ruiz",
            Guid.NewGuid(),
            Encrypted(new string('x', 4000)),
            ctx.TrainerId);

        // Chop a byte off an AES-GCM payload and the tag fails, which the client
        // correctly reads as tampering. So an over-long body cannot be shortened
        // the way the old plaintext preview was — it is left out entirely and the
        // device shows the sender's name alone.
        var message = Assert.Single(sender.Sent).message;
        Assert.False(message.Data.ContainsKey("ciphertext"));
        Assert.Equal("Dana Ruiz", message.Data["senderName"]);
    }

    [Fact]
    public async Task A_message_with_no_body_still_reaches_the_device()
    {
        using var ctx = new ChatScenario();
        var repo = new DeviceTokenRepository(ctx.Db);
        await repo.UpsertAsync(ctx.ClientId, "phone", DevicePlatform.Android);

        var sender = new RecordingPushSender();
        var service = new PushNotificationService(
            repo, sender, NullLogger<PushNotificationService>.Instance);

        await service.SendChatMessageAsync(
            ctx.ClientId, "Dana Ruiz", Guid.NewGuid(), new EncryptedChatBody(null, null, 1), ctx.TrainerId);

        // This used to assert the server wrote "Sent a message" into the body.
        // It cannot write anything any more, so the check moved to what it can
        // still guarantee: the push goes out, and it names the sender, so the
        // device has enough to draw something a user can interpret.
        var message = Assert.Single(sender.Sent).message;
        Assert.False(message.Data.ContainsKey("ciphertext"));
        Assert.Equal("Dana Ruiz", message.Data["senderName"]);
    }

    [Fact]
    public async Task A_recipient_with_no_devices_costs_nothing()
    {
        using var ctx = new ChatScenario();
        var sender = new RecordingPushSender();
        var service = new PushNotificationService(
            new DeviceTokenRepository(ctx.Db), sender, NullLogger<PushNotificationService>.Instance);

        await service.SendChatMessageAsync(
            ctx.ClientId, "Dana Ruiz", Guid.NewGuid(), Encrypted("hello"), ctx.TrainerId);

        // Normal, not an error: most users are reachable on some devices and not
        // others, and a user who has never installed the app has none.
        Assert.Empty(sender.Sent);
    }

    private sealed class RecordingPushSender : IPushSender
    {
        public List<(IReadOnlyList<string> tokens, PushMessage message)> Sent { get; } = [];
        public List<string> Dead { get; set; } = [];

        public bool IsConfigured => true;

        public Task<PushSendResult> SendAsync(
            IReadOnlyList<string> tokens,
            PushMessage message,
            CancellationToken cancellationToken = default)
        {
            Sent.Add((tokens, message));
            return Task.FromResult(new PushSendResult(Dead));
        }
    }
}
