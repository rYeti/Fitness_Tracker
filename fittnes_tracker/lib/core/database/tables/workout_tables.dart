import 'package:drift/drift.dart';

import 'sync_tables.dart';

// Workout planning tables

/// Sync state of a row in any table that syncs with the remote API, stored in
/// its `sync_status` column by [index].
///
/// - [pending]       New record, never pushed to the API. It already has its
///                   `serverId` — the device mints it on insert
///                   (`newSyncId`) — so this status, not a null id, is what
///                   says the server has not got it.
/// - [synced]        The server has exactly this.
/// - [pendingUpdate] Edited locally after a successful sync.
/// - [pendingDelete] Deleted locally; must be removed on the API before the
///                   local row is dropped.
/// - [retired]       Only on [WorkoutExerciseTable]: an exercise the server has
///                   already taken out of the workout, kept so logged sets can
///                   still resolve what was performed. See that table's doc
///                   comment.
///
/// Read a stored value with [fromDb], never `SyncStatus.values[i]`. `retired`
/// used to be a bare `4` outside this enum, and indexing `values` with it threw
/// a `RangeError` that stopped every pull that reached it — see
/// `docs/sync-architecture.md` §1. Being a member means every exhaustive
/// `switch` has to say what it does with one.
enum SyncStatus {
  pending,
  synced,
  pendingUpdate,
  pendingDelete,
  retired;

  /// The status stored as [raw]. A value this build does not know — only a
  /// newer build could have written one — reads as [synced]: neither pushed
  /// again nor deleted, and left for the next pull to reconcile.
  static SyncStatus fromDb(int raw) =>
      raw >= 0 && raw < values.length ? values[raw] : synced;

  /// Whether this row holds a change the server has not seen yet.
  bool get isDirty =>
      this == pending || this == pendingUpdate || this == pendingDelete;

  /// Whether this device knows the server has the row: its create was
  /// answered, or it came from the server.
  ///
  /// Every row has a `server_id` from the moment it is inserted, so the id no
  /// longer says this; the status is the only thing that does. And a row
  /// leaves [pending] the moment its create is answered — before whatever the
  /// push sends after it — so that a row the server holds is never taken for
  /// one it doesn't (`docs/sync-architecture.md`, part two).
  ///
  /// It is not the converse of "the server doesn't have it": a create whose
  /// answer was lost leaves the row [pending] on a server that stored it.
  bool get isOnServer => this != pending;
}

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
  TextColumn get serverId => text().nullable().clientDefault(newSyncId)();
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();

  /// Bumped by the database on every local change — see [SyncStatus] and
  /// `lib/core/sync/sync_triggers.dart`.
  IntColumn get localRev => integer().withDefault(const Constant(0))();
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
  TextColumn get serverId => text().nullable().clientDefault(newSyncId)();
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();

  /// Bumped by the database on every local change — see [SyncStatus] and
  /// `lib/core/sync/sync_triggers.dart`.
  IntColumn get localRev => integer().withDefault(const Constant(0))();
}

/// Table for linking exercises to workouts (workout_exercise)
///
/// The only table that uses [SyncStatus.retired] (`4`): an exercise that has
/// left the workout but that logged sets still point at. The pull stamps it on
/// an exercise the server reports `removedAt`, and the push stamps it on one
/// this device removed once the server has been told, instead of deleting the
/// row. Foreign keys are not enforced on this database (no
/// `PRAGMA foreign_keys`), so deleting it would not cascade into history —
/// it would orphan it, and every query that inner-joins a session's exercises
/// to this table would silently drop them.
///
/// A retired row stays out of every workout-builder and active-workout
/// listing (every such query excludes both `3` and `4`) and is never pushed:
/// the server already has it as removed.
class WorkoutExerciseTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workoutId =>
      integer().references(WorkoutTable, #id, onDelete: KeyAction.cascade)();
  IntColumn get exerciseId =>
      integer().references(ExerciseTable, #id, onDelete: KeyAction.cascade)();
  IntColumn get orderPosition => integer()();
  TextColumn get notes => text().nullable()();
  IntColumn get supersetGroupId => integer().nullable()();
  TextColumn get serverId => text().nullable().clientDefault(newSyncId)();
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();

  /// Bumped by the database on every local change — see [SyncStatus] and
  /// `lib/core/sync/sync_triggers.dart`.
  IntColumn get localRev => integer().withDefault(const Constant(0))();
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

  TextColumn get serverId => text().nullable().clientDefault(newSyncId)();
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();

  /// Bumped by the database on every local change — see [SyncStatus] and
  /// `lib/core/sync/sync_triggers.dart`.
  IntColumn get localRev => integer().withDefault(const Constant(0))();
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
  TextColumn get serverId => text().nullable().clientDefault(newSyncId)();
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
  TextColumn get serverId => text().nullable().clientDefault(newSyncId)();
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();

  /// Bumped by the database on every local change — see [SyncStatus] and
  /// `lib/core/sync/sync_triggers.dart`.
  IntColumn get localRev => integer().withDefault(const Constant(0))();
}

/// Table for linking workouts to plans (many-to-many)
class WorkoutPlanWorkoutTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get planId => integer().references(WorkoutPlanTable, #id)();
  IntColumn get workoutId => integer().references(WorkoutTable, #id)();
  /// Not an id of its own: the server never names a link, which is one plan
  /// and one workout (`PUT api/WorkoutPlan/{id}/workouts` takes the plan's
  /// whole list). Older builds stored the plan's server id here.
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

  TextColumn get serverId => text().nullable().clientDefault(newSyncId)();
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();

  /// Bumped by the database on every local change — see [SyncStatus] and
  /// `lib/core/sync/sync_triggers.dart`.
  IntColumn get localRev => integer().withDefault(const Constant(0))();
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

  TextColumn get serverId => text().nullable().clientDefault(newSyncId)();
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
}
