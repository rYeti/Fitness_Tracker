import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/dao/meal_template_dao.dart';
import 'package:ForgeForm/core/network/api_client.dart';
import 'package:ForgeForm/core/network/services/meal_entry_reconcile.dart';
import 'package:dio/dio.dart' show DioException;
import 'package:drift/drift.dart';
import 'package:logger/logger.dart';

class SyncService {
  final AppDatabase _db;
  final ApiClient _apiClient;
  final MealTemplateDao _mealTemplateDao;
  final Logger _logger = Logger();

  SyncService({
    required AppDatabase db,
    required ApiClient apiClient,
    required MealTemplateDao mealTemplateDao,
  }) : _db = db,
       _apiClient = apiClient,
       _mealTemplateDao = mealTemplateDao;

  // ── Entry points ─────────────────────────────────────────────────────────

  /// Runs all sync operations in dependency order:
  /// exercises → workout templates → workout plans → scheduled workouts →
  /// food items → meals → meal templates → user settings → weight logs.
  Future<void> syncAll() async {
    // Phase 0: remove any duplicate rows caused by previous sync bugs.
    await _deduplicateAll();

    // Phase 1: system exercise IDs must come first (workouts depend on them).
    await _syncSystemExerciseIds();

    // Phase 2: reconcile must finish before any push — its GET calls run in
    // parallel internally, but a push running alongside reconcile could race:
    // reconcile snapshots the server list before the push completes, then
    // resets the just-synced serverId, causing duplicate records next sync.
    await _reconcileAll();

    // Phase 3: independent pushes in parallel.
    await Future.wait([
      syncCustomExercises(),
      syncFoodItems(),
      syncUserSettings(),
      syncWeightLogs(),
    ]);

    // Phase 3: workouts depend on exercises being synced.
    await syncWorkoutTemplates();
    await _syncMissingWorkoutExercises();

    // Phase 4: plans depend on workouts; meals depend on food items — run in parallel.
    await Future.wait([syncWorkoutPlans(), syncMeals(), syncMealTemplates()]);

    // Phase 5: scheduled workouts depend on plans and workouts.
    await syncScheduledWorkouts();
    await _syncMissingScheduledExerciseSets();
    _logger.i('syncAll: complete');
  }

  // ── Custom exercises ──────────────────────────────────────────────────────

  Future<void> syncCustomExercises() async {
    final unsynced = await _db.exerciseDao.getUnsyncedCustomExercises();
    if (unsynced.isEmpty) return;

    for (final exercise in unsynced) {
      try {
        switch (SyncStatus.values[exercise.syncStatus]) {
          case SyncStatus.pending:
            await _syncNewExercise(exercise);
          case SyncStatus.pendingUpdate:
            await _syncUpdateExercise(exercise);
          case SyncStatus.pendingDelete:
            await _syncDeleteExercise(exercise);
          case SyncStatus.synced:
            break;
        }
      } catch (e) {
        _logger.w('Exercise sync failed for local ${exercise.id}: $e');
      }
    }
  }

  Future<void> _syncNewExercise(ExerciseTableData e) async {
    final response = await _apiClient.post(
      'api/Exercise/UserExercise',
      data: {
        'name': e.name,
        'description': e.description ?? '',
        'type': e.type,
        'targetMuscleGroups': e.targetMuscleGroups,
        'imageUrl': e.imageUrl ?? '',
        'isCustom': true,
        'nameDe': e.nameDe ?? '',
        'descriptionDe': e.descriptionDe ?? '',
      },
    );
    final serverId = response.data['id'] as String;
    await _db.exerciseDao.markExerciseSynced(e.id, serverId);
    _logger.i('Synced new exercise ${e.id} → server $serverId');
  }

  Future<void> _syncUpdateExercise(ExerciseTableData e) async {
    if (e.serverId == null) {
      await _syncNewExercise(e);
      return;
    }
    await _apiClient.put(
      'api/Exercise/UserExercise/${e.serverId}',
      data: {
        'name': e.name,
        'description': e.description ?? '',
        'type': e.type,
        'targetMuscleGroups': e.targetMuscleGroups,
        'imageUrl': e.imageUrl ?? '',
        'isCustom': true,
        'nameDe': e.nameDe ?? '',
        'descriptionDe': e.descriptionDe ?? '',
      },
    );
    await _db.exerciseDao.markExerciseSynced(e.id, e.serverId!);
    _logger.i('Updated exercise ${e.id} on server ${e.serverId}');
  }

  Future<void> _syncDeleteExercise(ExerciseTableData e) async {
    if (e.serverId == null) {
      await _db.exerciseDao.deleteExercise(e.id);
      return;
    }
    await _apiClient.delete('api/Exercise/UserExercise/${e.serverId}');
    await _db.exerciseDao.deleteExercise(e.id);
    _logger.i('Deleted exercise ${e.id} from server ${e.serverId}');
  }

  // ── Workout templates ─────────────────────────────────────────────────────

  Future<void> syncWorkoutTemplates() async {
    final unsynced = await _db.workoutDao.getUnsyncedTemplates();
    if (unsynced.isEmpty) return;

    for (final workout in unsynced) {
      try {
        switch (SyncStatus.values[workout.syncStatus]) {
          case SyncStatus.pending:
            await _syncNewWorkout(workout);
          case SyncStatus.pendingUpdate:
            await _syncUpdateWorkout(workout);
          case SyncStatus.pendingDelete:
            await _syncDeleteWorkout(workout);
          case SyncStatus.synced:
            break;
        }
      } catch (e) {
        _logger.w('Workout sync failed for local ${workout.id}: $e');
      }
    }
  }

  Future<void> _syncNewWorkout(WorkoutTableData w) async {
    final response = await _apiClient.post(
      'api/Workout',
      data: {
        'name': w.name,
        'description': w.description,
        'difficulty': w.difficulty,
        'estimatedDurationMinutes': w.estimatedDurationMinutes,
        'isTemplate': w.isTemplate,
        'scheduledDate': w.scheduledDate?.toUtc().toIso8601String(),
        'color': w.color?.toSigned(32),
      },
    );
    final serverId = response.data['id'] as String;
    await _db.workoutDao.markWorkoutSynced(w.id, serverId);

    // Push exercises for this workout (batch).
    final exercises = await _db.workoutDao.getExercisesForWorkoutRaw(w.id);
    await _syncNewWorkoutExercisesBatch(exercises, serverId);
    _logger.i('Synced new workout ${w.id} → server $serverId');
  }

  Future<void> _syncUpdateWorkout(WorkoutTableData w) async {
    if (w.serverId == null) {
      await _syncNewWorkout(w);
      return;
    }
    await _apiClient.put(
      'api/Workout/${w.serverId}',
      data: {
        'name': w.name,
        'description': w.description,
        'difficulty': w.difficulty,
        'estimatedDurationMinutes': w.estimatedDurationMinutes,
        'isTemplate': w.isTemplate,
        'scheduledDate': w.scheduledDate?.toUtc().toIso8601String(),
        'color': w.color?.toSigned(32),
      },
    );
    await _db.workoutDao.markWorkoutSynced(w.id, w.serverId!);

    // Sync unsynced exercises for this workout.
    final exercises = await _db.workoutDao.getExercisesForWorkoutRaw(w.id);
    final newExercises =
        exercises
            .where((e) => e.syncStatus == 0 && e.serverId == null)
            .toList();
    if (newExercises.isNotEmpty)
      await _syncNewWorkoutExercisesBatch(newExercises, w.serverId!);
    for (final we in exercises.where(
      (e) => e.syncStatus == 2 && e.serverId != null,
    )) {
      await _syncUpdateWorkoutExercise(we);
    }
    for (final we in exercises.where((e) => e.syncStatus == 3)) {
      await _syncDeleteWorkoutExercise(we);
    }
    _logger.i('Updated workout ${w.id} on server ${w.serverId}');
  }

  Future<void> _syncDeleteWorkout(WorkoutTableData w) async {
    if (w.serverId == null) {
      await _db.workoutDao.deleteWorkout(w.id);
      return;
    }
    await _apiClient.delete('api/Workout/${w.serverId}');
    await _db.workoutDao.deleteWorkout(w.id);
    _logger.i('Deleted workout ${w.id} from server ${w.serverId}');
  }

  Future<void> _syncNewWorkoutExercisesBatch(
    List<WorkoutExerciseTableData> exercises,
    String workoutServerId,
  ) async {
    final dtos = <Map<String, dynamic>>[];
    final valid = <WorkoutExerciseTableData>[];
    for (final we in exercises) {
      var exercise = await _db.exerciseDao.getExerciseById(we.exerciseId);
      if (exercise?.serverId == null && exercise != null) {
        // The local exercise row has no serverId — this happens when
        // _syncSystemExerciseIds created a new row from server data instead of
        // matching the existing local row (e.g. slight name difference).
        // Try to find any synced exercise with the same name as a fallback.
        final candidates = await _db.exerciseDao.searchExercises(exercise.name);
        final synced = candidates.where((c) => c.serverId != null).firstOrNull;
        if (synced != null) {
          _logger.i('_syncNewWorkoutExercisesBatch: resolved exercise "${exercise.name}" via synced duplicate (local ${exercise.id} → ${synced.id})');
          exercise = synced;
        }
      }
      if (exercise?.serverId == null) {
        _logger.w('_syncNewWorkoutExercisesBatch: skipping workoutExercise ${we.id} (pos ${we.orderPosition}, exerciseId=${we.exerciseId}, name="${exercise?.name}") — no serverId found');
        continue;
      }
      dtos.add({
        'exerciseId': exercise!.serverId,
        'orderPosition': we.orderPosition,
        'notes': we.notes,
        'supersetGroupId': we.supersetGroupId,
      });
      valid.add(we);
    }
    if (dtos.isEmpty) return;

    final response = await _apiClient.post(
      'api/Workout/$workoutServerId/exercises/batch',
      data: dtos,
    );
    final serverList = (response.data as List).cast<Map<String, dynamic>>();

    for (var i = 0; i < valid.length && i < serverList.length; i++) {
      final weServerId = serverList[i]['id'] as String;
      await _db.workoutDao.markWorkoutExerciseSynced(valid[i].id, weServerId);

      final templates = await _db.workoutDao.getSetTemplatesForWorkoutExercise(
        valid[i].id,
      );
      // The whole prescription, for the same reason as in
      // _syncMissingWorkoutExercises: the endpoint replaces rather than appends.
      if (templates.any((t) => t.syncStatus != 1))
        await _syncNewSetTemplatesBatch(templates, weServerId);
    }
  }

  Future<void> _syncUpdateWorkoutExercise(WorkoutExerciseTableData we) async {
    if (we.serverId == null) return;
    final exercise = await _db.exerciseDao.getExerciseById(we.exerciseId);
    if (exercise?.serverId == null) return;

    await _apiClient.put(
      'api/Workout/exercises/${we.serverId}',
      data: {
        'exerciseId': exercise!.serverId,
        'orderPosition': we.orderPosition,
        'notes': we.notes,
        'supersetGroupId': we.supersetGroupId,
      },
    );
    await _db.workoutDao.markWorkoutExerciseSynced(we.id, we.serverId!);
  }

  Future<void> _syncDeleteWorkoutExercise(WorkoutExerciseTableData we) async {
    if (we.serverId == null) {
      await _db.workoutDao.deleteWorkoutExercise(we.id);
      return;
    }
    await _apiClient.delete('api/Workout/exercises/${we.serverId}');
    await _db.workoutDao.deleteWorkoutExercise(we.id);
    _logger.i('Deleted workout exercise ${we.id} from server ${we.serverId}');
  }

