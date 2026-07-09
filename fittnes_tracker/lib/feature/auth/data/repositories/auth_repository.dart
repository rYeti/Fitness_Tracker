import 'package:ForgeForm/core/network/api_client.dart';
import 'package:ForgeForm/feature/auth/data/Models/auth_response_model.dart';
import 'package:dio/dio.dart';

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

  Future<AuthResponseModel> refresh(String refreshToken) async {
    final response = await _apiClient.post(
      'api/auth/refresh',
      data: {'refreshToken': refreshToken},
    );
    return AuthResponseModel.fromJson(response.data);
  }

  /// Best-effort — revokes the refresh token server-side. Swallows errors so
  /// a network failure never blocks the local logout flow.
  Future<void> logout(String refreshToken) async {
    try {
      await _apiClient.post(
        'api/auth/logout',
        data: {'refreshToken': refreshToken},
      );
    } catch (_) {}
  }

  Future<AuthResponseModel> updateProfile({
    required String token,
    required String firstName,
    required String lastName,
    required String email,
    required DateTime dateOfBirth,
  }) async {
    final response = await _apiClient.put(
      'api/auth/profile',
      data: {
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'dateOfBirth': dateOfBirth.toIso8601String(),
      },
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return AuthResponseModel.fromJson(response.data);
  }

  Future<void> changePassword({
    required String token,
    required String currentPassword,
    required String newPassword,
  }) async {
    await _apiClient.put(
      'api/auth/change-password',
      data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }

  Future<void> deleteAccount({required String token, required String password}) async {
    await _apiClient.delete(
      'api/auth/account',
      data: {'password': password},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }

  Future<void> forgotPassword(String email) async {
    await _apiClient.post(
      'api/auth/forgot-password',
      data: {'email': email},
    );
  }

  Future<void> resetPassword(String token, String newPassword) async {
    await _apiClient.post(
      'api/auth/reset-password',
      data: {'token': token, 'newPassword': newPassword},
    );
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
