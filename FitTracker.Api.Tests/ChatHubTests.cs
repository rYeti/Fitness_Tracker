using System.Security.Claims;
using FitTracker.Api.DTOs;
using FitTracker.Api.Hubs;
using FitTracker.Api.Repositories;
using FitTracker.Api.Services;
using FitTracker.Api.Services.Interfaces;
using Microsoft.AspNetCore.Http.Features;
using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace FitTracker.Api.Tests;

/// <summary>
/// Pins the hub's <em>return value</em>, which is the part of its contract the
/// C# compiler cannot see and the Flutter client cannot do without.
/// </summary>
/// <remarks>
/// <para>
/// <see cref="ChatHub.SendMessage"/> shipped as <c>Task</c> rather than
/// <c>Task&lt;ChatMessageDto&gt;</c>. It compiled, it persisted the message, it
/// broadcast the message — and every send from the app failed anyway, because a
/// hub method with no return value completes the invocation with no result and
/// the client reads that as "no acknowledgement". The message was delivered and
/// the sender was shown a failure for it.
/// </para>
/// <para>
/// Nothing in the existing suite could catch that: the controller tests never
/// touch the hub, and the Flutter fake returns an ack unconditionally because it
/// was written against the same roadmap the hub was supposed to implement. A
/// test has to assert on what the hub hands <em>back</em>, not just on what ends
/// up in the table.
/// </para>
/// </remarks>
public class ChatHubTests
{
    private static ChatHub NewHub(ChatScenario ctx, Guid callerId, out RecordingClients clients) =>
        NewHub(ctx, callerId, out clients, out _);

    private static ChatHub NewHub(
        ChatScenario ctx,
        Guid callerId,
        out RecordingClients clients,
        out RecordingPushDispatcher pushes)
    {
        var trainerClientRepo = new TrainerClientRepository(ctx.Db);
        var trainerClientService = new TrainerClientService(
            trainerClientRepo, new TrainerLicenceRepository(ctx.Db), new TrainerNutrientPinRepository(ctx.Db));
        clients = new RecordingClients();
        pushes = new RecordingPushDispatcher();

        return new ChatHub(
            trainerClientService,
            new ChatService(trainerClientRepo, new ChatRepository(ctx.Db)),
            pushes,
            NewAttachmentService(ctx, trainerClientService))
        {
            Context = new FakeHubCallerContext(callerId),
            Clients = clients,
            Groups = new RecordingGroups(),
        };
    }

    private static ChatAttachmentService NewAttachmentService(ChatScenario ctx, ITrainerClientService trainerClientService) =>
        new(
            new InMemoryChatAttachmentStore(),
            new ChatAttachmentRepository(ctx.Db),
            trainerClientService,
            new ConfigurationBuilder().Build(),
            NullLogger<ChatAttachmentService>.Instance);

    [Fact]
    public async Task SendMessage_returns_the_persisted_message_as_the_ack()
    {
        using var ctx = new ChatScenario();
        var hub = NewHub(ctx, ctx.TrainerId, out _);
        var messageId = Guid.NewGuid();

        ChatMessageDto ack = await hub.SendMessage(ctx.ClientId, "how did the last set feel?", messageId, iv: "iv-1", encryptionVersion: 1);

        // The id is the client's, unchanged: it is what lets a resend after a
        // dropped ack be recognised as the same message rather than a new one.
        Assert.Equal(messageId, ack.Id);
        Assert.Equal("how did the last set feel?", ack.Body);
        Assert.Equal(ctx.TrainerId, ack.SenderId);
        Assert.Equal(ctx.TrainerId, ack.TrainerId);
        Assert.Equal(ctx.ClientId, ack.ClientId);
        Assert.NotEqual(default, ack.SentAt);
    }

