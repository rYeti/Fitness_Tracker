import 'dart:async';

import 'package:drift/drift.dart';
import '../../app_database.dart';

part 'scheduled_workout_dao.g.dart';

class ScheduledWorkoutWithDetails {
  final ScheduledWorkoutTableData scheduled;
  final WorkoutTableData? workout;

  ScheduledWorkoutWithDetails({required this.scheduled, this.workout});
}

@DriftAccessor(tables: [ScheduledWorkoutTable])
class ScheduledWorkoutDao extends DatabaseAccessor<AppDatabase>
    with _$ScheduledWorkoutDaoMixin {
  ScheduledWorkoutDao(super.db);

  Future<List<ScheduledWorkoutTableData>> getForDate(DateTime date) {
    return (select(scheduledWorkoutTable)
      ..where((t) => t.scheduledDate.equals(date))).get();
  }

  Stream<List<ScheduledWorkoutTableData>> watchForDate(DateTime date) {
    return (select(scheduledWorkoutTable)
      ..where((t) => t.scheduledDate.equals(date))).watch();
  }

  Future<int> scheduleWorkout(Insertable<ScheduledWorkoutTableData> item) {
    return into(scheduledWorkoutTable).insert(item);
  }

  Future<int> removeScheduled(int id) {
    return (delete(scheduledWorkoutTable)..where((t) => t.id.equals(id))).go();
  }

  Future<void> skipWorkout(int id) {
    return (update(scheduledWorkoutTable)..where((t) => t.id.equals(id))).write(
      const ScheduledWorkoutTableCompanion(
        isSkipped: Value(true),
        syncStatus: Value(2),
      ),
    );
  }

  Future<void> unskipWorkout(int id) {
    return (update(scheduledWorkoutTable)..where((t) => t.id.equals(id))).write(
      const ScheduledWorkoutTableCompanion(
        isSkipped: Value(false),
        syncStatus: Value(2),
      ),
    );
  }

  Future<void> postponeWorkout(int id, DateTime newDate) {
    return (update(scheduledWorkoutTable)..where((t) => t.id.equals(id))).write(
      ScheduledWorkoutTableCompanion(
        scheduledDate: Value(newDate),
        syncStatus: const Value(2),
      ),
    );
  }

  /// Returns a map of date → (color, isCompleted, isSkipped) for all scheduled
  /// workouts in the given month. Used to render the calendar color dots.
  Future<Map<DateTime, ({int? color, bool isCompleted, bool isSkipped})>>
  getWorkoutColorSummariesForMonth(DateTime month) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);

    final results =
        await customSelect(
          '''
      SELECT
        sw.scheduled_date,
        sw.is_completed,
        sw.is_skipped,
        sw.workout_plan_id,
        COALESCE(w.color, tw.color) as color
      FROM scheduled_workout_table sw
      LEFT JOIN workout_table w ON w.id = sw.workout_id
      LEFT JOIN workout_table tw ON tw.id = sw.template_workout_id
      WHERE sw.scheduled_date >= ? AND sw.scheduled_date < ?
      ''',
          variables: [Variable.withDateTime(start), Variable.withDateTime(end)],
        ).get();

    // Fetch active plan to filter
    final db2 = attachedDatabase;
    final activePlans = await db2.workoutPlanDao.getActivePlans();
    final activePlanId = activePlans.isNotEmpty ? activePlans.first.id : null;

    final map = <DateTime, ({int? color, bool isCompleted, bool isSkipped})>{};
    for (final row in results) {
      final planId = row.readNullable<int>('workout_plan_id');
      if (activePlanId != null && planId != activePlanId) continue;
      final rawDate = row.read<DateTime>('scheduled_date');
      final date = DateTime(rawDate.year, rawDate.month, rawDate.day);
      final color = row.readNullable<int>('color');
      final isCompleted = row.read<bool>('is_completed');
      final isSkipped = row.read<bool>('is_skipped');
      // Prefer completed entry if multiple exist for a day
      if (!map.containsKey(date) || isCompleted) {
        map[date] = (
          color: color,
          isCompleted: isCompleted,
          isSkipped: isSkipped,
        );
      }
    }
    return map;
  }

  Future<List<ScheduledWorkoutTableData>> getAll() =>
      select(scheduledWorkoutTable).get();

  /// Counts scheduled workouts in the half-open range [start, end).
  ///
  /// Pass [completed] to restrict to completed (or not-completed) entries.
  /// The dashboard used to fetch every row ever scheduled and count in Dart.
  Future<int> countInRange({
    required DateTime start,
    required DateTime end,
    bool? completed,
  }) {
    final count = scheduledWorkoutTable.id.count();
    final query = selectOnly(scheduledWorkoutTable)..addColumns([count]);
    query.where(
      scheduledWorkoutTable.scheduledDate.isBiggerOrEqualValue(start) &
          scheduledWorkoutTable.scheduledDate.isSmallerThanValue(end),
    );
    if (completed != null) {
      query.where(scheduledWorkoutTable.isCompleted.equals(completed));
    }
    return query.map((row) => row.read(count) ?? 0).getSingle();
  }

  /// Total completed workouts, all time.
  Future<int> countCompleted() {
    final count = scheduledWorkoutTable.id.count();
    final query = selectOnly(scheduledWorkoutTable)
      ..addColumns([count])
      ..where(scheduledWorkoutTable.isCompleted.equals(true));
    return query.map((row) => row.read(count) ?? 0).getSingle();
  }

  Future<ScheduledWorkoutTableData?> getByServerId(String serverId) =>
      (select(scheduledWorkoutTable)
            ..where((t) => t.serverId.equals(serverId))
            ..limit(1))
          .getSingleOrNull();

  Future<List<ScheduledWorkoutWithDetails>> getScheduledWithDetailsForDate(
    DateTime date,
  ) async {
    // Use a half-open date range (start <= scheduled_date < end) so entries
    // are matched regardless of their time-of-day component.
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));

    final query =
        select(scheduledWorkoutTable).join([
            leftOuterJoin(
              workoutTable,
              workoutTable.id.equalsExp(scheduledWorkoutTable.workoutId),
            ),
            leftOuterJoin(
              workoutPlanTable,
              workoutPlanTable.id.equalsExp(
                scheduledWorkoutTable.workoutPlanId,
              ),
            ),
          ])
          ..where(
            scheduledWorkoutTable.scheduledDate.isBiggerOrEqualValue(start) &
                scheduledWorkoutTable.scheduledDate.isSmallerThanValue(end),
          )
          // Active plan's workouts come first so firstOrNull picks the right one.
          ..orderBy([
            OrderingTerm(
              expression: workoutPlanTable.isActive,
              mode: OrderingMode.desc,
            ),
          ]);

    final results = await query.get();

    return results.map((row) {
      return ScheduledWorkoutWithDetails(
        scheduled: row.readTable(scheduledWorkoutTable),
        workout: row.readTableOrNull(workoutTable),
      );
    }).toList();
  }

  Stream<List<ScheduledWorkoutWithDetails>> watchScheduledWithDetailsForDate(
    DateTime date,
  ) {
    // Create a function to fetch the current data
    Future<List<ScheduledWorkoutWithDetails>> fetchData() async {
      // Use a half-open date range (start <= scheduled_date < end) so
      // scheduled entries are matched regardless of their time-of-day.
      final start = DateTime(date.year, date.month, date.day);
      final end = start.add(const Duration(days: 1));

      final results =
          await customSelect(
            '''
        SELECT
          sw.id as sw_id,
          sw.workout_id,
          sw.scheduled_date,
          sw.is_completed,
          sw.is_skipped,
          sw.workout_plan_id,
          sw.created_at,
          sw.template_workout_id,

          -- primary workout (may be NULL if deleted)
          w.id as w_id,
          w.name as w_name,
          w.description as w_description,
          w.difficulty as w_difficulty,
          w.estimated_duration_minutes as w_estimated_duration_minutes,
          w.is_template as w_is_template,
          w.color as w_color,

          -- fallback template workout (use when primary is NULL)
          tw.id as tw_id,
          tw.name as tw_name,
          tw.description as tw_description,
          tw.difficulty as tw_difficulty,
          tw.estimated_duration_minutes as tw_estimated_duration_minutes,
          tw.is_template as tw_is_template,
          tw.color as tw_color,

          wp.is_active
        FROM scheduled_workout_table sw
        LEFT JOIN workout_table w ON w.id = sw.workout_id
        LEFT JOIN workout_table tw ON tw.id = sw.template_workout_id
        LEFT JOIN workout_plan_table wp ON wp.id = sw.workout_plan_id
        WHERE sw.scheduled_date >= ? AND sw.scheduled_date < ?
        ORDER BY sw.created_at DESC
        ''',
            variables: [
              Variable.withDateTime(start),
              Variable.withDateTime(end),
            ],
          ).get();

      return results.map((row) {
        final scheduled = ScheduledWorkoutTableData(
          id: row.read<int>('sw_id'),
          workoutId: row.read<int>('workout_id'),
          scheduledDate: row.read<DateTime>('scheduled_date'),
          isCompleted: row.read<bool>('is_completed'),
          isSkipped: row.read<bool>('is_skipped'),
          workoutPlanId: row.readNullable<int>('workout_plan_id'),
          createdAt: row.read<DateTime>('created_at'),
          templateWorkoutId: row.readNullable<int>('template_workout_id'),
          syncStatus: 0,
        );

        // Prefer the actual workout row (w_*). If missing, fall back to the
        // template workout (tw_*). This prevents the UI showing "Unknown Workout"
        // when a scheduled entry references a (deleted) workout but still has a
        // template available.
        WorkoutTableData? workout;
        if (row.readNullable<int>('w_id') != null) {
          workout = WorkoutTableData(
            id: row.read<int>('w_id'),
            name: row.read<String>('w_name'),
            description: row.readNullable<String>('w_description'),
            isTemplate: row.read<bool>('w_is_template'),
            difficulty: row.read<int>('w_difficulty'),
            estimatedDurationMinutes: row.read<int>(
              'w_estimated_duration_minutes',
            ),
            scheduledDate: null,
            completedDate: null,
            color: row.readNullable<int>('w_color'),
            syncStatus: 0,
          );
        } else if (row.readNullable<int>('tw_id') != null) {
          workout = WorkoutTableData(
            id: row.read<int>('tw_id'),
            name: row.read<String>('tw_name'),
            description: row.readNullable<String>('tw_description'),
            isTemplate: row.read<bool>('tw_is_template'),
            difficulty: row.read<int>('tw_difficulty'),
            estimatedDurationMinutes: row.read<int>(
              'tw_estimated_duration_minutes',
            ),
            scheduledDate: null,
            completedDate: null,
            color: row.readNullable<int>('tw_color'),
            syncStatus: 0,
          );
        } else {
          workout = null;
        }

        return ScheduledWorkoutWithDetails(
          scheduled: scheduled,
          workout: workout,
        );
      }).toList();
    }

    // Watch both tables and merge their streams
    final scheduledStream = select(scheduledWorkoutTable).watch();
    final planStream = select(workoutPlanTable).watch();
    // Also watch the workout table so edits to workouts trigger a refresh
    final workoutStream = select(workoutTable).watch();

    // Use async* generator to create a stream that responds to either table
    return Stream.multi((controller) {
      StreamSubscription? scheduledSub;
      StreamSubscription? planSub;
      StreamSubscription? workoutSub;
      Timer? debounceTimer;

      void emitData() async {
        // Cancel any pending emission
        debounceTimer?.cancel();

        // Debounce to avoid rapid multiple emissions
        debounceTimer = Timer(Duration(milliseconds: 100), () async {
          try {
            final data = await fetchData();
            controller.add(data);
          } catch (e) {
            controller.addError(e);
          }
        });
      }

      scheduledSub = scheduledStream.listen((_) {
        emitData();
      });
      planSub = planStream.listen((_) {
        emitData();
      });
      workoutSub = workoutStream.listen((_) {
        emitData();
      });

      controller.onCancel = () {
        debounceTimer?.cancel();
        scheduledSub?.cancel();
        planSub?.cancel();
        workoutSub?.cancel();
      };

      // Emit initial data
      emitData();
    });
  }
}
