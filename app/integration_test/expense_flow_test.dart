import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:integration_test/integration_test.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';

import 'package:budgetly/config/routes.dart';
import 'package:budgetly/screens/expense/add_expense_screen.dart';

import 'helpers/integration_harness.dart';

/// Expense flow: create an expense from the shell FAB and see it in the feed.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() {
    resetIntegrationPreferences();
    installPermissionHandler(PermissionStatus.denied);
  });

  testWidgets('saving an expense posts it and lists it in the feed', (
    tester,
  ) async {
    final harness = await pumpIntegrationApp(
      tester,
      initialLocation: AppRoutes.dashboard,
    );
    await settleFor(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.byType(AddExpenseScreen), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), '250');
    await tester.enterText(
      find.byType(TextField).at(1),
      'Integration Coffee',
    );
    await tester.tap(find.text('Save'));
    await settleFor(tester);

    // Back on the shell, with exactly one create call carrying the form data.
    expect(find.byType(AddExpenseScreen), findsNothing);
    expect(harness.transactions.createCalls, hasLength(1));
    final payload = harness.transactions.createCalls.single;
    expect(payload['amount'], 250.0);
    expect(payload['merchant'], 'Integration Coffee');
    expect(payload['type'], 'EXPENSE');

    // Tap the Feed destination by icon: the feed screen also renders a "Feed"
    // heading, so a text finder would be ambiguous.
    await tester.tap(find.byIcon(Icons.receipt_long_outlined));
    await settleFor(tester);
    expect(find.text('Integration Coffee'), findsWidgets);
  });

  testWidgets('validation stops an expense with no amount or merchant', (
    tester,
  ) async {
    final harness = await pumpIntegrationApp(
      tester,
      initialLocation: AppRoutes.dashboard,
    );
    await settleFor(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter an amount'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), '250');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a merchant name'), findsOneWidget);

    expect(harness.transactions.createCalls, isEmpty);
  });
}
