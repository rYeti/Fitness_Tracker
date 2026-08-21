using FitTracker.Api.Models;
using FitTracker.Api.Repositories;
using FitTracker.Api.Services;
using FitTracker.Api.Services.Interfaces;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace FitTracker.Api.Tests;

/// <summary>
/// Covers <see cref="ChatService"/> against a real (Sqlite) database, because the
/// two defects these tests were written for are both invisible at the C# level —
/// one is a foreign key the compiler never checks, the other is a pair of
/// same-typed arguments in the wrong order.
/// </summary>
public class ChatServiceTests
{
    private static IChatService NewService(ChatScenario ctx) =>
        new ChatService(new TrainerClientRepository(ctx.Db), new ChatRepository(ctx.Db));

    // ── Sending ───────────────────────────────────────────────────────────────

    [Fact]
    public async Task SendMessage_persists_the_message_for_an_active_pair()
    {
        using var ctx = new ChatScenario();
        var service = NewService(ctx);
        var messageId = Guid.NewGuid();

        var dto = await service.SendMessageAsync(
            trainerId: ctx.TrainerId,
            clientId: ctx.ClientId,
            senderId: ctx.TrainerId,
            messageId: messageId,
            "great set today");

        Assert.Equal(messageId, dto.Id);
        Assert.Equal("great set today", dto.Body);
        Assert.Equal(ctx.TrainerId, dto.SenderId);
        Assert.Equal(ctx.TrainerId, dto.TrainerId);
        Assert.Equal(ctx.ClientId, dto.ClientId);

        // The row must be attached to the *relationship*, not floating free.
        // ChatMessage has no TrainerId/ClientId of its own — the pair is reached
        // through TrainerClientId, and leaving it unset violates the FK.
        var stored = await ctx.Db.ChatMessages.SingleAsync();
        Assert.Equal(ctx.Relationship.Id, stored.TrainerClientId);
    }

    [Fact]
    public async Task SendMessage_records_the_sender_when_the_client_is_the_one_writing()
    {
        using var ctx = new ChatScenario();
        var service = NewService(ctx);

        var dto = await service.SendMessageAsync(
            trainerId: ctx.TrainerId,
            clientId: ctx.ClientId,
            senderId: ctx.ClientId,
            messageId: Guid.NewGuid(),
            "felt easy, can we add weight?");

        // trainerId/clientId identify the thread; senderId says who spoke. The
        // client writing into their own thread must not be rewritten as the trainer.
        Assert.Equal(ctx.ClientId, dto.SenderId);
        Assert.Equal(ctx.TrainerId, dto.TrainerId);
        Assert.Equal(ctx.ClientId, dto.ClientId);
    }

    [Fact]
    public async Task SendMessage_rejects_a_pair_with_no_active_relationship()
    {
        using var ctx = new ChatScenario();
        var stranger = ctx.AddUser("Ivy", "Stone");
        var service = NewService(ctx);

        await Assert.ThrowsAnyAsync<Exception>(() => service.SendMessageAsync(
            trainerId: ctx.TrainerId,
            clientId: stranger.Id,
            senderId: ctx.TrainerId,
            messageId: Guid.NewGuid(),
            "should not land"));

        Assert.Empty(await ctx.Db.ChatMessages.ToListAsync());
    }

    [Fact]
    public async Task SendMessage_rejects_a_revoked_relationship()
    {
        using var ctx = new ChatScenario();
        var formerClient = ctx.AddUser("Sam", "Okafor");
        ctx.AddRelationship(ctx.TrainerId, formerClient.Id, TrainerClientStatus.Revoked);
        var service = NewService(ctx);

        await Assert.ThrowsAnyAsync<Exception>(() => service.SendMessageAsync(
            trainerId: ctx.TrainerId,
            clientId: formerClient.Id,
            senderId: ctx.TrainerId,
            messageId: Guid.NewGuid(),
            "should not land"));

        Assert.Empty(await ctx.Db.ChatMessages.ToListAsync());
    }

    [Fact]
    public async Task Sending_the_same_messageId_twice_stores_one_message()
    {
        using var ctx = new ChatScenario();
        var service = NewService(ctx);
        var messageId = Guid.NewGuid();

        var first = await service.SendMessageAsync(
            ctx.TrainerId, ctx.ClientId, ctx.TrainerId, messageId, "great set today");
        var replayed = await service.SendMessageAsync(
            ctx.TrainerId, ctx.ClientId, ctx.TrainerId, messageId, "great set today");

        // This is what makes the client's outbox replay safe: after a dropped
        // connection the client cannot know whether the first attempt landed, so
        // it always resends with the same id and lets the server decide.
        Assert.Single(await ctx.Db.ChatMessages.ToListAsync());
        Assert.Equal(first.Id, replayed.Id);
        Assert.Equal(first.SentAt, replayed.SentAt);
    }

