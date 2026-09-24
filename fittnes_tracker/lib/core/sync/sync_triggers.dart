import 'package:drift/drift.dart';

/// The database's own record of every local change the sync engine has to send.
///
/// Before these triggers, "this row needs pushing" was a flag each writer had
/// to remember to set, and "the server has this" was stamped by the push without
/// checking whether the row had changed while the request was in flight. Both
/// failed repeatedly — six screens wrote a pushed column without marking the row
/// dirty, two added children to an already-synced parent that was never pushed
/// again, seven hard-deleted rows the server still had, and every one of those
/// is a change that either never reached the server or was reverted by the next
/// pull. `docs/sync-architecture.md` §3 walks through them.
///
/// Every table the push sends is listed here once, with the columns it sends.
/// From that list the database gets three kinds of trigger:
///
/// | Trigger                  | Fires on                             | Effect                                  |
/// |--------------------------|--------------------------------------|-----------------------------------------|
/// | `sync_<t>_update`        | a pushed column of an entity changes | `local_rev + 1`, `synced → pendingUpdate` |
/// | `sync_<t>_owner_*`       | a row of an owned list changes       | the same, applied to its owner          |
/// | `sync_<t>_delete`        | a row with a server id is deleted    | an entry in `sync_deletion_table`       |
///
/// None of them fires inside `AppDatabase.untracked`, which is how the sync
/// engine writes what the server sent without it looking like a local edit.
///
/// **Adding a column the push sends means adding it here.** That is the whole
/// change on this side: the triggers are reinstalled from this list every time
/// the database opens ([installSyncTriggers]), so there is no migration to
/// write and no flag to remember at any call site.

/// Rows whose own fields the push sends individually.
class _Entity {
  const _Entity(this.table, this.pushed, {this.onlyWhen, this.deletion});

  final String table;

  /// The columns the push sends. A change to any other column (a local-only
  /// flag such as `is_active`) is not a change the server needs to hear about.
  final List<String> pushed;

  /// An extra condition on the row, for tables that only partly sync (only
  /// custom exercises are the user's; the built-in ones are the server's).
  final String? onlyWhen;

  final _Deletion? deletion;
}

/// Rows the push sends as part of their owner — a workout exercise's set
/// templates, a session exercise's logged sets. The server replaces the whole
/// list, so any change to one of them is a change to the owner.
class _OwnedList {
  const _OwnedList(
    this.table, {
    required this.owner,
    required this.foreignKey,
    required this.pushed,
    this.deletion,
  });

  final String table;
  final String owner;
  final String foreignKey;
  final List<String> pushed;

  /// For a list the server can only append to, removing a row needs its own
  /// DELETE rather than a dirty owner.
  final _Deletion? deletion;
}

class _Deletion {
  const _Deletion(
    this.kind, {
    this.serverId = 'OLD.server_id',
    this.parent,
    this.extra,
    this.onlyWhen,
  });

  /// A [SyncDeletionKind] name.
  final String kind;

  /// SQL over `OLD` for each id the DELETE route needs.
  final String serverId;
  final String? parent;
  final String? extra;

  /// Replaces the default "has a server id" condition.
  final String? onlyWhen;
}

/// Where a `sync_deletion_table` entry's DELETE goes.
enum SyncDeletionKind {
  exercise,
  workout,
  workoutExercise,
  scheduledWorkout,
  workoutPlan,
  planWorkout,
  foodItem,
  meal,
  mealFood,
  weight,
}

