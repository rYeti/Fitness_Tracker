import 'dart:convert';

/// Deload weeks: which weeks of a programme are recovery weeks, and how much
/// volume each one prescribes.
///
/// See `docs/deload-weeks.md` for the design and the evidence behind the
/// numbers. The parts that matter when reading this file:
///
/// - A week is anchored on the plan's `startDate`, not the calendar. The
///   Trainer Console's attendance bars are Monday-anchored and are a
///   *different* week (§2).
/// - [DeloadWeek.volumePercent] is the share of normal volume to **perform**,
///   never the reduction (§4).
/// - A deload never changes training frequency. Nothing here removes a
///   session; the schedule is untouched and only the per-set guidance changes
///   (§3c, §8).

/// One deload week: which programme week, and how much volume it prescribes.
class DeloadWeek {
  /// 1-based programme week, counted from the plan's `startDate`.
  ///
  /// One-based because the UI says "Week 5", and storing zero-based numbers
  /// behind a one-based label is the most reliable way to ship an off-by-one.
  final int week;

  /// The share of normal volume to **perform**, as a percentage — *not* the
  /// reduction. 50 means "do half your sets", i.e. a 50% cut.
  ///
  /// The distinction is spelled out everywhere this field is declared because
  /// "a 50% deload" is used in the wild to mean both readings, and they differ
  /// by the entire point of the feature.
  final int volumePercent;

  const DeloadWeek({required this.week, required this.volumePercent});

  /// The default a newly-marked week gets: the middle of the "moderate
  /// recovery need" band (40–60% retained) from the literature. See
  /// `docs/deload-weeks.md` §3a.
  static const int defaultVolumePercent = 50;

  /// 100% retained is not a deload; 0% is total cessation, which is a
  /// different intervention with its own (unfavourable) evidence. Neither end
  /// is reachable by a slider — see `docs/deload-weeks.md` §3c.
  static const int minVolumePercent = 10;
  static const int maxVolumePercent = 90;

  static bool isValidVolumePercent(int value) =>
      value >= minVolumePercent && value <= maxVolumePercent;

  DeloadWeek copyWith({int? week, int? volumePercent}) => DeloadWeek(
    week: week ?? this.week,
    volumePercent: volumePercent ?? this.volumePercent,
  );

  Map<String, dynamic> toJson() => {
    'week': week,
    'volumePercent': volumePercent,
  };

  /// Returns null rather than throwing for an entry that isn't usable, so one
  /// bad row costs one week rather than the whole schedule — the same
  /// fail-soft choice `docs/chat-encryption.md` records for `decrypt`.
  static DeloadWeek? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    final week = raw['week'];
    if (week is! int || week < 1) return null;
    final volume = raw['volumePercent'];
    final resolved = volume is int ? volume : defaultVolumePercent;
    if (!isValidVolumePercent(resolved)) return null;
    return DeloadWeek(week: week, volumePercent: resolved);
  }

  @override
  bool operator ==(Object other) =>
      other is DeloadWeek &&
      other.week == week &&
      other.volumePercent == volumePercent;

  @override
  int get hashCode => Object.hash(week, volumePercent);

  @override
  String toString() => 'DeloadWeek(week: $week, volume: $volumePercent%)';
}

/// The whole set of deload weeks declared on a plan, and the operations the UI
/// performs on it.
///
/// Every mutating method returns a **new** schedule rather than editing in
/// place: a deload write always replaces the whole set (`docs/deload-weeks.md`
/// §4), because a replace is idempotent by construction and an add/remove pair
/// is two operations that can interleave.
class DeloadSchedule {
  /// Sorted by [DeloadWeek.week], at most one entry per week.
  final List<DeloadWeek> weeks;

  const DeloadSchedule._(this.weeks);

  static const DeloadSchedule empty = DeloadSchedule._([]);

