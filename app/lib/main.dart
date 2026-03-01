import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Catch any Flutter framework errors
  FlutterError.onError = (details) {
    debugPrint('⚠️ FlutterError: ${details.exception}');
    debugPrint('Stack: ${details.stack}');
  };

  debugPrint('🚀 Budgetly starting...');
  runApp(const ProviderScope(child: BudgetlyApp()));
}
