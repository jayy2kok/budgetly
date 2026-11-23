import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:integration_test/integration_test.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';

import 'helpers/integration_harness.dart';

/// Boot smoke: the app launches offline and renders its first screen.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() {
    resetIntegrationPreferences();
    installPermissionHandler(PermissionStatus.denied);
  });

  testWidgets('cold start renders the login screen without an error banner', (
    tester,
  ) async {
    await pumpIntegrationApp(tester, authenticated: false);
    await tester.pumpAndSettle();

    expect(find.text('Budgetly'), findsOneWidget);
    expect(find.text('Family Harmony Budget'), findsOneWidget);
    expect(find.text('Track shared family expenses'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.byKey(const ValueKey('login-error-banner')), findsNothing);
  });

  testWidgets('cold start via deep link opens the Join Family screen', (
    tester,
  ) async {
    await pumpIntegrationApp(
      tester,
      initialLocation: '/join?code=FAM-E2E',
      authenticated: false,
    );
    await tester.pumpAndSettle();

    expect(find.text('Join your family group'), findsOneWidget);
    expect(find.text('Join Family'), findsWidgets);
  });
}
