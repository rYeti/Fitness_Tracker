import 'dart:convert';

import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/feature/workout_planning/data/models/workout_set.dart';
import 'package:csv/csv.dart';
import 'package:drift/drift.dart';

/// Builds user-data exports. Free for every user — data ownership is never
/// paywalled (GDPR Art. 20; see the paywall policy in the project docs).
///
/// CSV column order for workouts mirrors the FitNotes import shape
/// (Date, Exercise, Category, Weight, Weight Unit, Reps, ...) so an export
/// from ForgeForm can be re-imported without remapping. Extra columns are
/// appended at the end, where importers ignore them.
class DataExporter {
  final AppDatabase db;

  DataExporter(this.db);

  static String _date(DateTime d) => d.toIso8601String().substring(0, 10);

  String _toCsv(List<List<dynamic>> rows) =>
      const ListToCsvConverter().convert(rows);

  /// Every logged (completed) set, one row per set, newest session first.
  Future<String> exportWorkoutsCsv() async {
    final query = db.select(db.workoutSetTable).join([
      innerJoin(
        db.scheduledWorkoutExerciseTable,
        db.scheduledWorkoutExerciseTable.id
            .equalsExp(db.workoutSetTable.scheduledWorkoutExerciseId),
      ),
      innerJoin(
        db.scheduledWorkoutTable,
        db.scheduledWorkoutTable.id
            .equalsExp(db.scheduledWorkoutExerciseTable.scheduledWorkoutId),
      ),
      innerJoin(
        db.workoutExerciseTable,
        db.workoutExerciseTable.id
            .equalsExp(db.scheduledWorkoutExerciseTable.workoutExerciseId),
      ),
      innerJoin(
        db.exerciseTable,
        db.exerciseTable.id.equalsExp(db.workoutExerciseTable.exerciseId),
      ),
    ])
      ..where(db.workoutSetTable.isCompleted.equals(true))
      ..orderBy([
        OrderingTerm.desc(db.scheduledWorkoutTable.scheduledDate),
        OrderingTerm.asc(db.workoutSetTable.setNumber),
      ]);

    final rows = <List<dynamic>>[
      [
        'Date',
        'Exercise',
        'Category',
        'Weight',
        'Weight Unit',
        'Reps',
        'RPE',
        'Set Type',
        'Side',
        'Notes',
      ],
    ];

    for (final row in await query.get()) {
      final set = row.readTable(db.workoutSetTable);
      final scheduled = row.readTable(db.scheduledWorkoutTable);
      final exercise = row.readTable(db.exerciseTable);
      rows.add([
        _date(scheduled.scheduledDate),
        exercise.name,
        exercise.targetMuscleGroups,
        set.weight ?? '',
        set.weightUnit ?? '',
        set.reps ?? '',
        set.rpe ?? '',
        SetType.values[set.setType].name,
        SetSide.values[set.side].name,
        set.notes ?? '',
      ]);
    }
    return _toCsv(rows);
  }

  /// Weight history, newest first.
  Future<String> exportWeightCsv() async {
    final records = await db.weightRecordDao.getAllWeightRecords();
    final rows = <List<dynamic>>[
      ['Date', 'Weight', 'Note'],
      for (final r in records) [_date(r.date), r.weight, r.note ?? ''],
    ];
    return _toCsv(rows);
  }

  /// Every meal entry with its food and macros, newest first.
  Future<String> exportNutritionCsv() async {
    final query = db.select(db.mealTable).join([
      innerJoin(
        db.foodItem,
        db.foodItem.id.equalsExp(db.mealTable.foodItemId),
      ),
    ])..orderBy([OrderingTerm.desc(db.mealTable.date)]);

    final rows = <List<dynamic>>[
      [
        'Date',
        'Meal',
        'Food',
        'Amount (g)',
        'Calories',
        'Protein',
        'Carbs',
        'Fat',
      ],
    ];

    for (final row in await query.get()) {
      final meal = row.readTable(db.mealTable);
      final food = row.readTable(db.foodItem);
      rows.add([
        _date(meal.date),
        meal.category,
        food.name,
        food.gramm,
        food.calories,
        food.protein,
        food.carbs,
        food.fat,
      ]);
    }
    return _toCsv(rows);
  }

  /// Complete dump of every local table as JSON — the "take all my data"
  /// export. Row shape follows the Drift data classes.
  Future<String> exportFullJson() async {
    final dump = <String, List<Map<String, dynamic>>>{};
    for (final table in db.allTables) {
      final rows = await db.select(table).get();
      dump[table.actualTableName] = [
        for (final row in rows) (row as DataClass).toJson(),
      ];
    }
    return const JsonEncoder.withIndent('  ').convert({
      'app': 'ForgeForm',
      'exportedAt': DateTime.now().toIso8601String(),
      'tables': dump,
    });
  }
}
