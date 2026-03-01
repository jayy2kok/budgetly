import 'package:go_router/go_router.dart';

import '../screens/shell/app_shell.dart';
import '../screens/auth/login_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/feed/transaction_feed_screen.dart';
import '../screens/budget/monthly_budget_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/expense/add_expense_screen.dart';
import '../screens/expense/transaction_detail_screen.dart';
import '../screens/messages/message_inbox_screen.dart';
import '../screens/messages/ignored_messages_screen.dart';
import '../screens/settings/link_family_screen.dart';
import '../screens/settings/family_group_settings_screen.dart';

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
  static const String ignoredMessages = '/messages/ignored';
  static const String linkFamily = '/settings/link-family';
  static const String familySettings = '/settings/family';
}

/// The app's router configuration using GoRouter.
final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.login,
  routes: [
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
        return TransactionDetailScreen(transactionId: id);
      },
    ),
    GoRoute(
      path: AppRoutes.messageInbox,
      builder: (context, state) => const MessageInboxScreen(),
    ),
    GoRoute(
      path: AppRoutes.ignoredMessages,
      builder: (context, state) => const IgnoredMessagesScreen(),
    ),
    GoRoute(
      path: AppRoutes.linkFamily,
      builder: (context, state) => const LinkFamilyScreen(),
    ),
    GoRoute(
      path: AppRoutes.familySettings,
      builder: (context, state) => const FamilyGroupSettingsScreen(),
    ),
  ],
);
