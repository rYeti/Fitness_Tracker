import '../base_api_service.dart';

class NutritionApiService extends BaseApiService {
  NutritionApiService(super.apiClient);

  Future<List<Map<String, dynamic>>> getMeals() async {
    return handleResponse(
      request: () => apiClient.get('/meals'),
      fromJson: (json) => List<Map<String, dynamic>>.from(json),
    );
  }

  Future<Map<String, dynamic>> createMeal(Map<String, dynamic> mealData) async {
    return handleResponse(
      request: () => apiClient.post('/meals', data: mealData),
      fromJson: (json) => json,
    );
  }

  Future<Map<String, dynamic>> updateMeal(
    String mealId,
    Map<String, dynamic> mealData,
  ) async {
    return handleResponse(
      request: () => apiClient.put('/meals/$mealId', data: mealData),
      fromJson: (json) => json,
    );
  }

  Future<void> deleteMeal(String mealId) async {
    return handleResponse(
      request: () => apiClient.delete('/meals/$mealId'),
      fromJson: (json) => null,
    );
  }

  Future<Map<String, dynamic>> getDailyNutrition() async {
    return handleResponse(
      request: () => apiClient.get('/nutrition/daily'),
      fromJson: (json) => json,
    );
  }
}
