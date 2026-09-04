import 'dart:async';

import 'package:ForgeForm/core/nutrition/extended_nutrients.dart';
import 'package:ForgeForm/feature/trainer_console/data/trainer_console_repository.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/trainer_console_models.dart';

/// Stands in for the network layer so each screen's states can be driven
/// deterministically. Shared across the console's tests so a repository change
/// only has to be absorbed in one place.
class FakeTrainerConsoleRepository implements TrainerConsoleRepository {
  final List<TrainerRosterEntry> rosterWithStats;
  final List<ClientSessionSummary> sessions;
  final TrainerDashboardKpis? kpis;
  final ClientNutritionSummary? nutrition;
  final ClientWorkoutSummary? workoutSummary;
  final List<ClientWeightEntry> weightHistory;
  final List<WorkoutPlanTemplateSummary> templates;
  final List<ClientWorkout> clientWorkouts;
  final List<ClientExerciseOption> exerciseLibrary;

  /// Set to make the matching call throw, for error-state tests.
  final bool throwOnSessions;
  final bool throwOnDashboard;
  final bool throwOnNutrition;
  final bool throwOnRoster;
  final bool throwOnClientWorkouts;
  final bool throwOnExerciseLibrary;

  /// Set to make the next `createClientWorkout`/`updateClientWorkout` call
  /// throw this instead of succeeding, for the conflict/unknown-exercise
  /// error-state tests.
  final WorkoutSaveException? saveWorkoutFailure;

  /// Completers that hold a fetch open so a test can look at a loading state.
  ///
  /// One per concern, deliberately. [gate] holds a *screen's own* client-scoped data —
  /// sessions, nutrition, workout summary, templates. The roster and the KPIs have their
  /// own, because they are shell-level and load independently of any one screen.
  ///
  /// The roster in particular must not sit behind [gate]: every per-client screen's
  /// `_pump` **awaits** `ActiveClientProvider.loadClients()` before pumping the widget,
  /// since there is nothing to render until an active client exists. A gate covering both
  /// deadlocks those tests — the completer is only completed after `_pump` returns.
  final Completer<void>? gate;
  final Completer<void>? rosterGate;
  final Completer<void>? kpiGate;

  /// How many times each fetch was made, so a test can assert that a section nobody has
  /// opened never fetched, and that revisiting one doesn't re-fetch.
  final Map<String, int> calls = {};

  /// Records what createClientWorkoutPlan was called with.
  final List<({String clientId, String name})> createdPlans = [];

  /// Records every createClientWorkout/updateClientWorkout call, newest last.
  final List<({String clientId, String? workoutId, String name, List<ClientWorkoutExerciseDraft> exercises})>
  savedWorkouts = [];

  final List<String> deletedWorkoutIds = [];

  /// Records what createTrainerExercise was called with.
  final List<({String clientId, String name})> createdExercises = [];

  FakeTrainerConsoleRepository({
    this.rosterWithStats = const [],
    this.sessions = const [],
    this.kpis,
    this.nutrition,
    this.workoutSummary,
    this.weightHistory = const [],
    this.templates = const [],
    List<ClientWorkout> clientWorkouts = const [],
    this.exerciseLibrary = const [],
    this.throwOnSessions = false,
    this.throwOnDashboard = false,
    this.throwOnNutrition = false,
    this.throwOnRoster = false,
    this.throwOnClientWorkouts = false,
    this.throwOnExerciseLibrary = false,
    this.saveWorkoutFailure,
    this.gate,
    this.rosterGate,
    this.kpiGate,
  }) : clientWorkouts = List.of(clientWorkouts);

  void _record(String name) => calls[name] = (calls[name] ?? 0) + 1;

  @override
  Future<List<TrainerRosterEntry>> getRosterWithStats() async {
    _record('roster');
    if (rosterGate != null) await rosterGate!.future;
    if (throwOnRoster) throw Exception('boom');
    return rosterWithStats;
  }

  @override
  Future<TrainerDashboardKpis> getDashboardKpis() async {
    _record('kpis');
    if (kpiGate != null) await kpiGate!.future;
    if (throwOnDashboard) throw Exception('boom');
    return kpis ??
        const TrainerDashboardKpis(
          activeClientCount: 0,
          avgAdherencePercent: 0,
          sessionsThisWeek: 0,
          alertCount: 0,
        );
  }