const _entities = [
  _Entity(
    'exercise_table',
    [
      'name',
      'description',
      'type',
      'target_muscle_groups',
      'image_url',
      'name_de',
      'description_de',
    ],
    onlyWhen: 'is_custom = 1',
    deletion: _Deletion('exercise', onlyWhen: 'OLD.is_custom = 1'),
  ),
  _Entity('workout_table', [
    'name',
    'description',
    'difficulty',
    'estimated_duration_minutes',
    'is_template',
    'scheduled_date',
    'color',
  ], deletion: _Deletion('workout')),
  _Entity('workout_exercise_table', [
    'exercise_id',
    'order_position',
    'notes',
    'superset_group_id',
  ], deletion: _Deletion('workoutExercise')),
  _Entity('scheduled_workout_table', [
    'workout_id',
    'workout_plan_id',
    'scheduled_date',
    'notes',
    'is_completed',
    'is_skipped',
  ], deletion: _Deletion('scheduledWorkout')),
  // A session exercise sends only its note on its own; its logged sets are an
  // owned list below.
  _Entity('scheduled_workout_exercise_table', ['notes']),
  _Entity('workout_plan_table', [
    'name',
    'description',
    'start_date',
    'cycle_pattern_json',
    'is_free_choice',
    'duration_days',
  ], deletion: _Deletion('workoutPlan')),
  _Entity('food_item', [
    'name',
    'calories',
    'protein',
    'carbs',
    'fat',
    'gramm',
    'hidden_from_recent',
    'extended_nutrients_json',
  ], deletion: _Deletion('foodItem')),
  _Entity('meal_table', [
    'date',
    'category',
    'food_item_id',
  ], deletion: _Deletion('meal')),
  _Entity('weight_record', [
    'date',
    'weight',
    'note',
  ], deletion: _Deletion('weight')),
];

const _ownedLists = [
  _OwnedList(
    'workout_set_template_table',
    owner: 'workout_exercise_table',
    foreignKey: 'workout_exercise_id',
    pushed: ['set_number', 'target_reps', 'order_position'],
  ),
  _OwnedList(
    'workout_set_table',
    owner: 'scheduled_workout_exercise_table',
    foreignKey: 'scheduled_workout_exercise_id',
    pushed: [
      'set_number',
      'reps',
      'weight',
      'weight_unit',
      'duration_seconds',
      'is_completed',
      'notes',
      'rpe',
      'set_type',
      'side',
    ],
  ),
  // The server can add a food to a meal but not replace the list, so taking
  // one out is its own DELETE — addressed by meal and food item, which is what
  // `DELETE api/Meal/{mealId}/foods/{foodItemId}` takes.
  _OwnedList(
    'meal_food_table',
    owner: 'meal_table',
    foreignKey: 'meal_id',
    pushed: ['food_entry_id'],
    deletion: _Deletion(
      'mealFood',
      parent: '(SELECT server_id FROM meal_table WHERE id = OLD.meal_id)',
      extra: '(SELECT server_id FROM food_item WHERE id = OLD.food_entry_id)',
    ),
  ),
  // A plan link's `server_id` holds the *plan's* server id (the server has no
  // id of its own for a link), so "known to the server" is its status, and the
  // DELETE is addressed by plan and workout.
  _OwnedList(
    'workout_plan_workout_table',
    owner: 'workout_plan_table',
    foreignKey: 'plan_id',
    pushed: ['workout_id'],
    deletion: _Deletion(
      'planWorkout',
      serverId:
          '(SELECT server_id FROM workout_table WHERE id = OLD.workout_id)',
      parent:
          '(SELECT server_id FROM workout_plan_table WHERE id = OLD.plan_id)',
      onlyWhen: 'OLD.sync_status = 1',
    ),
  ),
];

const _notInsideSync =
    '(SELECT active FROM sync_apply_guard_table WHERE id = 1) IS NOT 1';

/// `synced → pendingUpdate`; `pending`, `pendingDelete` and `retired` are each
/// already a stronger statement than "edited" and are left alone.
String _dirty(String table, String where) =>
    'UPDATE $table SET local_rev = local_rev + 1, '
    'sync_status = CASE sync_status WHEN 1 THEN 2 ELSE sync_status END '
    'WHERE $where;';

String _changed(List<String> columns) =>
    '(${columns.map((c) => 'NEW.$c IS NOT OLD.$c').join(' OR ')})';

String _recordDeletion(_Deletion d) {
  final values = [
    "'${d.kind}'",
    d.serverId,
    d.parent ?? 'NULL',
    d.extra ?? 'NULL',
  ];
  return 'INSERT INTO sync_deletion_table '
      '(kind, server_id, parent_server_id, extra_server_id) '
      'VALUES (${values.join(', ')});';
}

