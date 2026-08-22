import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ForgeForm/core/app_database.dart';

/// The dashboard used to fetch every scheduled workout ever recorded and count
/// in Dart on the first frame. These pin the SQL counts that replaced it to the
/// same boundaries the Dart filter used — a half-open [weekStart, weekEnd)
/// range — since getting them wrong shows up only as "the streak looks off".
void main() {
  late AppDatabase db;
  late int workoutId;

  setUp(() async {
    db = AppDatabase.test(NativeDatabase.memory());
    workoutId = await db
        .into(db.workoutTable)
        .insert(WorkoutTableCompanion.insert(name: 'Push A', difficulty: 2));
  });
  tearDown(() => db.close());

  Future<void> schedule(DateTime date, {bool completed = false}) {
    return db
        .into(db.scheduledWorkoutTable)
        .insert(
          ScheduledWorkoutTableCompanion.insert(
            workoutId: workoutId,
            scheduledDate: date,
            isCompleted: Value(completed),
          ),
        );
  }

  // Monday 2026-08-17 .. Sunday 2026-08-23.
  final weekStart = DateTime(2026, 8, 17);
  final weekEnd = weekStart.add(const Duration(days: 7));

  test('counts the week half-open, excluding the next week\'s Monday', () async {
    await schedule(weekStart); // first instant in range
    await schedule(DateTime(2026, 8, 20, 18, 30), completed: true);
    await schedule(DateTime(2026, 8, 23, 23, 59)); // last day, still in range
    await schedule(weekEnd); // next Monday — must be excluded
    await schedule(DateTime(2026, 8, 16, 23, 59)); // day before — excluded

    final dao = db.scheduledWorkoutDao;
    expect(await dao.countInRange(start: weekStart, end: weekEnd), 3);
    expect(
      await dao.countInRange(start: weekStart, end: weekEnd, completed: true),
      1,
    );
  });

  test('all-time completed ignores the date window', () async {
    await schedule(DateTime(2024, 1, 5), completed: true);
    await schedule(DateTime(2026, 8, 20), completed: true);
    await schedule(DateTime(2026, 8, 21));

    expect(await db.scheduledWorkoutDao.countCompleted(), 2);
    expect(
      await db.scheduledWorkoutDao.countInRange(
        start: weekStart,
        end: weekEnd,
        completed: false,
      ),
      1,
    );
  });

  test('empty table counts zero rather than failing', () async {
    expect(await db.scheduledWorkoutDao.countCompleted(), 0);
    expect(
      await db.scheduledWorkoutDao.countInRange(
        start: weekStart,
        end: weekEnd,
      ),
      0,
    );
  });
}
