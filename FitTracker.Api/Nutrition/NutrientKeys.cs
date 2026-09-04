namespace FitTracker.Api.Nutrition;

/// <summary>
/// The 21 nutrient keys a trainer can pin, mirroring
/// <c>nutrientDefs</c> in lib/core/nutrition/nutrient_defs.dart key for key
/// and order for order. Kept as a flat list rather than an enum so both sides
/// can be diffed directly — see the C#/Dart parity test in
/// FitTracker.Api.Tests, which fails the moment one side gains a key the
/// other doesn't know about.
/// </summary>
public static class NutrientKeys
{
    public static readonly IReadOnlyList<string> All =
    [
        "fibre", "sugar", "satfat",
        "salt", "sodium", "potassium", "calcium", "iron", "magnesium", "zinc",
        "vita", "vitc", "vitd", "vite", "vitk",
        "vitb1", "vitb2", "vitb3", "vitb6", "vitb9", "vitb12",
    ];

    private static readonly HashSet<string> AllSet = new(All);

    public static bool IsValid(string key) => AllSet.Contains(key);

    /// <summary>What a trainer+client pair with no saved pins sees — matches
    /// the Trainer Console design's own defaults, so a device that has never
    /// synced pins yet shows the same three nutrients the API would return.</summary>
    public static readonly IReadOnlyList<string> Defaults = ["fibre", "sugar", "sodium"];
}
