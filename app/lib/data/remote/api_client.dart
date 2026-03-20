import 'package:dio/dio.dart';
import '../../config/api_config.dart';

/// Singleton Dio API client with JWT interceptor.
///
/// Provides a pre-configured [Dio] instance for all remote services.
/// Handles:
///  - Base URL configuration
///  - Authorization header injection
///  - Token refresh on 401
///  - Logging in debug mode
class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  late final Dio _dio;
  String? _accessToken;
  String? _refreshToken;

  /// Initialize the Dio client. Call once at app startup.
  void init() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: Duration(milliseconds: ApiConfig.connectTimeout),
        receiveTimeout: Duration(milliseconds: ApiConfig.receiveTimeout),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_accessToken != null) {
            options.headers['Authorization'] = 'Bearer $_accessToken';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          // Auto-refresh on 401 if we have a refresh token
          if (error.response?.statusCode == 401 && _refreshToken != null) {
            try {
              final refreshed = await _tryRefreshToken();
              if (refreshed) {
                // Retry the original request with the new token
                final opts = error.requestOptions;
                opts.headers['Authorization'] = 'Bearer $_accessToken';
                final response = await _dio.fetch(opts);
                return handler.resolve(response);
              }
            } catch (_) {
              // Refresh failed — fall through to error
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  /// Get the configured Dio instance.
  Dio get dio => _dio;

  /// Store JWT tokens after login/refresh.
  void setTokens({required String accessToken, String? refreshToken}) {
    _accessToken = accessToken;
    _refreshToken = refreshToken ?? _refreshToken;
  }

  /// Clear tokens on sign-out.
  void clearTokens() {
    _accessToken = null;
    _refreshToken = null;
  }

  /// Current access token (for providers that need it).
  String? get accessToken => _accessToken;

  /// Attempt to refresh the access token using the refresh token.
  Future<bool> _tryRefreshToken() async {
    if (_refreshToken == null) return false;

    try {
      // Use a fresh Dio instance to avoid interceptor loops
      final refreshDio = Dio(
        BaseOptions(
          baseUrl: ApiConfig.baseUrl,
          headers: {'Content-Type': 'application/json'},
        ),
      );

      final response = await refreshDio.post(
        '/auth/refresh',
        data: {'refreshToken': _refreshToken},
      );

      if (response.statusCode == 200) {
        _accessToken = response.data['accessToken'] as String;
        _refreshToken = response.data['refreshToken'] as String?;
        return true;
      }
    } catch (_) {
      // Refresh failed
    }
    return false;
  }
}
