import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../error/app_exception.dart';
import 'api_endpoints.dart';

class ApiClient {
  late final Dio _dio;
  String? _authToken;
  String? _userEmail;

  ApiClient({Dio? dio}) {
    _dio =
        dio ??
        Dio(
          BaseOptions(
            baseUrl: ApiEndpoints.baseUrl,
            connectTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 10),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'ngrok-skip-browser-warning': 'true',
            },
          ),
        );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_authToken != null) {
            options.headers['Authorization'] = 'Bearer $_authToken';
          }
          if (_userEmail != null && _userEmail!.isNotEmpty) {
            options.headers['X-User-Email'] = _userEmail;
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          // Automatic host fallback between public HTTPS and local LAN/emulator
          if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
            final isConnectionIssue = e.type == DioExceptionType.connectionError ||
                e.type == DioExceptionType.connectionTimeout;
            if (isConnectionIssue) {
              final currentBase = _dio.options.baseUrl;
              String? altBase;
              if (currentBase.contains('ngrok-free.dev')) {
                altBase = 'http://10.47.11.97:8000';
              } else if (currentBase.contains('10.47.11.97')) {
                altBase = 'http://10.0.2.2:8000';
              } else if (currentBase.contains('10.0.2.2')) {
                altBase = 'https://satin-species-kilometer.ngrok-free.dev';
              }

              if (altBase != null && altBase != currentBase) {
                try {
                  _dio.options.baseUrl = altBase;
                  ApiEndpoints.setBaseUrl(altBase);
                  final retryOptions = e.requestOptions;
                  retryOptions.baseUrl = altBase;
                  final response = await _dio.fetch(retryOptions);
                  return handler.resolve(response);
                } catch (_) {
                  // Fall back through
                }
              }
            }
          }

          final exception = _handleDioError(e);
          return handler.reject(
            DioException(
              requestOptions: e.requestOptions,
              error: exception,
              response: e.response,
              type: e.type,
            ),
          );
        },
      ),
    );
  }

  void setAuthToken(String? token) {
    _authToken = token;
  }

  void setUserEmail(String? email) {
    _userEmail = email;
  }

  String? get userEmail => _userEmail;
  String? get authToken => _authToken;

  Dio get dio => _dio;

  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw e.error is AppException
          ? e.error as AppException
          : _handleDioError(e);
    }
  }

  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw e.error is AppException
          ? e.error as AppException
          : _handleDioError(e);
    }
  }

  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw e.error is AppException
          ? e.error as AppException
          : _handleDioError(e);
    }
  }

  Future<Response> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.patch(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw e.error is AppException
          ? e.error as AppException
          : _handleDioError(e);
    }
  }

  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw e.error is AppException
          ? e.error as AppException
          : _handleDioError(e);
    }
  }

  Future<Response> postMultipart(
    String path, {
    required FormData formData,
    Map<String, dynamic>? queryParameters,
    Options? options,
    ProgressCallback? onSendProgress,
  }) async {
    try {
      return await _dio.post(
        path,
        data: formData,
        queryParameters: queryParameters,
        options: options,
        onSendProgress: onSendProgress,
      );
    } on DioException catch (e) {
      throw e.error is AppException
          ? e.error as AppException
          : _handleDioError(e);
    }
  }

  AppException _handleDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.connectionError) {
      return NetworkException(
        'Unable to reach central DoSJE servers. Check connectivity.',
      );
    }

    final statusCode = e.response?.statusCode;
    final data = e.response?.data;
    String message = 'An unexpected error occurred';
    if (data is Map) {
      if (data['detail'] != null) {
        if (data['detail'] is List) {
          // Pydantic validation error list
          final errors = data['detail'] as List;
          message = errors
              .map((err) => err is Map ? (err['msg'] ?? err.toString()) : err.toString())
              .join('; ');
        } else {
          message = data['detail'].toString();
        }
      } else if (data['message'] != null) {
        message = data['message'].toString();
      }
    } else if (e.message != null && e.message!.isNotEmpty) {
      message = e.message!;
    }

    switch (statusCode) {
      case 400:
        return BadRequestException(message, data);
      case 401:
        return UnauthorizedException(message);
      case 403:
        return ForbiddenException(message);
      case 404:
        return NotFoundException(message);
      case 409:
        return ConflictException(message, data);
      case 413:
        return AppException('File payload too large: $message', statusCode: 413);
      case 422:
        return ValidationException(message, data);
      case 500:
      default:
        return ServerException(message);
    }
  }
}
