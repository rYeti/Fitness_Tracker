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

  Future<TrainerDashboardKpis> getDashboardKpis() {
    throw UnimplementedError();
  }

  Future<ClientWorkoutSummary> getClientWorkoutSummary(String clientId) {
    throw UnimplementedError();
  }

  Future<ClientWorkoutHistory> getClientWorkoutHistory(String clientId, DateTime date) {
    throw UnimplementedError();
  }

  Future<ClientNutritionSummary> getClientNutritionSummary(String clientId, DateTime date) {
    throw UnimplementedError();
  }

  Future<List<WorkoutPlanTemplateSummary>> getWorkoutPlanTemplates() {
    throw UnimplementedError();
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
