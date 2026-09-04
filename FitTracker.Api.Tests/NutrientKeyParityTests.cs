using System.Text.RegularExpressions;
using FitTracker.Api.Nutrition;
using Xunit;

namespace FitTracker.Api.Tests;

/// <summary>
/// The C# <see cref="NutrientKeys.All"/> list and the Dart
/// <c>nutrientDefs</c> table (fittnes_tracker/lib/core/nutrition/nutrient_defs.dart)
/// are two hand-maintained copies of the same 21-key set — nothing shares them
/// at compile time. This is the only thing that would ever notice the two
/// drifting apart, which is exactly the failure mode the C# side alone cannot
/// catch: a key added to one and not the other compiles cleanly on both sides
/// and only breaks at runtime, as a nutrient that silently never displays or a
/// pin the server rejects.
/// </summary>
public class NutrientKeyParityTests
{
    [Fact]
    public void CSharpAndDartAgreeOnTheNutrientKeySet()
    {
        var dartKeys = ParseDartNutrientKeys();

        Assert.Equal(dartKeys.Count, dartKeys.Distinct().Count());
        Assert.Equal(
            NutrientKeys.All.OrderBy(k => k, StringComparer.Ordinal),
            dartKeys.OrderBy(k => k, StringComparer.Ordinal));
    }

    private static List<string> ParseDartNutrientKeys()
    {
        var path = FindNutrientDefsFile();
        var source = File.ReadAllText(path);
        // Each NutrientDef entry starts `key: 'xxx',` in the const list.
        var matches = Regex.Matches(source, @"key:\s*'([a-z0-9]+)'");
        Assert.NotEmpty(matches);
        return [.. matches.Select(m => m.Groups[1].Value)];
    }

    /// <summary>Walks up from the test assembly's output directory to the repo
    /// root (marked by FitTracker.sln), then down into the Flutter project —
    /// there is no other shared coordinate between the two projects to anchor
    /// on.</summary>
    private static string FindNutrientDefsFile()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null && !File.Exists(Path.Combine(dir.FullName, "FitTracker.sln")))
        {
            dir = dir.Parent;
        }

        Assert.NotNull(dir);
        var path = Path.Combine(
            dir!.FullName, "fittnes_tracker", "lib", "core", "nutrition", "nutrient_defs.dart");
        Assert.True(File.Exists(path), $"Expected to find {path}");
        return path;
    }
}
