using System.Security.Claims;
using FitTracker.Api.DTOs;
using FitTracker.Api.Hubs;
using FitTracker.Api.Repositories;
using FitTracker.Api.Services;
using Microsoft.AspNetCore.Http.Features;
using Microsoft.AspNetCore.SignalR;
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
    private static ChatHub NewHub(ChatScenario ctx, Guid callerId, out RecordingClients clients)
    {
        var trainerClientRepo = new TrainerClientRepository(ctx.Db);
        clients = new RecordingClients();

        return new ChatHub(
            new TrainerClientService(
                trainerClientRepo, new TrainerLicenceRepository(ctx.Db)),
            new ChatService(trainerClientRepo, new ChatRepository(ctx.Db)))
        {
            Context = new FakeHubCallerContext(callerId),
            Clients = clients,
            Groups = new RecordingGroups(),
        };
    }

    [Fact]
    public async Task SendMessage_returns_the_persisted_message_as_the_ack()
    {
        using var ctx = new ChatScenario();
        var hub = NewHub(ctx, ctx.TrainerId, out _);
        var messageId = Guid.NewGuid();

        ChatMessageDto ack = await hub.SendMessage(ctx.ClientId, "how did the last set feel?", messageId);

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

        var ack = await hub.SendMessage(ctx.TrainerId, "sore but good", messageId);

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

        await hub.SendMessage(ctx.ClientId, "hello robert", Guid.NewGuid());

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

        var first = await hub.SendMessage(ctx.ClientId, "did you see my form?", messageId);
        // What the outbox does after a dropped ack: same id, same body, again.
        var second = await hub.SendMessage(ctx.ClientId, "did you see my form?", messageId);

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
            () => hub.SendMessage(ctx.ClientId, "let me in", Guid.NewGuid()));
        Assert.Empty(ctx.Db.ChatMessages);
    }

    [Fact]
    public async Task A_token_carrying_only_sub_is_accepted()
    {
        using var ctx = new ChatScenario();
        var trainerClientRepo = new TrainerClientRepository(ctx.Db);
        var hub = new ChatHub(
            new TrainerClientService(
                trainerClientRepo, new TrainerLicenceRepository(ctx.Db)),
            new ChatService(trainerClientRepo, new ChatRepository(ctx.Db)))
        {
            // ChatController already falls back to "sub"; the hub read only
            // NameIdentifier and threw on exactly the tokens the controller
            // served happily, so one entry point worked and the other didn't for
            // the same signed-in user.
            Context = new FakeHubCallerContext(ctx.TrainerId, claimType: "sub"),
            Clients = new RecordingClients(),
            Groups = new RecordingGroups(),
        };

        var ack = await hub.SendMessage(ctx.ClientId, "still here", Guid.NewGuid());

        Assert.Equal(ctx.TrainerId, ack.SenderId);
    }

    [Fact]
    public async Task An_unauthenticated_caller_gets_a_hub_exception_not_a_crash()
    {
        using var ctx = new ChatScenario();
        var trainerClientRepo = new TrainerClientRepository(ctx.Db);
        var hub = new ChatHub(
            new TrainerClientService(
                trainerClientRepo, new TrainerLicenceRepository(ctx.Db)),
            new ChatService(trainerClientRepo, new ChatRepository(ctx.Db)))
        {
            Context = new FakeHubCallerContext(userId: null),
            Clients = new RecordingClients(),
            Groups = new RecordingGroups(),
        };

        // A HubException reaches the client as a readable message. The
        // NullReferenceException it replaces arrived as an opaque
        // "an unexpected error occurred".
        await Assert.ThrowsAsync<HubException>(
            () => hub.SendMessage(ctx.ClientId, "who am i", Guid.NewGuid()));
    }

    [Fact]
    public async Task JoinClientGroup_puts_both_sides_in_the_same_group()
    {
        using var ctx = new ChatScenario();
        var trainerGroups = new RecordingGroups();
        var clientGroups = new RecordingGroups();
        var trainerClientRepo = new TrainerClientRepository(ctx.Db);

        ChatHub HubFor(Guid callerId, RecordingGroups groups) => new(
            new TrainerClientService(
                trainerClientRepo, new TrainerLicenceRepository(ctx.Db)),
            new ChatService(trainerClientRepo, new ChatRepository(ctx.Db)))
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

    // ── Minimal SignalR harness ───────────────────────────────────────────────
    // Hand-written rather than mocked: the project has no mocking library, and
    // these only need to record what the hub did with them.

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
