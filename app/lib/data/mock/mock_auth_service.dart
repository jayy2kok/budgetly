import '../../models/user.dart';
import 'sample_data.dart';

/// Mock authentication service for Phase 2.
class MockAuthService {
  /// Simulates Google sign-in by returning the first sample user.
  Future<({User user, String accessToken})> signInWithGoogle(
    String idToken,
  ) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return (user: SampleData.user1, accessToken: 'mock_jwt_token_001');
  }

  /// Simulates token refresh.
  Future<String> refreshToken(String refreshToken) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return 'mock_jwt_token_refreshed';
  }

  /// Returns the current user profile.
  Future<User> getCurrentUser() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return SampleData.user1;
  }
}
