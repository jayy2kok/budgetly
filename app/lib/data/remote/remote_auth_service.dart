import 'package:dio/dio.dart';
import '../../models/user.dart';
import '../auth_service.dart';
import 'api_client.dart';

/// Real API implementation of [AuthService].
class RemoteAuthService implements AuthService {
  final Dio _dio = ApiClient.instance.dio;

  @override
  Future<({User user, String accessToken, String refreshToken})>
      signInWithGoogle(String idToken) async {
    final response = await _dio.post(
      '/auth/google',
      data: {'idToken': idToken},
    );

    final data = response.data as Map<String, dynamic>;
    final user = User.fromJson(data['user'] as Map<String, dynamic>);
    final accessToken = data['accessToken'] as String;
    final refreshToken = data['refreshToken'] as String;

    // Store tokens in the API client for future requests
    ApiClient.instance.setTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );

    return (
      user: user,
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }

  @override
  Future<({String accessToken, String refreshToken})> refreshToken(
      String refreshToken) async {
    final response = await _dio.post(
      '/auth/refresh',
      data: {'refreshToken': refreshToken},
    );

    final data = response.data as Map<String, dynamic>;
    final newAccess = data['accessToken'] as String;
    final newRefresh = data['refreshToken'] as String;

    ApiClient.instance.setTokens(
      accessToken: newAccess,
      refreshToken: newRefresh,
    );

    return (accessToken: newAccess, refreshToken: newRefresh);
  }

  @override
  Future<User> getCurrentUser() async {
    final response = await _dio.get('/auth/me');
    return User.fromJson(response.data as Map<String, dynamic>);
  }
}
