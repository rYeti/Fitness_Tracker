import 'package:drift/drift.dart';
import '../../app_database.dart';

part 'workout_set_template_dao.g.dart';

@DriftAccessor(tables: [WorkoutSetTemplateTable])
class WorkoutSetTemplateTableDao extends DatabaseAccessor<AppDatabase>
    with _$WorkoutSetTemplateTableDaoMixin {
  WorkoutSetTemplateTableDao(super.db);

  Future<List<WorkoutSetTemplateData>> getForWorkoutExercise(
    int workoutExerciseId,
  ) {
    return (select(workoutSetTemplateTable)
      ..where((t) => t.workoutExerciseId.equals(workoutExerciseId))).get();
  }
}