    [Fact]
    public async Task SendMessage_returns_an_ack_when_the_client_is_the_sender()
    {
        using var ctx = new ChatScenario();
        // The trainee passes their trainer's id as "the other party" — the hub
        // resolves which side is which, so both roles must get an ack back.
        var hub = NewHub(ctx, ctx.ClientId, out _);
        var messageId = Guid.NewGuid();

        var ack = await hub.SendMessage(ctx.TrainerId, "sore but good", messageId, iv: "iv-1", encryptionVersion: 1);

        Assert.Equal(messageId, ack.Id);
        Assert.Equal(ctx.ClientId, ack.SenderId);
        Assert.Equal(ctx.TrainerId, ack.TrainerId);
        Assert.Equal(ctx.ClientId, ack.ClientId);
    }

    [Fact]
    public async Task SendMessage_broadcasts_to_the_pairs_group()
    {
        using var ctx = new ChatScenario();
        var hub = NewHub(ctx, ctx.TrainerId, out var clients);

        await hub.SendMessage(ctx.ClientId, "hello robert", Guid.NewGuid(), iv: "iv-1", encryptionVersion: 1);

        var (group, method, args) = Assert.Single(clients.Sent);
        Assert.Equal($"chat:{ctx.TrainerId}:{ctx.ClientId}", group);
        Assert.Equal("ReceiveMessage", method);
        // The broadcast payload is the same DTO the caller gets, which is what
        // lets the client dedupe the two copies by id.
        Assert.Equal("hello robert", Assert.IsType<ChatMessageDto>(Assert.Single(args)).Body);
    }

    [Fact]
    public async Task A_resend_with_the_same_id_acks_the_original_row()
    {
        using var ctx = new ChatScenario();
        var hub = NewHub(ctx, ctx.TrainerId, out _);
        var messageId = Guid.NewGuid();

        var first = await hub.SendMessage(ctx.ClientId, "did you see my form?", messageId, iv: "iv-1", encryptionVersion: 1);
        // What the outbox does after a dropped ack: same id, same body, again.
        var second = await hub.SendMessage(ctx.ClientId, "did you see my form?", messageId, iv: "iv-1", encryptionVersion: 1);

        Assert.Equal(first.Id, second.Id);
        Assert.Equal(first.SentAt, second.SentAt);
        Assert.Single(ctx.Db.ChatMessages.Where(m => m.Id == messageId));
    }

    [Fact]
    public async Task A_user_outside_the_relationship_is_refused()
    {
        using var ctx = new ChatScenario();
        var stranger = ctx.AddUser("Mara", "Vogel");
        var hub = NewHub(ctx, stranger.Id, out _);

        await Assert.ThrowsAsync<HubException>(
            () => hub.SendMessage(ctx.ClientId, "let me in", Guid.NewGuid(), iv: "iv-1", encryptionVersion: 1));
        Assert.Empty(ctx.Db.ChatMessages);
    }

    [Fact]
    public async Task A_token_carrying_only_sub_is_accepted()
    {
        using var ctx = new ChatScenario();
        var trainerClientRepo = new TrainerClientRepository(ctx.Db);
        var trainerClientService = new TrainerClientService(
            trainerClientRepo, new TrainerLicenceRepository(ctx.Db), new TrainerNutrientPinRepository(ctx.Db));
        var hub = new ChatHub(
            trainerClientService,
            new ChatService(trainerClientRepo, new ChatRepository(ctx.Db)),
            new RecordingPushDispatcher(),
            NewAttachmentService(ctx, trainerClientService))
        {
            // ChatController already falls back to "sub"; the hub read only
            // NameIdentifier and threw on exactly the tokens the controller
            // served happily, so one entry point worked and the other didn't for
            // the same signed-in user.
            Context = new FakeHubCallerContext(ctx.TrainerId, claimType: "sub"),
            Clients = new RecordingClients(),
            Groups = new RecordingGroups(),
        };

        var ack = await hub.SendMessage(ctx.ClientId, "still here", Guid.NewGuid(), iv: "iv-1", encryptionVersion: 1);

        Assert.Equal(ctx.TrainerId, ack.SenderId);
    }

