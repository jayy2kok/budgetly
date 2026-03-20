import '../models/user.dart';

/// Contract for authentication operations.
abstract class AuthService {
  /// Sign in using a Google ID token. Returns user + JWT pair.
  Future<({User user, String accessToken, String refreshToken})>
      signInWithGoogle(String idToken);

  /// Refresh an expired access token.
  Future<({String accessToken, String refreshToken})> refreshToken(
      String refreshToken);

  /// Get the currently authenticated user's profile.
  Future<User> getCurrentUser();
}
