using FitTracker.Api.Models;
using FitTracker.Api.Repositories;
using FitTracker.Api.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace FitTracker.Api.Tests;

/// <summary>
/// The persistence rules the client's retry logic leans on. The outbox resends a
/// message with its original id whenever it never saw an ack, so this layer's
/// dedup is the only thing standing between a flaky connection and duplicated
/// messages.
/// </summary>
public class ChatRepositoryTests
{
    private static IChatRepository NewRepository(ChatScenario ctx) => new ChatRepository(ctx.Db);

    [Fact]
    public async Task Adding_the_same_id_twice_returns_the_stored_message_without_inserting_again()
    {
        using var ctx = new ChatScenario();
        var repo = NewRepository(ctx);
        var id = Guid.NewGuid();

        var first = await repo.AddMessageAsync(new ChatMessage
        {
            Id = id,
            TrainerClientId = ctx.Relationship.Id,
            SenderId = ctx.TrainerId,
            Body = "great set today",
        });

        var replayed = await repo.AddMessageAsync(new ChatMessage
        {
            Id = id,
            TrainerClientId = ctx.Relationship.Id,
            SenderId = ctx.TrainerId,
            Body = "great set today",
        });

        Assert.Single(await ctx.Db.ChatMessages.ToListAsync());
        // The *original* row comes back, timestamp included — a replay must not
        // look to the reader like a message sent twice minutes apart.
        Assert.Equal(first.SentAt, replayed.SentAt);
    }

    [Fact]
    public async Task An_id_belonging_to_another_pair_is_never_returned()
    {
        using var ctx = new ChatScenario();
        var otherClient = ctx.AddUser("Lena", "Fischer");
        var otherRelationship = ctx.AddRelationship(ctx.TrainerId, otherClient.Id);
        var repo = NewRepository(ctx);
        var id = Guid.NewGuid();

        await repo.AddMessageAsync(new ChatMessage
        {
            Id = id,
            TrainerClientId = ctx.Relationship.Id,
            SenderId = ctx.TrainerId,
            Body = "private to robert",
        });

        // Same id presented for a different thread. Matching on id alone would
        // hand back the other pair's message body as if it were this caller's own.
        await Assert.ThrowsAnyAsync<Exception>(() => repo.AddMessageAsync(new ChatMessage
        {
            Id = id,
            TrainerClientId = otherRelationship.Id,
            SenderId = ctx.TrainerId,
            Body = "different message",
        }));

        var stored = Assert.Single(await ctx.Db.ChatMessages.ToListAsync());
        Assert.Equal(ctx.Relationship.Id, stored.TrainerClientId);
    }

    [Fact]
    public async Task A_message_without_a_relationship_is_rejected_by_the_database()
    {
        using var ctx = new ChatScenario();
        var repo = NewRepository(ctx);

        // Guards the exact defect this suite was written for: ChatMessage reaches
        // its trainer/client pair only through TrainerClientId, so an unset one is
        // an orphan the schema must refuse rather than silently accept.
        await Assert.ThrowsAnyAsync<DbUpdateException>(() => repo.AddMessageAsync(new ChatMessage
        {
            Id = Guid.NewGuid(),
            SenderId = ctx.TrainerId,
            Body = "orphan",
        }));
    }

    [Fact]
    public async Task History_is_scoped_to_the_pair_and_ordered_oldest_first()
    {
        using var ctx = new ChatScenario();
        var otherClient = ctx.AddUser("Lena", "Fischer");
        var otherRelationship = ctx.AddRelationship(ctx.TrainerId, otherClient.Id);
        var start = new DateTime(2026, 8, 1, 9, 0, 0, DateTimeKind.Utc);
        ctx.AddMessage(ctx.Relationship.Id, ctx.TrainerId, "b", start.AddMinutes(1));
        ctx.AddMessage(ctx.Relationship.Id, ctx.TrainerId, "a", start);
        ctx.AddMessage(otherRelationship.Id, ctx.TrainerId, "not mine", start);

        var history = await NewRepository(ctx).GetChatHistoryAsync(ctx.TrainerId, ctx.ClientId, 50, deviceId: null);

        Assert.Equal(new[] { "a", "b" }, history.Select(m => m.Body));
    }

    [Fact]
    public async Task A_message_carries_only_the_requesting_devices_wrapped_key()
    {
        // Every device of both parties gets its own row, but a caller must never
        // see another device's wrap — not even its own other device's.
        using var ctx = new ChatScenario();
        var repo = NewRepository(ctx);

        await repo.AddMessageAsync(new ChatMessage
        {
            Id = Guid.NewGuid(),
            TrainerClientId = ctx.Relationship.Id,
            SenderId = ctx.TrainerId,
            Body = "cipher",
            Iv = "iv",
            EncryptionVersion = 2,
            EphemeralPublicKeyJwk = "epk",
            Keys =
            [
                new ChatMessageKey { DeviceId = "trainer-phone", WrappedKey = "wk-1", WrappedIv = "wi-1" },
                new ChatMessageKey { DeviceId = "trainer-desktop", WrappedKey = "wk-2", WrappedIv = "wi-2" },
            ],
        });

        var history = await repo.GetChatHistoryAsync(ctx.TrainerId, ctx.ClientId, 50, deviceId: "trainer-desktop");

        var message = Assert.Single(history);
        var key = Assert.Single(message.Keys);
        Assert.Equal("trainer-desktop", key.DeviceId);
        Assert.Equal("wk-2", key.WrappedKey);
    }

    [Fact]
    public async Task A_replayed_send_keeps_the_originally_stored_keys()
    {
        using var ctx = new ChatScenario();
        var repo = NewRepository(ctx);
        var id = Guid.NewGuid();

        await repo.AddMessageAsync(new ChatMessage
        {
            Id = id,
            TrainerClientId = ctx.Relationship.Id,
            SenderId = ctx.TrainerId,
            Body = "first attempt",
            EncryptionVersion = 2,
            Keys = [new ChatMessageKey { DeviceId = "phone", WrappedKey = "wk-first", WrappedIv = "wi-first" }],
        });

        var replayed = await repo.AddMessageAsync(new ChatMessage
        {
            Id = id,
            TrainerClientId = ctx.Relationship.Id,
            SenderId = ctx.TrainerId,
            Body = "second attempt, fresh content key",
            EncryptionVersion = 2,
            Keys = [new ChatMessageKey { DeviceId = "phone", WrappedKey = "wk-second", WrappedIv = "wi-second" }],
        });

        var key = Assert.Single(replayed.Keys);
        Assert.Equal("wk-first", key.WrappedKey);
    }
}