    [Fact]
    public async Task An_unauthenticated_caller_gets_a_hub_exception_not_a_crash()
    {
        using var ctx = new ChatScenario();
        var trainerClientRepo = new TrainerClientRepository(ctx.Db);
        var trainerClientService = new TrainerClientService(
            trainerClientRepo, new TrainerLicenceRepository(ctx.Db), new TrainerNutrientPinRepository(ctx.Db));
        var hub = new ChatHub(
            trainerClientService,
            new ChatService(trainerClientRepo, new ChatRepository(ctx.Db)),
            new RecordingPushDispatcher(),
            NewAttachmentService(ctx, trainerClientService))
        {
            Context = new FakeHubCallerContext(userId: null),
            Clients = new RecordingClients(),
            Groups = new RecordingGroups(),
        };

        // A HubException reaches the client as a readable message. The
        // NullReferenceException it replaces arrived as an opaque
        // "an unexpected error occurred".
        await Assert.ThrowsAsync<HubException>(
            () => hub.SendMessage(ctx.ClientId, "who am i", Guid.NewGuid(), iv: "iv-1", encryptionVersion: 1));
    }

    [Fact]
    public async Task JoinClientGroup_puts_both_sides_in_the_same_group()
    {
        using var ctx = new ChatScenario();
        var trainerGroups = new RecordingGroups();
        var clientGroups = new RecordingGroups();
        var trainerClientRepo = new TrainerClientRepository(ctx.Db);
        var trainerClientService = new TrainerClientService(
            trainerClientRepo, new TrainerLicenceRepository(ctx.Db), new TrainerNutrientPinRepository(ctx.Db));

        ChatHub HubFor(Guid callerId, RecordingGroups groups) => new(
            trainerClientService,
            new ChatService(trainerClientRepo, new ChatRepository(ctx.Db)),
            new RecordingPushDispatcher(),
            NewAttachmentService(ctx, trainerClientService))
        {
            Context = new FakeHubCallerContext(callerId),
            Clients = new RecordingClients(),
            Groups = groups,
        };

        await HubFor(ctx.TrainerId, trainerGroups).JoinClientGroup(ctx.ClientId);
        await HubFor(ctx.ClientId, clientGroups).JoinClientGroup(ctx.TrainerId);

        // Each side passes the *other* party's id and they still land in one
        // group — that symmetry is the whole reason one hub serves both roles.
        Assert.Equal(trainerGroups.Added, clientGroups.Added);
        Assert.Equal($"chat:{ctx.TrainerId}:{ctx.ClientId}", Assert.Single(trainerGroups.Added).groupName);
    }


    [Fact]
    public async Task SendMessage_pushes_to_the_recipient_and_not_the_sender()
    {
        using var ctx = new ChatScenario();
        var hub = NewHub(ctx, ctx.TrainerId, out _, out var pushes);

        await hub.SendMessage(ctx.ClientId, "how did the last set feel?", Guid.NewGuid(), iv: "iv-1", encryptionVersion: 1);

        // The hub had never needed to name a recipient before — every other
        // operation on it is symmetric between the two parties.
        var push = Assert.Single(pushes.Queued);
        Assert.Equal(ctx.ClientId, push.recipientId);
        Assert.Equal(ctx.TrainerId, push.senderId);
        // The ciphertext, not the message. This assertion is the one that would
        // catch a well-meaning change putting a readable preview back into the
        // push payload.
        Assert.Equal("how did the last set feel?", push.body.Ciphertext);
        Assert.Equal("iv-1", push.body.Iv);
        Assert.Equal(1, push.body.EncryptionVersion);
    }

    [Fact]
    public async Task The_recipient_is_the_trainer_when_the_client_sends()
    {
        using var ctx = new ChatScenario();
        var hub = NewHub(ctx, ctx.ClientId, out _, out var pushes);

        await hub.SendMessage(ctx.TrainerId, "sore but good", Guid.NewGuid(), iv: "iv-1", encryptionVersion: 1);

        var push = Assert.Single(pushes.Queued);
        Assert.Equal(ctx.TrainerId, push.recipientId);
        Assert.Equal(ctx.ClientId, push.senderId);
    }

