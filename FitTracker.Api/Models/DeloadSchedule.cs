using System.Text.Json;
using System.Text.Json.Serialization;

namespace FitTracker.Api.Models;

/// <summary>One deload week: which programme week, and how much volume it prescribes.</summary>
/// <remarks>
/// <see cref="VolumePercent"/> is the share of normal volume to <em>perform</em>, never the
/// reduction. 50 means "do half your sets". The distinction is restated on every declaration
/// because "a 50% deload" is used in the wild to mean both readings, and they differ by the
/// entire point of the feature. See <c>docs/deload-weeks.md</c> §4.
/// </remarks>
public sealed record DeloadWeek
{
    /// <summary>1-based programme week, counted from the plan's <c>StartDate</c>.</summary>
    [JsonPropertyName("week")]
    public int Week { get; init; }

    /// <summary>Share of normal volume to perform, as a percentage. Not the reduction.</summary>
    [JsonPropertyName("volumePercent")]
    public int VolumePercent { get; init; } = DefaultVolumePercent;

    /// <summary>The middle of the "moderate recovery need" band (40–60% retained).</summary>
    public const int DefaultVolumePercent = 50;

    /// <summary>100% retained is not a deload; 0% is total cessation, a different
    /// intervention with its own (unfavourable) evidence. Neither end is reachable.</summary>
    public const int MinVolumePercent = 10;

    /// <inheritdoc cref="MinVolumePercent"/>
    public const int MaxVolumePercent = 90;

    public static bool IsValidVolumePercent(int value) =>
        value >= MinVolumePercent && value <= MaxVolumePercent;

    public bool IsValid() => Week >= 1 && IsValidVolumePercent(VolumePercent);
}

/// <summary>
/// The set of deload weeks declared on a plan: parsing, serialising, and the set arithmetic.
/// </summary>
/// <remarks>
/// <para>This is the C# half of a pair. <c>DeloadSchedule</c> in the Flutter client
/// (<c>feature/workout_planning/domain/deload_schedule.dart</c>) is the other, and both are
/// pinned by the same table of cases — the trainee app is offline-first and must answer "is
/// today a deload" with no server, while the server needs the same answer for its own reads.
/// Two implementations of one rule will drift; the mitigation is that a case added to one
/// test table is added to the other. See <c>docs/deload-weeks.md</c> §2b.</para>
/// </remarks>
public static class DeloadSchedule
{
    private static readonly JsonSerializerOptions SerializerOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
    };

    /// <summary>Parses the stored column.</summary>
    /// <remarks>
    /// Fail-soft throughout: a null, empty, malformed or wrong-typed value is an empty
    /// schedule, and an unusable individual entry is skipped rather than taking the rest of
    /// the set with it. A plan whose deload column is corrupt should train as a normal plan,
    /// not fail to load.
    /// <para>This is <em>not</em> how "the field was absent" is handled. An omitted field
    /// means "not provided", never "clear it" (§5a/§7a) — that distinction belongs to the
    /// caller, which must not reach this method at all for a missing key.</para>
    /// </remarks>
    public static IReadOnlyList<DeloadWeek> Parse(string? json)
    {
        if (string.IsNullOrWhiteSpace(json)) return [];

        List<DeloadWeek>? parsed;
        try
        {
            parsed = JsonSerializer.Deserialize<List<DeloadWeek>>(json, SerializerOptions);
        }
        catch (JsonException)
        {
            return [];
        }

        return parsed == null ? [] : Normalise(parsed);
    }

    /// <summary>Serialises a set for storage. Always valid JSON, never null.</summary>
    public static string Serialise(IEnumerable<DeloadWeek> weeks) =>
        JsonSerializer.Serialize(Normalise(weeks), SerializerOptions);

    /// <summary>Sorts by week, keeps one entry per week (last wins) and drops invalid ones.</summary>
    /// <remarks>
    /// Applied on the way in <em>and</em> the way out. Callers build these from client
    /// payloads, which are trusted to be neither ordered nor unique.
    /// </remarks>
    public static IReadOnlyList<DeloadWeek> Normalise(IEnumerable<DeloadWeek> weeks)
    {
        var byWeek = new Dictionary<int, DeloadWeek>();
        foreach (var week in weeks)
        {
            if (!week.IsValid()) continue;
            byWeek[week.Week] = week;
        }

        return byWeek.Values.OrderBy(w => w.Week).ToList();
    }

    /// <summary>True when every entry is usable — for validating a write before applying it.</summary>
    /// <remarks>
    /// A write rejects rather than silently normalising: <see cref="Normalise"/> dropping a
    /// bad week would save a schedule the caller didn't ask for and report success.
    /// </remarks>
    public static bool AllValid(IEnumerable<DeloadWeek> weeks, int? durationWeeks = null) =>
        weeks.All(w => w.IsValid() && (durationWeeks == null || w.Week <= durationWeeks));
}

/// <summary>Programme-week arithmetic. The mirror of <c>PlanWeek</c> in the Flutter client.</summary>
public static class PlanWeeks
{
    /// <summary>
    /// The 1-based programme week <paramref name="date"/> falls in, or null when it is
    /// outside the plan.
    /// </summary>
    /// <remarks>
    /// Null means "there is no deload question to ask here", never "week 0".
    /// <para>Both ends are reduced to a <see cref="DateTime.Date"/> before subtracting.
    /// Doing this on the raw instants is wrong twice over: <c>StartDate</c> carries a time of
    /// day, so the week boundary moves with it; and a local day is 23 or 25 hours across a
    /// DST changeover, so a <c>TimeSpan.Days</c> truncates to the wrong day twice a year.</para>
    /// </remarks>
    public static int? WeekNumberFor(DateTime planStart, DateTime date, int? durationDays = null)
    {
        var elapsed = (date.Date - planStart.Date).Days;
        if (elapsed < 0) return null;
        if (durationDays != null && elapsed >= durationDays) return null;
        return elapsed / 7 + 1;
    }

    /// <summary>Weeks a plan of <paramref name="durationDays"/> runs for, rounding a partial
    /// trailing week up so it still exists as a week.</summary>
    public static int WeeksIn(int durationDays) => (int)Math.Ceiling(durationDays / 7.0);

    /// <summary>
    /// How many of an exercise's <paramref name="totalSets"/> count as prescribed in a deload
    /// week at <paramref name="volumePercent"/> of normal volume.
    /// </summary>
    /// <remarks>
    /// <para><see cref="MidpointRounding.AwayFromZero"/> is passed <em>explicitly</em> and must
    /// stay that way. C# rounds halves to even by default and Dart's <c>num.round()</c> rounds
    /// them away from zero, and the most common configuration in this feature lands exactly on
    /// a midpoint: 5 sets at the default 50% is 2.5 — three sets on the client, two here under
    /// the default rule. The two halves of the pair would disagree about the same prescription.</para>
    /// <para>Never returns 0. At 10% volume a two-set exercise rounds to nothing, and an
    /// exercise where every set is optional is one the UI has quietly told the trainee to
    /// skip — cessation arrived at by rounding rather than by anyone choosing it.</para>
    /// </remarks>
    public static int KeptSetCount(int totalSets, int volumePercent)
    {
        if (totalSets <= 0) return 0;
        var kept = (int)Math.Round(totalSets * volumePercent / 100.0, MidpointRounding.AwayFromZero);
        return Math.Clamp(kept, 1, totalSets);
    }
}
