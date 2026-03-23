import '../base_api_service.dart';

class WorkoutApiService extends BaseApiService {
  WorkoutApiService(super.apiClient);

  Future<List<Map<String, dynamic>>> getWorkouts() async {
    return handleResponse(
      request: () => apiClient.get('/workouts'),
      fromJson: (json) => List<Map<String, dynamic>>.from(json),
    );
  }

  Future<Map<String, dynamic>> createWorkout(
    Map<String, dynamic> workoutData,
  ) async {
    return handleResponse(
      request: () => apiClient.post('/workouts', data: workoutData),
      fromJson: (json) => json,
    );
  }

  Future<Map<String, dynamic>> updateWorkout(
    String workoutId,
    Map<String, dynamic> workoutData,
  ) async {
    return handleResponse(
      request: () => apiClient.put('/workouts/$workoutId', data: workoutData),
      fromJson: (json) => json,
    );
  }

  Future<void> deleteWorkout(String workoutId) async {
    return handleResponse(
      request: () => apiClient.delete('/workouts/$workoutId'),
      fromJson: (json) => null,
    );
  }
}
