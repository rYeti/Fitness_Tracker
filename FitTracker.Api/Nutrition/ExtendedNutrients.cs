using System.Text.Json;
using System.Text.Json.Serialization;

namespace FitTracker.Api.Nutrition;

/// <summary>
/// Mirrors the Flutter client's <c>ExtendedNutrients</c>
/// (fittnes_tracker/lib/core/nutrition/extended_nutrients.dart) field for
/// field, including its exact JSON key names — this is the shape stored in
/// <see cref="Models.FoodItem.ExtendedNutrientsJson"/>. Every value is in
/// grams, regardless of source (OpenFoodFacts already reports grams; BLS 4.0
/// values are converted once, at seed-generation time — see
/// tool/generate_verified_foods.py). Display units (mg, µg) are a client-side
/// presentation concern; this type never converts.
///
/// Every field is nullable and stays that way through every operation here:
/// a nutrient no food reported must never be read as a reported zero. See
/// docs/trainer-console-micronutrients.md.
/// </summary>
public record ExtendedNutrients
{
    public double? Fiber { get; init; }
    public double? Sugar { get; init; }
    [JsonPropertyName("saturatedFat")]
    public double? SaturatedFat { get; init; }
    public double? Salt { get; init; }
    public double? Sodium { get; init; }

    [JsonPropertyName("vitaminA")]
    public double? VitaminA { get; init; }
    [JsonPropertyName("vitaminC")]
    public double? VitaminC { get; init; }
    [JsonPropertyName("vitaminD")]
    public double? VitaminD { get; init; }
    [JsonPropertyName("vitaminE")]
    public double? VitaminE { get; init; }
    [JsonPropertyName("vitaminK")]
    public double? VitaminK { get; init; }
    [JsonPropertyName("vitaminB1")]
    public double? VitaminB1 { get; init; }
    [JsonPropertyName("vitaminB2")]
    public double? VitaminB2 { get; init; }
    [JsonPropertyName("vitaminB3")]
    public double? VitaminB3 { get; init; }
    [JsonPropertyName("vitaminB6")]
    public double? VitaminB6 { get; init; }
    [JsonPropertyName("vitaminB9")]
    public double? VitaminB9 { get; init; }
    [JsonPropertyName("vitaminB12")]
    public double? VitaminB12 { get; init; }

    public double? Calcium { get; init; }
    public double? Iron { get; init; }
    public double? Magnesium { get; init; }
    public double? Potassium { get; init; }
    public double? Zinc { get; init; }

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true,
    };

    /// <summary>Parses a <see cref="Models.FoodItem.ExtendedNutrientsJson"/>-shaped
    /// blob. Returns null for a null, empty, or malformed blob — a client-authored
    /// value must never fail a trainer's read of an otherwise-healthy day. See
    /// <see cref="TrainerConsoleService"/> where this is called per resolved food.</summary>
    public static ExtendedNutrients? TryParse(string? json)
    {
        if (string.IsNullOrWhiteSpace(json)) return null;
        try
        {
            return JsonSerializer.Deserialize<ExtendedNutrients>(json, JsonOptions);
        }
        catch (JsonException)
        {
            return null;
        }
    }

    /// <summary>Null-preserving addition, mirroring the Dart side's
    /// <c>operator +</c>: a nutrient neither side reported stays null, never
    /// becomes a reported zero. <c>null + null == null</c>, <c>null + 5 == 5</c>.</summary>
    public static ExtendedNutrients operator +(ExtendedNutrients a, ExtendedNutrients b)
    {
        static double? Add(double? x, double? y) =>
            x is null && y is null ? null : (x ?? 0) + (y ?? 0);

        return new ExtendedNutrients
        {
            Fiber = Add(a.Fiber, b.Fiber),
            Sugar = Add(a.Sugar, b.Sugar),
            SaturatedFat = Add(a.SaturatedFat, b.SaturatedFat),
            Salt = Add(a.Salt, b.Salt),
            Sodium = Add(a.Sodium, b.Sodium),
            VitaminA = Add(a.VitaminA, b.VitaminA),
            VitaminC = Add(a.VitaminC, b.VitaminC),
            VitaminD = Add(a.VitaminD, b.VitaminD),
            VitaminE = Add(a.VitaminE, b.VitaminE),
            VitaminK = Add(a.VitaminK, b.VitaminK),
            VitaminB1 = Add(a.VitaminB1, b.VitaminB1),
            VitaminB2 = Add(a.VitaminB2, b.VitaminB2),
            VitaminB3 = Add(a.VitaminB3, b.VitaminB3),
            VitaminB6 = Add(a.VitaminB6, b.VitaminB6),
            VitaminB9 = Add(a.VitaminB9, b.VitaminB9),
            VitaminB12 = Add(a.VitaminB12, b.VitaminB12),
            Calcium = Add(a.Calcium, b.Calcium),
            Iron = Add(a.Iron, b.Iron),
            Magnesium = Add(a.Magnesium, b.Magnesium),
            Potassium = Add(a.Potassium, b.Potassium),
            Zinc = Add(a.Zinc, b.Zinc),
        };
    }

    /// <summary>The identity for <see cref="Sum"/> and <c>operator +</c> — every
    /// field null, not zero.</summary>
    public static readonly ExtendedNutrients Empty = new();

    /// <summary>Folds a collection with <c>operator +</c>. Returns <see cref="Empty"/>
    /// for an empty sequence, not a claim that zero was eaten.</summary>
    public static ExtendedNutrients Sum(IEnumerable<ExtendedNutrients> values)
    {
        var total = Empty;
        foreach (var v in values) total += v;
        return total;
    }

    public bool HasAnyData =>
        Fiber is not null || Sugar is not null || SaturatedFat is not null ||
        Salt is not null || Sodium is not null ||
        VitaminA is not null || VitaminC is not null || VitaminD is not null ||
        VitaminE is not null || VitaminK is not null || VitaminB1 is not null ||
        VitaminB2 is not null || VitaminB3 is not null || VitaminB6 is not null ||
        VitaminB9 is not null || VitaminB12 is not null ||
        Calcium is not null || Iron is not null || Magnesium is not null ||
        Potassium is not null || Zinc is not null;
}
