/// Date arithmetic and streak aggregation for the progress dashboard.
///
/// Extracted from `progress_dashboard_view.dart` (1,621 lines, no tests). The
/// three pieces here have one thing in common: each has already been wrong in
/// production, and each was wrong in a way that produced a *plausible number*.
/// A "last 7 days" average taken over 8 days is still an average. A week key
/// that collides across years still buckets. Nothing crashes, nothing fails to
/// compile, and the screen renders a figure the user has no way to check.
///
/// The comments preserved below are the record of those two bugs. The tests
/// beside this file are what stops them coming back.
library;

/// The ranges offered by the dashboard's range chips.
enum TimeRange { week, month, threeMonths, allTime, custom }

/// A week key that is unique across years and sorts chronologically.
///
/// This used to return the week index within its own year, so week 5 of two
/// different years landed in the same bucket — merging their calories into
/// one trend point, and inflating the workouts-per-week average by counting
/// two years' sessions as one week. Only reachable from the multi-year
/// ranges ("All time"), but wrong wherever it happened.
int weekKey(DateTime date) {
  final startOfYear = DateTime(date.year, 1, 1);
  final days = date.difference(startOfYear).inDays;
  final weekOfYear = (days / 7).floor();
  return date.year * 100 + weekOfYear;
}

/// The inclusive start of [range], counting back from [now].
///
/// [hasPremium] is passed in rather than read from a provider: the depth gate
/// is a rule about ranges, not about widgets, and a function that reaches for
/// a `BuildContext` to answer a date question cannot be tested without one.
DateTime rangeStart(
  TimeRange range, {
  required bool hasPremium,
  required DateTime now,
  DateTime? customStart,
}) {
  // Free tier gets up to 90 days of history; all-time and custom ranges
  // are premium (depth gate — the range chips enforce the same split).
  if (!hasPremium &&
      (range == TimeRange.allTime || range == TimeRange.custom)) {
    return now.subtract(const Duration(days: 89));
  }
  if (range == TimeRange.custom && customStart != null) return customStart;
  // n - 1, because the range is inclusive of both today and the start day.
  // Subtracting the full period gave n + 1 days: "last 7 days" spanned 8,
  // which is why day counters read 5/8 instead of 5/7 and why every average
  // was taken over one day too many.
  switch (range) {
    case TimeRange.week:
      return now.subtract(const Duration(days: 6));
    case TimeRange.month:
      return now.subtract(const Duration(days: 29));
    case TimeRange.threeMonths:
      return now.subtract(const Duration(days: 89));
    case TimeRange.allTime:
      return DateTime(2000);
    case TimeRange.custom:
      return now.subtract(const Duration(days: 29));
  }
}

class WorkoutFrequencyData {
  final int totalWorkouts;
  final Map<int, int> weeklyWorkouts;
  final int currentStreak;
  final int longestStreak;
  final double averagePerWeek;

  WorkoutFrequencyData({
    required this.totalWorkouts,
    required this.weeklyWorkouts,
    required this.currentStreak,
    required this.longestStreak,
    required this.averagePerWeek,
  });
}

/// Buckets completed sessions by week and derives the streak figures.
///
/// [completedDates] must be **ascending**; the caller's query orders them, and
/// the streak walk depends on it — fed unsorted dates it reports a streak of
/// 1 for a solid month of training, because a backwards step reads as a gap.
/// That ordering requirement used to be implicit in a `..orderBy` fifty lines
/// away from the loop that relied on it.
///
/// A gap of up to two days keeps a streak alive: a rest day between sessions
/// is training, not a lapse. The same tolerance decides whether the *current*
/// streak is still running, measured from [now] — so a streak that ended three
/// days ago reports 0 while still counting toward the longest.
WorkoutFrequencyData summariseFrequency(
  List<DateTime> completedDates, {
  required DateTime now,
}) {
  final weeklyWorkouts = <int, int>{};
  int currentStreak = 0;
  int longestStreak = 0;
  DateTime? lastWorkoutDate;

  for (final date in completedDates) {
    final key = weekKey(date);
    weeklyWorkouts[key] = (weeklyWorkouts[key] ?? 0) + 1;

    if (lastWorkoutDate == null) {
      currentStreak = 1;
    } else {
      final daysDiff = date.difference(lastWorkoutDate).inDays;
      if (daysDiff <= 2) {
        currentStreak++;
      } else {
        if (currentStreak > longestStreak) longestStreak = currentStreak;
        currentStreak = 1;
      }
    }

    lastWorkoutDate = date;
  }

  if (currentStreak > longestStreak) longestStreak = currentStreak;

  final isStreakActive =
      lastWorkoutDate != null && now.difference(lastWorkoutDate).inDays <= 2;

  return WorkoutFrequencyData(
    totalWorkouts: completedDates.length,
    weeklyWorkouts: weeklyWorkouts,
    currentStreak: isStreakActive ? currentStreak : 0,
    longestStreak: longestStreak,
    averagePerWeek: weeklyWorkouts.isEmpty
        ? 0
        : weeklyWorkouts.values.reduce((a, b) => a + b) /
            weeklyWorkouts.length,
  );
}