  /// Pushes an exercise's prescription. The endpoint replaces whatever the
  /// exercise currently has, matching the local save path, which rebuilds every
  /// set template rather than diffing them — so [templates] must always be the
  /// exercise's complete list, never only the rows that still need syncing.
  Future<void> _syncNewSetTemplatesBatch(
    List<WorkoutSetTemplateData> templates,
    String workoutExerciseServerId,
  ) async {
    final response = await _apiClient.post(
      'api/Workout/exercises/$workoutExerciseServerId/sets/batch',
      data:
          templates
              .map(
                (t) => {
                  'setNumber': t.setNumber,
                  'targetReps': t.targetReps,
                  'orderPosition': t.orderPosition,
                },
              )
              .toList(),
    );
    final serverList = (response.data as List).cast<Map<String, dynamic>>();
    for (var i = 0; i < templates.length && i < serverList.length; i++) {
      await _db.workoutDao.markSetTemplateSynced(
        templates[i].id,
        serverList[i]['id'] as String,
      );
    }
  }

  // ── Workout plans ─────────────────────────────────────────────────────────

  Future<void> syncWorkoutPlans() async {
    final unsynced = await _db.workoutPlanDao.getUnsyncedPlans();
    if (unsynced.isEmpty) return;

    for (final plan in unsynced) {
      try {
        switch (SyncStatus.values[plan.syncStatus]) {
          case SyncStatus.pending:
            await _syncNewPlan(plan);
          case SyncStatus.pendingUpdate:
            await _syncUpdatePlan(plan);
          case SyncStatus.pendingDelete:
            await _syncDeletePlan(plan);
          case SyncStatus.synced:
            break;
        }
      } catch (e) {
        _logger.w('Plan sync failed for local ${plan.id}: $e');
      }
    }
  }

  Future<int?> _getPlanDurationDays(int planId) async {
    final row = await _db
        .customSelect(
          'SELECT duration_days FROM workout_plan_table WHERE id = ?',
          variables: [Variable.withInt(planId)],
        )
        .getSingleOrNull();
    return row?.read<int?>('duration_days');
  }

  Future<void> _syncNewPlan(WorkoutPlanTableData p) async {
    final durationDays = await _getPlanDurationDays(p.id);
    final response = await _apiClient.post(
      'api/WorkoutPlan',
      data: {
        'name': p.name,
        'description': p.description,
        'startDate': p.startDate.toUtc().toIso8601String(),
        'cyclePatternJson': p.cyclePatternJson,
        'isFreeChoice': p.isFreeChoice,
        'durationDays': durationDays,
      },
    );
    final serverId = response.data['id'] as String;
    await _db.workoutPlanDao.markPlanSynced(p.id, serverId);

    // Link workouts to the plan (batch).
    final links = await _db.workoutPlanDao.getPlanWorkoutsForPlan(p.id);
    await _syncNewPlanWorkoutsBatch(
      links.where((l) => l.syncStatus != 1).toList(),
      serverId,
    );
    _logger.i('Synced new plan ${p.id} → server $serverId');
  }

  Future<void> _syncUpdatePlan(WorkoutPlanTableData p) async {
    if (p.serverId == null) {
      await _syncNewPlan(p);
      return;
    }
    final durationDays = await _getPlanDurationDays(p.id);
    await _apiClient.put(
      'api/WorkoutPlan/${p.serverId}',
      data: {
        'name': p.name,
        'description': p.description,
        'startDate': p.startDate.toUtc().toIso8601String(),
        'cyclePatternJson': p.cyclePatternJson,
        'isFreeChoice': p.isFreeChoice,
        'durationDays': durationDays,
      },
    );
    await _db.workoutPlanDao.markPlanSynced(p.id, p.serverId!);

    final links = await _db.workoutPlanDao.getPlanWorkoutsForPlan(p.id);
    await _syncNewPlanWorkoutsBatch(
      links.where((l) => l.syncStatus != 1).toList(),
      p.serverId!,
    );
    _logger.i('Updated plan ${p.id} on server ${p.serverId}');
  }

  Future<void> _syncDeletePlan(WorkoutPlanTableData p) async {
    if (p.serverId == null) {
      await _db.workoutPlanDao.deleteWorkoutPlan(p.id);
      return;
    }
    await _apiClient.delete('api/WorkoutPlan/${p.serverId}');
    await _db.workoutPlanDao.deleteWorkoutPlan(p.id);
    _logger.i('Deleted plan ${p.id} from server ${p.serverId}');
  }

  Future<void> _syncNewPlanWorkoutsBatch(
    List<WorkoutPlanWorkoutTableData> links,
    String planServerId,
  ) async {
    final serverIds = <String>[];
    final valid = <WorkoutPlanWorkoutTableData>[];
    for (final link in links) {
      final workoutRow =
          await ((_db.select(_db.workoutTable))
            ..where((w) => w.id.equals(link.workoutId))).getSingleOrNull();
      if (workoutRow?.serverId == null) continue;
      serverIds.add(workoutRow!.serverId!);
      valid.add(link);
    }
    if (serverIds.isEmpty) return;
    await _apiClient.post(
      'api/WorkoutPlan/$planServerId/workouts/batch',
      data: serverIds,
    );
    for (final link in valid) {
      await _db.workoutPlanDao.markPlanWorkoutSynced(link.id, planServerId);
    }
  }

  // ── Scheduled workouts ────────────────────────────────────────────────────

  Future<void> syncScheduledWorkouts() async {
    final unsynced = await _db.workoutDao.getUnsyncedScheduledWorkouts();
    _logger.i('syncScheduledWorkouts: ${unsynced.length} unsynced rows');
    if (unsynced.isEmpty) return;

    for (final sw in unsynced) {
      try {
        switch (SyncStatus.values[sw.syncStatus]) {
          case SyncStatus.pending:
            await _syncNewScheduledWorkout(sw);
          case SyncStatus.pendingUpdate:
            await _syncUpdateScheduledWorkout(sw);
          case SyncStatus.pendingDelete:
            await _syncDeleteScheduledWorkout(sw);
          case SyncStatus.synced:
            break;
        }
      } catch (e) {
        _logger.w('ScheduledWorkout sync failed for local ${sw.id}: $e');
      }
    }
  }

