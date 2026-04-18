import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/dao/meal_template_dao.dart';
import 'package:ForgeForm/core/network/api_client.dart';
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
    await syncCustomExercises();
    await syncWorkoutTemplates();
    await syncWorkoutPlans();
    await syncScheduledWorkouts();
    await syncFoodItems();
    await syncMeals();
    await syncMealTemplates();
    await syncUserSettings();
    await syncWeightLogs();
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
    if (e.serverId == null) { await _syncNewExercise(e); return; }
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
        'color': w.color,
      },
    );
    final serverId = response.data['id'] as String;
    await _db.workoutDao.markWorkoutSynced(w.id, serverId);

    // Push exercises for this workout.
    final exercises = await _db.workoutDao.getExercisesForWorkoutRaw(w.id);
    for (final we in exercises) {
      await _syncNewWorkoutExercise(we, serverId);
    }
    _logger.i('Synced new workout ${w.id} → server $serverId');
  }

  Future<void> _syncUpdateWorkout(WorkoutTableData w) async {
    if (w.serverId == null) { await _syncNewWorkout(w); return; }
    await _apiClient.put(
      'api/Workout/${w.serverId}',
      data: {
        'name': w.name,
        'description': w.description,
        'difficulty': w.difficulty,
        'estimatedDurationMinutes': w.estimatedDurationMinutes,
        'isTemplate': w.isTemplate,
        'scheduledDate': w.scheduledDate?.toUtc().toIso8601String(),
        'color': w.color,
      },
    );
    await _db.workoutDao.markWorkoutSynced(w.id, w.serverId!);

    // Sync unsynced exercises for this workout.
    final exercises = await _db.workoutDao.getExercisesForWorkoutRaw(w.id);
    for (final we in exercises.where((e) => e.syncStatus != 1)) {
      if (we.serverId == null) {
        await _syncNewWorkoutExercise(we, w.serverId!);
      } else {
        await _syncUpdateWorkoutExercise(we);
      }
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

  Future<void> _syncNewWorkoutExercise(
    WorkoutExerciseTableData we,
    String workoutServerId,
  ) async {
    // Need the exercise's serverId to reference it on the API.
    final exercise = await _db.exerciseDao.getExerciseById(we.exerciseId);
    if (exercise?.serverId == null) return; // exercise not synced yet

    final response = await _apiClient.post(
      'api/Workout/$workoutServerId/exercises',
      data: {
        'exerciseId': exercise!.serverId,
        'orderPosition': we.orderPosition,
        'notes': we.notes,
        'supersetGroupId': we.supersetGroupId,
      },
    );
    final weServerId = response.data['id'] as String;
    await _db.workoutDao.markWorkoutExerciseSynced(we.id, weServerId);

    // Push set templates.
    final templates = await _db.workoutDao.getSetTemplatesForWorkoutExercise(we.id);
    for (final t in templates.where((t) => t.syncStatus != 1)) {
      await _syncNewSetTemplate(t, weServerId);
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

  Future<void> _syncNewSetTemplate(
    WorkoutSetTemplateData t,
    String workoutExerciseServerId,
  ) async {
    final response = await _apiClient.post(
      'api/Workout/exercises/$workoutExerciseServerId/sets',
      data: {
        'setNumber': t.setNumber,
        'targetReps': t.targetReps,
        'orderPosition': t.orderPosition,
      },
    );
    final serverId = response.data['id'] as String;
    await _db.workoutDao.markSetTemplateSynced(t.id, serverId);
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

  Future<void> _syncNewPlan(WorkoutPlanTableData p) async {
    final response = await _apiClient.post(
      'api/WorkoutPlan',
      data: {
        'name': p.name,
        'description': p.description,
        'startDate': p.startDate.toUtc().toIso8601String(),
        'cyclePatternJson': p.cyclePatternJson,
        'isFreeChoice': p.isFreeChoice,
      },
    );
    final serverId = response.data['id'] as String;
    await _db.workoutPlanDao.markPlanSynced(p.id, serverId);

    // Link workouts to the plan.
    final links = await _db.workoutPlanDao.getPlanWorkoutsForPlan(p.id);
    for (final link in links.where((l) => l.syncStatus != 1)) {
      await _syncNewPlanWorkout(link, serverId);
    }
    _logger.i('Synced new plan ${p.id} → server $serverId');
  }

  Future<void> _syncUpdatePlan(WorkoutPlanTableData p) async {
    if (p.serverId == null) { await _syncNewPlan(p); return; }
    await _apiClient.put(
      'api/WorkoutPlan/${p.serverId}',
      data: {
        'name': p.name,
        'description': p.description,
        'startDate': p.startDate.toUtc().toIso8601String(),
        'cyclePatternJson': p.cyclePatternJson,
        'isFreeChoice': p.isFreeChoice,
      },
    );
    await _db.workoutPlanDao.markPlanSynced(p.id, p.serverId!);

    final links = await _db.workoutPlanDao.getPlanWorkoutsForPlan(p.id);
    for (final link in links.where((l) => l.syncStatus != 1)) {
      await _syncNewPlanWorkout(link, p.serverId!);
    }
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

  Future<void> _syncNewPlanWorkout(
    WorkoutPlanWorkoutTableData link,
    String planServerId,
  ) async {
    final workout = await _db.workoutDao.getWorkoutById(link.workoutId);
    if (workout == null) return;
    final workoutRow = await ((_db.select(_db.workoutTable))
      ..where((w) => w.id.equals(link.workoutId))).getSingleOrNull();
    if (workoutRow?.serverId == null) return; // workout not synced yet

    await _apiClient.post(
      'api/WorkoutPlan/$planServerId/workouts/${workoutRow!.serverId}',
    );
    await _db.workoutPlanDao.markPlanWorkoutSynced(link.id, planServerId);
    _logger.i('Linked workout ${link.workoutId} to plan $planServerId');
  }

  // ── Scheduled workouts ────────────────────────────────────────────────────

  Future<void> syncScheduledWorkouts() async {
    final unsynced = await _db.workoutDao.getUnsyncedScheduledWorkouts();
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
    final workoutRow = await ((_db.select(_db.workoutTable))
      ..where((w) => w.id.equals(sw.workoutId))).getSingleOrNull();
    if (workoutRow?.serverId == null) return; // workout not synced yet

    String? planServerId;
    if (sw.workoutPlanId != null) {
      final planRow = await ((_db.select(_db.workoutPlanTable))
        ..where((p) => p.id.equals(sw.workoutPlanId!))).getSingleOrNull();
      planServerId = planRow?.serverId;
    }

    final response = await _apiClient.post(
      'api/ScheduledWorkout',
      data: {
        'workoutId': workoutRow!.serverId,
        'workoutPlanId': planServerId,
        'scheduledDate': sw.scheduledDate.toUtc().toIso8601String(),
        'notes': sw.notes,
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
    if (sw.serverId == null) { await _syncNewScheduledWorkout(sw); return; }

    final workoutRow = await ((_db.select(_db.workoutTable))
      ..where((w) => w.id.equals(sw.workoutId))).getSingleOrNull();
    if (workoutRow?.serverId == null) return;

    String? planServerId;
    if (sw.workoutPlanId != null) {
      final planRow = await ((_db.select(_db.workoutPlanTable))
        ..where((p) => p.id.equals(sw.workoutPlanId!))).getSingleOrNull();
      planServerId = planRow?.serverId;
    }

    await _apiClient.put(
      'api/ScheduledWorkout/${sw.serverId}',
      data: {
        'workoutId': workoutRow!.serverId,
        'workoutPlanId': planServerId,
        'scheduledDate': sw.scheduledDate.toUtc().toIso8601String(),
        'notes': sw.notes,
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
    final localExercises =
        await _db.scheduledWorkoutExerciseDao.getAllForScheduledWorkout(localSwId);

    for (final localEx in localExercises) {
      // Look up the server UUID of this exercise's workout exercise template.
      final weRow = await ((_db.select(_db.workoutExerciseTable))
        ..where((we) => we.id.equals(localEx.workoutExerciseId))).getSingleOrNull();
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
    final localExercises =
        await _db.scheduledWorkoutExerciseDao.getAllForScheduledWorkout(localSwId);

    for (final localEx in localExercises) {
      if (localEx.serverId == null) continue; // exercise not synced yet
      final sets = await _db.workoutDao.getSetsForScheduledExercise(localEx.id);

      for (final set in sets.where((s) => s.syncStatus != 1)) {
        try {
          if (set.serverId == null) {
            await _syncNewWorkoutSet(set, swServerId, localEx.serverId!);
          } else if (set.syncStatus == 2) {
            await _syncUpdateWorkoutSet(set);
          } else if (set.syncStatus == 3) {
            await _syncDeleteWorkoutSet(set);
          }
        } catch (e) {
          _logger.w('Set sync failed for local ${set.id}: $e');
        }
      }
    }
  }

  Future<void> _syncNewWorkoutSet(
    WorkoutSetTableData s,
    String swServerId,
    String scheduledExerciseServerId,
  ) async {
    final response = await _apiClient.post(
      'api/ScheduledWorkout/$swServerId/exercises/$scheduledExerciseServerId/sets',
      data: {
        'setNumber': s.setNumber,
        'reps': s.reps,
        'weight': s.weight,
        'weightUnit': s.weightUnit,
        'durationSeconds': s.durationSeconds,
        'notes': s.notes,
      },
    );
    final serverId = response.data['id'] as String;
    await _db.workoutDao.markWorkoutSetSynced(s.id, serverId);
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
    await _apiClient.delete('api/ScheduledWorkout/exercises/sets/${s.serverId}');
    await ((_db.delete(_db.workoutSetTable))
      ..where((t) => t.id.equals(s.id))).go();
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
    await _db.foodItemDao.markSynced(localId: item.id, serverId: item.serverId!);
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

    // Push each food entry in the join table.
    final entries = await _db.mealDao.getAllFoodEntriesForMeal(meal.id);
    for (final entry in entries) {
      if (entry.serverId != null) continue; // already pushed
      try {
        final food = await _db.foodItemDao.getFoodItemById(entry.foodEntryId);
        if (food?.serverId == null) continue; // food not synced yet — skip
        final entryResponse = await _apiClient.post(
          'api/Meal/$mealServerId/foods/${food!.serverId}',
        );
        final entryServerId = entryResponse.data['id'] as String;
        await _db.mealDao.setFoodEntryServerId(entry.id, entryServerId);
      } catch (e) {
        _logger.w('Failed to sync food entry ${entry.id} for meal ${meal.id}: $e');
      }
    }
    _logger.i('Synced new meal ${meal.id} → server $mealServerId');
  }

  Future<void> _syncUpdateMeal(MealTableData meal) async {
    if (meal.serverId == null) {
      await _syncNewMeal(meal);
      return;
    }
    final primaryFood = await _db.foodItemDao.getFoodItemById(meal.foodItemId);
    await _apiClient.put(
      'api/Meal/${meal.serverId}',
      data: {
        'date': meal.date.toUtc().toIso8601String(),
        'category': meal.category,
        'foodItemId':
            primaryFood?.serverId ??
            '00000000-0000-0000-0000-000000000000',
      },
    );
    await _db.mealDao.markMealSynced(
      localId: meal.id,
      serverId: meal.serverId!,
    );

    // Push any food entries that haven't been synced yet.
    final entries = await _db.mealDao.getAllFoodEntriesForMeal(meal.id);
    for (final entry in entries) {
      if (entry.serverId != null) continue;
      try {
        final food = await _db.foodItemDao.getFoodItemById(entry.foodEntryId);
        if (food?.serverId == null) continue;
        final entryResponse = await _apiClient.post(
          'api/Meal/${meal.serverId}/foods/${food!.serverId}',
        );
        final entryServerId = entryResponse.data['id'] as String;
        await _db.mealDao.setFoodEntryServerId(entry.id, entryServerId);
      } catch (e) {
        _logger.w('Failed to sync food entry ${entry.id}: $e');
      }
    }
    _logger.i('Updated meal ${meal.id} on server ${meal.serverId}');
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
    final items = (template['items'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    final response = await _apiClient.post(
      'api/MealTemplate',
      data: {
        'name': template['name'],
        'description': template['description'] ?? '',
        'category': template['category'],
        'items': items.map((i) => {
          'foodId': '00000000-0000-0000-0000-000000000000', // no FK enforced
          'foodName': i['foodName'] ?? i['food_name'] ?? '',
          'quantity': (i['quantity'] as num?)?.toDouble() ?? 0.0,
          'unit': i['unit'] ?? 'g',
          'calories': (i['calories'] as num?)?.toDouble() ?? 0.0,
          'protein': (i['protein'] as num?)?.toDouble() ?? 0.0,
          'carbs': (i['carbs'] as num?)?.toDouble() ?? 0.0,
          'fat': (i['fat'] as num?)?.toDouble() ?? 0.0,
        }).toList(),
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
    _logger.i('Updated weight record ${record.id} on server ${record.serverId}');
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

  // ── Legacy ────────────────────────────────────────────────────────────────

  @Deprecated('Use syncWeightLogs() or syncAll()')
  Future<void> syncWeightLogsLegacy() => syncWeightLogs();

  @Deprecated('Use syncAll()')
  Future<void> markWeightRecordAsSynced(int localId, String serverId) =>
      _db.weightRecordDao.markSynced(localId: localId, serverId: serverId);
}