  @override
  Future<List<ClientSessionSummary>> getClientSessionHistory(
    String clientId, {
    int count = 10,
  }) async {
    _record('sessions');
    if (gate != null) await gate!.future;
    if (throwOnSessions) throw Exception('boom');
    return sessions;
  }

  @override
  Future<ClientNutritionSummary> getClientNutritionSummary(
    String clientId,
    DateTime date,
  ) async {
    _record('nutrition');
    if (gate != null) await gate!.future;
    if (throwOnNutrition) throw Exception('boom');
    if (nutrition == null) throw StateError('no nutrition fixture supplied');
    return nutrition!;
  }

  /// Records every pin-set write, newest last, so a test can assert what was
  /// sent without a real backend.
  final List<({String clientId, List<String> nutrientKeys})> savedNutrientPins = [];

  /// Set to make the next `setClientNutrientPins` call throw, for the
  /// pin-toggle-failure/revert test.
  bool throwOnSetNutrientPins = false;

  @override
  Future<void> setClientNutrientPins(String clientId, List<String> nutrientKeys) async {
    _record('setNutrientPins');
    if (throwOnSetNutrientPins) throw Exception('boom');
    savedNutrientPins.add((clientId: clientId, nutrientKeys: nutrientKeys));
  }

  @override
  Future<ClientWorkoutSummary> getClientWorkoutSummary(String clientId) async {
    _record('workoutSummary');
    if (gate != null) await gate!.future;
    return workoutSummary ??
        const ClientWorkoutSummary(attendance: [], strengthProgression: []);
  }

  @override
  Future<List<ClientWeightEntry>> getClientWeightHistory(String clientId) async =>
      weightHistory;

  @override
  Future<List<WorkoutPlanTemplateSummary>> getWorkoutPlanTemplates() async {
    _record('templates');
    return templates;
  }

  @override
  Future<WorkoutPlanSummary> createClientWorkoutPlan({
    required String clientId,
    required String name,
    String? description,
    DateTime? startDate,
  }) async {
    createdPlans.add((clientId: clientId, name: name));
    return WorkoutPlanSummary(
      id: 'plan-new',
      name: name,
      description: description,
      isActive: true,
      startDate: startDate ?? DateTime(2026, 8, 20),
    );
  }

  @override
  Future<List<ClientWorkout>> getClientWorkouts(String clientId) async {
    _record('clientWorkouts');
    if (gate != null) await gate!.future;
    if (throwOnClientWorkouts) throw Exception('boom');
    return clientWorkouts;
  }

  @override
  Future<List<ClientExerciseOption>> getClientExerciseLibrary(String clientId) async {
    _record('exerciseLibrary');
    if (gate != null) await gate!.future;
    if (throwOnExerciseLibrary) throw Exception('boom');
    return exerciseLibrary;
  }

  @override
  Future<ClientExerciseOption> createTrainerExercise(
    String clientId, {
    required String name,
    String? description,
  }) async {
    createdExercises.add((clientId: clientId, name: name));
    return ClientExerciseOption(
      id: 'exercise-${createdExercises.length}',
      name: name,
      description: description,
      isTrainerOwned: true,
    );
  }

  @override
  Future<ClientWorkout> createClientWorkout(
    String clientId, {
    required String name,
    String? description,
    required int difficulty,
    required int estimatedDurationMinutes,
    String? planId,
    required List<ClientWorkoutExerciseDraft> exercises,
  }) async {
    if (saveWorkoutFailure != null) throw saveWorkoutFailure!;
    savedWorkouts.add((
      clientId: clientId,
      workoutId: null,
      name: name,
      exercises: exercises,
    ));
    final workout = ClientWorkout(
      id: 'workout-${savedWorkouts.length}',
      name: name,
      description: description,
      difficulty: difficulty,
      estimatedDurationMinutes: estimatedDurationMinutes,
      planIds: [if (planId != null) planId],
      exercises: _draftsToExercises(exercises),
    );
    clientWorkouts.add(workout);
    return workout;
  }

