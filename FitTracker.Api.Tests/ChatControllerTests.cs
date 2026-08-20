using System.Security.Claims;
using FitTracker.Api.Controllers;
using FitTracker.Api.DTOs;
using FitTracker.Api.Repositories;
using FitTracker.Api.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Xunit;

namespace FitTracker.Api.Tests;

/// <summary>
/// Exercises the controller with a signed-in user, because one of the two defects
/// this suite was written for lives in the call it makes rather than in anything
/// below it: the service takes <c>(trainerId, clientId, range)</c> and the
/// controller passed the first two the other way round. Both are <see cref="Guid"/>,
/// so nothing but a test that reads real rows back can catch it.
/// </summary>
public class ChatControllerTests
{
    private static ChatController NewController(ChatTestContext ctx, Guid callerId)
    {
        var trainerClientRepo = new TrainerClientRepository(ctx.Db);
        var controller = new ChatController(
            new ChatService(trainerClientRepo, new ChatRepository(ctx.Db)),
            new TrainerClientService(trainerClientRepo))
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
        return controller;
    }

    private static T OkValue<T>(IActionResult result)
    {
        var ok = Assert.IsType<OkObjectResult>(result);
        return Assert.IsAssignableFrom<T>(ok.Value!);
    }

    [Fact]
    public async Task A_trainer_reading_history_gets_the_threads_messages()
    {
        using var ctx = new ChatTestContext();
        var start = new DateTime(2026, 8, 1, 9, 0, 0, DateTimeKind.Utc);
        ctx.AddMessage(ctx.Relationship.Id, ctx.TrainerId, "hello robert", start);
        var controller = NewController(ctx, ctx.TrainerId);

        var history = OkValue<List<ChatMessageDto>>(await controller.chatHistory(ctx.ClientId, 50));

        Assert.Equal(new[] { "hello robert" }, history.Select(m => m.Body));
    }

    [Fact]
    public async Task A_client_reading_history_passes_their_trainers_id_and_gets_the_same_thread()
    {
        using var ctx = new ChatTestContext();
        var start = new DateTime(2026, 8, 1, 9, 0, 0, DateTimeKind.Utc);
        ctx.AddMessage(ctx.Relationship.Id, ctx.TrainerId, "hello robert", start);
        var controller = NewController(ctx, ctx.ClientId);

        // From the client's side the route parameter is the *other party* — their
        // trainer. The controller resolves which side the caller is on.
        var history = OkValue<List<ChatMessageDto>>(await controller.chatHistory(ctx.TrainerId, 50));

        Assert.Equal(new[] { "hello robert" }, history.Select(m => m.Body));
    }

    [Fact]
    public async Task History_without_an_explicit_range_still_returns_messages()
    {
        using var ctx = new ChatTestContext();
        ctx.AddMessage(ctx.Relationship.Id, ctx.TrainerId, "hello robert",
            new DateTime(2026, 8, 1, 9, 0, 0, DateTimeKind.Utc));
        var controller = NewController(ctx, ctx.TrainerId);

        // An omitted query parameter binds to 0, and "take 0" is indistinguishable
        // from "this pair has never spoken" at the call site that consumes it.
        var history = OkValue<List<ChatMessageDto>>(await controller.chatHistory(ctx.ClientId));

        Assert.Single(history);
    }

    [Fact]
    public async Task History_for_a_pair_the_caller_is_not_part_of_is_unauthorized()
    {
        using var ctx = new ChatTestContext();
        var stranger = ctx.AddUser("Ivy", "Stone");
        var controller = NewController(ctx, ctx.TrainerId);

        Assert.IsType<UnauthorizedResult>(await controller.chatHistory(stranger.Id, 50));
    }

    [Fact]
    public async Task Conversations_returns_the_callers_threads()
    {
        using var ctx = new ChatTestContext();
        ctx.AddMessage(ctx.Relationship.Id, ctx.ClientId, "morning!",
            new DateTime(2026, 8, 1, 9, 0, 0, DateTimeKind.Utc));
        var controller = NewController(ctx, ctx.TrainerId);

        var conversations = OkValue<List<ChatConversationDto>>(await controller.Conversations());

        var only = Assert.Single(conversations);
        Assert.Equal(ctx.ClientId, only.OtherPartyId);
        Assert.Equal("morning!", only.LastMessagePreview);
        Assert.Equal(1, only.UnreadCount);
    }

    [Fact]
    public async Task Marking_a_thread_read_zeroes_its_unread_count()
    {
        using var ctx = new ChatTestContext();
        ctx.AddMessage(ctx.Relationship.Id, ctx.ClientId, "morning!",
            new DateTime(2026, 8, 1, 9, 0, 0, DateTimeKind.Utc));
        var controller = NewController(ctx, ctx.TrainerId);

        Assert.IsType<NoContentResult>(await controller.MarkRead(ctx.ClientId));

        var conversations = OkValue<List<ChatConversationDto>>(await controller.Conversations());
        Assert.Equal(0, Assert.Single(conversations).UnreadCount);
    }

    [Fact]
    public async Task Marking_a_thread_the_caller_is_not_part_of_is_unauthorized()
    {
        using var ctx = new ChatTestContext();
        var stranger = ctx.AddUser("Ivy", "Stone");
        var controller = NewController(ctx, ctx.TrainerId);

        Assert.IsType<UnauthorizedResult>(await controller.MarkRead(stranger.Id));
    }
}
