import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'config/theme.dart';
import 'config/routes.dart';
import 'providers/push_providers.dart';
import 'providers/theme_provider.dart';
import 'services/push/push_messaging_service.dart';

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
  StreamSubscription<PushNotificationPayload>? _pushForegroundSub;
  PushTapHandler? _pushTapHandler;
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    // Subscribe to warm deep-link events as early as possible.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _subscribeToDeepLinks();
      _subscribeToPush();
    });
  }

  @override
  void dispose() {
    _deepLinkSub?.cancel();
    _pushForegroundSub?.cancel();
    unawaited(_pushTapHandler?.dispose());
    super.dispose();
  }

  /// Routes tapped notifications (background/terminated) to their screen and
  /// surfaces foreground alerts without stealing focus.
  void _subscribeToPush() {
    if (_pushTapHandler != null) return;
    final messaging = ref.read(pushMessagingServiceProvider);

    _pushTapHandler = PushTapHandler(
      taps: messaging.onMessageOpened,
      onNavigate: (location) => (_router ?? appRouter).go(location),
    );

    _pushForegroundSub = messaging.onForegroundMessage.listen((payload) {
      final text = payload.body?.isNotEmpty == true
          ? payload.body!
          : payload.title?.isNotEmpty == true
              ? payload.title!
              : 'New expense alert';
      _messengerKey.currentState?.showSnackBar(SnackBar(content: Text(text)));
    });
  }

  void _subscribeToDeepLinks() {
    if (_deepLinkSub != null) return; // already listening
    final stream = widget.deepLinkStream;
    if (stream == null) return;

    _deepLinkSub = stream.listen((event) {
      final rawUri = event?.toString();
      if (rawUri == null || rawUri.isEmpty) return;
      debugPrint('🔗 Dart received EventChannel deep link: $rawUri');
      final path = widget.onNewDeepLink?.call(rawUri);
      debugPrint('🔗 Converted to: $path');
      if (path != null) {
        debugPrint('🔗 Calling router.go($path)');
        // Navigate the router actually mounted in the tree.
        (_router ?? appRouter).go(path);
      } else {
        debugPrint('⚠️ Deep link path was null, ignoring');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    // Build (once) a router that may carry the cold-start deep link.
    // overridePlatformDefaultLocation prevents GoRouter from preferring the
    // RAW platform deep-link URI as the initial route (see routes.dart).
    final router = _router ??= GoRouter(
      initialLocation: widget.initialDeepLink ?? AppRoutes.login,
      overridePlatformDefaultLocation: true,
      redirect: deepLinkRedirect,
      routes: appRouteList,
    );

    return MaterialApp.router(
      title: 'Budgetly',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messengerKey,
      theme: BudgetlyTheme.lightTheme(),
      darkTheme: BudgetlyTheme.darkTheme(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}