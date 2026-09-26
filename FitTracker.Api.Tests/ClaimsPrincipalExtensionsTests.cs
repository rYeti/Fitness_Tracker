using System.Security.Claims;
using FitTracker.Api.Services;
using Xunit;

namespace FitTracker.Api.Tests;

/// <summary>
/// The one reading of a caller's id. It was copied into the hub, every controller, a filter and
/// the live-update middleware, and a copy that read only <c>NameIdentifier</c> once left the hub
/// refusing OAuth tokens the controllers accepted, and later left the sync controllers throwing
/// on tokens the hub and the console accepted.
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

    [Fact]
    public void Nothing_else_in_the_api_reads_a_callers_claims()
    {
        // A rule in CLAUDE.md that 49 copies of the old parse contradicted, unnoticed, because
        // each copy worked for the tokens the app sends. This is what keeps the rule true.
        var api = Path.Combine(RepositoryRoot(), "FitTracker.Api");
        var readers = Directory.EnumerateFiles(api, "*.cs", SearchOption.AllDirectories)
            .Where(path => !IsBuildOutput(api, path))
            .Where(path => File.ReadAllText(path).Contains("FindFirst"))
            .Select(path => Path.GetRelativePath(api, path).Replace('\\', '/'))
            .ToList();

        Assert.Equal(["Services/ClaimsPrincipalExtensions.cs"], readers);
    }

    private static bool IsBuildOutput(string api, string path)
    {
        var top = Path.GetRelativePath(api, path).Split(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar)[0];
        return top is "bin" or "obj";
    }

    /// <summary>Walks up from the test assembly's output to the directory holding
    /// FitTracker.sln.</summary>
    private static string RepositoryRoot()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null && !File.Exists(Path.Combine(dir.FullName, "FitTracker.sln"))) dir = dir.Parent;
        Assert.NotNull(dir);
        return dir!.FullName;
    }
}