String _deletionCondition(_Deletion d) {
  final parts = [
    d.onlyWhen ?? 'OLD.server_id IS NOT NULL',
    if (d.serverId != 'OLD.server_id') '${d.serverId} IS NOT NULL',
    if (d.parent != null) '${d.parent} IS NOT NULL',
    if (d.extra != null) '${d.extra} IS NOT NULL',
  ];
  return parts.join(' AND ');
}

/// Every sync trigger, by name. Exposed for the tests that pin them.
Map<String, String> syncTriggerDdl() {
  final ddl = <String, String>{};

  for (final e in _entities) {
    final t = e.table;
    ddl['sync_${t}_update'] =
        'CREATE TRIGGER sync_${t}_update '
        'AFTER UPDATE OF ${e.pushed.join(', ')} ON $t '
        'WHEN $_notInsideSync AND ${_changed(e.pushed)}'
        '${e.onlyWhen == null ? '' : ' AND NEW.${e.onlyWhen}'} '
        'BEGIN ${_dirty(t, 'id = NEW.id')} END';

    final d = e.deletion;
    if (d != null) {
      ddl['sync_${t}_delete'] =
          'CREATE TRIGGER sync_${t}_delete '
          'AFTER DELETE ON $t '
          'WHEN $_notInsideSync AND ${_deletionCondition(d)} '
          'BEGIN ${_recordDeletion(d)} END';
    }
  }

  for (final l in _ownedLists) {
    final t = l.table;
    final fk = l.foreignKey;
    ddl['sync_${t}_owner_insert'] =
        'CREATE TRIGGER sync_${t}_owner_insert '
        'AFTER INSERT ON $t '
        'WHEN $_notInsideSync '
        'BEGIN ${_dirty(l.owner, 'id = NEW.$fk')} END';
    ddl['sync_${t}_owner_update'] =
        'CREATE TRIGGER sync_${t}_owner_update '
        'AFTER UPDATE OF $fk, ${l.pushed.join(', ')} ON $t '
        'WHEN $_notInsideSync AND ${_changed([fk, ...l.pushed])} '
        'BEGIN ${_dirty(l.owner, 'id IN (NEW.$fk, OLD.$fk)')} END';

    final d = l.deletion;
    if (d == null) {
      ddl['sync_${t}_owner_delete'] =
          'CREATE TRIGGER sync_${t}_owner_delete '
          'AFTER DELETE ON $t '
          'WHEN $_notInsideSync '
          'BEGIN ${_dirty(l.owner, 'id = OLD.$fk')} END';
    } else {
      ddl['sync_${t}_delete'] =
          'CREATE TRIGGER sync_${t}_delete '
          'AFTER DELETE ON $t '
          'WHEN $_notInsideSync AND ${_deletionCondition(d)} '
          'BEGIN ${_recordDeletion(d)} END';
    }
  }

  return ddl;
}

/// Brings the database's sync triggers in line with [syncTriggerDdl].
///
/// Runs every time the database opens, so a trigger always matches the code
/// that ships with it: a trigger whose SQL differs is dropped and recreated, and
/// one this build no longer defines is dropped. Nothing is rewritten when
/// nothing changed, so an ordinary launch costs one read of `sqlite_master`.
Future<void> installSyncTriggers(GeneratedDatabase db) async {
  final wanted = syncTriggerDdl();
  final rows =
      await db
          .customSelect(
            "SELECT name, sql FROM sqlite_master WHERE type = 'trigger' "
            "AND name LIKE 'sync\\_%' ESCAPE '\\'",
          )
          .get();
  final existing = {
    for (final r in rows) r.read<String>('name'): r.read<String?>('sql'),
  };

  final stale = [
    for (final name in existing.keys)
      if (wanted[name] != existing[name]) name,
  ];
  final missing = [
    for (final name in wanted.keys)
      if (wanted[name] != existing[name]) name,
  ];
  if (stale.isEmpty && missing.isEmpty) return;

  await db.transaction(() async {
    for (final name in stale) {
      await db.customStatement('DROP TRIGGER IF EXISTS $name');
    }
    for (final name in missing) {
      await db.customStatement(wanted[name]!);
    }
  });
}
