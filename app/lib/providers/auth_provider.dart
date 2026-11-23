import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_service.dart';
import '../models/user.dart';
import 'auth_error.dart';
import 'family_provider.dart';
import 'push_providers.dart';
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

      // Register this device for push while the session is fresh. Best-effort:
      // a missing token or provider failure must not affect sign-in.
      unawaited(
        ref.read(pushControllerProvider.notifier).registerForUser(result.user.id),
      );

      // After auth, load (or auto-create) the user's family.
      // This stores the real family ID in familyProvider for all screens to use.
      ref.read(familyProvider.notifier).loadMyFamily();
    } catch (e, stackTrace) {
      // Raw exception details stay in logs; the banner only shows a short
      // message so it can never leak Dio internals (issue #23).
      debugPrint('Google sign-in failed: $e');
      debugPrintStack(stackTrace: stackTrace);
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: authErrorMessage(e),
      );
    }
  }

  /// Sign out the current user.
  ///
  /// The push token is removed first, while the session is still valid, so
  /// the backend stops delivering alerts to this device.
  Future<void> signOut() async {
    await ref.read(pushControllerProvider.notifier).unregisterCurrentToken();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

/// Provider for the auth state.
final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