  factory DeloadSchedule(Iterable<DeloadWeek> weeks) {
    // Deduplicate by week, last writer wins, then sort. Callers build these
    // from user taps and from server payloads; neither is trusted to be
    // ordered or unique.
    final byWeek = <int, DeloadWeek>{};
    for (final w in weeks) {
      byWeek[w.week] = w;
    }
    final sorted = byWeek.values.toList()
      ..sort((a, b) => a.week.compareTo(b.week));
    return DeloadSchedule._(List.unmodifiable(sorted));
  }

  bool get isEmpty => weeks.isEmpty;
  bool get isNotEmpty => weeks.isNotEmpty;

  /// The deload declared for [week], or null if that week is a normal week.
  DeloadWeek? forWeek(int? week) {
    if (week == null) return null;
    for (final w in weeks) {
      if (w.week == week) return w;
    }
    return null;
  }

  bool isDeload(int? week) => forWeek(week) != null;

  /// Marks [week] as a deload, or clears it if it already is one.
  ///
  /// This is the primary interaction: one tap, one week, nothing else touched.
  /// Marking a single week is the common case — "this athlete is beaten up
  /// now" — and it must never opt the user into a cadence (§4a).
  DeloadSchedule toggle(int week, {int? volumePercent}) {
    if (isDeload(week)) {
      return DeloadSchedule(weeks.where((w) => w.week != week));
    }
    return DeloadSchedule([
      ...weeks,
      DeloadWeek(
        week: week,
        volumePercent: volumePercent ?? DeloadWeek.defaultVolumePercent,
      ),
    ]);
  }

  /// Retunes the volume of a week that is already a deload. A no-op on a week
  /// that isn't one — setting a volume is not a way to create a deload, so a
  /// stray slider drag can't mark a week.
  DeloadSchedule withVolume(int week, int volumePercent) {
    if (!isDeload(week) || !DeloadWeek.isValidVolumePercent(volumePercent)) {
      return this;
    }
    return DeloadSchedule(
      weeks.map(
        (w) => w.week == week ? w.copyWith(volumePercent: volumePercent) : w,
      ),
    );
  }

  /// Expands a "repeat every N weeks" cadence into explicit entries.
  ///
  /// Three rules, all from `docs/deload-weeks.md` §4a:
  ///
  /// - The final week is excluded **strictly**. A block that ends on its
  ///   easiest week is a bug, not a taper: without this, "every 4 weeks" on a
  ///   12-week plan yields weeks 4, 8 and 12, and week 12 is the last one.
  /// - It **merges**, never replaces. A week that already has a deload keeps
  ///   the volume it was given, so reaching for a cadence never silently
  ///   rewrites a prescription already made by hand.
  /// - A plan too short to hold one (a 4-week plan at every-4-weeks) yields
  ///   nothing. Callers are expected to say so rather than show an empty
  ///   result as success.
  DeloadSchedule withCadence(
    int everyNWeeks,
    int durationWeeks, {
    int? volumePercent,
  }) {
    if (everyNWeeks < 1 || durationWeeks < 1) return this;
    final generated = <DeloadWeek>[];
    for (var week = everyNWeeks; week < durationWeeks; week += everyNWeeks) {
      if (isDeload(week)) continue;
      generated.add(
        DeloadWeek(
          week: week,
          volumePercent: volumePercent ?? DeloadWeek.defaultVolumePercent,
        ),
      );
    }
    return DeloadSchedule([...weeks, ...generated]);
  }

  /// Drops any week beyond the plan's length. A plan shortened after its
  /// deloads were set would otherwise keep entries nothing can reach or edit.
  DeloadSchedule clampTo(int durationWeeks) =>
      DeloadSchedule(weeks.where((w) => w.week <= durationWeeks));

  List<Map<String, dynamic>> toJson() =>
      weeks.map((w) => w.toJson()).toList(growable: false);

  String encode() => jsonEncode(toJson());

