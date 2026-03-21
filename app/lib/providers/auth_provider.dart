import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_service.dart';
import '../models/user.dart';
import 'family_provider.dart';
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
  /// fully configured with a serverClientId. Pass the ID token from the login
  /// screen via [overrideIdToken].
  Future<void> signInWithGoogle({String? overrideIdToken}) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final String idToken;

      if (useRealApi) {
        if (overrideIdToken == null || overrideIdToken.isEmpty) {
          throw Exception(
            'Real API mode requires a Google ID token. '
            'Use GoogleSignIn in the login screen to obtain one.',
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

      // After auth, load (or auto-create) the user's family.
      // This stores the real family ID in familyProvider for all screens to use.
      ref.read(familyProvider.notifier).loadMyFamily();
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
