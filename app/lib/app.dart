import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'config/theme.dart';
import 'config/routes.dart';
import 'providers/theme_provider.dart';

/// Root widget for the Budgetly app.
class BudgetlyApp extends ConsumerStatefulWidget {
  /// Optional deep link path (e.g. `/join?code=XXX`) from the cold-start intent.
  final String? initialDeepLink;

  /// Maps a raw deep-link URI to a GoRouter path, or null if irrelevant.
  final String? Function(String rawUri)? onNewDeepLink;

  /// Stream of deep-link URIs arriving while the app is already running.
  final Stream<dynamic>? deepLinkStream;

  const BudgetlyApp({
    super.key,
    this.initialDeepLink,
    this.onNewDeepLink,
    this.deepLinkStream,
  });

  @override
  ConsumerState<BudgetlyApp> createState() => _BudgetlyAppState();
}

class _BudgetlyAppState extends ConsumerState<BudgetlyApp> {
  GoRouter? _router;
  StreamSubscription<dynamic>? _deepLinkSub;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _deepLinkSub?.cancel();
    super.dispose();
  }

  void _subscribeToDeepLinks(GoRouter router) {
    if (_deepLinkSub != null) return; // already listening
    final stream = widget.deepLinkStream;
    if (stream == null) return;

    _deepLinkSub = stream.listen((event) {
      final rawUri = event?.toString();
      if (rawUri == null || rawUri.isEmpty) return;
      final path = widget.onNewDeepLink?.call(rawUri);
      if (path != null) router.go(path);
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    // Build (once) a router that may carry the cold-start deep link.
    final router = _router ??= widget.initialDeepLink != null
        ? GoRouter(
            initialLocation: widget.initialDeepLink!,
            debugLogDiagnostics: true,
            routes: appRouteList,
          )
        : appRouter;

    _subscribeToDeepLinks(router);

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