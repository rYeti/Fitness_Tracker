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
}
