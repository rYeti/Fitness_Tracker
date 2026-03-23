import 'package:dio/dio.dart';
import 'api_client.dart';

abstract class BaseApiService {
  final ApiClient apiClient;

  BaseApiService(this.apiClient);

  Future<T> handleResponse<T>({
    required Future<Response> Function() request,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await request();
      if (fromJson != null) {
        return fromJson(response.data);
      }
      return response.data as T;
    } catch (e) {
      rethrow;
    }
  }
}
