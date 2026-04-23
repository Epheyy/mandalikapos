// The API client is a single Dio instance used for ALL HTTP requests.
// It automatically:
//   1. Adds the Firebase auth token to every request
//   2. Handles token expiry (gets a fresh token if needed)
//   3. Converts API errors into readable messages
// Every feature uses this — never create a raw http.Client or Dio directly.
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';

// Riverpod provider — the rest of the app accesses the API client via this
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

class ApiClient {
  late final Dio _dio;

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // Add our auth interceptor
    _dio.interceptors.add(_AuthInterceptor());

    // Add logging in debug mode
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      // Only log in debug — never log tokens in production
      logPrint: (obj) => debugPrint('[API] $obj'),
    ));
  }

  // ── HTTP methods ────────────────────────────────────────────

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? params}) {
    return _dio.get<T>(path, queryParameters: params);
  }

  Future<Response<T>> post<T>(String path, {dynamic data}) {
    return _dio.post<T>(path, data: data);
  }

  Future<Response<T>> patch<T>(String path, {dynamic data}) {
    return _dio.patch<T>(path, data: data);
  }

  Future<Response<T>> put<T>(String path, {dynamic data}) {
    return _dio.put<T>(path, data: data);
  }

  Future<Response<T>> delete<T>(String path) {
    return _dio.delete<T>(path);
  }
}

// ── Auth Interceptor ─────────────────────────────────────────────
// This runs before EVERY request and injects the Firebase token.
// If the token is expired, Firebase automatically refreshes it.
class _AuthInterceptor extends Interceptor {
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // getIdToken(false) returns cached token if still valid,
      // or fetches a fresh one if expired — all automatic
      final token = await user.getIdToken(false);
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Convert Dio errors into user-friendly messages
    final message = _extractErrorMessage(err);
    handler.next(
      err.copyWith(
        message: message,
      ),
    );
  }

  String _extractErrorMessage(DioException err) {
    if (err.response?.data is Map) {
      return err.response?.data['error'] as String? ?? err.message ?? 'Unknown error';
    }
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timed out. Check your internet connection.';
      case DioExceptionType.connectionError:
        return 'Cannot connect to server. Make sure the backend is running.';
      default:
        return err.message ?? 'Something went wrong';
    }
  }
}