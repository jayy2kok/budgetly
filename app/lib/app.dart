import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/theme.dart';
import 'config/routes.dart';
import 'providers/theme_provider.dart';

/// Root widget for the Budgetly app.
class BudgetlyApp extends ConsumerWidget {
  const BudgetlyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Budgetly',
      debugShowCheckedModeBanner: false,
      theme: BudgetlyTheme.lightTheme(),
      darkTheme: BudgetlyTheme.darkTheme(),
      themeMode: themeMode,
      routerConfig: appRouter,
    );
  }
}
