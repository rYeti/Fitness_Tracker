import 'package:csv/csv.dart';
import 'package:drift/drift.dart';
import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/feature/workout_planning/data/models/exercise.dart';

/// Imports exercises from a structured CSV into the exercise library.
///
/// Only the Exercise column is required. Week, Day, Workout, Sets, Reps, Notes
/// are accepted but ignored for import purposes — they are present so the user
/// can reuse the same CSV they would hand to a trainer. After import the user
/// creates their own workout(s) using the newly available exercises.
class CsvWorkoutImporter {
  final AppDatabase db;

  CsvWorkoutImporter(this.db);

  Future<CsvImportResult> importExercises({
    required String csvContent,
    void Function(int current, int total)? onProgress,
  }) async {
    try {
      final normalized =
          csvContent.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
      final rows =
          const CsvToListConverter().convert(normalized, eol: '\n');

      if (rows.length < 2) {
        return CsvImportResult.error('CSV file is empty or has no data rows');
      }

      final headers =
          rows[0].map((h) => h.toString().trim().toLowerCase()).toList();

      final exerciseColIndex = headers.indexOf('exercise');
      if (exerciseColIndex == -1) {
        return CsvImportResult.error(
          'Missing required column: Exercise',
        );
      }

      // Collect unique exercise names preserving first-seen order
      final seen = <String>{};
      final exerciseNames = <String>[];
      for (final row in rows.skip(1)) {
        if (exerciseColIndex >= row.length) continue;
        final name = row[exerciseColIndex]?.toString().trim() ?? '';
        if (name.isNotEmpty && seen.add(name)) {
          exerciseNames.add(name);
        }
      }

      if (exerciseNames.isEmpty) {
        return CsvImportResult.error('No valid exercises found in CSV');
      }

      int created = 0;
      int skipped = 0;

      for (int i = 0; i < exerciseNames.length; i++) {
        final name = exerciseNames[i];
        final existing = await (db.select(db.exerciseTable)
              ..where((t) => t.name.equals(name)))
            .getSingleOrNull();

        if (existing == null) {
          await db.into(db.exerciseTable).insert(
            ExerciseTableCompanion(
              name: Value(name),
              description: const Value('Imported from CSV'),
              type: Value(ExerciseType.strength.index),
              targetMuscleGroups: const Value(''),
              isCustom: const Value(true),
            ),
          );
          created++;
        } else {
          skipped++;
        }

        onProgress?.call(i + 1, exerciseNames.length);
      }

      return CsvImportResult.success(
        exercisesCreated: created,
        exercisesSkipped: skipped,
      );
    } catch (e) {
      return CsvImportResult.error('Import failed: $e');
    }
  }
}

// ---------------------------------------------------------------------------
// Result
// ---------------------------------------------------------------------------

class CsvImportResult {
  final bool isSuccess;
  final String message;
  final int exercisesCreated;
  final int exercisesSkipped;

  CsvImportResult._({
    required this.isSuccess,
    required this.message,
    this.exercisesCreated = 0,
    this.exercisesSkipped = 0,
  });

  factory CsvImportResult.success({
    required int exercisesCreated,
    required int exercisesSkipped,
  }) =>
      CsvImportResult._(
        isSuccess: true,
        message: 'Import complete',
        exercisesCreated: exercisesCreated,
        exercisesSkipped: exercisesSkipped,
      );

  factory CsvImportResult.error(String message) =>
      CsvImportResult._(isSuccess: false, message: message);
}