  @override
  Future<ClientWorkout> updateClientWorkout(
    String clientId,
    String workoutId, {
    required String name,
    String? description,
    required int difficulty,
    required int estimatedDurationMinutes,
    required List<ClientWorkoutExerciseDraft> exercises,
  }) async {
    if (saveWorkoutFailure != null) throw saveWorkoutFailure!;
    savedWorkouts.add((
      clientId: clientId,
      workoutId: workoutId,
      name: name,
      exercises: exercises,
    ));
    final existing = clientWorkouts.firstWhere((w) => w.id == workoutId);
    final updated = ClientWorkout(
      id: workoutId,
      name: name,
      description: description,
      difficulty: difficulty,
      estimatedDurationMinutes: estimatedDurationMinutes,
      planIds: existing.planIds,
      exercises: _draftsToExercises(exercises),
    );
    clientWorkouts
      ..removeWhere((w) => w.id == workoutId)
      ..add(updated);
    return updated;
  }

  @override
  Future<void> deleteClientWorkout(String clientId, String workoutId) async {
    if (saveWorkoutFailure != null) throw saveWorkoutFailure!;
    deletedWorkoutIds.add(workoutId);
    clientWorkouts.removeWhere((w) => w.id == workoutId);
  }

  @override
  Future<int> scheduleClientPlan(
    String clientId,
    String planId, {
    required List<String> cyclePattern,
    required int durationWeeks,
  }) async => 0;

  List<ClientWorkoutExercise> _draftsToExercises(
    List<ClientWorkoutExerciseDraft> drafts,
  ) {
    var i = 0;
    return drafts
        .map(
          (d) => ClientWorkoutExercise(
            id: d.id ?? 'we-${++i}',
            exerciseId: d.exerciseId,
            exerciseName: exerciseLibrary
                .where((e) => e.id == d.exerciseId)
                .map((e) => e.name)
                .firstOrNull ??
                d.exerciseId,
            notes: d.notes,
            sets: [
              for (var s = 0; s < d.targetReps.length; s++)
                ClientWorkoutSet(
                  id: 'set-$s',
                  setNumber: s + 1,
                  targetReps: d.targetReps[s],
                ),
            ],
          ),
        )
        .toList();
  }

  @override
  noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

TrainerRosterEntry fakeRosterEntry({
  String id = 'client-1',
  String name = 'Robert Meyer',
  String? program = 'Push / Pull / Legs',
  double? adherence = 86,
  DateTime? lastSession,
}) => TrainerRosterEntry(
  clientId: id,
  clientName: name,
  programLabel: program,
  adherencePercent: adherence,
  lastSessionDate: lastSession ?? DateTime(2026, 8, 17),
);

ClientSessionSummary fakeSession({
  String id = 'sess-1',
  String name = 'Push Day A',
  SessionStatus status = SessionStatus.done,
  bool isPr = false,
  String? note,
  List<SessionExerciseLog> exercises = const [],
}) => ClientSessionSummary(
  scheduledWorkoutId: id,
  date: DateTime(2026, 8, 17),
  workoutName: name,
  status: status,
  isPr: isPr,
  totalVolume: 8420,
  avgRpe: 8.2,
  clientNote: note,
  exercises: exercises,
);

ClientNutritionSummary fakeNutrition({
  int totalCalories = 1850,
  int goal = 2200,
  List<LoggedMeal> meals = const [],
  List<DailyCalorieTotal>? trend,
  ExtendedNutrients? micronutrients,
  // Defaults locked: none of the existing screen tests are about
  // micronutrients, so they see the same upgrade-prompt card a Free-tier
  // trainer would. Tests of the tracked-nutrients card itself pass
  // `micronutrientsLocked: false` explicitly.
  bool micronutrientsLocked = true,
  List<String> pinnedNutrients = const [],
}) => ClientNutritionSummary(
  date: DateTime(2026, 8, 20),
  calorieGoal: goal,
  totalCalories: totalCalories,
  macros: const MacroTotals(protein: 140, carbs: 190, fat: 60),
  loggedMeals: meals,
  sevenDayTrend: trend ??
      [
        for (var i = 6; i >= 0; i--)
          DailyCalorieTotal(
            date: DateTime(2026, 8, 20).subtract(Duration(days: i)),
            totalCalories: 1800 + i * 90,
            goal: goal,
          ),
      ],
  micronutrients: micronutrients,
  micronutrientsLocked: micronutrientsLocked,
  pinnedNutrients: pinnedNutrients,
);
