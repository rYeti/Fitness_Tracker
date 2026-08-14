import 'package:drift/drift.dart';
import '../../../feature/workout_planning/data/models/exercise.dart';
import '../../app_database.dart';

part 'exercise_dao.g.dart';

// Workout planning DAOs

@DriftAccessor(tables: [ExerciseTable])
class ExerciseDao extends DatabaseAccessor<AppDatabase>
    with _$ExerciseDaoMixin {
  ExerciseDao(super.db);

  // Get all exercises
  Future<List<ExerciseTableData>> getAllExercises() =>
      select(exerciseTable).get();

  // Get a specific exercise by ID
  Future<ExerciseTableData?> getExerciseById(int id) =>
      (select(exerciseTable)..where((e) => e.id.equals(id))).getSingleOrNull();

  // Get exercises by type
  Future<List<ExerciseTableData>> getExercisesByType(ExerciseType type) =>
      (select(exerciseTable)..where((e) => e.type.equals(type.index))).get();

  // Get exercises by muscle group
  Future<List<ExerciseTableData>> getExercisesByMuscleGroup(
    MuscleGroup muscleGroup,
  ) async {
    final allExercises = await getAllExercises();
    return allExercises.where((exercise) {
      final muscleGroups =
          exercise.targetMuscleGroups
              .split(',')
              .map((e) => int.tryParse(e.trim()))
              .where((e) => e != null)
              .cast<int>()
              .toList();
      return muscleGroups.contains(muscleGroup.index);
    }).toList();
  }

  // Search exercises by name (matches English and German)
  Future<List<ExerciseTableData>> searchExercises(String query) async {
    final lowerQuery = query.toLowerCase();
    final allExercises = await getAllExercises();
    return allExercises
        .where(
          (e) =>
              e.name.toLowerCase().contains(lowerQuery) ||
              (e.nameDe?.toLowerCase().contains(lowerQuery) ?? false),
        )
        .toList();
  }

  // Get exercises by muscle group with search (matches English and German)
  Future<List<ExerciseTableData>> searchExercisesByMuscleGroup(
    MuscleGroup muscleGroup,
    String query,
  ) async {
    final exercises = await getExercisesByMuscleGroup(muscleGroup);
    if (query.isEmpty) return exercises;

    final lowerQuery = query.toLowerCase();
    return exercises
        .where(
          (e) =>
              e.name.toLowerCase().contains(lowerQuery) ||
              (e.nameDe?.toLowerCase().contains(lowerQuery) ?? false),
        )
        .toList();
  }

  // Insert or update an exercise
  Future<int> saveExercise(ExerciseTableCompanion exercise) =>
      into(exerciseTable).insert(exercise, mode: InsertMode.insertOrReplace);

  // Delete an exercise
  Future<int> deleteExercise(int id) =>
      (delete(exerciseTable)..where((e) => e.id.equals(id))).go();

  // Convert database entity to model
  Exercise entityToModel(ExerciseTableData data) {
    List<MuscleGroup> muscleGroups =
        data.targetMuscleGroups
            .split(',')
            .map((e) => int.parse(e.trim()))
            .map((index) => MuscleGroup.values[index])
            .toList();

    return Exercise(
      id: data.id,
      name: data.name,
      description: data.description,
      nameDe: data.nameDe,
      descriptionDe: data.descriptionDe,
      type: ExerciseType.values[data.type],
      targetMuscleGroups: muscleGroups,
      imageUrl: data.imageUrl,
      isCustom: data.isCustom,
    );
  }

  // Convert model to database entity companion
  ExerciseTableCompanion modelToEntity(Exercise model) {
    String muscleGroupString = model.targetMuscleGroups
        .map((mg) => mg.index.toString())
        .join(',');

    return ExerciseTableCompanion(
      id: model.id == null ? const Value.absent() : Value(model.id!),
      name: Value(model.name),
      description: Value(model.description),
      nameDe: Value(model.nameDe),
      descriptionDe: Value(model.descriptionDe),
      type: Value(model.type.index),
      targetMuscleGroups: Value(muscleGroupString),
      imageUrl: Value(model.imageUrl),
      isCustom: Value(model.isCustom),
    );
  }

  // ── Sync helpers (custom exercises only) ────────────────────────────────────

  Future<List<ExerciseTableData>> getUnsyncedCustomExercises() =>
      (select(exerciseTable)..where(
        (e) => e.isCustom.equals(true) & e.syncStatus.isNotValue(1),
      )).get();

  Future<void> markExerciseSynced(int localId, String serverId) =>
      (update(exerciseTable)..where((e) => e.id.equals(localId))).write(
        ExerciseTableCompanion(
          syncStatus: const Value(1),
          serverId: Value(serverId),
        ),
      );

  Future<void> markExercisePendingUpdate(int id) => (update(exerciseTable)
    ..where(
      (e) => e.id.equals(id),
    )).write(const ExerciseTableCompanion(syncStatus: Value(2)));

  Future<void> markExercisePendingDelete(int id) => (update(exerciseTable)
    ..where(
      (e) => e.id.equals(id),
    )).write(const ExerciseTableCompanion(syncStatus: Value(3)));

  Future<ExerciseTableData?> getExerciseByServerId(String serverId) =>
      (select(exerciseTable)
            ..where((e) => e.serverId.equals(serverId))
            ..limit(1))
          .getSingleOrNull();
}

/// Returns the exercise name/description in the given locale language,
/// falling back to English when no translation is available.
extension ExerciseTableDataLocalization on ExerciseTableData {
  String localizedName(String languageCode) =>
      languageCode == 'de' && nameDe != null ? nameDe! : name;

  String? localizedDescription(String languageCode) =>
      languageCode == 'de' && descriptionDe != null
          ? descriptionDe
          : description;
}
