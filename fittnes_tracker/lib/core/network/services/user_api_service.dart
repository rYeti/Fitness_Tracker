import '../base_api_service.dart';

class UserApiService extends BaseApiService {
  UserApiService(super.apiClient);

  Future<Map<String, dynamic>> getUserProfile() async {
    return handleResponse(
      request: () => apiClient.get('/user/profile'),
      fromJson: (json) => json,
    );
  }

  Future<Map<String, dynamic>> updateUserProfile(
    Map<String, dynamic> profileData,
  ) async {
    return handleResponse(
      request: () => apiClient.put('/user/profile', data: profileData),
      fromJson: (json) => json,
    );
  }

  Future<Map<String, dynamic>> updateUserGoals(
    Map<String, dynamic> goalsData,
  ) async {
    return handleResponse(
      request: () => apiClient.put('/user/goals', data: goalsData),
      fromJson: (json) => json,
    );
  }
}
