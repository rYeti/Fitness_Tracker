import 'package:flutter_test/flutter_test.dart';

import 'package:ForgeForm/feature/progress/domain/progress_ranges.dart';

/// Two bugs are recorded in the comments of the code under test: a range that
/// spanned one day too many, and a week key that collided across years. Both
/// shipped, both produced numbers that looked fine, and neither had a test.
/// These are those tests.
void main() {
  // Fixed so nothing here depends on the day it runs. A Wednesday.
  final now = DateTime(2026, 8, 26, 14, 30);

  group('rangeStart', () {
    test('a range is inclusive of both ends, so "7 days" spans 7', () {
      final start = rangeStart(TimeRange.week, hasPremium: true, now: now);
      // Counting the start day and today, inclusive.
      expect(now.difference(start).inDays + 1, 7);
    });

    test('month and three months span 30 and 90 inclusive days', () {
      for (final (range, days) in [
        (TimeRange.month, 30),
        (TimeRange.threeMonths, 90),
      ]) {
        final start = rangeStart(range, hasPremium: true, now: now);
        expect(
          now.difference(start).inDays + 1,
          days,
          reason: '$range should span $days days inclusive',
        );
      }
    });

    test('all time reaches back before any plausible record', () {
      expect(
        rangeStart(TimeRange.allTime, hasPremium: true, now: now),
        DateTime(2000),
      );
    });

    test('a custom range starts where the user said', () {
      final chosen = DateTime(2026, 1, 15);
      expect(
        rangeStart(
          TimeRange.custom,
          hasPremium: true,
          now: now,
          customStart: chosen,
        ),
        chosen,
      );
    });

    test('a custom range with no start falls back to a month', () {
      final start = rangeStart(TimeRange.custom, hasPremium: true, now: now);
      expect(now.difference(start).inDays + 1, 30);
    });

    group('the free-tier depth gate', () {
      test('caps all-time and custom at 90 days', () {
        for (final range in [TimeRange.allTime, TimeRange.custom]) {
          final start = rangeStart(
            range,
            hasPremium: false,
            now: now,
            customStart: DateTime(2020),
          );
          expect(
            now.difference(start).inDays + 1,
            90,
            reason: '$range must not reach past the free window',
          );
        }
      });

      test('a chosen custom start inside the window is still capped', () {
        // The gate is a floor on depth, not a filter on intent: it ignores
        // customStart entirely rather than taking the later of the two. That
        // means a free user picking "last week" gets 90 days, not 7 — a
        // deliberate simplification, pinned here so it is a decision rather
        // than a surprise.
        final start = rangeStart(
          TimeRange.custom,
          hasPremium: false,
          now: now,
          customStart: DateTime(2026, 8, 20),
        );
        expect(now.difference(start).inDays + 1, 90);
      });

      test('the ranges inside the free window are unaffected', () {
        for (final range in [
          TimeRange.week,
          TimeRange.month,
          TimeRange.threeMonths,
        ]) {
          expect(
            rangeStart(range, hasPremium: false, now: now),
            rangeStart(range, hasPremium: true, now: now),
            reason: '$range is free either way',
          );
        }
      });
    });
  });

  group('weekKey', () {
    test('two dates in the same week share a key', () {
      expect(weekKey(DateTime(2026, 8, 24)), weekKey(DateTime(2026, 8, 26)));
    });

    test('the same week index in different years does not collide', () {
      // The original bug: both returned 5, so two years of training merged
      // into one bucket and inflated the per-week average.
      expect(
        weekKey(DateTime(2025, 2, 5)),
        isNot(weekKey(DateTime(2026, 2, 5))),
      );
    });

    test('keys sort chronologically across a year boundary', () {
      final keys = [
        weekKey(DateTime(2025, 12, 30)),
        weekKey(DateTime(2026, 1, 2)),
        weekKey(DateTime(2026, 6, 1)),
      ];
      expect(keys, orderedEquals([...keys]..sort()));
    });
  });

  group('summariseFrequency', () {
    test('no sessions is a legitimate zero, not a divide by zero', () {
      final data = summariseFrequency([], now: now);
      expect(data.totalWorkouts, 0);
      expect(data.currentStreak, 0);
      expect(data.longestStreak, 0);
      expect(data.averagePerWeek, 0);
      expect(data.weeklyWorkouts, isEmpty);
    });

    test('counts every session and buckets them by week', () {
      final data = summariseFrequency([
        DateTime(2026, 8, 24),
        DateTime(2026, 8, 26),
        DateTime(2026, 8, 31),
      ], now: now);
      expect(data.totalWorkouts, 3);
      expect(data.weeklyWorkouts.length, 2);
      expect(data.averagePerWeek, 1.5);
    });

    test('a rest day of up to two days keeps a streak alive', () {
      final data = summariseFrequency([
        DateTime(2026, 8, 22),
        DateTime(2026, 8, 24), // two days later — still the same streak
        DateTime(2026, 8, 26),
      ], now: now);
      expect(data.currentStreak, 3);
      expect(data.longestStreak, 3);
    });

    test('a three-day gap breaks it', () {
      final data = summariseFrequency([
        DateTime(2026, 8, 18),
        DateTime(2026, 8, 19),
        DateTime(2026, 8, 20), // longest run: 3
        DateTime(2026, 8, 25),
        DateTime(2026, 8, 26), // current run: 2
      ], now: now);
      expect(data.currentStreak, 2);
      expect(data.longestStreak, 3);
    });

    test('a streak that ended reports zero but still counts as the longest', () {
      final data = summariseFrequency([
        DateTime(2026, 8, 10),
        DateTime(2026, 8, 11),
        DateTime(2026, 8, 12),
      ], now: now); // two weeks ago
      expect(
        data.currentStreak,
        0,
        reason: 'nothing logged for a fortnight is not an active streak',
      );
      expect(data.longestStreak, 3);
    });

    test('the last session still counts toward the longest streak', () {
      // The final run is only compared against longestStreak after the loop
      // ends; without that comparison a personal best set in the current
      // streak would never be recorded.
      final data = summariseFrequency([
        DateTime(2026, 8, 1),
        DateTime(2026, 8, 10),
        DateTime(2026, 8, 11),
        DateTime(2026, 8, 12),
        DateTime(2026, 8, 13),
      ], now: DateTime(2026, 8, 13));
      expect(data.longestStreak, 4);
    });

    test('a single session is a streak of one', () {
      final data = summariseFrequency([DateTime(2026, 8, 26)], now: now);
      expect(data.currentStreak, 1);
      expect(data.longestStreak, 1);
      expect(data.averagePerWeek, 1);
    });
  });
}
