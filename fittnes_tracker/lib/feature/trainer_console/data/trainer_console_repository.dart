import 'package:dio/dio.dart';
import 'package:ForgeForm/feature/trainer_console/data/trainer_console_api.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/trainer_console_models.dart';

class TrainerConsoleRepository {
  final TrainerConsoleApi _api;

  TrainerConsoleRepository({TrainerConsoleApi? api})
    : _api = api ?? TrainerConsoleApi();

  /// The trainer's active clients with their training stats. The single roster read for
  /// the whole console — the client switcher and the Dashboard both render from it.
  ///
  /// The server already filters to active relationships, so there's no status filter here.
  Future<List<TrainerRosterEntry>> getRosterWithStats() async {
    final raw = await _api.fetchRoster();
    return raw.map(TrainerRosterEntry.fromJson).toList();
  }

  Future<TrainerDashboardKpis> getDashboardKpis() async {
    return TrainerDashboardKpis.fromJson(await _api.fetchDashboardKpis());
  }

  Future<ClientWorkoutSummary> getClientWorkoutSummary(String clientId) async {
    return ClientWorkoutSummary.fromJson(
      await _api.fetchClientWorkoutSummary(clientId),
    );
  }

  Future<List<ClientWeightEntry>> getClientWeightHistory(String clientId) async {
    final raw = await _api.fetchClientWeightHistory(clientId);
    final entries = raw.map(ClientWeightEntry.fromJson).toList();
    // Oldest-first so the chart reads left-to-right; the endpoint doesn't
    // promise an order.
    entries.sort((a, b) => a.date.compareTo(b.date));
    return entries;
  }

  Future<ClientNutritionSummary> getClientNutritionSummary(
    String clientId,
    DateTime date,
  ) async {
    return ClientNutritionSummary.fromJson(
      await _api.fetchClientNutritionSummary(clientId, date),
    );
  }

  Future<void> setClientNutrientPins(String clientId, List<String> nutrientKeys) =>
      _api.setClientNutrientPins(clientId, nutrientKeys);

  Future<List<WorkoutPlanTemplateSummary>> getWorkoutPlanTemplates() async {
    final raw = await _api.fetchWorkoutPlanTemplates();
    return raw.map(WorkoutPlanTemplateSummary.fromJson).toList();
  }

  /// Creates a plan for [clientId].
  ///
  /// Only plan-level metadata crosses the wire — `WorkoutPlanRequestDto` has no
  /// exercises/sets, and there's no trainer-scoped endpoint for a client's
  /// workouts, so the per-exercise editor in the design can't be saved yet.
  Future<WorkoutPlanSummary> createClientWorkoutPlan({
    required String clientId,
    required String name,
    String? description,
    DateTime? startDate,
  }) async {
    final response = await _api.createClientWorkoutPlan(clientId, {
      'name': name,
      'description': description,
      'startDate': (startDate ?? DateTime.now()).toUtc().toIso8601String(),
      'cyclePatternJson': '',
      'isFreeChoice': true,
      'durationDays': null,
    });
    return WorkoutPlanSummary.fromJson(response);
  }

  /// The client's recent sessions, newest first, each already carrying its
  /// full exercise/set detail — status/volume/avgRpe/PR are derived
  /// server-side (see trainer_console_models.dart), so this is a straight
  /// `ClientSessionSummary.fromJson` map with no computation.
  Future<List<ClientSessionSummary>> getClientSessionHistory(
    String clientId, {
    int count = 10,
  }) async {
    final raw = await _api.fetchClientSessionHistory(clientId, count: count);
    return raw.map(ClientSessionSummary.fromJson).toList();
  }

  // ── Workout Builder: create/edit a client's workouts ────────────────────

  Future<List<ClientWorkout>> getClientWorkouts(String clientId) async {
    final raw = await _api.fetchClientWorkouts(clientId);
    return raw.map(ClientWorkout.fromJson).toList();
  }

  /// System exercises, the client's own, and the trainer's own (the last
  /// flagged `isTrainerOwned` — see `ClientExerciseOption`).
  Future<List<ClientExerciseOption>> getClientExerciseLibrary(String clientId) async {
    final raw = await _api.fetchClientExerciseLibrary(clientId);
    return raw.map(ClientExerciseOption.fromJson).toList();
  }

  /// Adds an exercise to the trainer's own library, for use across their
  /// whole roster. Returns it as a [ClientExerciseOption] the picker can drop
  /// straight into its list — freshly created, so always trainer-owned.
  Future<ClientExerciseOption> createTrainerExercise(
    String clientId, {
    required String name,
    String? description,
  }) async {
    final response = await _api.createTrainerExercise(clientId, {
      'name': name,
      'description': description ?? '',
      'type': 0,
      'targetMuscleGroups': '',
      'imageUrl': '',
      'isCustom': true,
      'nameDe': '',
      'descriptionDe': '',
    });
    return ClientExerciseOption(
      id: response['id'] as String,
      name: response['name'] as String? ?? name,
      description: response['description'] as String?,
      isTrainerOwned: true,
    );
  }

