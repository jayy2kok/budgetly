import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'config/theme.dart';
import 'config/routes.dart';
import 'providers/theme_provider.dart';

/// Root widget for the Budgetly app.
class BudgetlyApp extends ConsumerWidget {
  /// Optional deep link path (e.g. `/join?code=XXX`) from Android intent.
  final String? initialDeepLink;

  const BudgetlyApp({super.key, this.initialDeepLink});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    // Build router with initial deep link location if present
    final router = initialDeepLink != null
        ? GoRouter(
            initialLocation: initialDeepLink!,
            debugLogDiagnostics: true,
            routes: appRouteList,
          )
        : appRouter;

    return MaterialApp.router(
      title: 'Budgetly',
      debugShowCheckedModeBanner: false,
      theme: BudgetlyTheme.lightTheme(),
      darkTheme: BudgetlyTheme.darkTheme(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
