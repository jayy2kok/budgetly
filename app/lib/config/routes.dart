import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/transaction.dart';
import '../screens/shell/app_shell.dart';
import '../screens/auth/login_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/feed/transaction_feed_screen.dart';
import '../screens/budget/monthly_budget_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/expense/add_expense_screen.dart';
import '../screens/expense/transaction_detail_screen.dart';
import '../screens/messages/message_inbox_screen.dart';
import '../screens/settings/link_family_screen.dart';
import '../screens/settings/family_group_settings_screen.dart';
import '../screens/settings/profile_screen.dart';
import '../screens/settings/join_family_screen.dart';
import '../screens/settings/pattern_registry_screen.dart';
import '../screens/settings/pattern_builder_screen.dart';

/// Route path constants.
class AppRoutes {
  AppRoutes._();

  static const String login = '/login';
  static const String dashboard = '/dashboard';
  static const String feed = '/feed';
  static const String budget = '/budget';
  static const String settings = '/settings';
  static const String addExpense = '/add-expense';
  static const String transactionDetail = '/transaction';
  static const String messageInbox = '/messages';
  static const String linkFamily = '/settings/link-family';
  static const String familySettings = '/settings/family';
  static const String profile = '/settings/profile';
  static const String joinFamily = '/join';
  static const String patternRegistry = '/settings/patterns';
  static const String patternBuilder = '/settings/patterns/new';
}

/// All route definitions, reused by both the default and deep-link routers.
final List<RouteBase> appRouteList = [
  // ── Auth ──
  GoRoute(
    path: AppRoutes.login,
    builder: (context, state) => const LoginScreen(),
  ),

  // ── Bottom nav shell ──
  ShellRoute(
    builder: (context, state, child) => AppShell(child: child),
    routes: [
      GoRoute(
        path: AppRoutes.dashboard,
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: DashboardScreen()),
      ),
      GoRoute(
        path: AppRoutes.feed,
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: TransactionFeedScreen()),
      ),
      GoRoute(
        path: AppRoutes.budget,
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: MonthlyBudgetScreen()),
      ),
      GoRoute(
        path: AppRoutes.settings,
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: SettingsScreen()),
      ),
    ],
  ),

  // ── Standalone screens ──
  GoRoute(
    path: AppRoutes.addExpense,
    builder: (context, state) => const AddExpenseScreen(),
  ),
  GoRoute(
    path: '${AppRoutes.transactionDetail}/:id',
    builder: (context, state) {
      final id = state.pathParameters['id']!;
      // Callers that already hold the transaction (the inbox, which may show
      // rows older than the feed's first page) pass it along so the detail
      // screen does not have to re-resolve it from the paged provider list.
      return TransactionDetailScreen(
        transactionId: id,
        transaction: state.extra as Transaction?,
      );
    },
  ),
  GoRoute(
    path: AppRoutes.messageInbox,
    builder: (context, state) => const MessageInboxScreen(),
  ),
  GoRoute(
    path: AppRoutes.linkFamily,
    builder: (context, state) => const LinkFamilyScreen(),
  ),
  GoRoute(
    path: AppRoutes.familySettings,
    builder: (context, state) => const FamilyGroupSettingsScreen(),
  ),
  GoRoute(
    path: AppRoutes.profile,
    builder: (context, state) => const ProfileScreen(),
  ),
  GoRoute(
    path: AppRoutes.patternRegistry,
    builder: (context, state) => const PatternRegistryScreen(),
  ),
  GoRoute(
    path: AppRoutes.patternBuilder,
    builder: (context, state) => PatternBuilderScreen(
      messageId: state.uri.queryParameters['messageId'],
      patternId: state.uri.queryParameters['patternId'],
    ),
  ),

  // ── Join Family — from deep link or manual entry ──
  GoRoute(
    path: AppRoutes.joinFamily,
    builder: (context, state) {
      final deepLinkCode = state.uri.queryParameters['code'];
      return JoinFamilyScreen(deepLinkCode: deepLinkCode);
    },
  ),
];

/// Convert a deep-link URI to a GoRouter-compatible path.
///
/// Supports:
///   budgetly://join?code=XXX
///   budgetly://join/?code=XXX          (Android-normalized form)
///   budgetly://join/XXX                (path-based)
///   https://budgetly.app/join?code=XXX
String? deepLinkToGoRouterPath(String uriStr) {
  final uri = Uri.tryParse(uriStr);
  if (uri == null) return null;
  if (uriStr.isEmpty) return null;

  // Query-param form:  .../join?code=XXX
  final code = uri.queryParameters['code'];
  if (code != null && code.isNotEmpty) {
    return '/join?code=$code';
  }

  // Path-based form, only for real deep-link schemes/hosts:
  //   budgetly://join/XXX, https://budgetly.app/join/XXX
  if (uriStr.toLowerCase().startsWith('budgetly://') ||
      uri.host == 'budgetly.app') {
    final segments =
        uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isNotEmpty) {
      return '/join?code=${segments.first}';
    }
  }

  return '/join';
}

/// Catch-all redirect so a RAW deep-link location is normalized before
/// GoRouter tries to match it (e.g. the platform's initial route on cold
/// start, or a stray navigator call). App-internal paths are never touched.
String? deepLinkRedirect(BuildContext context, GoRouterState state) {
  final loc = state.uri.toString();
  if (loc.startsWith('budgetly://') || loc.startsWith('https://budgetly.app')) {
    final converted = deepLinkToGoRouterPath(loc);
    if (converted != null && converted != loc) return converted;
  }
  return null;
}

/// The app's default router configuration.
///
/// `overridePlatformDefaultLocation: true` is critical: without it, GoRouter
/// prefers Flutter's `defaultRouteName` over `initialLocation` — and on a
/// cold start via a VIEW intent that value is the RAW deep-link URI
/// (`budgetly://join/?code=...`), which matches no route and yields the
/// built-in "Page Not Found" screen. All deep-link handling goes through our
/// own Android bridge ([deepLinkToGoRouterPath] + [deepLinkRedirect]).
final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.login,
  overridePlatformDefaultLocation: true,
  redirect: deepLinkRedirect,
  routes: appRouteList,
);
