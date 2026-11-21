import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:budgetly/config/budgetly_colors.dart';
import 'package:budgetly/data/mock/sample_data.dart';
import 'package:budgetly/models/family_group.dart';
import 'package:budgetly/models/transaction.dart';
import 'package:budgetly/models/user.dart';
import 'package:budgetly/providers/auth_provider.dart';
import 'package:budgetly/providers/budget_provider.dart';
import 'package:budgetly/providers/category_provider.dart';
import 'package:budgetly/providers/family_provider.dart';
import 'package:budgetly/providers/sms_provider.dart';
import 'package:budgetly/providers/transaction_provider.dart';
import 'package:budgetly/screens/dashboard/dashboard_screen.dart';

// ── Fakes ─────────────────────────────────────────────────────────

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this._user);

  final User? _user;

  @override
  AuthState build() => AuthState(
    status: AuthStatus.authenticated,
    user: _user,
  );
}

class _FakeFamilyNotifier extends FamilyNotifier {
  _FakeFamilyNotifier(this._state);

  final FamilyState _state;

  @override
  FamilyState build() => _state;
}

/// BudgetNotifier whose state is fixed at construction time.
class _FakeBudgetNotifier extends BudgetNotifier {
  _FakeBudgetNotifier(this._state);

  final BudgetState _state;

  @override
  BudgetState build() => _state;

  @override
  Future<void> loadDashboard(String familyGroupId) async {}
}

class _FakeCategoryNotifier extends CategoryNotifier {
  _FakeCategoryNotifier(this._state);

  final CategoryState _state;

  @override
  CategoryState build() => _state;

  @override
  Future<void> loadCategories(String familyGroupId) async {}
}

class _FakeTransactionNotifier extends TransactionNotifier {
  _FakeTransactionNotifier(this._state);

  final TransactionState _state;

  @override
  TransactionState build() => _state;

  @override
  Future<void> loadTransactions({TransactionType? type}) async {}
}

class _FakeSmsNotifier extends SmsNotifier {
  _FakeSmsNotifier(this._state);

  final SmsState _state;

  @override
  SmsState build() => _state;
}

// ── Test rig ──────────────────────────────────────────────────────

/// Pumps [DashboardScreen] with a fixed budget and no network-backed services.
Future<ProviderContainer> pumpDashboard(
  WidgetTester tester, {
  required BudgetState budget,
}) async {
  GoogleFonts.config.allowRuntimeFetching = false;

  tester.view.physicalSize = const Size(800, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final familyGroup = FamilyGroup(
    id: SampleData.familyGroup.id,
    name: SampleData.familyGroup.name,
    monthlyBudgetLimit: budget.monthlyLimit,
    createdByUserId: SampleData.familyGroup.createdByUserId,
    createdAt: SampleData.familyGroup.createdAt,
  );

  final container = ProviderContainer(
    overrides: [
      authProvider.overrideWith(() => _FakeAuthNotifier(SampleData.user1)),
      familyProvider.overrideWith(
        () => _FakeFamilyNotifier(
          FamilyState(
            currentFamily: familyGroup,
            members: SampleData.members,
            isLoading: false,
          ),
        ),
      ),
      budgetProvider.overrideWith(() => _FakeBudgetNotifier(budget)),
      categoryProvider.overrideWith(
        () => _FakeCategoryNotifier(const CategoryState()),
      ),
      transactionProvider.overrideWith(
        () => _FakeTransactionNotifier(const TransactionState()),
      ),
      // Consent already prompted so the post-frame check never opens a sheet.
      smsProvider.overrideWith(
        () => _FakeSmsNotifier(
          const SmsState(hasPromptedForConsent: true),
        ),
      ),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: ThemeData(extensions: [BudgetlyColors.dark]),
        home: const DashboardScreen(),
      ),
    ),
  );

  // Run the post-frame loads, then fire the 500 ms SMS-consent timer so no
  // timer is left pending when the test ends.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pumpAndSettle();

  return container;
}

void main() {
  testWidgets(
    'no budget with spending shows a "set a budget" empty state, not a ring',
    (tester) async {
      await pumpDashboard(
        tester,
        budget: const BudgetState(monthlyLimit: 0, totalSpent: 4710),
      );

      // Issue #22: a fresh family with monthlyBudgetLimit = 0 must get an
      // explicit "set a budget" state instead of a contradictory ring.
      expect(find.text('No budget set'), findsOneWidget);
      expect(find.text('Set a budget'), findsOneWidget);
      expect(find.textContaining('Set a monthly budget'), findsOneWidget);
      // Spending is still surfaced so no information is hidden.
      expect(find.text('₹4,710 spent this month'), findsOneWidget);
      // No ring figures or badges for a limit that was never set.
      expect(find.text('LEFT TO SPEND'), findsNothing);
      expect(find.text('OVER BUDGET'), findsNothing);
      expect(find.text('ON TRACK'), findsNothing);
    },
  );

  testWidgets(
    'over budget shows a negative overage, never a positive "left to spend"',
    (tester) async {
      await pumpDashboard(
        tester,
        budget: const BudgetState(monthlyLimit: 1000, totalSpent: 1500),
      );

      expect(find.text('OVER BUDGET'), findsOneWidget);
      expect(find.text('OVER BY'), findsOneWidget);
      expect(find.text('−₹500', findRichText: true), findsOneWidget);
      // The ring must never render a positive leftover while over budget.
      expect(find.text('LEFT TO SPEND'), findsNothing);
      expect(find.text('₹500', findRichText: true), findsNothing);
    },
  );

  testWidgets('within budget still shows a positive "left to spend"', (
    tester,
  ) async {
    await pumpDashboard(
      tester,
      budget: const BudgetState(monthlyLimit: 1000, totalSpent: 400),
    );

    expect(find.text('LEFT TO SPEND'), findsOneWidget);
    expect(find.text('ON TRACK'), findsOneWidget);
    expect(find.text('₹600', findRichText: true), findsOneWidget);
    expect(find.text('OVER BUDGET'), findsNothing);
  });
}