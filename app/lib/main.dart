import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

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

  // Extract code from query param
  final code = uri.queryParameters['code'];
  final path = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
  final extractedCode = code ?? path;

  // Normalize to /join route
  if (extractedCode != null) {
    return '/join?code=$extractedCode';
  }
  return '/join';
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Catch any Flutter framework errors
  FlutterError.onError = (details) {
    debugPrint('⚠️ FlutterError: ${details.exception}');
    debugPrint('Stack: ${details.stack}');
  };

  // Listen for initial intent (deep links on Android)
  try {
    final initialIntent = await SystemChannels.platform
        .invokeMethod<Map<dynamic, dynamic>>('getInitialIntent');
    if (initialIntent != null && initialIntent['data'] != null) {
      final rawUri = initialIntent['data'] as String;
      _initialDeepLink = _deepLinkToGoRouterPath(rawUri);
      debugPrint(
          '🔗 Budgetly opened via deep link: $rawUri -> ${_initialDeepLink ?? "unknown"}');
    }
  } catch (e) {
    debugPrint('⚠️ Failed to read initial intent: $e');
  }

  debugPrint('🚀 Budgetly starting...');
  runApp(ProviderScope(
    child: BudgetlyApp(initialDeepLink: _initialDeepLink),
  ));
}
