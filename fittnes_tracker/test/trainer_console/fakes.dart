import 'dart:async';

import 'package:ForgeForm/feature/trainer_console/data/trainer_console_repository.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/trainer_client_summary.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/trainer_console_models.dart';

/// Stands in for the network layer so each screen's states can be driven
/// deterministically. Shared across the console's tests so a repository change
/// only has to be absorbed in one place.
class FakeTrainerConsoleRepository implements TrainerConsoleRepository {
  final List<TrainerClientSummary> roster;
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

  /// Completes only when a test says so, to hold a screen in loading.
  final Completer<void>? gate;

  /// Records what createClientWorkoutPlan was called with.
  final List<({String clientId, String name})> createdPlans = [];

  FakeTrainerConsoleRepository({
    this.roster = const [],
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
    this.gate,
  });

  @override
  Future<List<TrainerClientSummary>> getRoster() async => roster;

  @override
  Future<List<TrainerRosterEntry>> getRosterWithStats() async {
    if (gate != null) await gate!.future;
    if (throwOnDashboard) throw Exception('boom');
    return rosterWithStats;
  }

  @override
  Future<TrainerDashboardKpis> getDashboardKpis() async {
    if (gate != null) await gate!.future;
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
    if (gate != null) await gate!.future;
    if (throwOnSessions) throw Exception('boom');
    return sessions;
  }

  @override
  Future<ClientNutritionSummary> getClientNutritionSummary(
    String clientId,
    DateTime date,
  ) async {
    if (gate != null) await gate!.future;
    if (throwOnNutrition) throw Exception('boom');
    if (nutrition == null) throw StateError('no nutrition fixture supplied');
    return nutrition!;
  }

  @override
  Future<ClientWorkoutSummary> getClientWorkoutSummary(String clientId) async {
    if (gate != null) await gate!.future;
    return workoutSummary ??
        const ClientWorkoutSummary(attendance: [], strengthProgression: []);
  }

  @override
  Future<List<ClientWeightEntry>> getClientWeightHistory(String clientId) async =>
      weightHistory;

  @override
  Future<List<WorkoutPlanTemplateSummary>> getWorkoutPlanTemplates() async =>
      templates;

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

TrainerClientSummary fakeClient({
  String id = 'client-1',
  String name = 'Robert Meyer',
}) => TrainerClientSummary(
  relationshipId: 'rel-$id',
  clientId: id,
  clientName: name,
  status: 'Active',
);

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