    // ── History ───────────────────────────────────────────────────────────────

    [Fact]
    public async Task History_returns_the_pairs_messages_oldest_first()
    {
        using var ctx = new ChatScenario();
        var start = new DateTime(2026, 8, 1, 9, 0, 0, DateTimeKind.Utc);
        ctx.AddMessage(ctx.Relationship.Id, ctx.TrainerId, "first", start);
        ctx.AddMessage(ctx.Relationship.Id, ctx.ClientId, "second", start.AddMinutes(1));
        ctx.AddMessage(ctx.Relationship.Id, ctx.TrainerId, "third", start.AddMinutes(2));

        var history = await NewService(ctx).GetChatHistoryAsync(ctx.TrainerId, ctx.ClientId, 50);

        Assert.Equal(new[] { "first", "second", "third" }, history.Select(m => m.Body));
    }

    [Fact]
    public async Task History_takes_the_most_recent_messages_but_still_returns_them_oldest_first()
    {
        using var ctx = new ChatScenario();
        var start = new DateTime(2026, 8, 1, 9, 0, 0, DateTimeKind.Utc);
        for (var i = 0; i < 5; i++)
        {
            ctx.AddMessage(ctx.Relationship.Id, ctx.TrainerId, $"m{i}", start.AddMinutes(i));
        }

        var history = await NewService(ctx).GetChatHistoryAsync(ctx.TrainerId, ctx.ClientId, 2);

        // `range` is a message count, not a number of days — the two newest,
        // presented in reading order.
        Assert.Equal(new[] { "m3", "m4" }, history.Select(m => m.Body));
    }

    [Fact]
    public async Task History_does_not_leak_another_pairs_messages()
    {
        using var ctx = new ChatScenario();
        var otherClient = ctx.AddUser("Lena", "Fischer");
        var otherRelationship = ctx.AddRelationship(ctx.TrainerId, otherClient.Id);
        var start = new DateTime(2026, 8, 1, 9, 0, 0, DateTimeKind.Utc);
        ctx.AddMessage(ctx.Relationship.Id, ctx.TrainerId, "for robert", start);
        ctx.AddMessage(otherRelationship.Id, ctx.TrainerId, "for lena", start);

        var history = await NewService(ctx).GetChatHistoryAsync(ctx.TrainerId, ctx.ClientId, 50);

        Assert.Equal(new[] { "for robert" }, history.Select(m => m.Body));
    }

    [Fact]
    public async Task History_stamps_both_sides_of_the_pair_on_every_message()
    {
        using var ctx = new ChatScenario();
        ctx.AddMessage(ctx.Relationship.Id, ctx.ClientId, "hi coach",
            new DateTime(2026, 8, 1, 9, 0, 0, DateTimeKind.Utc));

        var history = await NewService(ctx).GetChatHistoryAsync(ctx.TrainerId, ctx.ClientId, 50);

        // The client relies on trainerId/clientId being present to decide which
        // side of the thread a bubble belongs on — it has no user id of its own.
        var message = Assert.Single(history);
        Assert.Equal(ctx.TrainerId, message.TrainerId);
        Assert.Equal(ctx.ClientId, message.ClientId);
        Assert.Equal(ctx.ClientId, message.SenderId);
    }

    // ── Conversations ─────────────────────────────────────────────────────────

    [Fact]
    public async Task Conversations_lists_one_row_per_active_relationship_with_the_last_message()
    {
        using var ctx = new ChatScenario();
        var otherClient = ctx.AddUser("Lena", "Fischer");
        var otherRelationship = ctx.AddRelationship(ctx.TrainerId, otherClient.Id);
        var start = new DateTime(2026, 8, 1, 9, 0, 0, DateTimeKind.Utc);
        ctx.AddMessage(ctx.Relationship.Id, ctx.TrainerId, "older", start);
        ctx.AddMessage(ctx.Relationship.Id, ctx.ClientId, "newest for robert", start.AddMinutes(5));
        ctx.AddMessage(otherRelationship.Id, ctx.TrainerId, "only one for lena", start.AddMinutes(1));

        var conversations = await NewService(ctx).GetConversationsAsync(ctx.TrainerId);

        Assert.Equal(2, conversations.Count);
        var robert = conversations.Single(c => c.OtherPartyId == ctx.ClientId);
        Assert.Equal("Robert Meyer", robert.OtherPartyName);
        Assert.Equal("newest for robert", robert.LastMessagePreview);
        Assert.Equal(start.AddMinutes(5), robert.LastMessageAt);
    }

