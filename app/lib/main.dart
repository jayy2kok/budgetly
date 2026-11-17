import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'config/routes.dart' show deepLinkToGoRouterPath;

/// Native method channel exposed by MainActivity.kt.
const MethodChannel _deepLinkMethodChannel = MethodChannel('budgetly/deep_link');

/// Stream of deep-link URIs delivered while the app is already running.
const EventChannel _deepLinkEventChannel =
    EventChannel('budgetly/deep_link/events');

/// Holds the initial deep link URI received from Android intent.
String? _initialDeepLink;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Catch any Flutter framework errors.
  FlutterError.onError = (details) {
    debugPrint('⚠️ FlutterError: ${details.exception}');
    debugPrint('Stack: ${details.stack}');
  };

  // Cold-start deep link: ask the native side for the intent that launched us.
  // (Flutter's own getInitialRoute()/getInitialIntent() do not surface VIEW
  // intents reliably across OEMs, so we bridge through MainActivity.)
  String? rawUri;
  try {
    rawUri = await _deepLinkMethodChannel
        .invokeMethod<String>('initialLink');
  } catch (e) {
    debugPrint('⚠️ Failed to read initial deep link: $e');
  }

  // Fallback: the Flutter engine also surfaces the cold-start VIEW intent as
  // `defaultRouteName` — but as the RAW URI (e.g. budgetly://join/?code=…),
  // which GoRouter must never use directly as a location.
  if (rawUri == null || rawUri.isEmpty) {
    final def = WidgetsBinding.instance.platformDispatcher.defaultRouteName;
    if (def.isNotEmpty && def != '/') rawUri = def;
  }

  if (rawUri != null && rawUri.isNotEmpty) {
    _initialDeepLink = deepLinkToGoRouterPath(rawUri);
    debugPrint('🔗 Budgetly opened via deep link: $rawUri -> $_initialDeepLink');
  }

  debugPrint('🚀 Budgetly starting...');
  runApp(ProviderScope(
    child: BudgetlyApp(
      initialDeepLink: _initialDeepLink,
      onNewDeepLink: (rawUri) {
        final path = deepLinkToGoRouterPath(rawUri);
        if (path != null) {
          debugPrint('🔗 Budgetly received deep link (warm): $rawUri -> $path');
          return path;
        }
        return null;
      },
      deepLinkStream: _deepLinkEventChannel.receiveBroadcastStream(),
    ),
  ));
}