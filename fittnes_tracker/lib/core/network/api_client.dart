import 'package:ForgeForm/core/network/secure_token_storage.dart';
import 'package:ForgeForm/core/network/token_refresh_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

class ApiClient {
  final Dio _dio;
  final Logger _logger;

  /// Whether a 401 should trigger a silent token refresh + retry.
  ///
  /// Must be false for [ApiClient]s used from the background sync isolate
  /// (see main.dart's Workmanager dispatcher): that isolate has its own
  /// [TokenRefreshService] instance, so a refresh triggered from there can
  /// race the foreground app's refresh. The server treats a reused
  /// already-rotated refresh token as a compromise signal and revokes the
  /// whole token chain, forcing a real logout for what was actually a
  /// harmless race. Background sync just lets a 401 fail the sync silently
  /// instead — the foreground app will refresh normally on its own.
  final bool allowTokenRefresh;

  ApiClient({
    required String baseUrl,
    Map<String, String>? headers,
    this.allowTokenRefresh = true,
  }) : _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          headers: headers,
          contentType: 'application/json',
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
        ),
      ),

      _logger = Logger() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await SecureTokenStorage.getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          if (options.data != null && kDebugMode) {
            _logger.d('${options.method} ${options.path}');
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response != null) {
            _logger.e('${error.requestOptions.method} ${error.requestOptions.path} → ${error.response?.statusCode}');
          }

          final isAuthEndpoint = error.requestOptions.path.contains('api/auth/');
          final alreadyRetried = error.requestOptions.extra['retried'] == true;
          if (error.response?.statusCode == 401 &&
              !isAuthEndpoint &&
              !alreadyRetried &&
              allowTokenRefresh) {
            final refreshed = await TokenRefreshService.instance.refreshIfNeeded(
              _dio.options.baseUrl,
            );
            if (refreshed) {
              final newToken = await SecureTokenStorage.getToken();
              final opts = error.requestOptions;
              opts.headers['Authorization'] = 'Bearer $newToken';
              opts.extra['retried'] = true;
              try {
                final response = await _dio.fetch(opts);
                return handler.resolve(response);
              } catch (_) {
                return handler.next(error);
              }
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
      );
      return response;
    } catch (e) {
      _logger.e('GET request failed: $e');
      rethrow;
    }
  }

  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return response;
    } catch (e) {
      if (e is DioException && e.response != null) {
        _logger.e('POST request failed: $e\nResponse body: ${e.response?.data}');
      } else {
        _logger.e('POST request failed: $e');
      }
      rethrow;
    }
  }

  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return response;
    } catch (e) {
      _logger.e('PUT request failed: $e');
      rethrow;
    }
  }

  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return response;
    } catch (e) {
      _logger.e('DELETE request failed: $e');
      rethrow;
    }
  }
}
