import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user.dart';
import '../data/mock/mock_auth_service.dart';

/// Auth state — tracks the current user's sign-in state.
enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState {
  final AuthStatus status;
  final User? user;
  final String? accessToken;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.accessToken,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? accessToken,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      accessToken: accessToken ?? this.accessToken,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  bool get isAuthenticated => status == AuthStatus.authenticated;
}

/// Auth notifier — manages sign-in / sign-out lifecycle.
class AuthNotifier extends Notifier<AuthState> {
  late final MockAuthService _authService;

  @override
  AuthState build() {
    _authService = MockAuthService();
    return const AuthState();
  }

  /// Sign in with Google via mock service.
  Future<void> signInWithGoogle() async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final result = await _authService.signInWithGoogle('mock_id_token');
      state = AuthState(
        status: AuthStatus.authenticated,
        user: result.user,
        accessToken: result.accessToken,
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
