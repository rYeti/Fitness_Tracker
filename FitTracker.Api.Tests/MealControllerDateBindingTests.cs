using System.Security.Claims;
using FitTracker.Api.Controllers;
using FitTracker.Api.Repositories;
using FitTracker.Api.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Xunit;

namespace FitTracker.Api.Tests;

/// <summary>
/// What <c>GET api/Meal</c> does when the caller leaves the date off.
///
/// It used to throw. A non-nullable <c>[FromQuery] DateTime</c> binds a missing
/// value to <see cref="DateTime.MinValue"/>, and <c>0001-01-01</c> is the one
/// date this route cannot answer for: <see cref="MealDayWindow.ForRange"/>
/// widens the requested day by twelve hours in each direction, and going back
/// twelve hours from <c>0001-01-01T00:00Z</c> underflows
/// <see cref="DateTime.MinValue"/>. <c>AddHours</c> throws before a query is
/// ever built, so the caller got a 500 and the log got a stack trace, for what
/// is plainly a malformed request.
///
/// No user could reach this — the app always sends a date — which is exactly
/// why it survived. It was found by a script calling the endpoint by hand.
/// </summary>
public class MealControllerDateBindingTests : IDisposable
{
    private readonly DbFixture _fx = new();
    private readonly MealController _controller;

    public MealControllerDateBindingTests()
    {
        _controller = new MealController(new MealService(new MealRepository(_fx.Db)))
        {
            ControllerContext = new ControllerContext
            {
                HttpContext = new DefaultHttpContext
                {
                    User = new ClaimsPrincipal(new ClaimsIdentity(
                        [new Claim(ClaimTypes.NameIdentifier, Guid.NewGuid().ToString())],
                        authenticationType: "Test")),
                },
            },
        };
    }

    public void Dispose() => _fx.Dispose();

    [Fact]
    public async Task OmittingTheDateIsABadRequest()
    {
        var result = await _controller.GetForDate(date: null);

        Assert.IsType<BadRequestObjectResult>(result);
    }

    /// <summary>
    /// The value the old signature bound a missing parameter to. Pinned
    /// separately from the null case because a future refactor could easily
    /// reintroduce the non-nullable parameter and "fix" the null test by
    /// defaulting, putting MinValue straight back on the path that throws.
    /// </summary>
    [Fact]
    public void TheDateThatUsedToThrowStillThrows()
    {
        var window = Record.Exception(() => MealDayWindow.ForRange(
            DateTime.MinValue, DateTime.MinValue));

        Assert.IsType<ArgumentOutOfRangeException>(window);
    }

    [Fact]
    public async Task ASuppliedDateStillReturnsOk()
    {
        var result = await _controller.GetForDate(new DateTime(2026, 8, 31, 0, 0, 0, DateTimeKind.Utc));

        Assert.IsType<OkObjectResult>(result);
    }
}
