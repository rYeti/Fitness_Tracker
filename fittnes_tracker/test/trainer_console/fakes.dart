import 'dart:async';

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

  /// Set to make the matching call throw, for error-state tests.
  final bool throwOnSessions;
  final bool throwOnDashboard;
  final bool throwOnNutrition;
  final bool throwOnRoster;

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

  FakeTrainerConsoleRepository({
    this.rosterWithStats = const [],
    this.sessions = const [],
    this.kpis,
    this.nutrition,
    this.workoutSummary,
    this.weightHistory = const [],
    this.templates = const [],
    this.throwOnSessions = false,
    this.throwOnDashboard = false,
    this.throwOnNutrition = false,
    this.throwOnRoster = false,
    this.gate,
    this.rosterGate,
    this.kpiGate,
  });

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
);
