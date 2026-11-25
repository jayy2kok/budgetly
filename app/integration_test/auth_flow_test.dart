import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:integration_test/integration_test.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';

import 'package:budgetly/data/mock/sample_data.dart';
import 'package:budgetly/providers/auth_provider.dart';
import 'package:budgetly/providers/family_provider.dart';

import 'helpers/integration_harness.dart';

/// Auth flow: the login gate hands off to the dashboard shell once a session
/// exists, and the family is loaded for the signed-in user.
///
/// The Google account picker itself cannot run on a CI emulator, so the test
/// drives the same notifier entry point the button uses, with the ID token the
/// button would have forwarded (`signInWithGoogle(overrideIdToken: ...)`).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() {
    resetIntegrationPreferences();
    installPermissionHandler(PermissionStatus.denied);
  });

  testWidgets('sign-in navigates from login to the dashboard shell', (
    tester,
  ) async {
    final harness = await pumpIntegrationApp(tester, authenticated: false);
    await tester.pumpAndSettle();

    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    // MockAuthService simulates a 500 ms network round-trip; await it so the
    // navigation triggered by the auth listener is observed deterministically.
    await harness.container
        .read(authProvider.notifier)
        .signInWithGoogle(overrideIdToken: 'integration-test-id-token');
    await settleFor(tester);

    expect(harness.container.read(authProvider).isAuthenticated, isTrue);
    expect(
      harness.container.read(familyProvider).currentFamily?.id,
      SampleData.familyGroup.id,
    );

    // The login route is gone and the four-tab shell is mounted.
    expect(find.text('Continue with Google'), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Feed'), findsOneWidget);
    expect(find.text('Budget'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Budget Overview'), findsOneWidget);
  });
}
