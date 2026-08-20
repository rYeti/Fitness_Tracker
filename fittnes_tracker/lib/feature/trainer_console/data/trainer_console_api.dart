import 'package:ForgeForm/core/di/service_locator.dart';
import 'package:ForgeForm/core/network/api_client.dart';

/// Thin wrapper over `api/TrainerClient` — raw JSON in, no domain mapping
/// (that's [TrainerConsoleRepository]'s job).
class TrainerConsoleApi {
  final ApiClient _client;

  TrainerConsoleApi({ApiClient? client}) : _client = client ?? sl<ApiClient>();

  Future<List<Map<String, dynamic>>> fetchMyClients() async {
    final response = await _client.get('api/TrainerClient/my-clients');
    return (response.data as List).cast<Map<String, dynamic>>();
  }

  // Endpoints below exist on TrainerConsoleController/WorkoutPlanTemplateController
  // but their service-layer bodies are stubs (throw NotImplementedException)
  // until the backend logic is filled in — these Flutter methods are
  // signatures only for the same reason.

  Future<Map<String, dynamic>> fetchDashboardKpis() {
    throw UnimplementedError();
  }

  Future<List<Map<String, dynamic>>> fetchClientWeightHistory(String clientId) {
    throw UnimplementedError();
  }

  Future<Map<String, dynamic>> fetchClientWorkoutSummary(String clientId) {
    throw UnimplementedError();
  }

  Future<Map<String, dynamic>> fetchClientWorkoutHistory(String clientId, DateTime date) {
    throw UnimplementedError();
  }

  Future<Map<String, dynamic>> fetchClientNutritionSummary(String clientId, DateTime date) {
    throw UnimplementedError();
  }

  /// `GET api/TrainerConsole/{clientId}/session-history?count=` — returns
  /// `List<ClientSessionSummaryDto>` newest-first. Unlike the stubs above,
  /// this endpoint IS implemented server-side
  /// (TrainerConsoleService.GetClientSessionHistoryAsync); `count` must be
  /// 1..50 or the controller 400s.
  Future<List<Map<String, dynamic>>> fetchClientSessionHistory(String clientId, {int count = 10}) async {
    final response = await _client.get(
      'api/TrainerConsole/$clientId/session-history',
      queryParameters: {'count': count},
    );
    return (response.data as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchWorkoutPlanTemplates() {
    throw UnimplementedError();
  }

  Future<Map<String, dynamic>> createClientWorkoutPlan(String clientId, Map<String, dynamic> plan) {
    throw UnimplementedError();
  }

  Future<Map<String, dynamic>> updateClientWorkoutPlan(String clientId, String planId, Map<String, dynamic> plan) {
    throw UnimplementedError();
  }
}
