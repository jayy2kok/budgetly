import 'package:budgetly/config/api_config.dart';
import 'package:budgetly/config/budgetly_colors.dart';
import 'package:budgetly/config/theme.dart';
import 'package:budgetly/providers/auth_provider.dart';
import 'package:budgetly/providers/backend_base_url_provider.dart';
import 'package:budgetly/screens/settings/backend_url_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A GoRouter with the login route so `context.go('/login')` after a save
/// lands somewhere observable (the sign-out is asserted via a fake notifier).
GoRouter _router() => GoRouter(
      initialLocation: '/settings/backend-url',
      routes: [
        GoRoute(
          path: '/settings/backend-url',
          builder: (_, _) => const BackendUrlScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (_, _) => const Scaffold(
            body: Center(child: Text('LOGIN SCREEN')),
          ),
        ),
      ],
    );

class _FakeAuthNotifier extends AuthNotifier {
  int signOutCalls = 0;

  @override
  AuthState build() => const AuthState();

  @override
  Future<void> signOut() async {
    signOutCalls++;
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

Future<AuthNotifier> pumpScreen(WidgetTester tester) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final auth = _FakeAuthNotifier();
  final container = ProviderContainer(
    overrides: [authProvider.overrideWith(() => auth)],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: ThemeData(extensions: [BudgetlyColors.dark]),
        routerConfig: _router(),
      ),
    ),
  );
  // Let the provider's async SharedPreferences load apply before asserting.
  await tester.pumpAndSettle();
  await container.read(backendBaseUrlProvider.notifier).load();
  await tester.pumpAndSettle();
  return auth;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows the effective base URL (default when none stored)', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('Custom'), findsNothing);
    // The URL is the initial input value.
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('backend-url-input')),
    );
    expect(field.controller?.text, ApiConfig.defaultBaseUrl);
  });

  testWidgets('shows the persisted override and a Custom badge', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      BackendBaseUrlNotifier.storageKey: 'http://10.0.2.2:8080/api/v1',
    });
    await pumpScreen(tester);

    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('backend-url-input')),
    );
    expect(field.controller?.text, 'http://10.0.2.2:8080/api/v1');
    expect(find.text('Custom'), findsOneWidget);
  });

  testWidgets('saving a valid URL persists it and signs out', (tester) async {
    final auth = await pumpScreen(tester) as _FakeAuthNotifier;

    await tester.enterText(
      find.byKey(const ValueKey('backend-url-input')),
      '192.168.1.10:8080/api/v1',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString(BackendBaseUrlNotifier.storageKey),
      'http://192.168.1.10:8080/api/v1',
    );
    expect(auth.signOutCalls, 1);
    expect(find.text('LOGIN SCREEN'), findsOneWidget);
  });

  testWidgets('saving the same URL does not sign out', (tester) async {
    SharedPreferences.setMockInitialValues({
      BackendBaseUrlNotifier.storageKey: 'http://10.0.2.2:8080/api/v1',
    });
    final auth = await pumpScreen(tester) as _FakeAuthNotifier;

    await tester.enterText(
      find.byKey(const ValueKey('backend-url-input')),
      'http://10.0.2.2:8080/api/v1',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(auth.signOutCalls, 0);
    expect(find.text('LOGIN SCREEN'), findsNothing);
  });

  testWidgets('invalid input shows an error and does not save', (
    tester,
  ) async {
    final auth = await pumpScreen(tester) as _FakeAuthNotifier;

    await tester.enterText(
      find.byKey(const ValueKey('backend-url-input')),
      'not a url',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Enter a valid URL'),
      findsOneWidget,
    );
    // The typed text is preserved (never clobbered by a rebuild).
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('backend-url-input')),
    );
    expect(field.controller?.text, 'not a url');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(BackendBaseUrlNotifier.storageKey), isNull);
    expect(auth.signOutCalls, 0);
  });

  testWidgets('empty input resets to the default', (tester) async {
    SharedPreferences.setMockInitialValues({
      BackendBaseUrlNotifier.storageKey: 'http://10.0.2.2:8080/api/v1',
    });
    await pumpScreen(tester);

    await tester.enterText(
      find.byKey(const ValueKey('backend-url-input')),
      '',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(BackendBaseUrlNotifier.storageKey), isNull);
  });
}