using System.Security.Claims;
using FitTracker.Api.Services;
using Xunit;

namespace FitTracker.Api.Tests;

/// <summary>
/// The one reading of a caller's id. It was copied into the hub, eight controllers, a filter and
/// the live-update middleware, and a copy that read only <c>NameIdentifier</c> once left the hub
/// refusing OAuth tokens the controllers accepted.
/// </summary>
public class ClaimsPrincipalExtensionsTests
{
    private static ClaimsPrincipal Caller(params (string Type, string Value)[] claims) =>
        new(new ClaimsIdentity(claims.Select(c => new Claim(c.Type, c.Value)), authenticationType: "Test"));

    [Fact]
    public void The_id_is_read_from_NameIdentifier_then_sub_and_must_be_a_guid()
    {
        var id = Guid.NewGuid();
        var other = Guid.NewGuid();

        Assert.True(Caller((ClaimTypes.NameIdentifier, id.ToString())).TryGetUserId(out var fromNameIdentifier));
        Assert.Equal(id, fromNameIdentifier);

        // What an OAuth token carries.
        Assert.True(Caller(("sub", id.ToString())).TryGetUserId(out var fromSub));
        Assert.Equal(id, fromSub);

        Assert.True(Caller((ClaimTypes.NameIdentifier, id.ToString()), ("sub", other.ToString())).TryGetUserId(out var both));
        Assert.Equal(id, both);

        // The first claim found is the one parsed; a bad NameIdentifier doesn't fall back to sub.
        Assert.False(Caller((ClaimTypes.NameIdentifier, "robert"), ("sub", id.ToString())).TryGetUserId(out _));
        Assert.False(Caller().TryGetUserId(out _));
        Assert.False(((ClaimsPrincipal?)null).TryGetUserId(out _));
    }
}
