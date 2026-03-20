import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_service.dart';
import '../models/user.dart';
import 'service_providers.dart';

/// Auth state — tracks the current user's sign-in state.
enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState {
  final AuthStatus status;
  final User? user;
  final String? accessToken;
  final String? refreshToken;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.accessToken,
    this.refreshToken,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? accessToken,
    String? refreshToken,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  bool get isAuthenticated => status == AuthStatus.authenticated;
}

/// Auth notifier — manages sign-in / sign-out lifecycle.
class AuthNotifier extends Notifier<AuthState> {
  late final AuthService _authService;

  @override
  AuthState build() {
    _authService = ref.watch(authServiceProvider);
    return const AuthState();
  }

  /// Sign in with Google.
  ///
  /// In mock mode (useRealApi = false): returns sample user data instantly.
  ///
  /// In real-API mode (useRealApi = true): Requires google_sign_in v7 to be
  /// fully configured with a serverClientId. See GOOGLE_SIGNIN_SETUP.md for
  /// setup instructions. Call `GoogleSignInHelper.getIdToken()` from your
  /// platform-specific integration layer and pass it here via [overrideIdToken].
  Future<void> signInWithGoogle({String? overrideIdToken}) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final String idToken;

      if (useRealApi) {
        // In real-API mode, the ID token must be provided by the calling UI layer
        // (via a platform-specific GoogleSignIn flow) or via overrideIdToken.
        if (overrideIdToken == null || overrideIdToken.isEmpty) {
          throw Exception(
            'Real API mode requires a Google ID token. '
            'Use GoogleSignInHelper in the login screen to obtain one.',
          );
        }
        idToken = overrideIdToken;
      } else {
        idToken = 'mock_id_token';
      }

      final result = await _authService.signInWithGoogle(idToken);
      state = AuthState(
        status: AuthStatus.authenticated,
        user: result.user,
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
      );
    } catch (e) {
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: 'Sign-in failed: ${e.toString()}',
      );
    }
  }

  /// Sign out the current user.
  Future<void> signOut() async {
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

/// Provider for the auth state.
final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
