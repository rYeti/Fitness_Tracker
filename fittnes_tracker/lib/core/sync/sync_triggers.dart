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
/// An owned list whose members the server removes one at a time (a meal's
/// foods) gets `sync_<t>_delete` in place of `sync_<t>_owner_delete`: taking
/// a member out is a DELETE of that member, not a change to its owner.
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
/// templates, a session exercise's logged sets, a meal's foods, a plan's
/// workouts. Adding one, or changing one, is a change to the owner: its push
/// is what sends them.
///
/// Removing one depends on how the server takes the list. Where it replaces
/// the whole list, removing a member leaves no row behind to find, so that is
/// a change to the owner too. Where it takes members one at a time — a meal's
/// foods, upserted by id — removing one is its own DELETE ([deletion]):
/// a list sent whole would also remove whatever this device has never seen.
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
  final _Deletion? deletion;
}

class _Deletion {
  const _Deletion(this.kind, {this.parent, this.onlyWhen});

  /// A [SyncDeletionKind] name.
  final String kind;

  /// SQL over `OLD` for the server id of the row the DELETE route is nested
  /// under. A deletion needing one is recorded only when it resolves.
  final String? parent;

  /// A further condition on the deleted row, on top of its having a server id.
  final String? onlyWhen;
}

/// Where a `sync_deletion_table` entry's DELETE goes.
///
/// [planWorkout] is no longer recorded: a plan's workouts are sent as the
/// whole list (`PUT api/WorkoutPlan/{id}/workouts`), so removing one only has
/// to dirty the plan. It stays so entries an older build queued are still
/// sent. [mealFood] was retired the same way and is recorded again: a meal's
/// foods are upserted by id, and a whole-list replace of them deleted the
/// foods another device had added (`docs/sync-architecture.md` §18).
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
  // A meal's foods are upserted by id, so taking one out is its own DELETE —
  // by the entry's id, which tells two portions of one food apart. Sent as
  // the whole list instead, the meal's foods would replace the server's, and
  // every food another device had added and this one hadn't pulled yet went
  // with them. A dangling entry — its food row gone here — records nothing:
  // this device can't say what it was, and must not take it off the server.
  _OwnedList(
    'meal_food_table',
    owner: 'meal_table',
    foreignKey: 'meal_id',
    pushed: ['food_entry_id'],
    deletion: _Deletion(
      'mealFood',
      parent: '(SELECT server_id FROM meal_table WHERE id = OLD.meal_id)',
      onlyWhen:
          'EXISTS (SELECT 1 FROM food_item WHERE id = OLD.food_entry_id)',
    ),
  ),
  // A plan's workouts go as the whole list, like the first two: taking one
  // out dirties the plan. A link has no id of its own to address a DELETE by.
  _OwnedList(
    'workout_plan_workout_table',
    owner: 'workout_plan_table',
    foreignKey: 'plan_id',
    pushed: ['workout_id'],
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

String _recordDeletion(_Deletion d) =>
    'INSERT INTO sync_deletion_table (kind, server_id, parent_server_id) '
    "VALUES ('${d.kind}', OLD.server_id, ${d.parent ?? 'NULL'});";

/// Whether the server may have the deleted row, and so needs telling.
///
/// Any row with a `server_id` may. The device mints that id on insert and
/// every create sends it, so a create that reached the server but whose answer
/// was lost has stored the row under that id while this device still calls it
/// `pending` (0). A status test here used to skip those rows, and the server
/// kept one the user had deleted, for the next pull to bring back. A DELETE
/// for a row the server never got costs one 404, which the push treats as
/// done. See `docs/sync-architecture.md` §15.
///
/// A null id still means the server can't have it: a built-in exercise until
/// it is linked by name, which is the server's row and never the user's to
/// delete.
String _deletionCondition(_Deletion d) {
  final parts = [
    'OLD.server_id IS NOT NULL',
    if (d.parent != null) '${d.parent} IS NOT NULL',
    if (d.onlyWhen != null) d.onlyWhen!,
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
