using System.Security.Claims;
using FitTracker.Api.Data;
using FitTracker.Api.Services.Interfaces;

namespace FitTracker.Api.Services;

/// <summary>
/// After each request, queues the live updates for whatever it committed. See
/// docs/sync-architecture.md, part four.
/// </summary>
/// <remarks>
/// The request is the unit of "once": a trainer's Workout Builder save is a dozen saves and a
/// transaction or two, and the console should hear of it once, naming every area it touched.
/// So nothing is sent at a commit. Each commit adds to the request's
/// <see cref="ChangedDataLog"/>, and this takes what it holds when the request is done —
/// including when the request then fails, because what it committed stays committed.
///
/// Only HTTP requests pass through here. A hub invocation or a background job has a scope,
/// and so a log, of its own; one that ever writes synced data hands its log to
/// <see cref="ILiveUpdateDispatcher"/> itself. None does today.
/// </remarks>
public class LiveUpdateMiddleware(RequestDelegate next)
{
    private readonly RequestDelegate _next = next;

    public async Task InvokeAsync(HttpContext context, ChangedDataLog log, ILiveUpdateDispatcher dispatcher)
    {
        try
        {
            await _next(context);
        }
        finally
        {
            var committed = log.TakeCommitted();
            if (committed.Count > 0) dispatcher.Queue(ActorOf(context.User), committed);
        }
    }

    /// <summary>The signed-in caller: the same claims the controllers read, including the
    /// bare <c>sub</c> an OAuth token carries.</summary>
    private static Guid? ActorOf(ClaimsPrincipal user)
    {
        var claim = user.FindFirst(ClaimTypes.NameIdentifier) ?? user.FindFirst("sub");
        return Guid.TryParse(claim?.Value, out var id) ? id : null;
    }
}
