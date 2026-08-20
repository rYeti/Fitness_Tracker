using System.Security.Claims;
using FitTracker.Api.Filters;
using FitTracker.Api.Models;
using FitTracker.Api.Repositories;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Abstractions;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.AspNetCore.Routing;

namespace FitTracker.Api.Tests;

/// <summary>
/// The write guard on the Trainer Console. Reads must stay open after a licence
/// lapses — the trainer keeps their roster and can still look at it — but
/// changing a client's plan requires a current licence.
/// </summary>
public class RequireEntitledLicenceFilterTests : IDisposable
{
    private readonly DbFixture _fx = new();

    public void Dispose() => _fx.Dispose();

    private async Task<(IActionResult? Result, bool Continued)> RunAsync(Guid? userId)
    {
        var httpContext = new DefaultHttpContext();
        if (userId is Guid id)
        {
            httpContext.User = new ClaimsPrincipal(new ClaimsIdentity(
                [new Claim(ClaimTypes.NameIdentifier, id.ToString())], "test"));
        }

        var actionContext = new ActionContext(
            httpContext, new RouteData(), new ActionDescriptor());
        var executing = new ActionExecutingContext(
            actionContext, [], new Dictionary<string, object?>(), controller: null!);

        var continued = false;
        var filter = new RequireEntitledLicenceFilter(new TrainerLicenceRepository(_fx.Db));
        await filter.OnActionExecutionAsync(executing, () =>
        {
            continued = true;
            return Task.FromResult(new ActionExecutedContext(actionContext, [], controller: null!));
        });

        return (executing.Result, continued);
    }

    [Fact]
    public async Task AllowsAPaidCurrentLicence()
    {
        var trainer = _fx.AddUser();
        _fx.AddLicence(trainer.Id, LicenceTier.Pro, seatLimit: 30);

        var (result, continued) = await RunAsync(trainer.Id);

        Assert.True(continued);
        Assert.Null(result);
    }

    [Fact]
    public async Task AllowsAFreeLicence()
    {
        // Free grants no Pro, but it is a working plan — a free trainer can
        // still build their three clients' programmes.
        var trainer = _fx.AddUser();
        _fx.AddLicence(trainer.Id, LicenceTier.Free);

        var (_, continued) = await RunAsync(trainer.Id);

        Assert.True(continued);
    }

    [Fact]
    public async Task AllowsWritesDuringGrace()
    {
        var trainer = _fx.AddUser();
        _fx.AddLicence(
            trainer.Id, LicenceTier.Pro, seatLimit: 30,
            status: LicenceStatus.PastDue, graceEndsAt: DateTime.UtcNow.AddDays(5));

        var (_, continued) = await RunAsync(trainer.Id);

        Assert.True(continued);
    }

    [Fact]
    public async Task BlocksWritesOnceGraceHasElapsed()
    {
        var trainer = _fx.AddUser();
        _fx.AddLicence(
            trainer.Id, LicenceTier.Pro, seatLimit: 30,
            status: LicenceStatus.Canceled, graceEndsAt: DateTime.UtcNow.AddDays(-1));

        var (result, continued) = await RunAsync(trainer.Id);

        Assert.False(continued);
        var objectResult = Assert.IsType<ObjectResult>(result);
        Assert.Equal(StatusCodes.Status402PaymentRequired, objectResult.StatusCode);
    }

    [Fact]
    public async Task BlocksAUserWithNoLicenceAtAll()
    {
        var user = _fx.AddUser();

        var (_, continued) = await RunAsync(user.Id);

        Assert.False(continued);
    }

    [Fact]
    public async Task RejectsAnUnauthenticatedCaller()
    {
        var (result, continued) = await RunAsync(null);

        Assert.False(continued);
        Assert.IsType<UnauthorizedResult>(result);
    }
}