    [Fact]
    public async Task A_refused_send_pushes_nothing()
    {
        using var ctx = new ChatScenario();
        var stranger = ctx.AddUser("Mara", "Vogel");
        var hub = NewHub(ctx, stranger.Id, out _, out var pushes);

        await Assert.ThrowsAsync<HubException>(
            () => hub.SendMessage(ctx.ClientId, "let me in", Guid.NewGuid(), iv: "iv-1", encryptionVersion: 1));

        // Authorisation is checked before anything is persisted or queued, so a
        // stranger cannot make someone else's phone buzz.
        Assert.Empty(pushes.Queued);
    }

    [Fact]
    public async Task SendMessageV2_commits_attachments_belonging_to_the_pair()
    {
        using var ctx = new ChatScenario();
        var hub = NewHub(ctx, ctx.TrainerId, out _);
        var attachment = ctx.AddAttachment(ctx.Relationship.Id, ctx.TrainerId);
        var messageId = Guid.NewGuid();

        await hub.SendMessageV2(
            ctx.ClientId, "check this out", messageId, iv: "iv-1", encryptionVersion: 1,
            attachmentIds: [attachment.Id]);

        var committed = ctx.Db.ChatAttachments.Single(a => a.Id == attachment.Id);
        Assert.Equal(messageId, committed.MessageId);
        Assert.NotNull(committed.CommittedAt);
    }

    [Fact]
    public async Task SendMessageV2_skips_an_attachment_from_another_pair_without_failing_the_send()
    {
        using var ctx = new ChatScenario();
        var otherClient = ctx.AddUser("Petra", "Voss");
        var otherRelationship = ctx.AddRelationship(ctx.TrainerId, otherClient.Id);
        var foreignAttachment = ctx.AddAttachment(otherRelationship.Id, ctx.TrainerId);
        var hub = NewHub(ctx, ctx.TrainerId, out _);

        var ack = await hub.SendMessageV2(
            ctx.ClientId, "check this out", Guid.NewGuid(), iv: "iv-1", encryptionVersion: 1,
            attachmentIds: [foreignAttachment.Id]);

        // The send still succeeds — bookkeeping must never cost the message.
        Assert.NotEqual(default, ack.SentAt);
        var stillUncommitted = ctx.Db.ChatAttachments.Single(a => a.Id == foreignAttachment.Id);
        Assert.Null(stillUncommitted.CommittedAt);
        Assert.Null(stillUncommitted.MessageId);
    }

    [Fact]
    public async Task A_replayed_SendMessageV2_does_not_recommit_an_already_committed_attachment()
    {
        using var ctx = new ChatScenario();
        var hub = NewHub(ctx, ctx.TrainerId, out _);
        var attachment = ctx.AddAttachment(ctx.Relationship.Id, ctx.TrainerId);
        var messageId = Guid.NewGuid();

        await hub.SendMessageV2(
            ctx.ClientId, "check this out", messageId, iv: "iv-1", encryptionVersion: 1,
            attachmentIds: [attachment.Id]);
        var firstCommittedAt = ctx.Db.ChatAttachments.Single(a => a.Id == attachment.Id).CommittedAt;

        // The outbox always resends on a lost ack, same messageId, same attachmentIds.
        await hub.SendMessageV2(
            ctx.ClientId, "check this out", messageId, iv: "iv-1", encryptionVersion: 1,
            attachmentIds: [attachment.Id]);

        var row = ctx.Db.ChatAttachments.Single(a => a.Id == attachment.Id);
        Assert.Equal(firstCommittedAt, row.CommittedAt);
        Assert.Equal(messageId, row.MessageId);
    }

    [Fact]
    public async Task The_five_argument_SendMessage_still_works_after_SendMessageV2_was_added()
    {
        // The regression that matters: SignalR binds by position and arity, so
        // adding attachmentIds directly to SendMessage would have broken every
        // already-shipped client outright rather than merely ignoring the new
        // argument. This is why SendMessage delegates to SendMessageV2 instead
        // of growing a parameter.
        using var ctx = new ChatScenario();
        var hub = NewHub(ctx, ctx.TrainerId, out _);

        var ack = await hub.SendMessage(ctx.ClientId, "still five args", Guid.NewGuid(), iv: "iv-1", encryptionVersion: 1);

        Assert.Equal("still five args", ack.Body);
    }

