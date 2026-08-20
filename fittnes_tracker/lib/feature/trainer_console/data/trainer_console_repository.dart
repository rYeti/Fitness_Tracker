import 'package:ForgeForm/feature/trainer_console/data/trainer_console_api.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/trainer_client_summary.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/trainer_console_models.dart';

class TrainerConsoleRepository {
  final TrainerConsoleApi _api;

  TrainerConsoleRepository({TrainerConsoleApi? api})
    : _api = api ?? TrainerConsoleApi();

  /// Active clients only — pending invites and revoked relationships don't
  /// belong on the roster (see CLAUDE.md: gate on Status == Active).
  Future<List<TrainerClientSummary>> getRoster() async {
    final raw = await _api.fetchMyClients();
    return raw
        .map(TrainerClientSummary.fromJson)
        .where((c) => c.status == 'Active')
        .toList();
  }

  /// Roster with training stats for the Dashboard. The server already filters
  /// to active relationships, so there's no status filter here.
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
}
