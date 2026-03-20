import '../../models/user.dart';
import '../auth_service.dart';
import 'sample_data.dart';

/// Mock authentication service for Phase 2 / offline development.
class MockAuthService implements AuthService {
  @override
  Future<({User user, String accessToken, String refreshToken})>
      signInWithGoogle(String idToken) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return (
      user: SampleData.user1,
      accessToken: 'mock_jwt_access_001',
      refreshToken: 'mock_jwt_refresh_001',
    );
  }

  @override
  Future<({String accessToken, String refreshToken})> refreshToken(
      String refreshToken) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return (
      accessToken: 'mock_jwt_access_refreshed',
      refreshToken: 'mock_jwt_refresh_refreshed',
    );
  }

  @override
  Future<User> getCurrentUser() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return SampleData.user1;
  }
}