    // ── Minimal SignalR harness ───────────────────────────────────────────────
    // Hand-written rather than mocked: the project has no mocking library, and
    // these only need to record what the hub did with them.

    /// <summary>
    /// Stands in for the real dispatcher, which detaches a task and opens its own
    /// DI scope — untestable in-process, and not what these tests are about. What
    /// matters here is only that the hub queued the right push for the right
    /// person.
    /// </summary>
    private sealed class RecordingPushDispatcher : IChatPushDispatcher
    {
        public List<(Guid recipientId, Guid senderId, Guid messageId, EncryptedChatBody body)> Queued { get; } = [];

        public void Queue(Guid recipientId, Guid senderId, Guid messageId, EncryptedChatBody body) =>
            Queued.Add((recipientId, senderId, messageId, body));
    }

    private sealed class FakeHubCallerContext(Guid? userId, string? claimType = null) : HubCallerContext
    {
        private readonly ClaimsPrincipal _user = userId is null
            ? new ClaimsPrincipal(new ClaimsIdentity())
            : new ClaimsPrincipal(new ClaimsIdentity(
                [new Claim(claimType ?? ClaimTypes.NameIdentifier, userId.Value.ToString())],
                authenticationType: "Test"));

        public override string ConnectionId => "test-connection";
        public override string? UserIdentifier => userId?.ToString();
        public override ClaimsPrincipal? User => _user;
        public override IDictionary<object, object?> Items { get; } = new Dictionary<object, object?>();
        public override IFeatureCollection Features { get; } = new FeatureCollection();
        public override CancellationToken ConnectionAborted => CancellationToken.None;
        public override void Abort() { }
    }

    private sealed class RecordingGroups : IGroupManager
    {
        public List<(string connectionId, string groupName)> Added { get; } = [];
        public List<(string connectionId, string groupName)> Removed { get; } = [];

        public Task AddToGroupAsync(string connectionId, string groupName, CancellationToken cancellationToken = default)
        {
            Added.Add((connectionId, groupName));
            return Task.CompletedTask;
        }

        public Task RemoveFromGroupAsync(string connectionId, string groupName, CancellationToken cancellationToken = default)
        {
            Removed.Add((connectionId, groupName));
            return Task.CompletedTask;
        }
    }

    private sealed class RecordingClients : IHubCallerClients
    {
        public List<(string target, string method, object?[] args)> Sent { get; } = [];

        private IClientProxy Proxy(string target) => new RecordingProxy(target, Sent);

        public IClientProxy All => Proxy("all");
        public IClientProxy Caller => Proxy("caller");
        public IClientProxy Others => Proxy("others");

        public IClientProxy AllExcept(IReadOnlyList<string> excludedConnectionIds) => Proxy("all-except");
        public IClientProxy Client(string connectionId) => Proxy($"client:{connectionId}");
        public IClientProxy Clients(IReadOnlyList<string> connectionIds) => Proxy("clients");
        public IClientProxy Group(string groupName) => Proxy(groupName);
        public IClientProxy GroupExcept(string groupName, IReadOnlyList<string> excludedConnectionIds) => Proxy(groupName);
        public IClientProxy Groups(IReadOnlyList<string> groupNames) => Proxy("groups");
        public IClientProxy OthersInGroup(string groupName) => Proxy(groupName);
        public IClientProxy User(string userId) => Proxy($"user:{userId}");
        public IClientProxy Users(IReadOnlyList<string> userIds) => Proxy("users");

        private sealed class RecordingProxy(
            string target,
            List<(string target, string method, object?[] args)> sink) : IClientProxy
        {
            public Task SendCoreAsync(string method, object?[] args, CancellationToken cancellationToken = default)
            {
                sink.Add((target, method, args));
                return Task.CompletedTask;
            }
        }
    }
}