  /// Parses the stored column.
  ///
  /// Fail-soft throughout: a null, empty, malformed or wrong-typed value is an
  /// empty schedule, and an unusable individual entry is skipped rather than
  /// taking the rest of the set with it. A plan whose deload column is corrupt
  /// should train as a normal plan, not fail to open.
  ///
  /// Note this is *not* how "the field was absent" is handled — absence means
  /// "not provided", never "clear it" (§5a/§7a), and that distinction lives at
  /// the sync layer, which must not call this method on a missing key at all.
  static DeloadSchedule decode(String? json) {
    if (json == null || json.trim().isEmpty) return empty;
    Object? raw;
    try {
      raw = jsonDecode(json);
    } catch (_) {
      return empty;
    }
    if (raw is! List) return empty;
    final parsed = <DeloadWeek>[];
    for (final entry in raw) {
      final week = DeloadWeek.tryFromJson(entry);
      if (week != null) parsed.add(week);
    }
    return DeloadSchedule(parsed);
  }

  @override
  String toString() => 'DeloadSchedule(${weeks.join(', ')})';
}

/// Programme-week arithmetic, in one place.
///
/// The C# side has a mirror of this (`PlanWeeks`), and both are pinned by the
/// same table of cases — see `docs/deload-weeks.md` §2b. A case added to one
/// test table is added to the other.
class PlanWeek {
  const PlanWeek._();

  /// The 1-based programme week that [date] falls in, or null when [date] is
  /// outside the plan.
  ///
  /// Null means "there is no deload question to ask here", never "week 0".
  ///
  /// Both ends are normalised to a **date** before subtracting. Doing this on
  /// the raw instants is wrong twice over: `startDate` carries a time of day,
  /// so the week boundary moves with it; and a local day is 23 or 25 hours on
  /// a DST changeover, so `.inDays` truncates to the wrong day twice a year.
  static int? weekNumberFor(
    DateTime planStart,
    DateTime date, {
    int? durationDays,
  }) {
    final elapsed = daysBetween(planStart, date);
    if (elapsed < 0) return null;
    if (durationDays != null && elapsed >= durationDays) return null;
    return elapsed ~/ 7 + 1;
  }

  /// Whole calendar days from [a] to [b], ignoring time of day and DST.
  ///
  /// The `DateTime.utc` is a normalisation trick, not a timezone conversion:
  /// both operands are moved to the same fictional zone, so the difference is
  /// exactly the number of calendar days between them.
  static int daysBetween(DateTime a, DateTime b) =>
      DateTime.utc(b.year, b.month, b.day)
          .difference(DateTime.utc(a.year, a.month, a.day))
          .inDays;

  /// How many weeks a plan of [durationDays] runs for, rounded up so a partial
  /// trailing week still exists as a week.
  static int weeksIn(int durationDays) => (durationDays / 7).ceil();
}

/// How many of an exercise's [totalSets] to treat as prescribed in a deload
/// week at [volumePercent] of normal volume.
///
/// **Rounds half away from zero**, matching Dart's `num.round()`. This is
/// pinned rather than left to each language's default because C# and Python
/// both round halves to *even* by default, and the most common configuration
/// in this whole feature lands exactly on a midpoint: 5 sets at the default
/// 50% is 2.5 — three sets under Dart's rule, two under a banker's-rounding
/// one. The C# mirror must pass `MidpointRounding.AwayFromZero` explicitly.
///
/// Never returns 0. At 10% volume a two-set exercise rounds to nothing, and an
/// exercise where every set is optional is one the UI has quietly told the
/// trainee to skip — which is cessation (§3c), arrived at by rounding rather
/// than by anyone choosing it.
int keptSetCount(int totalSets, int volumePercent) {
  if (totalSets <= 0) return 0;
  final kept = (totalSets * volumePercent / 100).round();
  return kept < 1 ? 1 : (kept > totalSets ? totalSets : kept);
}
