import 'package:ForgeForm/core/network/api_client.dart';
import 'package:ForgeForm/feature/auth/data/Models/auth_response_model.dart';

class AuthRepository {
  late final ApiClient _apiClient;

  AuthRepository(ApiClient apiClient) {
    _apiClient = apiClient;
  }

  Future<AuthResponseModel> login(String username, String password) async {
    final response = await _apiClient.post(
      'api/auth/login',
      data: {'username': username, 'password': password},
    );

    return AuthResponseModel.fromJson(response.data);
  }

  Future<AuthResponseModel> register(
    String username,
    String email,
    String password,
    String firstName,
    String lastName,
    DateTime dateOfBirth,
  ) async {
    final response = await _apiClient.post(
      'api/auth/register',
      data: {
        'username': username,
        'email': email,
        'password': password,
        'firstName': firstName,
        'lastName': lastName,
        'dateOfBirth': dateOfBirth.toIso8601String(),
      },
    );

    return AuthResponseModel.fromJson(response.data);
  }
}