  Future<void> _syncNewScheduledWorkout(ScheduledWorkoutTableData sw) async {
    // Resolve server IDs for the referenced workout and plan.
    final workoutRow =
        await ((_db.select(_db.workoutTable))
          ..where((w) => w.id.equals(sw.workoutId))).getSingleOrNull();
    if (workoutRow?.serverId == null) return; // workout not synced yet

    String? planServerId;
    if (sw.workoutPlanId != null) {
      final planRow =
          await ((_db.select(_db.workoutPlanTable))
            ..where((p) => p.id.equals(sw.workoutPlanId!))).getSingleOrNull();
      planServerId = planRow?.serverId;
    }

    String? templateWorkoutServerId;
    if (sw.templateWorkoutId != null) {
      final templateRow =
          await ((_db.select(_db.workoutTable))..where(
            (w) => w.id.equals(sw.templateWorkoutId!),
          )).getSingleOrNull();
      templateWorkoutServerId = templateRow?.serverId;
    }

    final response = await _apiClient.post(
      'api/ScheduledWorkout',
      data: {
        'workoutId': workoutRow!.serverId,
        'workoutPlanId': planServerId,
        'templateWorkoutId': templateWorkoutServerId,
        'scheduledDate': sw.scheduledDate.toUtc().toIso8601String(),
        'notes': sw.notes,
        'isCompleted': sw.isCompleted,
        'isSkipped': sw.isSkipped,
      },
    );
    final swServerId = response.data['id'] as String;
    await _db.workoutDao.markScheduledWorkoutSynced(sw.id, swServerId);

    // The API returns the scheduled workout exercises in the response.
    // Store their server IDs so we can push sets against them.
    final serverExercises =
        (response.data['exercises'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
    await _storeScheduledExerciseServerIds(sw.id, swServerId, serverExercises);

    // Push unsynced workout sets.
    await _syncSetsForScheduledWorkout(sw.id, swServerId);
    _logger.i('Synced new scheduled workout ${sw.id} → server $swServerId');
  }

  Future<void> _syncUpdateScheduledWorkout(ScheduledWorkoutTableData sw) async {
    if (sw.serverId == null) {
      await _syncNewScheduledWorkout(sw);
      return;
    }

    final workoutRow =
        await ((_db.select(_db.workoutTable))
          ..where((w) => w.id.equals(sw.workoutId))).getSingleOrNull();
    if (workoutRow?.serverId == null) {
      _logger.w(
        '_syncUpdateScheduledWorkout: SW ${sw.id} skipped — workout ${sw.workoutId} has no serverId (workout not yet synced)',
      );
      return;
    }

    String? planServerId;
    if (sw.workoutPlanId != null) {
      final planRow =
          await ((_db.select(_db.workoutPlanTable))
            ..where((p) => p.id.equals(sw.workoutPlanId!))).getSingleOrNull();
      planServerId = planRow?.serverId;
    }

    String? templateWorkoutServerId;
    if (sw.templateWorkoutId != null) {
      final templateRow =
          await ((_db.select(_db.workoutTable))..where(
            (w) => w.id.equals(sw.templateWorkoutId!),
          )).getSingleOrNull();
      templateWorkoutServerId = templateRow?.serverId;
    }

    await _apiClient.put(
      'api/ScheduledWorkout/${sw.serverId}',
      data: {
        'workoutId': workoutRow!.serverId,
        'workoutPlanId': planServerId,
        'templateWorkoutId': templateWorkoutServerId,
        'scheduledDate': sw.scheduledDate.toUtc().toIso8601String(),
        'notes': sw.notes,
        'isCompleted': sw.isCompleted,
        'isSkipped': sw.isSkipped,
      },
    );
    await _db.workoutDao.markScheduledWorkoutSynced(sw.id, sw.serverId!);
    await _syncSetsForScheduledWorkout(sw.id, sw.serverId!);
    _logger.i('Updated scheduled workout ${sw.id} on server ${sw.serverId}');
  }

  Future<void> _syncDeleteScheduledWorkout(ScheduledWorkoutTableData sw) async {
    if (sw.serverId == null) {
      await ((_db.delete(_db.scheduledWorkoutTable))
        ..where((t) => t.id.equals(sw.id))).go();
      return;
    }
    await _apiClient.delete('api/ScheduledWorkout/${sw.serverId}');
    await ((_db.delete(_db.scheduledWorkoutTable))
      ..where((t) => t.id.equals(sw.id))).go();
    _logger.i('Deleted scheduled workout ${sw.id} from server ${sw.serverId}');
  }

  /// After creating a scheduled workout, match server exercise IDs back to
  /// local [ScheduledWorkoutExerciseTable] rows by workout exercise server ID.
  Future<void> _storeScheduledExerciseServerIds(
    int localSwId,
    String swServerId,
    List<Map<String, dynamic>> serverExercises,
  ) async {
    final localExercises = await _db.scheduledWorkoutExerciseDao
        .getAllForScheduledWorkout(localSwId);

    for (final localEx in localExercises) {
      // Look up the server UUID of this exercise's workout exercise template.
      final weRow =
          await ((_db.select(_db.workoutExerciseTable))..where(
            (we) => we.id.equals(localEx.workoutExerciseId),
          )).getSingleOrNull();
      if (weRow?.serverId == null) continue;

      // Find the matching server exercise by its workoutExerciseId.
      final serverEx = serverExercises.cast<Map<String, dynamic>>().firstWhere(
        (s) => s['workoutExerciseId'] == weRow!.serverId,
        orElse: () => {},
      );
      if (serverEx.isEmpty) continue;

      final serverExId = serverEx['id'] as String?;
      if (serverExId != null) {
        await _db.scheduledWorkoutExerciseDao.markScheduledExerciseSynced(
          localEx.id,
          serverExId,
        );
      }
    }
  }

  /// Pushes unsynced [WorkoutSetTable] rows for a given scheduled workout.
  Future<void> _syncSetsForScheduledWorkout(
    int localSwId,
    String swServerId,
  ) async {
    final localExercises = await _db.scheduledWorkoutExerciseDao
        .getAllForScheduledWorkout(localSwId);

    _logger.i(
      '_syncSetsForScheduledWorkout: SW $localSwId has ${localExercises.length} exercises',
    );
    for (final localEx in localExercises) {
      if (localEx.serverId == null) {
        _logger.w(
          '_syncSetsForScheduledWorkout: skipping exercise ${localEx.id} (workoutExerciseId=${localEx.workoutExerciseId}) — no serverId',
        );
        continue;
      }
      final sets = await _db.workoutDao.getSetsForScheduledExercise(localEx.id);

      // Batch new sets.
      final newSets =
          sets.where((s) => s.syncStatus == 0 && s.serverId == null).toList();
      if (newSets.isNotEmpty) {
        try {
          await _syncNewWorkoutSetsBatch(
            newSets,
            swServerId,
            localEx.serverId!,
          );
        } catch (e) {
          _logger.w('Batch set sync failed for exercise ${localEx.id}: $e');
        }
      }

      // Handle updates and deletes individually.
      for (final set in sets.where(
        (s) => s.syncStatus == 2 || s.syncStatus == 3,
      )) {
        try {
          if (set.syncStatus == 2) {
            await _syncUpdateWorkoutSet(set);
          } else {
            await _syncDeleteWorkoutSet(set);
          }
        } catch (e) {
          _logger.w('Set sync failed for local ${set.id}: $e');
        }
      }
    }
  }

  Future<void> _syncNewWorkoutSetsBatch(
    List<WorkoutSetTableData> sets,
    String swServerId,
    String scheduledExerciseServerId,
  ) async {
    final response = await _apiClient.post(
      'api/ScheduledWorkout/$swServerId/exercises/$scheduledExerciseServerId/sets/batch',
      data:
          sets
              .map(
                (s) => {
                  'setNumber': s.setNumber,
                  'reps': s.reps,
                  'weight': s.weight,
                  'weightUnit': s.weightUnit,
                  'durationSeconds': s.durationSeconds,
                  'isCompleted': s.isCompleted,
                  'notes': s.notes,
                },
              )
              .toList(),
    );
    final serverList = (response.data as List).cast<Map<String, dynamic>>();
    for (var i = 0; i < sets.length && i < serverList.length; i++) {
      await _db.workoutDao.markWorkoutSetSynced(
        sets[i].id,
        serverList[i]['id'] as String,
      );
    }
    _logger.i(
      '_syncNewWorkoutSetsBatch: pushed ${serverList.length} sets to SW $swServerId / exercise $scheduledExerciseServerId',
    );
  }

  Future<void> _syncUpdateWorkoutSet(WorkoutSetTableData s) async {
    if (s.serverId == null) return;
    await _apiClient.put(
      'api/ScheduledWorkout/exercises/sets/${s.serverId}',
      data: {
        'setNumber': s.setNumber,
        'reps': s.reps,
        'weight': s.weight,
        'weightUnit': s.weightUnit,
        'durationSeconds': s.durationSeconds,
        'isCompleted': s.isCompleted,
        'notes': s.notes,
      },
    );
    await _db.workoutDao.markWorkoutSetSynced(s.id, s.serverId!);
  }

  Future<void> _syncDeleteWorkoutSet(WorkoutSetTableData s) async {
    if (s.serverId == null) {
      await ((_db.delete(_db.workoutSetTable))
        ..where((t) => t.id.equals(s.id))).go();
      return;
    }
    await _apiClient.delete(
      'api/ScheduledWorkout/exercises/sets/${s.serverId}',
    );
    await ((_db.delete(_db.workoutSetTable))
      ..where((t) => t.id.equals(s.id))).go();
  }

  /// Finds workouts already on the server whose exercises were never pushed
  /// (skipped because system exercise serverIds were missing at sync time).
  Future<void> _syncMissingWorkoutExercises() async {
    final syncedWorkouts =
        await (_db.select(_db.workoutTable)
          ..where((w) => w.serverId.isNotNull())).get();

    for (final w in syncedWorkouts) {
      try {
        final exercises = await _db.workoutDao.getExercisesForWorkoutRaw(w.id);
        final unsyncedExercises =
            exercises.where((e) => e.serverId == null).toList();
        if (unsyncedExercises.isNotEmpty) {
          await _syncNewWorkoutExercisesBatch(unsyncedExercises, w.serverId!);
        }
        // Also check for set templates on exercises that are now synced.
        final syncedExercises =
            exercises.where((e) => e.serverId != null).toList();
        for (final ex in syncedExercises) {
          final templates = await _db.workoutDao
              .getSetTemplatesForWorkoutExercise(ex.id);
          // Push the whole prescription, not just the rows missing a serverId:
          // the endpoint replaces what the exercise has, so a partial list would
          // delete the templates that did make it across on an earlier attempt.
          if (templates.any((t) => t.serverId == null)) {
            await _syncNewSetTemplatesBatch(templates, ex.serverId!);
          }
        }
      } catch (e) {
        _logger.w(
          '_syncMissingWorkoutExercises failed for workout ${w.id}: $e',
        );
      }
    }
  }

  /// Deduplicates workout_table rows by name, keeping the row with a non-null
  /// serverId (preferred) or the lowest local id. Re-links any
  /// scheduled_workout_table rows from the loser to the winner before deleting
  /// the loser, so the subsequent SW content dedup can finish the job.
  Future<void> _deduplicateWorkoutsByContent() async {
    try {
      final all =
          await (_db.select(_db.workoutTable)
            ..orderBy([(t) => OrderingTerm.asc(t.id)])).get();

      // Sort so non-null serverId comes first (those are the "winners").
      final sorted = [...all]..sort((a, b) {
        if (a.serverId != null && b.serverId == null) return -1;
        if (a.serverId == null && b.serverId != null) return 1;
        return a.id.compareTo(b.id);
      });

      final seen = <String, WorkoutTableData>{};
      for (final w in sorted) {
        final key = w.name.toLowerCase().trim();
        if (!seen.containsKey(key)) {
          seen[key] = w;
        } else {
          final winner = seen[key]!;
          // Re-link scheduled workouts from loser → winner.
          await (_db.update(_db.scheduledWorkoutTable)..where(
            (t) => t.workoutId.equals(w.id),
          )).write(ScheduledWorkoutTableCompanion(workoutId: Value(winner.id)));
          // Cascade-delete loser's child exercises.
          final exercises =
              await (_db.select(_db.workoutExerciseTable)
                ..where((e) => e.workoutId.equals(w.id))).get();
          for (final ex in exercises) {
            await (_db.delete(_db.workoutSetTemplateTable)
              ..where((t) => t.workoutExerciseId.equals(ex.id))).go();
          }
          await (_db.delete(_db.workoutExerciseTable)
            ..where((t) => t.workoutId.equals(w.id))).go();
          await (_db.delete(_db.workoutTable)
            ..where((t) => t.id.equals(w.id))).go();
          _logger.i(
            'Dedup by name: removed duplicate workout ${w.id} "${w.name}", re-linked SWs to winner ${winner.id}',
          );
        }
      }
    } catch (e) {
      _logger.w('_deduplicateWorkoutsByContent failed: $e');
    }
  }

  /// Removes duplicate rows (same serverId) from every synced table, keeping
  /// the row with the lowest local id. Cascades to child tables.
  Future<void> _deduplicateScheduledWorkoutsByContent() async {
    try {
      final all =
          await (_db.select(_db.scheduledWorkoutTable)
            ..orderBy([(t) => OrderingTerm.asc(t.id)])).get();

      // Group by workoutId + scheduledDate — keep first (lowest id), delete the rest.
      final seen = <String>{};
      for (final sw in all) {
        // Normalize to date-only so UTC-stored vs local-stored dates on the
        // same calendar day are treated as identical.
        final d = sw.scheduledDate;
        final key = '${sw.workoutId}_${d.year}-${d.month}-${d.day}';
        if (!seen.add(key)) {
          final exercises = await _db.scheduledWorkoutExerciseDao
              .getAllForScheduledWorkout(sw.id);
          for (final ex in exercises) {
            await (_db.delete(_db.workoutSetTable)
              ..where((t) => t.scheduledWorkoutExerciseId.equals(ex.id))).go();
          }
          await (_db.delete(_db.scheduledWorkoutExerciseTable)
            ..where((t) => t.scheduledWorkoutId.equals(sw.id))).go();
          await (_db.delete(_db.scheduledWorkoutTable)
            ..where((t) => t.id.equals(sw.id))).go();
          _logger.i(
            'Dedup by content: removed duplicate SW ${sw.id} (workout ${sw.workoutId} date ${sw.scheduledDate})',
          );
        }
      }
    } catch (e) {
      _logger.w('_deduplicateScheduledWorkoutsByContent failed: $e');
    }
  }

  Future<void> _deduplicateScheduledExercisesByContent() async {
    try {
      final all =
          await (_db.select(_db.scheduledWorkoutExerciseTable)
            ..orderBy([(t) => OrderingTerm.asc(t.id)])).get();

      // Keep the first (lowest id) row per (scheduledWorkoutId, workoutExerciseId).
      final seen = <String>{};
      for (final ex in all) {
        final key = '${ex.scheduledWorkoutId}_${ex.workoutExerciseId}';
        if (!seen.add(key)) {
          await (_db.delete(_db.workoutSetTable)
            ..where((t) => t.scheduledWorkoutExerciseId.equals(ex.id))).go();
          await (_db.delete(_db.scheduledWorkoutExerciseTable)
            ..where((t) => t.id.equals(ex.id))).go();
          _logger.i(
            'Dedup by content: removed duplicate ScheduledExercise ${ex.id} '
            '(SW ${ex.scheduledWorkoutId}, WE ${ex.workoutExerciseId})',
          );
        }
      }
    } catch (e) {
      _logger.w('_deduplicateScheduledExercisesByContent failed: $e');
    }
  }

  Future<void> _deduplicateMealsByContent() async {
    try {
      await _db.mealDao.deduplicateMeals();
    } catch (e) {
      _logger.w('_deduplicateMealsByContent failed: $e');
    }
  }

  Future<void> _deduplicateAll() async {
    // Content-based dedup for workouts: two rows with the same name are always
    // duplicates. Must run first so SWs are re-linked before SW dedup.
    await _deduplicateWorkoutsByContent();

    // Content-based dedup for scheduled workouts: two rows for the same
    // workout+date are always duplicates regardless of their serverIds.
    await _deduplicateScheduledWorkoutsByContent();

    // Content-based dedup for scheduled workout exercises: two rows with the
    // same (scheduledWorkoutId, workoutExerciseId) are always duplicates,
    // caused by concurrent debounce saves both inserting before either updates
    // the in-memory scheduledExerciseId.
    await _deduplicateScheduledExercisesByContent();

    await _deduplicateTable<ScheduledWorkoutTableData>(
      query:
          () =>
              (_db.select(_db.scheduledWorkoutTable)
                    ..where((t) => t.serverId.isNotNull())
                    ..orderBy([(t) => OrderingTerm.asc(t.id)]))
                  .get(),
      getServerId: (r) => r.serverId!,
      getLocalId: (r) => r.id,
      onDelete: (id) async {
        final exercises = await _db.scheduledWorkoutExerciseDao
            .getAllForScheduledWorkout(id);
        for (final ex in exercises) {
          await (_db.delete(_db.workoutSetTable)
            ..where((t) => t.scheduledWorkoutExerciseId.equals(ex.id))).go();
        }
        await (_db.delete(_db.scheduledWorkoutExerciseTable)
          ..where((t) => t.scheduledWorkoutId.equals(id))).go();
        await (_db.delete(_db.scheduledWorkoutTable)
          ..where((t) => t.id.equals(id))).go();
      },
    );

    await _deduplicateTable<WorkoutTableData>(
      query:
          () =>
              (_db.select(_db.workoutTable)
                    ..where((t) => t.serverId.isNotNull())
                    ..orderBy([(t) => OrderingTerm.asc(t.id)]))
                  .get(),
      getServerId: (r) => r.serverId!,
      getLocalId: (r) => r.id,
      onDelete: (id) async {
        final exercises =
            await (_db.select(_db.workoutExerciseTable)
              ..where((e) => e.workoutId.equals(id))).get();
        for (final ex in exercises) {
          await (_db.delete(_db.workoutSetTemplateTable)
            ..where((t) => t.workoutExerciseId.equals(ex.id))).go();
        }
        await (_db.delete(_db.workoutExerciseTable)
          ..where((t) => t.workoutId.equals(id))).go();
        await (_db.delete(_db.workoutTable)
          ..where((t) => t.id.equals(id))).go();
      },
    );

    await _deduplicateTable<ExerciseTableData>(
      query:
          () =>
              (_db.select(_db.exerciseTable)
                    ..where((t) => t.serverId.isNotNull())
                    ..orderBy([(t) => OrderingTerm.asc(t.id)]))
                  .get(),
      getServerId: (r) => r.serverId!,
      getLocalId: (r) => r.id,
      onDelete:
          (id) =>
              (_db.delete(_db.exerciseTable)
                ..where((t) => t.id.equals(id))).go(),
    );

    await _deduplicateTable<WorkoutExerciseTableData>(
      query:
          () =>
              (_db.select(_db.workoutExerciseTable)
                    ..where((t) => t.serverId.isNotNull())
                    ..orderBy([(t) => OrderingTerm.asc(t.id)]))
                  .get(),
      getServerId: (r) => r.serverId!,
      getLocalId: (r) => r.id,
      onDelete: (id) async {
        await (_db.delete(_db.workoutSetTemplateTable)
          ..where((t) => t.workoutExerciseId.equals(id))).go();
        await (_db.delete(_db.workoutExerciseTable)
          ..where((t) => t.id.equals(id))).go();
      },
    );

    await _deduplicateTable<FoodItemData>(
      query:
          () =>
              (_db.select(_db.foodItem)
                    ..where((t) => t.serverId.isNotNull())
                    ..orderBy([(t) => OrderingTerm.asc(t.id)]))
                  .get(),
      getServerId: (r) => r.serverId!,
      getLocalId: (r) => r.id,
      onDelete:
          (id) =>
              (_db.delete(_db.foodItem)..where((t) => t.id.equals(id))).go(),
    );

    await _deduplicateTable<MealTableData>(
      query:
          () =>
              (_db.select(_db.mealTable)
                    ..where((t) => t.serverId.isNotNull())
                    ..orderBy([(t) => OrderingTerm.asc(t.id)]))
                  .get(),
      getServerId: (r) => r.serverId!,
      getLocalId: (r) => r.id,
      onDelete: (id) async {
        await (_db.delete(_db.mealFoodTable)
          ..where((t) => t.mealId.equals(id))).go();
        await (_db.delete(_db.mealTable)..where((t) => t.id.equals(id))).go();
      },
    );

    await _deduplicateTable<WeightRecordData>(
      query:
          () =>
              (_db.select(_db.weightRecord)
                    ..where((t) => t.serverId.isNotNull())
                    ..orderBy([(t) => OrderingTerm.asc(t.id)]))
                  .get(),
      getServerId: (r) => r.serverId!,
      getLocalId: (r) => r.id,
      onDelete:
          (id) =>
              (_db.delete(_db.weightRecord)
                ..where((t) => t.id.equals(id))).go(),
    );
  }

  Future<void> _deduplicateTable<T>({
    required Future<List<T>> Function() query,
    required String Function(T) getServerId,
    required int Function(T) getLocalId,
    required Future<void> Function(int localId) onDelete,
  }) async {
    try {
      final rows = await query();
      final seen = <String>{};
      for (final row in rows) {
        final sid = getServerId(row);
        if (!seen.add(sid)) {
          await onDelete(getLocalId(row));
          _logger.i(
            'Dedup: removed duplicate local ${getLocalId(row)} (serverId $sid)',
          );
        }
      }
    } catch (e) {
      _logger.w('_deduplicateTable failed: $e');
    }
  }

  /// For every synced entity type, fetches the current server list and resets
  /// any local record whose serverId is no longer present on the server.
  /// This handles the case where records were manually deleted from the server.
  Future<void> _reconcileAll() async {
    // All reconcile fetches are independent GETs — run them in parallel.
    await Future.wait([
      _reconcileTable<ExerciseTableData>(
        endpoint: 'api/Exercise/UserExercise',
        localQuery: () async {
          final all =
              await (_db.select(_db.exerciseTable)
                ..where((t) => t.serverId.isNotNull())).get();
          return all.where((e) => e.isCustom).toList();
        },
        getServerId: (r) => r.serverId!,
        getLocalId: (r) => r.id,
        resetRow:
            (id) => (_db.update(_db.exerciseTable)
              ..where((t) => t.id.equals(id))).write(
              const ExerciseTableCompanion(
                serverId: Value(null),
                syncStatus: Value(0),
              ),
            ),
      ),
      _reconcileTable<WorkoutTableData>(
        endpoint: 'api/Workout',
        localQuery:
            () =>
                (_db.select(_db.workoutTable)
                  ..where((t) => t.serverId.isNotNull())).get(),
        getServerId: (r) => r.serverId!,
        getLocalId: (r) => r.id,
        resetRow: (id) async {
          await (_db.update(_db.workoutTable)
            ..where((t) => t.id.equals(id))).write(
            const WorkoutTableCompanion(
              serverId: Value(null),
              syncStatus: Value(0),
            ),
          );
          final exercises =
              await (_db.select(_db.workoutExerciseTable)
                ..where((e) => e.workoutId.equals(id))).get();
          for (final ex in exercises) {
            await (_db.update(_db.workoutExerciseTable)
              ..where((t) => t.id.equals(ex.id))).write(
              const WorkoutExerciseTableCompanion(
                serverId: Value(null),
                syncStatus: Value(0),
              ),
            );
            await (_db.update(_db.workoutSetTemplateTable)
              ..where((t) => t.workoutExerciseId.equals(ex.id))).write(
              const WorkoutSetTemplateTableCompanion(
                serverId: Value(null),
                syncStatus: Value(0),
              ),
            );
          }
        },
      ),
      _reconcileTable<WorkoutPlanTableData>(
        endpoint: 'api/WorkoutPlan',
        localQuery:
            () =>
                (_db.select(_db.workoutPlanTable)
                  ..where((t) => t.serverId.isNotNull())).get(),
        getServerId: (r) => r.serverId!,
        getLocalId: (r) => r.id,
        resetRow: (id) async {
          await (_db.update(_db.workoutPlanTable)
            ..where((t) => t.id.equals(id))).write(
            const WorkoutPlanTableCompanion(
              serverId: Value(null),
              syncStatus: Value(0),
            ),
          );
          await (_db.update(_db.workoutPlanWorkoutTable)
            ..where((t) => t.planId.equals(id))).write(
            const WorkoutPlanWorkoutTableCompanion(syncStatus: Value(0)),
          );
        },
      ),
      _reconcileTable<ScheduledWorkoutTableData>(
        endpoint: 'api/ScheduledWorkout',
        localQuery:
            () =>
                (_db.select(_db.scheduledWorkoutTable)
                  ..where((t) => t.serverId.isNotNull())).get(),
        getServerId: (r) => r.serverId!,
        getLocalId: (r) => r.id,
        resetRow: (id) async {
          await (_db.update(_db.scheduledWorkoutTable)
            ..where((t) => t.id.equals(id))).write(
            const ScheduledWorkoutTableCompanion(
              serverId: Value(null),
              syncStatus: Value(0),
            ),
          );
          final exercises = await _db.scheduledWorkoutExerciseDao
              .getAllForScheduledWorkout(id);
          for (final ex in exercises) {
            await (_db.update(_db.scheduledWorkoutExerciseTable)
              ..where((t) => t.id.equals(ex.id))).write(
              const ScheduledWorkoutExerciseTableCompanion(
                serverId: Value(null),
                syncStatus: Value(0),
              ),
            );
            final sets = await _db.workoutDao.getSetsForScheduledExercise(
              ex.id,
            );
            for (final s in sets) {
              await (_db.update(_db.workoutSetTable)
                ..where((t) => t.id.equals(s.id))).write(
                const WorkoutSetTableCompanion(
                  serverId: Value(null),
                  syncStatus: Value(0),
                ),
              );
            }
          }
        },
      ),
      _reconcileTable<FoodItemData>(
        endpoint: 'api/FoodItem',
        localQuery:
            () =>
                (_db.select(_db.foodItem)
                  ..where((t) => t.serverId.isNotNull())).get(),
        getServerId: (r) => r.serverId!,
        getLocalId: (r) => r.id,
        resetRow:
            (id) => (_db.update(_db.foodItem)
              ..where((t) => t.id.equals(id))).write(
              const FoodItemCompanion(
                serverId: Value(null),
                syncStatus: Value(0),
              ),
            ),
      ),
      _reconcileTable<MealTableData>(
        endpoint: 'api/Meal/all',
        localQuery:
            () =>
                (_db.select(_db.mealTable)
                  ..where((t) => t.serverId.isNotNull())).get(),
        getServerId: (r) => r.serverId!,
        getLocalId: (r) => r.id,
        resetRow: (id) async {
          await (_db.update(_db.mealTable)
            ..where((t) => t.id.equals(id))).write(
            const MealTableCompanion(
              serverId: Value(null),
              syncStatus: Value(0),
            ),
          );
          await (_db.update(_db.mealFoodTable)..where(
            (t) => t.mealId.equals(id),
          )).write(const MealFoodTableCompanion(serverId: Value(null)));
        },
      ),
      _reconcileTable<WeightRecordData>(
        endpoint: 'api/WeightTracking/TrackWeight',
        localQuery:
            () =>
                (_db.select(_db.weightRecord)
                  ..where((t) => t.serverId.isNotNull())).get(),
        getServerId: (r) => r.serverId!,
        getLocalId: (r) => r.id,
        resetRow:
            (id) => (_db.update(_db.weightRecord)
              ..where((t) => t.id.equals(id))).write(
              const WeightRecordCompanion(
                serverId: Value(null),
                syncStatus: Value(0),
              ),
            ),
      ),
    ]);
  }

  Future<void> _reconcileTable<T>({
    required String endpoint,
    required Future<List<T>> Function() localQuery,
    required String Function(T) getServerId,
    required int Function(T) getLocalId,
    required Future<void> Function(int localId) resetRow,
  }) async {
    try {
      final response = await _apiClient.get(endpoint);
      final list = (response.data as List).cast<Map<String, dynamic>>();
      final serverIds = list.map((e) => e['id'] as String).toSet();
      final locals = await localQuery();
      for (final row in locals) {
        if (serverIds.contains(getServerId(row))) continue;
        await resetRow(getLocalId(row));
        _logger.i(
          'Reconcile $endpoint: reset local ${getLocalId(row)} (server ${getServerId(row)} gone)',
        );
      }
    } catch (e) {
      _logger.w('_reconcileTable($endpoint) failed: $e');
    }
  }

  /// For every synced scheduled workout, ensures local scheduled exercise
  /// serverIds are stamped (by fetching the SW from the server), then pushes
  /// any pending sets.  Never creates duplicate exercises: exercises are
  /// auto-created server-side when the SW is POSTed, so we only need to store
  /// their IDs — not create new ones.
  Future<void> _syncMissingScheduledExerciseSets() async {
    final syncedSws =
        await (_db.select(_db.scheduledWorkoutTable)
          ..where((sw) => sw.serverId.isNotNull())).get();

    _logger.i(
      '_syncMissingScheduledExerciseSets: checking ${syncedSws.length} synced SWs',
    );
    for (final sw in syncedSws) {
      try {
        final localExercises = await _db.scheduledWorkoutExerciseDao
            .getAllForScheduledWorkout(sw.id);
        final missingServerId =
            localExercises.where((e) => e.serverId == null).toList();
        if (missingServerId.isNotEmpty) {
          _logger.w(
            '_syncMissingScheduledExerciseSets: SW ${sw.id} has ${missingServerId.length} exercises with no serverId — fetching from server',
          );
          // Fetch the existing scheduled workout from the server to get the
          // server-assigned exercise IDs.  The server auto-creates exercises
          // when the SW is POSTed, so they should already exist — we must NOT
          // POST again or we will create duplicates.
          final swResponse = await _apiClient.get(
            'api/ScheduledWorkout/${sw.serverId}',
          );
          final serverExercises =
              (swResponse.data['exercises'] as List? ?? [])
                  .cast<Map<String, dynamic>>();

          await _storeScheduledExerciseServerIds(
            sw.id,
            sw.serverId!,
            serverExercises,
          );

          // After stamping from the server, check if any are genuinely absent
          // (e.g. workout template changed after SW was created on server).
          final stillMissing =
              (await _db.scheduledWorkoutExerciseDao.getAllForScheduledWorkout(
                sw.id,
              )).where((e) => e.serverId == null).toList();

          if (stillMissing.isNotEmpty) {
            final weServerIds = <String>[];
            final valid = <ScheduledWorkoutExerciseTableData>[];
            for (final localEx in stillMissing) {
              final weRow =
                  await (_db.select(_db.workoutExerciseTable)..where(
                    (we) => we.id.equals(localEx.workoutExerciseId),
                  )).getSingleOrNull();
              if (weRow?.serverId == null) continue;
              weServerIds.add(weRow!.serverId!);
              valid.add(localEx);
            }
            if (weServerIds.isNotEmpty) {
              final response = await _apiClient.post(
                'api/ScheduledWorkout/${sw.serverId}/exercises/batch',
                data: weServerIds,
              );
              final serverList =
                  (response.data as List).cast<Map<String, dynamic>>();
              for (var i = 0; i < valid.length && i < serverList.length; i++) {
                await _db.scheduledWorkoutExerciseDao
                    .markScheduledExerciseSynced(
                      valid[i].id,
                      serverList[i]['id'] as String,
                    );
              }
            }
          }
        }

        // Push any sets that still have no serverId.
        await _syncSetsForScheduledWorkout(sw.id, sw.serverId!);
      } catch (e) {
        _logger.w(
          '_syncMissingScheduledExerciseSets failed for sw ${sw.id}: $e',
        );
      }
    }
  }

  // ── Food items ────────────────────────────────────────────────────────────

  Future<void> syncFoodItems() async {
    final unsynced = await _db.foodItemDao.getUnsyncedItems();
    if (unsynced.isEmpty) return;

    for (final item in unsynced) {
      try {
        switch (FoodItemSyncStatus.values[item.syncStatus]) {
          case FoodItemSyncStatus.pending:
            await _syncNewFoodItem(item);
          case FoodItemSyncStatus.pendingUpdate:
            await _syncUpdateFoodItem(item);
          case FoodItemSyncStatus.pendingDelete:
            await _syncDeleteFoodItem(item);
          case FoodItemSyncStatus.synced:
            break;
        }
      } catch (e) {
        _logger.w('Food item sync failed for local ${item.id}: $e');
      }
    }
  }

  Future<void> _syncNewFoodItem(FoodItemData item) async {
    final response = await _apiClient.post(
      'api/FoodItem',
      data: {
        'name': item.name,
        'calories': item.calories,
        'protein': item.protein,
        'carbs': item.carbs,
        'fat': item.fat,
        'gramm': item.gramm,
        'hiddenFromRecent': item.hiddenFromRecent,
        'extendedNutrientsJson': item.extendedNutrientsJson,
      },
    );
    final serverId = response.data['id'] as String;
    await _db.foodItemDao.markSynced(localId: item.id, serverId: serverId);
    _logger.i('Synced new food item ${item.id} → server $serverId');
  }

  Future<void> _syncUpdateFoodItem(FoodItemData item) async {
    if (item.serverId == null) {
      await _syncNewFoodItem(item);
      return;
    }
    await _apiClient.put(
      'api/FoodItem/${item.serverId}',
      data: {
        'name': item.name,
        'calories': item.calories,
        'protein': item.protein,
        'carbs': item.carbs,
        'fat': item.fat,
        'gramm': item.gramm,
        'hiddenFromRecent': item.hiddenFromRecent,
        'extendedNutrientsJson': item.extendedNutrientsJson,
      },
    );
    await _db.foodItemDao.markSynced(
      localId: item.id,
      serverId: item.serverId!,
    );
    _logger.i('Updated food item ${item.id} on server ${item.serverId}');
  }

  Future<void> _syncDeleteFoodItem(FoodItemData item) async {
    if (item.serverId == null) {
      await _db.foodItemDao.deleteById(item.id);
      return;
    }
    await _apiClient.delete('api/FoodItem/${item.serverId}');
    await _db.foodItemDao.deleteById(item.id);
    _logger.i('Deleted food item ${item.id} from server ${item.serverId}');
  }

  // ── Meals ─────────────────────────────────────────────────────────────────

  Future<void> syncMeals() async {
    // Removals first, and unconditionally: a meal can have nothing else pending
    // and still owe the server a deletion, and pushing a re-added food before
    // the removal that preceded it would delete the wrong one.
    await _syncMealFoodDeletions();

    final unsynced = await _db.mealDao.getUnsyncedMeals();
    if (unsynced.isEmpty) return;

    for (final meal in unsynced) {
      try {
        switch (MealSyncStatus.values[meal.syncStatus]) {
          case MealSyncStatus.pending:
            await _syncNewMeal(meal);
          case MealSyncStatus.pendingUpdate:
            await _syncUpdateMeal(meal);
          case MealSyncStatus.pendingDelete:
            await _syncDeleteMeal(meal);
          case MealSyncStatus.synced:
            break;
        }
      } catch (e) {
        _logger.w('Meal sync failed for local ${meal.id}: $e');
      }
    }
  }

  Future<void> _syncNewMeal(MealTableData meal) async {
    // Resolve the primary food item's server ID.
    final primaryFood = await _db.foodItemDao.getFoodItemById(meal.foodItemId);
    final primaryServerId = primaryFood?.serverId;

    final response = await _apiClient.post(
      'api/Meal',
      data: {
        'date': meal.date.toUtc().toIso8601String(),
        'category': meal.category,
        'foodItemId': primaryServerId ?? '00000000-0000-0000-0000-000000000000',
      },
    );
    final mealServerId = response.data['id'] as String;
    await _db.mealDao.markMealSynced(localId: meal.id, serverId: mealServerId);

    // The response is not necessarily an empty meal: creating is idempotent
    // server-side, so a meal this device has pushed before comes back with the
    // food it already holds. Reconcile against it rather than appending.
    await _pushMealFoodEntries(meal.id, mealServerId, response.data);
    _logger.i('Synced new meal ${meal.id} → server $mealServerId');
  }

  Future<void> _syncUpdateMeal(MealTableData meal) async {
    if (meal.serverId == null) {
      await _syncNewMeal(meal);
      return;
    }
    final primaryFood = await _db.foodItemDao.getFoodItemById(meal.foodItemId);
    final response = await _apiClient.put(
      'api/Meal/${meal.serverId}',
      data: {
        'date': meal.date.toUtc().toIso8601String(),
        'category': meal.category,
        'foodItemId':
            primaryFood?.serverId ?? '00000000-0000-0000-0000-000000000000',
      },
    );
    await _db.mealDao.markMealSynced(
      localId: meal.id,
      serverId: meal.serverId!,
    );

    // This is the path a food added to an already-pushed meal travels, so the
    // meal on the server nearly always holds entries already.
    await _pushMealFoodEntries(meal.id, meal.serverId!, response.data);
    _logger.i('Updated meal ${meal.id} on server ${meal.serverId}');
  }

  /// Brings the server's copy of one meal's food entries up to date with this
  /// device's, given what the server said it holds ([serverMeal] is a meal
  /// response body). Entries the server already has are adopted rather than
  /// re-sent — see [planMealEntryPush] for why that matters.
  Future<void> _pushMealFoodEntries(
    int localMealId,
    String mealServerId,
    dynamic serverMeal,
  ) async {
    final localRows = await _db.mealDao.getAllFoodEntriesForMeal(localMealId);
    final local = <LocalFoodEntry>[];
    final foodServerIdByEntry = <int, String>{};
    for (final row in localRows) {
      final food = await _db.foodItemDao.getFoodItemById(row.foodEntryId);
      final foodServerId = food?.serverId;
      if (foodServerId != null) foodServerIdByEntry[row.id] = foodServerId;
      local.add(
        LocalFoodEntry(
          id: row.id,
          serverId: row.serverId,
          foodServerId: foodServerId,
        ),
      );
    }

    final serverEntries =
        ((serverMeal is Map ? serverMeal['foodEntries'] : null) as List? ??
                const [])
            .whereType<Map>()
            .map(
              (e) => ServerFoodEntry(
                id: e['id'] as String,
                foodItemId: e['foodItemId'] as String,
              ),
            )
            .toList();

    final plan = planMealEntryPush(local: local, server: serverEntries);

    for (final adopted in plan.adopt.entries) {
      await _db.mealDao.setFoodEntryServerId(adopted.key, adopted.value);
    }
    if (plan.adopt.isNotEmpty) {
      _logger.i(
        'Meal $mealServerId: adopted ${plan.adopt.length} entries the server already had',
      );
    }
    if (plan.push.isEmpty) return;

    final response = await _apiClient.post(
      'api/Meal/$mealServerId/foods/batch',
      data: [for (final id in plan.push) foodServerIdByEntry[id]!],
    );
    final created = (response.data as List).cast<Map<String, dynamic>>();
    for (var i = 0; i < plan.push.length && i < created.length; i++) {
      await _db.mealDao.setFoodEntryServerId(
        plan.push[i],
        created[i]['id'] as String,
      );
    }
  }

  /// Pushes food removals that outlived their local rows. A 404 is success:
  /// the entry being gone is exactly what the queued row was asking for.
  Future<void> _syncMealFoodDeletions() async {
    final pending = await _db.mealDao.getPendingFoodEntryDeletions();
    if (pending.isEmpty) return;

    for (final deletion in pending) {
      try {
        await _apiClient.delete(
          'api/Meal/${deletion.mealServerId}/foods/${deletion.foodItemServerId}',
        );
        await _db.mealDao.clearFoodEntryDeletion(deletion.id);
        _logger.i(
          'Deleted food ${deletion.foodItemServerId} from meal ${deletion.mealServerId}',
        );
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) {
          await _db.mealDao.clearFoodEntryDeletion(deletion.id);
          continue;
        }
        _logger.w('Meal food deletion failed for ${deletion.id}: $e');
      } catch (e) {
        _logger.w('Meal food deletion failed for ${deletion.id}: $e');
      }
    }
  }

  Future<void> _syncDeleteMeal(MealTableData meal) async {
    if (meal.serverId == null) {
      await ((_db.delete(_db.mealTable))
        ..where((t) => t.id.equals(meal.id))).go();
      return;
    }
    await _apiClient.delete('api/Meal/${meal.serverId}');
    await ((_db.delete(_db.mealTable))
      ..where((t) => t.id.equals(meal.id))).go();
    _logger.i('Deleted meal ${meal.id} from server ${meal.serverId}');
  }

  // ── Meal templates ────────────────────────────────────────────────────────

  Future<void> syncMealTemplates() async {
    final unsynced = await _mealTemplateDao.getUnsyncedTemplates();
    if (unsynced.isEmpty) return;

    for (final template in unsynced) {
      try {
        await _syncNewMealTemplate(template);
      } catch (e) {
        _logger.w('Meal template sync failed for local ${template['id']}: $e');
      }
    }
  }

  Future<void> _syncNewMealTemplate(Map<String, dynamic> template) async {
    final items =
        (template['items'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();

    final response = await _apiClient.post(
      'api/MealTemplate',
      data: {
        'name': template['name'],
        'description': template['description'] ?? '',
        'category': template['category'],
        'totalWeightGrams':
            (template['total_weight_grams'] as num?)?.toDouble(),
        'items':
            items
                .map(
                  (i) => {
                    'foodId':
                        '00000000-0000-0000-0000-000000000000', // no FK enforced
                    'foodName': i['foodName'] ?? i['food_name'] ?? '',
                    'quantity': (i['quantity'] as num?)?.toDouble() ?? 0.0,
                    'unit': i['unit'] ?? 'g',
                    'calories': (i['calories'] as num?)?.toDouble() ?? 0.0,
                    'protein': (i['protein'] as num?)?.toDouble() ?? 0.0,
                    'carbs': (i['carbs'] as num?)?.toDouble() ?? 0.0,
                    'fat': (i['fat'] as num?)?.toDouble() ?? 0.0,
                  },
                )
                .toList(),
      },
    );
    final serverId = response.data['id'] as String;
    await _mealTemplateDao.markTemplateSynced(template['id'] as int, serverId);
    _logger.i('Synced meal template ${template['id']} → server $serverId');
  }

  // ── User settings ─────────────────────────────────────────────────────────

  Future<void> syncUserSettings() async {
    final settings = await _db.userSettingsDao.getSettings();
    if (settings == null) return;

    try {
      await _apiClient.put(
        'api/UserSettings',
        data: {
          'dailyCalorieGoal': settings.dailyCalorieGoal,
          'themeMode': settings.themeMode,
          'name': settings.name,
          'age': settings.age,
          'heightCm': settings.heightCm,
          'sex': settings.sex,
          'activityLevel': settings.activityLevel,
          'goalType': settings.goalType,
          'startingWeight': settings.startingWeight,
          'goalWeight': settings.goalWeight,
        },
      );
      _logger.i('Synced user settings');
    } catch (e) {
      _logger.w('User settings sync failed: $e');
    }
  }

  // ── Weight logs ───────────────────────────────────────────────────────────

  Future<void> syncWeightLogs() async {
    final unsynced = await _db.weightRecordDao.getUnsyncedRecords();
    if (unsynced.isEmpty) return;

    for (final record in unsynced) {
      try {
        switch (WeightSyncStatus.values[record.syncStatus]) {
          case WeightSyncStatus.pending:
            await _syncNewWeight(record);
          case WeightSyncStatus.pendingUpdate:
            await _syncUpdateWeight(record);
          case WeightSyncStatus.pendingDelete:
            await _syncDeleteWeight(record);
          case WeightSyncStatus.synced:
            break;
        }
      } catch (e) {
        _logger.w('Weight sync failed for local ${record.id}: $e');
      }
    }
  }

  Future<void> _syncNewWeight(WeightRecordData record) async {
    final response = await _apiClient.post(
      'api/WeightTracking/TrackWeight',
      data: {
        'date': record.date.toIso8601String(),
        'weight': record.weight,
        'note': record.note,
      },
    );
    final serverId = response.data['id'] as String;
    await _db.weightRecordDao.markSynced(
      localId: record.id,
      serverId: serverId,
    );
    _logger.i('Synced new weight record ${record.id} → server $serverId');
  }

  Future<void> _syncUpdateWeight(WeightRecordData record) async {
    if (record.serverId == null) {
      await _syncNewWeight(record);
      return;
    }
    await _apiClient.put(
      'api/WeightTracking/TrackWeight/${record.serverId}',
      data: {
        'date': record.date.toIso8601String(),
        'weight': record.weight,
        'note': record.note,
      },
    );
    await _db.weightRecordDao.markSynced(
      localId: record.id,
      serverId: record.serverId!,
    );
    _logger.i(
      'Updated weight record ${record.id} on server ${record.serverId}',
    );
  }

  Future<void> _syncDeleteWeight(WeightRecordData record) async {
    if (record.serverId == null) {
      await _db.weightRecordDao.deleteWeightRecord(record.id);
      return;
    }
    await _apiClient.delete(
      'api/WeightTracking/TrackWeight/${record.serverId}',
    );
    await _db.weightRecordDao.deleteWeightRecord(record.id);
    _logger.i(
      'Deleted weight record ${record.id} from server ${record.serverId}',
    );
  }

  // ── Pull (server → local) ─────────────────────────────────────────────────

  /// Downloads all server data and inserts any records not yet present locally.
  /// Safe to run on a fresh install or after switching devices.
  Future<void> pullAll() async {
    await _syncSystemExerciseIds(); // must run first so workout exercise lookups work
    await _pullUserSettings();
    await _pullCustomExercises();
    await _pullWorkouts();
    await _pullWorkoutPlans();
    await _pullScheduledWorkouts();
    // Second pass: re-link any scheduled exercises that were skipped because
    // the workout exercise wasn't created yet on the first pass.
    await _relinkMissingScheduledExercises();
    await _pullFoodItems();
    await _pullMeals(); // food items must exist before meals
    await _pullWeightLogs();
    await _pullMealTemplates();
    // Clean up any content-based duplicates the pull may have created.
    await _deduplicateScheduledWorkoutsByContent();
    await _deduplicateMealsByContent();
  }

  Future<void> _pullUserSettings() async {
    try {
      final response = await _apiClient.get('api/UserSettings');
      final data = response.data as Map<String, dynamic>?;
      if (data == null) return;
      final existing = await _db.userSettingsDao.getSettings();
      if (existing != null)
        return; // already populated, let syncUserSettings handle updates
      await _db.userSettingsDao.updateProfile(
        name: data['name'] as String?,
        age: data['age'] as int?,
        heightCm: data['heightCm'] as int?,
        sex: data['sex'] as String?,
        activityLevel: data['activityLevel'] as int?,
        goalType: data['goalType'] as int?,
        startingWeight: (data['startingWeight'] as num?)?.toDouble(),
        goalWeight: (data['goalWeight'] as num?)?.toDouble(),
      );
      final calorieGoal = data['dailyCalorieGoal'] as int?;
      if (calorieGoal != null) {
        await _db.userSettingsDao.setCalorieGoal(calorieGoal);
      }
      _logger.i('Pulled user settings from server');
    } catch (e) {
      _logger.w('_pullUserSettings failed: $e');
    }
  }

  /// Re-fetches each synced scheduled workout from the server and stores
  /// exercise serverIds for any local scheduled exercise that still has none.
  /// This fixes the case where `_pullWorkouts` skipped some workout exercises
  /// (missing exercise serverId), so `_pullScheduledWorkouts` couldn't link them.
  Future<void> _relinkMissingScheduledExercises() async {
    final syncedSws =
        await (_db.select(_db.scheduledWorkoutTable)
          ..where((sw) => sw.serverId.isNotNull())).get();

    for (final sw in syncedSws) {
      try {
        final exercises = await _db.scheduledWorkoutExerciseDao
            .getAllForScheduledWorkout(sw.id);
        if (exercises.any((e) => e.serverId == null)) {
          final response = await _apiClient.get(
            'api/ScheduledWorkout/${sw.serverId}',
          );
          final serverExercises =
              (response.data['exercises'] as List? ?? [])
                  .cast<Map<String, dynamic>>();
          await _storeScheduledExerciseServerIds(
            sw.id,
            sw.serverId!,
            serverExercises,
          );
        }
      } catch (e) {
        _logger.w(
          '_relinkMissingScheduledExercises failed for sw ${sw.id}: $e',
        );
      }
    }
  }

  /// Fetches all system (non-custom) exercises from the server and stores their
  /// server Guid as `serverId` on matching local exercises (matched by name).
  /// This is required before pulling workouts, since workout exercises reference
  /// exercises by their server Guid.
  Future<void> _syncSystemExerciseIds() async {
    final response = await _apiClient.get('api/Exercise/AllExercises');
    final list = (response.data as List).cast<Map<String, dynamic>>();
    for (final e in list) {
      if (e['isCustom'] == true) continue;
      final serverId = e['id'] as String;
      final name = e['name'] as String;

      // Already in local DB with serverId — nothing to do.
      if (await _db.exerciseDao.getExerciseByServerId(serverId) != null)
        continue;

      // Try to match an existing local exercise and stamp its serverId.
      // Priority: exact English name → exact German name → single unambiguous
      // candidate from search results (avoids creating orphaned duplicate rows).
      final nameDe = e['nameDe'] as String?;
      final localsEn = await _db.exerciseDao.searchExercises(name);
      final unsyncedLocals = localsEn.where((l) => l.serverId == null && !l.isCustom).toList();

      ExerciseTableData? match = unsyncedLocals
          .where((l) => l.name.toLowerCase() == name.toLowerCase())
          .firstOrNull;

      if (match == null && nameDe != null && nameDe.isNotEmpty) {
        final localsDe = await _db.exerciseDao.searchExercises(nameDe);
        match = localsDe
            .where((l) => l.serverId == null && !l.isCustom && l.name.toLowerCase() == nameDe.toLowerCase())
            .firstOrNull;
        if (match != null) {
          _logger.i('_syncSystemExerciseIds: matched "${match.name}" to server "$name" via nameDe');
        }
      }

      // Last resort: if the search returned exactly one unsynced system exercise,
      // it is almost certainly the same exercise with a slightly different name.
      // Stamp it rather than creating a duplicate orphan row.
      if (match == null && unsyncedLocals.length == 1) {
        match = unsyncedLocals.first;
        _logger.w('_syncSystemExerciseIds: fuzzy-matched "${match.name}" to server "$name" (only candidate)');
      }

      if (match != null) {
        await _db.exerciseDao.markExerciseSynced(match.id, serverId);
      } else {
        // No local match (e.g. fresh install, seed hasn't run yet) — create
        // from server data so workout exercise links can be resolved immediately.
        await _db.exerciseDao.saveExercise(
          ExerciseTableCompanion(
            name: Value(name),
            description: Value(e['description'] as String?),
            nameDe: Value(e['nameDe'] as String?),
            descriptionDe: Value(e['descriptionDe'] as String?),
            type: Value(e['type'] as int? ?? 0),
            targetMuscleGroups: Value(e['targetMuscleGroups'] as String? ?? ''),
            imageUrl: Value(e['imageUrl'] as String?),
            isCustom: const Value(false),
            serverId: Value(serverId),
            syncStatus: const Value(1),
          ),
        );
      }
    }
  }

  Future<void> _pullCustomExercises() async {
    final response = await _apiClient.get('api/Exercise/UserExercise');
    final list = (response.data as List).cast<Map<String, dynamic>>();
    for (final e in list) {
      final serverId = e['id'] as String;
      if (await _db.exerciseDao.getExerciseByServerId(serverId) != null)
        continue;
      await _db.exerciseDao.saveExercise(
        ExerciseTableCompanion(
          name: Value(e['name'] as String),
          description: Value(e['description'] as String?),
          nameDe: Value(e['nameDe'] as String?),
          descriptionDe: Value(e['descriptionDe'] as String?),
          type: Value(e['type'] as int),
          targetMuscleGroups: Value(e['targetMuscleGroups'] as String? ?? ''),
          imageUrl: Value(e['imageUrl'] as String?),
          isCustom: const Value(true),
          serverId: Value(serverId),
          syncStatus: const Value(1),
        ),
      );
      _logger.i('Pulled exercise $serverId');
    }
  }

  Future<void> _pullWorkouts() async {
    final response = await _apiClient.get('api/Workout');
    final list = (response.data as List).cast<Map<String, dynamic>>();
    for (final w in list) {
      final workoutServerId = w['id'] as String;
      if (await _db.workoutDao.getWorkoutByServerId(workoutServerId) != null)
        continue;

      // Guard: if a local workout with the same name exists but no serverId
      // (reconcile cleared it), stamp its serverId instead of inserting a new
      // row — this prevents duplicate workouts after a server wipe-and-resync.
      final nameMatch =
          await (_db.select(_db.workoutTable)
                ..where(
                  (t) =>
                      t.serverId.isNull() & t.name.equals(w['name'] as String),
                )
                ..limit(1))
              .getSingleOrNull();

      late int localWorkoutId;
      if (nameMatch != null) {
        localWorkoutId = nameMatch.id;
        await (_db.update(_db.workoutTable)
          ..where((t) => t.id.equals(localWorkoutId))).write(
          WorkoutTableCompanion(
            serverId: Value(workoutServerId),
            syncStatus: const Value(1),
          ),
        );
        _logger.i(
          'Re-linked existing workout $localWorkoutId to server $workoutServerId',
        );
      } else {
        localWorkoutId = await _db
            .into(_db.workoutTable)
            .insert(
              WorkoutTableCompanion(
                name: Value(w['name'] as String),
                description: Value(w['description'] as String?),
                difficulty: Value(w['difficulty'] as int),
                estimatedDurationMinutes: Value(
                  w['estimatedDurationMinutes'] as int? ?? 30,
                ),
                isTemplate: Value(w['isTemplate'] as bool),
                scheduledDate: Value(
                  w['scheduledDate'] != null
                      ? DateTime.parse(w['scheduledDate'] as String)
                      : null,
                ),
                completedDate: Value(
                  w['completedDate'] != null
                      ? DateTime.parse(w['completedDate'] as String)
                      : null,
                ),
                color: Value(w['color'] as int?),
                serverId: Value(workoutServerId),
                syncStatus: const Value(1),
              ),
            );
      }

      final exercises = (w['exercises'] as List).cast<Map<String, dynamic>>();
      for (final ex in exercises) {
        final exServerId = ex['id'] as String;
        // A retired exercise is still returned so that logged sessions can resolve
        // what was performed, but it is no longer part of the workout — pulling it
        // back in would put an exercise the user deleted back into their plan.
        if (ex['removedAt'] != null) continue;
        if (await _db.workoutDao.getWorkoutExerciseByServerId(exServerId) !=
            null)
          continue;
        final localExercise = await _db.exerciseDao.getExerciseByServerId(
          ex['exerciseId'] as String,
        );
        if (localExercise == null) {
          _logger.w(
            'Pull workout $workoutServerId: skipping exercise — no local match for exercise server ID ${ex['exerciseId']}',
          );
          continue;
        }

        // When re-using an existing workout, stamp existing unsynced exercises
        // rather than inserting new ones.
        int localWeId;
        if (nameMatch != null) {
          final weMatch =
              await (_db.select(_db.workoutExerciseTable)
                    ..where(
                      (t) =>
                          t.workoutId.equals(localWorkoutId) &
                          t.exerciseId.equals(localExercise.id) &
                          t.serverId.isNull(),
                    )
                    ..limit(1))
                  .getSingleOrNull();
          if (weMatch != null) {
            localWeId = weMatch.id;
            await (_db.update(_db.workoutExerciseTable)
              ..where((t) => t.id.equals(localWeId))).write(
              WorkoutExerciseTableCompanion(
                serverId: Value(exServerId),
                syncStatus: const Value(1),
              ),
            );
          } else {
            localWeId = await _db
                .into(_db.workoutExerciseTable)
                .insert(
                  WorkoutExerciseTableCompanion(
                    workoutId: Value(localWorkoutId),
                    exerciseId: Value(localExercise.id),
                    orderPosition: Value(ex['orderPosition'] as int),
                    notes: Value(ex['notes'] as String?),
                    supersetGroupId: Value(ex['supersetGroupId'] as int?),
                    serverId: Value(exServerId),
                    syncStatus: const Value(1),
                  ),
                );
          }
        } else {
          localWeId = await _db
              .into(_db.workoutExerciseTable)
              .insert(
                WorkoutExerciseTableCompanion(
                  workoutId: Value(localWorkoutId),
                  exerciseId: Value(localExercise.id),
                  orderPosition: Value(ex['orderPosition'] as int),
                  notes: Value(ex['notes'] as String?),
                  supersetGroupId: Value(ex['supersetGroupId'] as int?),
                  serverId: Value(exServerId),
                  syncStatus: const Value(1),
                ),
              );
        }

        for (final st
            in (ex['setTemplates'] as List).cast<Map<String, dynamic>>()) {
          final stServerId = st['id'] as String;
          // Stamp existing unsynced set template if one already exists.
          if (nameMatch != null) {
            final stMatch =
                await (_db.select(_db.workoutSetTemplateTable)
                      ..where(
                        (t) =>
                            t.workoutExerciseId.equals(localWeId) &
                            t.setNumber.equals(st['setNumber'] as int) &
                            t.serverId.isNull(),
                      )
                      ..limit(1))
                    .getSingleOrNull();
            if (stMatch != null) {
              await (_db.update(_db.workoutSetTemplateTable)
                ..where((t) => t.id.equals(stMatch.id))).write(
                WorkoutSetTemplateTableCompanion(
                  serverId: Value(stServerId),
                  syncStatus: const Value(1),
                ),
              );
              continue;
            }
          }
          await _db
              .into(_db.workoutSetTemplateTable)
              .insert(
                WorkoutSetTemplateTableCompanion(
                  workoutExerciseId: Value(localWeId),
                  setNumber: Value(st['setNumber'] as int),
                  targetReps: Value(st['targetReps'] as String),
                  orderPosition: Value(st['orderPosition'] as int),
                  serverId: Value(stServerId),
                  syncStatus: const Value(1),
                ),
              );
        }
      }
      _logger.i('Pulled workout $workoutServerId');
    }
  }

  Future<void> _pullWorkoutPlans() async {
    final response = await _apiClient.get('api/WorkoutPlan');
    final list = (response.data as List).cast<Map<String, dynamic>>();
    for (final p in list) {
      final planServerId = p['id'] as String;
      if (await _db.workoutPlanDao.getPlanByServerId(planServerId) != null)
        continue;
      final localPlanId = await _db
          .into(_db.workoutPlanTable)
          .insert(
            WorkoutPlanTableCompanion(
              name: Value(p['name'] as String),
              description: Value(p['description'] as String?),
              startDate: Value(DateTime.parse(p['startDate'] as String)),
              createdAt: Value(DateTime.parse(p['createdAt'] as String)),
              isActive: Value(p['isActive'] as bool),
              cyclePatternJson: Value(p['cyclePatternJson'] as String),
              isFreeChoice: Value(p['isFreeChoice'] as bool),
              serverId: Value(planServerId),
              syncStatus: const Value(1),
            ),
          );
      final serverDurationDays = p['durationDays'] as int?;
      if (serverDurationDays != null) {
        await _db.customStatement(
          'UPDATE workout_plan_table SET duration_days = ? WHERE id = ?',
          [serverDurationDays, localPlanId],
        );
      }
      for (final workoutServerId in (p['workoutIds'] as List).cast<String>()) {
        final localWorkout = await _db.workoutDao.getWorkoutByServerId(
          workoutServerId,
        );
        if (localWorkout == null) continue;
        await _db
            .into(_db.workoutPlanWorkoutTable)
            .insert(
              WorkoutPlanWorkoutTableCompanion(
                planId: Value(localPlanId),
                workoutId: Value(localWorkout.id),
                syncStatus: const Value(1),
              ),
            );
      }
      _logger.i('Pulled plan $planServerId');
    }
  }

  Future<void> _pullScheduledWorkouts() async {
    final response = await _apiClient.get('api/ScheduledWorkout');
    final list = (response.data as List).cast<Map<String, dynamic>>();
    for (final sw in list) {
      final swServerId = sw['id'] as String;
      final localWorkout = await _db.workoutDao.getWorkoutByServerId(
        sw['workoutId'] as String,
      );
      if (localWorkout == null) continue;

      // Resolve (or create) the local scheduled workout row.
      int localSwId;
      final existingBySid = await _db.scheduledWorkoutDao.getByServerId(
        swServerId,
      );
      if (existingBySid != null) {
        localSwId = existingBySid.id;
        // Always update mutable server-authoritative fields so completions/skips
        // made on other devices are reflected locally.
        if (existingBySid.syncStatus == 1) {
          await (_db.update(_db.scheduledWorkoutTable)
            ..where((t) => t.id.equals(localSwId))).write(
            ScheduledWorkoutTableCompanion(
              isCompleted: Value(sw['isCompleted'] as bool),
              isSkipped: Value(sw['isSkipped'] as bool),
              notes: Value(sw['notes'] as String?),
            ),
          );
        }
      } else {
        // Convert to local time for comparison — locally stored dates use local midnight.
        final scheduledDate =
            DateTime.parse(sw['scheduledDate'] as String).toLocal();
        final dateStart = DateTime(
          scheduledDate.year,
          scheduledDate.month,
          scheduledDate.day,
        );
        final dateEnd = dateStart.add(const Duration(days: 1));
        final existingByContent =
            await (_db.select(_db.scheduledWorkoutTable)
                  ..where(
                    (t) =>
                        t.workoutId.equals(localWorkout.id) &
                        t.scheduledDate.isBiggerOrEqualValue(dateStart) &
                        t.scheduledDate.isSmallerThanValue(dateEnd),
                  )
                  ..limit(1))
                .getSingleOrNull();

        if (existingByContent != null) {
          // If it already has a different serverId, this is a server-side duplicate — skip entirely.
          if (existingByContent.serverId != null &&
              existingByContent.serverId != swServerId)
            continue;
          localSwId = existingByContent.id;
          final companion =
              existingByContent.serverId == null
                  ? ScheduledWorkoutTableCompanion(
                    serverId: Value(swServerId),
                    syncStatus: const Value(1),
                    isCompleted: Value(sw['isCompleted'] as bool),
                    isSkipped: Value(sw['isSkipped'] as bool),
                    notes: Value(sw['notes'] as String?),
                  )
                  : ScheduledWorkoutTableCompanion(
                    isCompleted: Value(sw['isCompleted'] as bool),
                    isSkipped: Value(sw['isSkipped'] as bool),
                    notes: Value(sw['notes'] as String?),
                  );
          await (_db.update(_db.scheduledWorkoutTable)
            ..where((t) => t.id.equals(existingByContent.id))).write(companion);
        } else {
          int? localPlanId;
          if (sw['workoutPlanId'] != null) {
            localPlanId =
                (await _db.workoutPlanDao.getPlanByServerId(
                  sw['workoutPlanId'] as String,
                ))?.id;
          }
          int? localTemplateId;
          if (sw['templateWorkoutId'] != null) {
            localTemplateId =
                (await _db.workoutDao.getWorkoutByServerId(
                  sw['templateWorkoutId'] as String,
                ))?.id;
          }
          localSwId = await _db.scheduledWorkoutDao.scheduleWorkout(
            ScheduledWorkoutTableCompanion(
              workoutId: Value(localWorkout.id),
              scheduledDate: Value(scheduledDate),
              createdAt: Value(DateTime.parse(sw['createdAt'] as String)),
              notes: Value(sw['notes'] as String?),
              isCompleted: Value(sw['isCompleted'] as bool),
              isSkipped: Value(sw['isSkipped'] as bool),
              workoutPlanId: Value(localPlanId),
              templateWorkoutId: Value(localTemplateId),
              serverId: Value(swServerId),
              syncStatus: const Value(1),
            ),
          );
        }
      }

      // Always sync exercises and sets — fill in anything missing locally.
      for (final se in (sw['exercises'] as List).cast<Map<String, dynamic>>()) {
        final seServerId = se['id'] as String;

        final existingSe = await _db.scheduledWorkoutExerciseDao.getByServerId(
          seServerId,
        );
        int localSeId;
        if (existingSe != null) {
          localSeId = existingSe.id;
        } else {
          final localWe = await _db.workoutDao.getWorkoutExerciseByServerId(
            se['workoutExerciseId'] as String,
          );
          if (localWe == null) {
            _logger.w(
              'Pull SW $swServerId: skipping exercise $seServerId — no local workout exercise for ${se['workoutExerciseId']}',
            );
            continue;
          }
          localSeId = await _db
              .into(_db.scheduledWorkoutExerciseTable)
              .insert(
                ScheduledWorkoutExerciseTableCompanion(
                  scheduledWorkoutId: Value(localSwId),
                  workoutExerciseId: Value(localWe.id),
                  isCompleted: Value(se['isCompleted'] as bool),
                  notes: Value(se['notes'] as String?),
                  serverId: Value(seServerId),
                  syncStatus: const Value(1),
                ),
              );
        }

        for (final s in (se['sets'] as List).cast<Map<String, dynamic>>()) {
          final setServerId = s['id'] as String;
          final existingSet =
              await (_db.select(_db.workoutSetTable)
                    ..where((t) => t.serverId.equals(setServerId))
                    ..limit(1))
                  .getSingleOrNull();
          if (existingSet != null) continue;

          // If a local set for the same exercise+setNumber exists without a
          // serverId, stamp it rather than inserting a duplicate row. This
          // prevents double rows when _saveCurrentExercise re-inserts sets
          // after losing their serverIds.
          final unlinkedSet =
              await (_db.select(_db.workoutSetTable)
                    ..where(
                      (t) =>
                          t.scheduledWorkoutExerciseId.equals(localSeId) &
                          t.setNumber.equals(s['setNumber'] as int) &
                          t.serverId.isNull(),
                    )
                    ..limit(1))
                  .getSingleOrNull();
          if (unlinkedSet != null) {
            await (_db.update(_db.workoutSetTable)
              ..where((t) => t.id.equals(unlinkedSet.id))).write(
              WorkoutSetTableCompanion(
                serverId: Value(setServerId),
                syncStatus: const Value(1),
              ),
            );
            continue;
          }

          await _db
              .into(_db.workoutSetTable)
              .insert(
                WorkoutSetTableCompanion(
                  scheduledWorkoutExerciseId: Value(localSeId),
                  setNumber: Value(s['setNumber'] as int),
                  reps: Value(s['reps'] as int?),
                  weight: Value((s['weight'] as num?)?.toDouble()),
                  weightUnit: Value(s['weightUnit'] as String?),
                  durationSeconds: Value(s['durationSeconds'] as int?),
                  isCompleted: Value(s['isCompleted'] as bool),
                  notes: Value(s['notes'] as String?),
                  serverId: Value(setServerId),
                  syncStatus: const Value(1),
                ),
              );
        }
      }
      _logger.i('Pulled scheduled workout $swServerId');
    }
  }

  Future<void> _pullWeightLogs() async {
    final response = await _apiClient.get('api/WeightTracking/TrackWeight');
    final list = (response.data as List).cast<Map<String, dynamic>>();
    for (final w in list) {
      final serverId = w['id'] as String;
      if (await _db.weightRecordDao.getByServerId(serverId) != null) continue;
      await _db.weightRecordDao.addWeightRecord(
        WeightRecordCompanion(
          date: Value(DateTime.parse(w['date'] as String)),
          weight: Value((w['weight'] as num).toDouble()),
          note: Value(w['note'] as String?),
          syncStatus: Value(WeightSyncStatus.synced.index),
          serverId: Value(serverId),
        ),
      );
    }
    _logger.i('Pulled ${list.length} weight records');
  }

  Future<void> _pullFoodItems() async {
    final response = await _apiClient.get('api/FoodItem');
    final list = (response.data as List).cast<Map<String, dynamic>>();
    for (final f in list) {
      final serverId = f['id'] as String;
      if (await _db.foodItemDao.getByServerId(serverId) != null) continue;
      await _db.foodItemDao.insertFoodItem(
        FoodItemCompanion(
          name: Value(f['name'] as String),
          calories: Value(f['calories'] as int),
          protein: Value(f['protein'] as int),
          carbs: Value(f['carbs'] as int),
          fat: Value(f['fat'] as int),
          gramm: Value(f['gramm'] as int? ?? 100),
          hiddenFromRecent: Value(f['hiddenFromRecent'] as bool? ?? false),
          extendedNutrientsJson: Value(f['extendedNutrientsJson'] as String?),
          serverId: Value(serverId),
          syncStatus: const Value(1),
        ),
      );
    }
    _logger.i('Pulled ${list.length} food items');
  }

  Future<void> _pullMeals() async {
    final response = await _apiClient.get('api/Meal/all');
    final list = (response.data as List).cast<Map<String, dynamic>>();
    for (final m in list) {
      final mealServerId = m['id'] as String;
      final localFood = await _db.foodItemDao.getByServerId(
        m['foodItemId'] as String,
      );
      if (localFood == null) continue;

      // Check by serverId first (already synced).
      var existing = await _db.mealDao.getByServerId(mealServerId);

      // If not found by serverId, look for a locally-created meal with same date+category
      // that hasn't been linked to the server yet — adopt it rather than duplicating.
      if (existing == null) {
        final serverDate = _toLocalMidnight(
          DateTime.parse(m['date'] as String),
        );
        final unlinked = await _db.mealDao.getMealByDateAndCategory(
          serverDate,
          m['category'] as String,
        );
        if (unlinked != null && unlinked.serverId == null) {
          await _db.mealDao.markMealSynced(
            localId: unlinked.id,
            serverId: mealServerId,
          );
          existing = await _db.mealDao.getMealById(unlinked.id);
        }
      }

      final int localMealId;
      if (existing == null) {
        final serverDate = _toLocalMidnight(
          DateTime.parse(m['date'] as String),
        );
        localMealId = await _db.mealDao.insertMeal(
          MealTableCompanion(
            date: Value(serverDate),
            category: Value(m['category'] as String),
            foodItemId: Value(localFood.id),
            serverId: Value(mealServerId),
            syncStatus: const Value(1),
          ),
        );
      } else {
        localMealId = existing.id;
      }

      // Removals this device has made but not yet pushed: the server still
      // lists that food, and without this the pull puts back what the user
      // deleted (one occurrence per queued deletion, so a second portion the
      // user kept survives).
      final awaitingDeletion = await _db.mealDao
          .pendingFoodEntryDeletionsForMeal(mealServerId);

      for (final entry
          in (m['foodEntries'] as List).cast<Map<String, dynamic>>()) {
        final entryServerId = entry['id'] as String;
        if (awaitingDeletion.remove(entry['foodItemId'] as String)) continue;
        if (await _db.mealDao.getFoodEntryByServerId(entryServerId) != null)
          continue;
        final entryFood = await _db.foodItemDao.getByServerId(
          entry['foodItemId'] as String,
        );
        if (entryFood == null) continue;
        // Skip if this food item is already in the meal (locally added, no serverId yet).
        final existingEntries = await _db.mealDao.getFoodItemsForMeal(
          localMealId,
        );
        if (existingEntries.any((e) => e.foodEntryId == entryFood.id)) {
          // Just stamp the serverId on the existing entry.
          final match = existingEntries.firstWhere(
            (e) => e.foodEntryId == entryFood.id,
          );
          await _db.mealDao.setFoodEntryServerId(match.id, entryServerId);
          continue;
        }
        await _db.mealDao.addFoodToMeal(
          entryFood.id,
          localMealId,
          entryServerId,
        );
      }
    }
    _logger.i('Pulled ${list.length} meals');
  }

  Future<void> _pullMealTemplates() async {
    final response = await _apiClient.get('api/MealTemplate');
    final list = (response.data as List).cast<Map<String, dynamic>>();
    final existing = await _mealTemplateDao.getAllTemplates();
    final existingServerIds =
        existing
            .map((t) => t['serverId'] as String?)
            .whereType<String>()
            .toSet();

    for (final t in list) {
      final serverId = t['id'] as String;
      if (existingServerIds.contains(serverId)) continue;

      final items =
          (t['items'] as List? ?? [])
              .cast<Map<String, dynamic>>()
              .map(
                (i) => {
                  'foodId': 0, // items aren't tied to a live food-catalog row
                  'foodName': i['foodName'] ?? '',
                  'quantity': (i['quantity'] as num?)?.toDouble() ?? 0.0,
                  'unit': i['unit'] ?? 'g',
                  'calories': (i['calories'] as num?)?.toDouble() ?? 0.0,
                  'protein': (i['protein'] as num?)?.toDouble() ?? 0.0,
                  'carbs': (i['carbs'] as num?)?.toDouble() ?? 0.0,
                  'fat': (i['fat'] as num?)?.toDouble() ?? 0.0,
                },
              )
              .toList();

      final localId = await _mealTemplateDao.insertTemplate({
        'name': t['name'],
        'description': t['description'] ?? '',
        'category': t['category'] ?? '',
        if (t['totalWeightGrams'] != null)
          'total_weight_grams': (t['totalWeightGrams'] as num).toDouble(),
        'items': items,
        'serverId': serverId,
      });
      _logger.i('Pulled meal template $serverId → local $localId');
    }
  }

  DateTime _toLocalMidnight(DateTime dt) {
    final local = dt.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  // ── Legacy ────────────────────────────────────────────────────────────────

  @Deprecated('Use syncWeightLogs() or syncAll()')
  Future<void> syncWeightLogsLegacy() => syncWeightLogs();

  @Deprecated('Use syncAll()')
  Future<void> markWeightRecordAsSynced(int localId, String serverId) =>
      _db.weightRecordDao.markSynced(localId: localId, serverId: serverId);
}