    [Fact]
    public async Task Conversations_includes_a_client_who_has_never_sent_a_message()
    {
        using var ctx = new ChatScenario();

        var conversations = await NewService(ctx).GetConversationsAsync(ctx.TrainerId);

        // An empty thread is still a conversation — the roster row has to appear
        // or a trainer cannot start the first message.
        var only = Assert.Single(conversations);
        Assert.Equal(ctx.ClientId, only.OtherPartyId);
        Assert.Null(only.LastMessagePreview);
        Assert.Null(only.LastMessageAt);
        Assert.Equal(0, only.UnreadCount);
    }

    [Fact]
    public async Task Conversations_seen_from_the_clients_side_names_the_trainer()
    {
        using var ctx = new ChatScenario();

        var conversations = await NewService(ctx).GetConversationsAsync(ctx.ClientId);

        // One endpoint serves both roles: the "other party" is whoever the caller
        // is not.
        var only = Assert.Single(conversations);
        Assert.Equal(ctx.TrainerId, only.OtherPartyId);
        Assert.Equal("Dana Ruiz", only.OtherPartyName);
    }

    [Fact]
    public async Task Conversations_excludes_relationships_that_are_not_active()
    {
        using var ctx = new ChatScenario();
        var pending = ctx.AddUser("Nils", "Berg");
        ctx.AddRelationship(ctx.TrainerId, pending.Id, TrainerClientStatus.Pending);

        var conversations = await NewService(ctx).GetConversationsAsync(ctx.TrainerId);

        Assert.Equal(new[] { ctx.ClientId }, conversations.Select(c => c.OtherPartyId));
    }

    // ── Unread / read state ───────────────────────────────────────────────────

    [Fact]
    public async Task Unread_counts_the_other_partys_messages_when_the_thread_was_never_opened()
    {
        using var ctx = new ChatScenario();
        var start = new DateTime(2026, 8, 1, 9, 0, 0, DateTimeKind.Utc);
        ctx.AddMessage(ctx.Relationship.Id, ctx.ClientId, "one", start);
        ctx.AddMessage(ctx.Relationship.Id, ctx.ClientId, "two", start.AddMinutes(1));
        ctx.AddMessage(ctx.Relationship.Id, ctx.TrainerId, "my own reply", start.AddMinutes(2));

        var conversations = await NewService(ctx).GetConversationsAsync(ctx.TrainerId);

        // Three messages in the thread, but the trainer's own doesn't count as
        // unread to the trainer — it was sent after they last looked, which is
        // exactly the trap a naive timestamp comparison falls into.
        Assert.Equal(2, Assert.Single(conversations).UnreadCount);
    }

    [Fact]
    public async Task Marking_read_clears_the_callers_unread_count_only()
    {
        using var ctx = new ChatScenario();
        var start = new DateTime(2026, 8, 1, 9, 0, 0, DateTimeKind.Utc);
        ctx.AddMessage(ctx.Relationship.Id, ctx.ClientId, "from client", start);
        ctx.AddMessage(ctx.Relationship.Id, ctx.TrainerId, "from trainer", start.AddMinutes(1));
        var service = NewService(ctx);

        await service.MarkReadAsync(ctx.TrainerId, ctx.ClientId);

        Assert.Equal(0, Assert.Single(await service.GetConversationsAsync(ctx.TrainerId)).UnreadCount);
        // The pair shares one relationship row, so a single LastReadAt column
        // would have zeroed the client's badge too.
        Assert.Equal(1, Assert.Single(await service.GetConversationsAsync(ctx.ClientId)).UnreadCount);
    }

    [Fact]
    public async Task Messages_arriving_after_a_read_become_unread_again()
    {
        using var ctx = new ChatScenario();
        var start = new DateTime(2026, 8, 1, 9, 0, 0, DateTimeKind.Utc);
        ctx.AddMessage(ctx.Relationship.Id, ctx.ClientId, "before", start);
        var service = NewService(ctx);

        await service.MarkReadAsync(ctx.TrainerId, ctx.ClientId);
        ctx.AddMessage(ctx.Relationship.Id, ctx.ClientId, "after", DateTime.UtcNow.AddMinutes(1));

        Assert.Equal(1, Assert.Single(await service.GetConversationsAsync(ctx.TrainerId)).UnreadCount);
    }

    [Fact]
    public async Task Marking_read_on_a_pair_with_no_active_relationship_is_rejected()
    {
        using var ctx = new ChatScenario();
        var stranger = ctx.AddUser("Ivy", "Stone");

        await Assert.ThrowsAnyAsync<Exception>(
            () => NewService(ctx).MarkReadAsync(ctx.TrainerId, stranger.Id));
    }
}
