import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  final Dio _dio;
  final Logger _logger;

  ApiClient({required String baseUrl, Map<String, String>? headers})
    : _dio = Dio(
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
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          if (options.data != null) {
            _logger.d('${options.method} ${options.path} body: ${options.data}');
          }
          handler.next(options);
        },
        onError: (error, handler) {
          if (error.response != null) {
            _logger.e('${error.requestOptions.method} ${error.requestOptions.path} → ${error.response?.statusCode} body: ${error.response?.data}');
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
