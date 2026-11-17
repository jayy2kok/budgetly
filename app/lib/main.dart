import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

/// Native method channel exposed by MainActivity.kt.
const MethodChannel _deepLinkMethodChannel = MethodChannel('budgetly/deep_link');

/// Stream of deep-link URIs delivered while the app is already running.
const EventChannel _deepLinkEventChannel =
    EventChannel('budgetly/deep_link/events');

/// Holds the initial deep link URI received from Android intent.
String? _initialDeepLink;

/// Convert a deep link to a GoRouter-compatible path.
/// Supports:
///   budgetly://join?code=XXX
///   https://budgetly.app/join?code=XXX
///   budgetly://join/XXX  (path-based)
String? _deepLinkToGoRouterPath(String uriStr) {
  final uri = Uri.tryParse(uriStr);
  if (uri == null) return null;

  // Extract code from query param, falling back to the first path segment.
  final code = uri.queryParameters['code'];
  final path = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
  final extractedCode = code ?? path;

  if (extractedCode != null && extractedCode.isNotEmpty) {
    return '/join?code=$extractedCode';
  }
  return '/join';
}

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
  try {
    final rawUri = await _deepLinkMethodChannel
        .invokeMethod<String>('initialLink');
    if (rawUri != null && rawUri.isNotEmpty) {
      _initialDeepLink = _deepLinkToGoRouterPath(rawUri);
      debugPrint('🔗 Budgetly opened via deep link: $rawUri -> $_initialDeepLink');
    }
  } catch (e) {
    debugPrint('⚠️ Failed to read initial deep link: $e');
  }

  debugPrint('🚀 Budgetly starting...');
  runApp(ProviderScope(
    child: BudgetlyApp(
      initialDeepLink: _initialDeepLink,
      onNewDeepLink: (rawUri) {
        final path = _deepLinkToGoRouterPath(rawUri);
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