import 'package:flutter_test/flutter_test.dart';

import 'package:ForgeForm/feature/workout_planning/domain/deload_schedule.dart';

/// Deload weeks: the week arithmetic, the stored schedule, and the set count a
/// deload week prescribes. See `docs/deload-weeks.md`.
///
/// **The `PlanWeek` cases in this file are one half of a pair.** The API has a
/// mirror (`PlanWeeks` in C#) pinned by the same table, because the trainee app
/// is offline-first and must resolve "is today a deload" with no server, while
/// the server needs the same answer for its own reads. Two implementations of
/// one rule will drift; the mitigation is that a case added to one table is
/// added to the other (§2b).
void main() {
  group('PlanWeek.weekNumberFor', () {
    // Deliberately a Wednesday. A plan anchored mid-week is the case that
    // breaks any implementation that reaches for a Monday-anchored calendar
    // week — which the Trainer Console's attendance bars genuinely are, and
    // which is a *different* week from this one (§2).
    final start = DateTime(2026, 9, 2);

    test('the start day is week 1, not week 0', () {
      expect(PlanWeek.weekNumberFor(start, start), 1);
    });

    test('day 6 is still week 1 and day 7 rolls to week 2', () {
      expect(PlanWeek.weekNumberFor(start, DateTime(2026, 9, 8)), 1);
      expect(PlanWeek.weekNumberFor(start, DateTime(2026, 9, 9)), 2);
    });

    test('week boundaries follow the plan, not the calendar', () {
      // Day 27 / day 28. Both are inside the same Monday-anchored calendar
      // week; they are different programme weeks.
      expect(PlanWeek.weekNumberFor(start, DateTime(2026, 9, 29)), 4);
      expect(PlanWeek.weekNumberFor(start, DateTime(2026, 9, 30)), 5);
    });

    test('a date before the plan starts has no week', () {
      expect(PlanWeek.weekNumberFor(start, DateTime(2026, 9, 1)), isNull);
    });

    test('the last day is in the plan and the day after is not', () {
      // durationDays 84 = 12 weeks. Day 83 is the last day.
      expect(
        PlanWeek.weekNumberFor(start, DateTime(2026, 11, 24), durationDays: 84),
        12,
      );
      expect(
        PlanWeek.weekNumberFor(start, DateTime(2026, 11, 25), durationDays: 84),
        isNull,
      );
    });

    test('an open-ended plan keeps counting past any duration', () {
      expect(PlanWeek.weekNumberFor(start, DateTime(2027, 9, 2)), 53);
    });

    test('time of day on either operand cannot move a week boundary', () {
      // The bug this pins: `startDate` is an instant, not a day. A plan
      // created at 23:30 and a session logged at 00:30 are 1 hour apart and
      // must still be the same programme day.
      final lateStart = DateTime(2026, 9, 2, 23, 30);
      expect(PlanWeek.weekNumberFor(lateStart, DateTime(2026, 9, 8, 0, 30)), 1);
      expect(PlanWeek.weekNumberFor(lateStart, DateTime(2026, 9, 9, 0, 30)), 2);
    });

    group('DST', () {
      // A local day is 23 or 25 hours across a changeover, so subtracting
      // instants and taking `.inDays` truncates to the wrong day twice a year.
      // These pass regardless of the machine's zone because the arithmetic
      // normalises to dates first — which is the whole point.
      test('spring forward does not lose a day', () {
        final s = DateTime(2026, 3, 25);
        expect(PlanWeek.weekNumberFor(s, s), 1);
        expect(PlanWeek.weekNumberFor(s, DateTime(2026, 3, 31)), 1);
        expect(PlanWeek.weekNumberFor(s, DateTime(2026, 4, 1)), 2);
      });

      test('falling back does not gain a day', () {
        final s = DateTime(2026, 10, 21);
        expect(PlanWeek.weekNumberFor(s, s), 1);
        expect(PlanWeek.weekNumberFor(s, DateTime(2026, 10, 27)), 1);
        expect(PlanWeek.weekNumberFor(s, DateTime(2026, 10, 28)), 2);
      });
    });

    test('weeksIn rounds a partial trailing week up', () {
      expect(PlanWeek.weeksIn(84), 12);
      expect(PlanWeek.weeksIn(85), 13);
      expect(PlanWeek.weeksIn(7), 1);
    });
  });

  group('keptSetCount', () {
    test('takes the given share of the sets', () {
      expect(keptSetCount(4, 50), 2);
      expect(keptSetCount(6, 40), 2);
      expect(keptSetCount(4, 70), 3);
      expect(keptSetCount(8, 25), 2);
    });

    test('rounds halves away from zero, not to even', () {
      // The reason this is pinned rather than left to the language default:
      // C# and Python round halves to *even*, Dart rounds away from zero, and
      // the most common configuration in the feature lands on a midpoint.
      // 5 sets at the default 50% is 2.5 — three sets here, two under
      // banker's rounding. The C# mirror must pass MidpointRounding
      // .AwayFromZero explicitly to agree with this.
      expect(keptSetCount(5, 50), 3);
      expect(keptSetCount(3, 50), 2);
      expect(keptSetCount(7, 50), 4);
      expect(keptSetCount(5, 90), 5);
      expect(keptSetCount(10, 45), 5);
    });

    test('never returns zero', () {
      // An exercise where every set is optional is an exercise the UI has
      // quietly told the trainee to skip — cessation reached by rounding
      // rather than by anyone choosing it.
      expect(keptSetCount(2, 10), 1);
      expect(keptSetCount(1, 10), 1);
      expect(keptSetCount(3, 10), 1);
    });

    test('never exceeds the sets actually prescribed', () {
      expect(keptSetCount(2, 90), 2);
      expect(keptSetCount(1, 90), 1);
    });

    test('an exercise with no sets keeps none', () {
      expect(keptSetCount(0, 50), 0);
    });
  });

  group('DeloadSchedule round-trip', () {
    test('encodes and decodes back to the same schedule', () {
      final schedule = DeloadSchedule([
        const DeloadWeek(week: 5, volumePercent: 50),
        const DeloadWeek(week: 10, volumePercent: 40),
      ]);
      expect(DeloadSchedule.decode(schedule.encode()).weeks, schedule.weeks);
    });

    test('stores the share to perform, not the reduction', () {
      // Guards the one ambiguity that would invert the whole feature: a "50%
      // deload" is used in the wild to mean both readings.
      final encoded = DeloadSchedule([
        const DeloadWeek(week: 3, volumePercent: 40),
      ]).encode();
      expect(encoded, contains('"volumePercent":40'));
      expect(keptSetCount(5, 40), 2, reason: '40% retained = do 2 of 5 sets');
    });

    test('sorts by week and keeps one entry per week', () {
      final schedule = DeloadSchedule([
        const DeloadWeek(week: 9, volumePercent: 50),
        const DeloadWeek(week: 2, volumePercent: 60),
        const DeloadWeek(week: 9, volumePercent: 30),
      ]);
      expect(schedule.weeks.map((w) => w.week), [2, 9]);
      expect(schedule.forWeek(9)!.volumePercent, 30);
    });

    group('decode is fail-soft', () {
      test('null, empty and malformed all read as no deloads', () {
        expect(DeloadSchedule.decode(null).isEmpty, isTrue);
        expect(DeloadSchedule.decode('').isEmpty, isTrue);
        expect(DeloadSchedule.decode('   ').isEmpty, isTrue);
        expect(DeloadSchedule.decode('not json').isEmpty, isTrue);
        expect(DeloadSchedule.decode('{"week":1}').isEmpty, isTrue);
      });

      test('one unusable entry costs one week, not the whole schedule', () {
        final schedule = DeloadSchedule.decode(
          '[{"week":4,"volumePercent":50},'
          '{"week":0,"volumePercent":50},'
          '{"week":6,"volumePercent":999},'
          '"nonsense",'
          '{"week":8,"volumePercent":40}]',
        );
        expect(schedule.weeks.map((w) => w.week), [4, 8]);
      });

      test('an entry with no volume takes the default', () {
        final schedule = DeloadSchedule.decode('[{"week":4}]');
        expect(schedule.forWeek(4)!.volumePercent, 50);
      });
    });
  });

  group('toggle — the primary interaction', () {
    test('marks one week and touches nothing else', () {
      final schedule = DeloadSchedule.empty.toggle(7);
      expect(schedule.weeks.length, 1);
      expect(schedule.forWeek(7)!.volumePercent, 50);
      // The point of the whole interaction: a one-off deload never opts the
      // user into a cadence.
      expect(schedule.isDeload(14), isFalse);
      expect(schedule.isDeload(21), isFalse);
    });

    test('toggling the same week again clears it', () {
      expect(DeloadSchedule.empty.toggle(7).toggle(7).isEmpty, isTrue);
    });

    test('clearing one week leaves the others alone', () {
      final schedule = DeloadSchedule.empty.toggle(4).toggle(8).toggle(4);
      expect(schedule.weeks.map((w) => w.week), [8]);
    });
  });

  group('withVolume', () {
    test('retunes a week that is already a deload', () {
      final schedule = DeloadSchedule.empty.toggle(5).withVolume(5, 40);
      expect(schedule.forWeek(5)!.volumePercent, 40);
    });

    test('does not create a deload on a normal week', () {
      // A stray slider drag must not be able to mark a week.
      expect(DeloadSchedule.empty.withVolume(5, 40).isEmpty, isTrue);
    });

    test('refuses a volume outside the allowed band', () {
      final schedule = DeloadSchedule.empty.toggle(5);
      expect(schedule.withVolume(5, 0).forWeek(5)!.volumePercent, 50);
      expect(schedule.withVolume(5, 100).forWeek(5)!.volumePercent, 50);
      expect(schedule.withVolume(5, 10).forWeek(5)!.volumePercent, 10);
      expect(schedule.withVolume(5, 90).forWeek(5)!.volumePercent, 90);
    });
  });

  group('withCadence', () {
    test('excludes the final week strictly', () {
      // Without this, every-4-weeks on a 12-week plan ends the block on its
      // easiest week.
      expect(
        DeloadSchedule.empty.withCadence(4, 12).weeks.map((w) => w.week),
        [4, 8],
      );
      expect(
        DeloadSchedule.empty.withCadence(5, 12).weeks.map((w) => w.week),
        [5, 10],
      );
      expect(
        DeloadSchedule.empty.withCadence(4, 8).weeks.map((w) => w.week),
        [4],
      );
    });

    test('a plan too short for one yields nothing', () {
      // Callers must say so rather than presenting this as success.
      expect(DeloadSchedule.empty.withCadence(4, 4).isEmpty, isTrue);
      expect(DeloadSchedule.empty.withCadence(5, 4).isEmpty, isTrue);
    });

    test('merges into hand-set weeks without rewriting them', () {
      // Reaching for a cadence never silently overwrites a prescription
      // someone already made by hand.
      final schedule = DeloadSchedule.empty
          .toggle(4)
          .withVolume(4, 30)
          .withCadence(4, 12);
      expect(schedule.weeks.map((w) => w.week), [4, 8]);
      expect(schedule.forWeek(4)!.volumePercent, 30);
      expect(schedule.forWeek(8)!.volumePercent, 50);
    });

    test('generated weeks can take a caller-chosen volume', () {
      final schedule = DeloadSchedule.empty.withCadence(5, 12, volumePercent: 60);
      expect(schedule.weeks.every((w) => w.volumePercent == 60), isTrue);
    });
  });

  test('clampTo drops weeks past a shortened plan', () {
    final schedule = DeloadSchedule.empty.toggle(4).toggle(10);
    expect(schedule.clampTo(8).weeks.map((w) => w.week), [4]);
  });

  test('forWeek and isDeload treat a null week as no deload', () {
    // `weekNumberFor` returns null outside the plan, and that flows straight
    // into these — "no week to ask about" must not read as week 0 or crash.
    final schedule = DeloadSchedule.empty.toggle(1);
    expect(schedule.forWeek(null), isNull);
    expect(schedule.isDeload(null), isFalse);
  });
}
