import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:budgetly/config/budgetly_colors.dart';
import 'package:budgetly/data/auth_service.dart';
import 'package:budgetly/models/user.dart';
import 'package:budgetly/providers/auth_error.dart';
import 'package:budgetly/providers/auth_provider.dart';
import 'package:budgetly/providers/service_providers.dart';
import 'package:budgetly/screens/auth/login_screen.dart';

DioException _dioError(DioExceptionType type, {int? statusCode}) => DioException(
  requestOptions: RequestOptions(path: '/auth/google'),
  type: type,
  response: statusCode == null
      ? null
      : Response(requestOptions: RequestOptions(path: '/auth/google'),
          statusCode: statusCode),
);

const _rejectedMessage = 'Google sign-in was rejected. Please try again.';
const _networkMessage = "Can't reach Budgetly. Check your connection.";
const _serverMessage = 'Budgetly is having trouble. Try again in a moment.';

/// The exact 400 from the live reproduction in issue #23.
final _liveReproductionError = DioException(
  requestOptions: RequestOptions(path: '/auth/google'),
  type: DioExceptionType.badResponse,
  response: Response(
    requestOptions: RequestOptions(path: '/auth/google'),
    statusCode: 400,
  ),
);

/// Fails sign-in with [error]; a stand-in for the failing `/auth/google` call.
class _FailingAuthService implements AuthService {
  _FailingAuthService(this.error);

  final Object error;

  @override
  Future<({User user, String accessToken, String refreshToken})>
      signInWithGoogle(String idToken) async {
    throw error;
  }

  @override
  Future<({String accessToken, String refreshToken})> refreshToken(
      String token) async {
    throw UnimplementedError();
  }

  @override
  Future<User> getCurrentUser() async => throw UnimplementedError();
}

/// Runs a failed sign-in through [AuthNotifier] and returns the resulting
/// state — the state the login banner renders.
Future<AuthState> signInFailureState(Object error) async {
  final container = ProviderContainer(
    overrides: [authServiceProvider.overrideWithValue(
      _FailingAuthService(error),
    )],
  );
  addTearDown(container.dispose);
  await container.read(authProvider.notifier).signInWithGoogle(
        overrideIdToken: 'token',
      );
  return container.read(authProvider);
}

/// Renders the login screen and returns the banner text for [state].
Future<String?> renderLoginBanner(WidgetTester tester, AuthState state) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  tester.view.physicalSize = const Size(1216, 2640);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: [authProvider.overrideWith(() => _StaticAuthNotifier(state))],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: ThemeData(extensions: [BudgetlyColors.dark]),
        home: const LoginScreen(),
      ),
    ),
  );
  await tester.pump();

  final banner = find.byKey(const ValueKey('login-error-banner'));
  expect(banner, findsOneWidget);
  return tester.widget<Text>(find.descendant(
    of: banner,
    matching: find.byType(Text),
  )).data;
}

class _StaticAuthNotifier extends AuthNotifier {
  _StaticAuthNotifier(this._initial);

  final AuthState _initial;

  @override
  AuthState build() => _initial;
}

void main() {
  test('maps the live 400 to the rejection message', () {
    expect(authErrorMessage(_liveReproductionError), _rejectedMessage);
  });

  group('authErrorKind', () {
    test('network failures', () {
      for (final type in [
        DioExceptionType.connectionError,
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ]) {
        expect(authErrorKind(_dioError(type)), AuthErrorKind.network,
            reason: type.name);
      }
      expect(
        authErrorKind(const SocketException('failed host lookup')),
        AuthErrorKind.network,
      );
    });

    test('4xx responses', () {
      for (final status in [400, 401, 403, 404]) {
        expect(
          authErrorKind(_dioError(DioExceptionType.badResponse,
              statusCode: status)),
          AuthErrorKind.rejected,
          reason: 'status $status',
        );
      }
    });

    test('5xx responses', () {
      for (final status in [500, 502, 503]) {
        expect(
          authErrorKind(_dioError(DioExceptionType.badResponse,
              statusCode: status)),
          AuthErrorKind.server,
          reason: 'status $status',
        );
      }
    });

    test('cancellation and unknown failures', () {
      expect(authErrorKind(_dioError(DioExceptionType.cancel)),
          AuthErrorKind.unknown);
      expect(authErrorKind(Exception('anything')), AuthErrorKind.unknown);
    });
  });

  test('sign-in failure maps to a distinct message per failure kind', () async {
    expect((await signInFailureState(_liveReproductionError)).errorMessage,
        _rejectedMessage);
    expect(
      (await signInFailureState(
        _dioError(DioExceptionType.connectionError),
      )).errorMessage,
      _networkMessage,
    );
    expect(
      (await signInFailureState(
        _dioError(DioExceptionType.badResponse, statusCode: 503),
      )).errorMessage,
      _serverMessage,
    );
  });

  testWidgets('banner renders the short message, never raw exception text', (
    tester,
  ) async {
    // The flutter test framework captures debugPrint output itself; here we
    // only assert what the banner shows.
    final state = await signInFailureState(_liveReproductionError);
    final bannerText = await renderLoginBanner(tester, state);

    expect(bannerText, _rejectedMessage);
    expect(find.textContaining('DioException'), findsNothing);
    expect(find.textContaining('RequestOptions'), findsNothing);
    expect(find.textContaining('Read more about status codes'), findsNothing);

    final banner = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('login-error-banner')),
        matching: find.byType(Text),
      ),
    );
    expect(banner.maxLines, lessThanOrEqualTo(3));
  });
}