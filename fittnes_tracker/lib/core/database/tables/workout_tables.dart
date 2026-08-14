import 'package:drift/drift.dart';

// Workout planning tables

/// Sync state used across all tables that sync with the remote API.
///
/// - [pending]       New record, never pushed to the API.
/// - [synced]        Successfully pushed; [serverId] is set.
/// - [pendingUpdate] Edited locally after a successful sync.
/// - [pendingDelete] Deleted locally; must be removed on the API before the
///                   local row is dropped.
enum SyncStatus { pending, synced, pendingUpdate, pendingDelete }

/// Table for storing exercise definitions
class ExerciseTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get nameDe => text().nullable()();
  TextColumn get descriptionDe => text().nullable()();
  IntColumn get type => integer()(); // Maps to ExerciseType enum index
  TextColumn get targetMuscleGroups => text()();
  TextColumn get imageUrl => text().nullable()();
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();
  TextColumn get serverId => text().nullable()();
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
}

/// Table for storing complete workouts
class WorkoutTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  IntColumn get difficulty =>
      integer()(); // Maps to WorkoutDifficulty enum index
  IntColumn get estimatedDurationMinutes =>
      integer().withDefault(const Constant(30))();
  BoolColumn get isTemplate => boolean().withDefault(const Constant(true))();
  DateTimeColumn get scheduledDate => dateTime().nullable()();
  DateTimeColumn get completedDate => dateTime().nullable()();
  IntColumn get color => integer().nullable()();
  TextColumn get serverId => text().nullable()();
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
}

/// Table for linking exercises to workouts (workout_exercise)
class WorkoutExerciseTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workoutId =>
      integer().references(WorkoutTable, #id, onDelete: KeyAction.cascade)();
  IntColumn get exerciseId =>
      integer().references(ExerciseTable, #id, onDelete: KeyAction.cascade)();
  IntColumn get orderPosition => integer()();
  TextColumn get notes => text().nullable()();
  IntColumn get supersetGroupId => integer().nullable()();
  TextColumn get serverId => text().nullable()();
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
}

class ScheduledWorkoutExerciseTable extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// The scheduled workout (this is the date!)
  IntColumn get scheduledWorkoutId =>
      integer().references(
        ScheduledWorkoutTable,
        #id,
        onDelete: KeyAction.cascade,
      )();
  IntColumn get workoutExerciseId =>
      integer().references(
        WorkoutExerciseTable,
        #id,
        onDelete: KeyAction.cascade,
      )();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();

  TextColumn get notes => text().nullable()();

  /// Exercise override for this specific day only. Null = use the template exercise.
  IntColumn get overrideExerciseId => integer().nullable()();

  TextColumn get serverId => text().nullable()();
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
}

/// Table for storing individual sets within a workout exercise
class WorkoutSetTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get scheduledWorkoutExerciseId =>
      integer().references(
        ScheduledWorkoutExerciseTable,
        #id,
        onDelete: KeyAction.cascade,
      )();
  IntColumn get setNumber => integer()();
  IntColumn get reps => integer().nullable()();
  RealColumn get weight => real().nullable()();
  TextColumn get weightUnit => text().nullable()();
  IntColumn get durationSeconds => integer().nullable()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().nullable()();
  TextColumn get serverId => text().nullable()();
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();

  /// Rate of Perceived Exertion (6-10). Null when the user didn't log one.
  IntColumn get rpe => integer().nullable()();

  /// Maps to [SetType] by index. Warmups are excluded from volume/PR stats.
  IntColumn get setType => integer().withDefault(const Constant(0))();

  /// Maps to [SetSide] by index. Left/right for unilateral tracking.
  IntColumn get side => integer().withDefault(const Constant(0))();
}

/// Table for workout plans/schedules
class WorkoutPlanTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();
  BoolColumn get isActive => boolean().withDefault(const Constant(false))();
  TextColumn get cyclePatternJson => text()();
  BoolColumn get isFreeChoice => boolean().withDefault(const Constant(false))();
  IntColumn get durationDays => integer().nullable()();
  TextColumn get serverId => text().nullable()();
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
}

/// Table for linking workouts to plans (many-to-many)
class WorkoutPlanWorkoutTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get planId => integer().references(WorkoutPlanTable, #id)();
  IntColumn get workoutId => integer().references(WorkoutTable, #id)();
  TextColumn get serverId => text().nullable()();
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
}

/// Table for storing scheduled workouts (instances of a workout scheduled on a date)
class ScheduledWorkoutTable extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Links to the workout template or workout entry
  IntColumn get workoutId => integer().references(WorkoutTable, #id)();
  IntColumn get workoutPlanId =>
      integer().nullable().references(WorkoutPlanTable, #id)();
  @ReferenceName('scheduledWorkoutTemplateRefs')
  IntColumn get templateWorkoutId =>
      integer().nullable().references(
        WorkoutTable,
        #id,
        onDelete: KeyAction.cascade,
      )();

  /// The date/time this workout is scheduled for
  DateTimeColumn get scheduledDate => dateTime()();

  /// When the scheduled entry was created. Use a clientDefault so
  /// sqlite3 native doesn't receive a non-constant SQL default.
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();

  TextColumn get notes => text().nullable()();

  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  BoolColumn get isSkipped => boolean().withDefault(const Constant(false))();

  TextColumn get serverId => text().nullable()();
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
}

@DataClassName('WorkoutSetTemplateData')
class WorkoutSetTemplateTable extends Table {
  IntColumn get id => integer().autoIncrement()();

  // Links to the workout-exercise relationship
  IntColumn get workoutExerciseId =>
      integer().references(
        WorkoutExerciseTable,
        #id,
        onDelete: KeyAction.cascade,
      )();

  // Which set number (1, 2, 3, etc.)
  IntColumn get setNumber => integer()();

  // Target reps as string (e.g., "8-12", "10", "15-20")
  TextColumn get targetReps => text()();

  // Order position for sorting
  IntColumn get orderPosition => integer()();

  TextColumn get serverId => text().nullable()();
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
}