  /// Throws a [WorkoutSaveException] when the server declines the write —
  /// the workout has logged history (409) or the prescription names an
  /// exercise the client still can't see (400, which per
  /// `docs/trainer-workout-builder.md` should only happen for a stale
  /// picker selection, since a valid pick is always resolvable).
  Future<ClientWorkout> createClientWorkout(
    String clientId, {
    required String name,
    String? description,
    required int difficulty,
    required int estimatedDurationMinutes,
    String? planId,
    required List<ClientWorkoutExerciseDraft> exercises,
  }) async {
    try {
      final response = await _api.createClientWorkout(
        clientId,
        _workoutRequestBody(
          name: name,
          description: description,
          difficulty: difficulty,
          estimatedDurationMinutes: estimatedDurationMinutes,
          planId: planId,
          exercises: exercises,
        ),
      );
      return ClientWorkout.fromJson(response);
    } on DioException catch (e) {
      throw _asWorkoutSaveException(e);
    }
  }

  /// See [createClientWorkout] for the exceptions this can throw.
  Future<ClientWorkout> updateClientWorkout(
    String clientId,
    String workoutId, {
    required String name,
    String? description,
    required int difficulty,
    required int estimatedDurationMinutes,
    required List<ClientWorkoutExerciseDraft> exercises,
  }) async {
    try {
      final response = await _api.updateClientWorkout(
        clientId,
        workoutId,
        _workoutRequestBody(
          name: name,
          description: description,
          difficulty: difficulty,
          estimatedDurationMinutes: estimatedDurationMinutes,
          planId: null,
          exercises: exercises,
        ),
      );
      return ClientWorkout.fromJson(response);
    } on DioException catch (e) {
      throw _asWorkoutSaveException(e);
    }
  }

  /// Throws [WorkoutSaveException] with [WorkoutSaveFailure.hasLoggedHistory]
  /// when the client has logged sets against this day (409) — it's kept
  /// server-side rather than deleted, per `WorkoutDeleteResult`.
  Future<void> deleteClientWorkout(String clientId, String workoutId) async {
    try {
      await _api.deleteClientWorkout(clientId, workoutId);
    } on DioException catch (e) {
      throw _asWorkoutSaveException(e);
    }
  }

  WorkoutSaveException _asWorkoutSaveException(DioException e) {
    return switch (e.response?.statusCode) {
      409 => const WorkoutSaveException(WorkoutSaveFailure.hasLoggedHistory),
      400 => const WorkoutSaveException(WorkoutSaveFailure.unknownExercise),
      _ => const WorkoutSaveException(WorkoutSaveFailure.other),
    };
  }

  /// Generates dated sessions for [planId] from a weekly cycle of workout
  /// names, mirroring the trainee's own cycle-plan create flow. Additive —
  /// see `docs/trainer-workout-builder.md`. Returns how many sessions were
  /// actually created (0 is a valid, non-error result: every date may
  /// already have been scheduled).
  Future<int> scheduleClientPlan(
    String clientId,
    String planId, {
    required List<String> cyclePattern,
    required int durationWeeks,
  }) {
    return _api.scheduleClientPlan(clientId, planId, {
      'cyclePattern': cyclePattern,
      'durationWeeks': durationWeeks,
    });
  }

  Map<String, dynamic> _workoutRequestBody({
    required String name,
    String? description,
    required int difficulty,
    required int estimatedDurationMinutes,
    String? planId,
    required List<ClientWorkoutExerciseDraft> exercises,
  }) {
    return {
      'name': name,
      'description': description,
      'difficulty': difficulty,
      'estimatedDurationMinutes': estimatedDurationMinutes,
      'planId': planId,
      'exercises': exercises.map((e) => e.toJson()).toList(),
    };
  }
}

/// One exercise's prescription as the builder is about to save it — the
/// request-side counterpart of [ClientWorkoutExercise]. A plain draft rather
/// than reusing the read model because [id] is optional here (null means
/// "new entry") and [targetReps] is edited as a list of strings, not
/// [ClientWorkoutSet] objects.
class ClientWorkoutExerciseDraft {
  final String? id;
  final String exerciseId;
  final String? notes;
  final int? supersetGroupId;
  final List<String> targetReps;

  const ClientWorkoutExerciseDraft({
    this.id,
    required this.exerciseId,
    this.notes,
    this.supersetGroupId,
    required this.targetReps,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'exerciseId': exerciseId,
    'notes': notes,
    'supersetGroupId': supersetGroupId,
    'targetReps': targetReps,
  };
}

/// Why a write to a client's workout was declined by the server. See
/// [TrainerConsoleRepository.createClientWorkout].
enum WorkoutSaveFailure { hasLoggedHistory, unknownExercise, other }

class WorkoutSaveException implements Exception {
  final WorkoutSaveFailure failure;
  const WorkoutSaveException(this.failure);
}
