import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:budgetly/config/budgetly_colors.dart';
import 'package:budgetly/config/routes.dart';
import 'package:budgetly/screens/shell/app_shell.dart';

/// Stub page so the shell test never builds the real tab screens.
class _StubPage extends StatelessWidget {
  final String label;

  const _StubPage({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(label));
  }
}

/// Pumps the real [AppShell] inside a minimal GoRouter that starts on [path].
Future<void> pumpShell(WidgetTester tester, String path) async {
  GoogleFonts.config.allowRuntimeFetching = false;

  final router = GoRouter(
    initialLocation: path,
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            builder: (context, state) => const _StubPage(label: 'Home'),
          ),
          GoRoute(
            path: AppRoutes.feed,
            builder: (context, state) => const _StubPage(label: 'Feed'),
          ),
          GoRoute(
            path: AppRoutes.budget,
            builder: (context, state) => const _StubPage(label: 'Budget'),
          ),
          GoRoute(
            path: AppRoutes.settings,
            builder: (context, state) => const _StubPage(label: 'Settings'),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.addExpense,
        builder: (context, state) => const _StubPage(label: 'Add Expense'),
      ),
    ],
  );

  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      theme: ThemeData(extensions: [BudgetlyColors.dark]),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Home and Feed tabs show the add-expense FAB', (tester) async {
    await pumpShell(tester, AppRoutes.dashboard);
    expect(find.byType(FloatingActionButton), findsOneWidget);

    await pumpShell(tester, AppRoutes.feed);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('Budget and Settings tabs hide the add-expense FAB', (
    tester,
  ) async {
    await pumpShell(tester, AppRoutes.budget);
    expect(find.byType(FloatingActionButton), findsNothing);

    await pumpShell(tester, AppRoutes.settings);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('FAB on Home pushes the add-expense screen', (tester) async {
    await pumpShell(tester, AppRoutes.dashboard);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('Add Expense'), findsOneWidget);
    // The add-expense screen is a standalone route, not inside the shell.
    expect(find.byType(NavigationBar), findsNothing);
  });
}