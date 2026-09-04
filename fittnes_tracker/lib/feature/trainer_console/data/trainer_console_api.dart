import 'package:ForgeForm/core/di/service_locator.dart';
import 'package:ForgeForm/core/network/api_client.dart';

/// Thin wrapper over `api/TrainerConsole` — raw JSON in, no domain mapping
/// (that's [TrainerConsoleRepository]'s job).
class TrainerConsoleApi {
  final ApiClient _client;

  TrainerConsoleApi({ApiClient? client})
    : _client = client ?? sl<ApiClient>(instanceName: backendApiClient);

  /// Active clients with the stats the Dashboard roster displays.
  Future<List<Map<String, dynamic>>> fetchRoster() async {
    final response = await _client.get('api/TrainerConsole/roster');
    return (response.data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> fetchDashboardKpis() async {
    final response = await _client.get('api/TrainerConsole/dashboard-kpis');
    return response.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> fetchClientWeightHistory(String clientId) async {
    final response = await _client.get(
      'api/TrainerConsole/$clientId/weight-history',
    );
    return (response.data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> fetchClientWorkoutSummary(String clientId) async {
    final response = await _client.get(
      'api/TrainerConsole/$clientId/workout-summary',
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchClientWorkoutHistory(
    String clientId,
    DateTime date,
  ) async {
    final response = await _client.get(
      'api/TrainerConsole/$clientId/workout-history',
      queryParameters: {'date': _dateParam(date)},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchClientNutritionSummary(
    String clientId,
    DateTime date,
  ) async {
    final response = await _client.get(
      'api/TrainerConsole/$clientId/nutrition-summary',
      queryParameters: {'date': _dateParam(date)},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> fetchWorkoutPlanTemplates() async {
    final response = await _client.get('api/WorkoutPlanTemplate');
    return (response.data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createClientWorkoutPlan(
    String clientId,
    Map<String, dynamic> plan,
  ) async {
    final response = await _client.post(
      'api/TrainerConsole/$clientId/workout-plans',
      data: plan,
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateClientWorkoutPlan(
    String clientId,
    String planId,
    Map<String, dynamic> plan,
  ) async {
    final response = await _client.put(
      'api/TrainerConsole/$clientId/workout-plans/$planId',
      data: plan,
    );
    return response.data as Map<String, dynamic>;
  }

  /// `GET api/TrainerConsole/{clientId}/session-history?count=` — returns
  /// `List<ClientSessionSummaryDto>` newest-first. `count` must be 1..50 or
  /// the controller 400s.
  Future<List<Map<String, dynamic>>> fetchClientSessionHistory(
    String clientId, {
    int count = 10,
  }) async {
    final response = await _client.get(
      'api/TrainerConsole/$clientId/session-history',
      queryParameters: {'count': count},
    );
    return (response.data as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchClientWorkouts(String clientId) async {
    final response = await _client.get('api/TrainerConsole/$clientId/workouts');
    return (response.data as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchClientExerciseLibrary(String clientId) async {
    final response = await _client.get('api/TrainerConsole/$clientId/exercises');
    return (response.data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createTrainerExercise(
    String clientId,
    Map<String, dynamic> exercise,
  ) async {
    final response = await _client.post(
      'api/TrainerConsole/$clientId/exercises',
      data: exercise,
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createClientWorkout(
    String clientId,
    Map<String, dynamic> workout,
  ) async {
    final response = await _client.post(
      'api/TrainerConsole/$clientId/workouts',
      data: workout,
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateClientWorkout(
    String clientId,
    String workoutId,
    Map<String, dynamic> workout,
  ) async {
    final response = await _client.put(
      'api/TrainerConsole/$clientId/workouts/$workoutId',
      data: workout,
    );
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteClientWorkout(String clientId, String workoutId) async {
    await _client.delete('api/TrainerConsole/$clientId/workouts/$workoutId');
  }

  Future<void> deleteClientWorkoutPlan(String clientId, String planId) async {
    await _client.delete('api/TrainerConsole/$clientId/workout-plans/$planId');
  }

  /// Returns the number of sessions the schedule call actually created.
  Future<int> scheduleClientPlan(
    String clientId,
    String planId,
    Map<String, dynamic> schedule,
  ) async {
    final response = await _client.post(
      'api/TrainerConsole/$clientId/workout-plans/$planId/schedule',
      data: schedule,
    );
    final data = response.data as Map<String, dynamic>;
    return data['sessionsCreated'] as int? ?? 0;
  }

  /// Date-only, so a device in a timezone behind UTC doesn't ask the server
  /// for the previous day.
  static String _dateParam(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
