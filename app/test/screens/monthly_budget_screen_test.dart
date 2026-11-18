import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:budgetly/config/budgetly_colors.dart';
import 'package:budgetly/data/budget_service.dart';
import 'package:budgetly/data/category_service.dart';
import 'package:budgetly/data/transaction_service.dart';
import 'package:budgetly/data/mock/sample_data.dart';
import 'package:budgetly/models/category.dart';
import 'package:budgetly/models/family_member.dart';
import 'package:budgetly/models/transaction.dart';
import 'package:budgetly/models/user.dart';
import 'package:budgetly/providers/auth_provider.dart';
import 'package:budgetly/providers/category_provider.dart';
import 'package:budgetly/providers/family_provider.dart';
import 'package:budgetly/providers/service_providers.dart';
import 'package:budgetly/screens/budget/monthly_budget_screen.dart';

// ── Fakes ─────────────────────────────────────────────────────────

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this._user);

  final User? _user;

  @override
  AuthState build() => AuthState(
    status: _user == null ? AuthStatus.unauthenticated : AuthStatus.authenticated,
    user: _user,
  );
}

class _FakeFamilyNotifier extends FamilyNotifier {
  _FakeFamilyNotifier(this._state);

  final FamilyState _state;

  @override
  FamilyState build() => _state;
}

/// CategoryService whose list is fixed at construction time.
class _FakeCategoryService implements CategoryService {
  _FakeCategoryService(this._categories);

  final List<Category> _categories;
  int createCalls = 0;

  @override
  Future<List<Category>> getCategories(String familyGroupId) async =>
      _categories;

  @override
  Future<Category> createCategory(
      String familyGroupId, Map<String, dynamic> data) async {
    createCalls++;
    return Category(
      id: 'cat_new',
      familyGroupId: familyGroupId,
      name: data['name'] as String,
      icon: data['icon'] as String? ?? '🛒',
      budgetLimit: (data['budgetLimit'] as num?)?.toDouble() ?? 0,
      color: data['color'] as String? ?? '#5B5EF4',
    );
  }

  @override
  Future<Category> updateCategory(
          String familyGroupId, String id, Map<String, dynamic> data) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteCategory(String familyGroupId, String id) async {}
}

// ── Test rig ──────────────────────────────────────────────────────

/// Services that need no network. The screen reads the budget total and the
/// transaction list; neither matters for the category list, so they are
/// stubbed out rather than letting the real API client initialise.
class _NoopBudgetService implements BudgetService {
  @override
  Future<Map<String, dynamic>> getDashboardData(String familyGroupId) async =>
      const {};

  @override
  Future<Map<String, dynamic>> getBudgetSummary(
      String familyGroupId, String? month) async => const {};

  @override
  Future<void> updateBudgetLimit(String familyGroupId, double newLimit) async {}
}

class _NoopTransactionService implements TransactionService {
  @override
  Future<List<Transaction>> getTransactions(
    String familyGroupId, {
    int page = 0,
    int size = 20,
    TransactionType? type,
  }) async =>
      const [];

  @override
  Future<Transaction> getTransaction(String familyGroupId, String id) async =>
      throw UnimplementedError();

  @override
  Future<Transaction> createTransaction(
          String familyGroupId, Map<String, dynamic> data) async =>
      throw UnimplementedError();

  @override
  Future<Transaction> updateTransaction(
          String familyGroupId, String id, Map<String, dynamic> data) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteTransaction(String familyGroupId, String id) async {}
}

/// Pumps [MonthlyBudgetScreen] with a fixed category list and the given
/// member role for the current user.
Future<ProviderContainer> pumpBudget(
  WidgetTester tester, {
  required List<Category> categories,
  MemberRole role = MemberRole.admin,
}) async {
  GoogleFonts.config.allowRuntimeFetching = false;

  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final member = FamilyMember(
    id: 'member_001',
    userId: SampleData.user1.id,
    familyGroupId: SampleData.familyGroup.id,
    role: role,
    status: MemberStatus.active,
    joinedAt: DateTime.utc(2026, 1, 1),
  );

  final service = _FakeCategoryService(categories);

  final container = ProviderContainer(
    overrides: [
      authProvider.overrideWith(() => _FakeAuthNotifier(SampleData.user1)),
      familyProvider.overrideWith(
        () => _FakeFamilyNotifier(
          FamilyState(
            currentFamily: SampleData.familyGroup,
            members: [member],
            isLoading: false,
          ),
        ),
      ),
      categoryServiceProvider.overrideWithValue(service),
      budgetServiceProvider.overrideWithValue(_NoopBudgetService()),
      transactionServiceProvider.overrideWithValue(_NoopTransactionService()),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: ThemeData(extensions: [BudgetlyColors.dark]),
        home: const MonthlyBudgetScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();

  // Seed the category state the screen reads from the provider.
  container.read(categoryProvider.notifier).state =
      CategoryState(categories: categories);
  await tester.pumpAndSettle();

  return container;
}

void main() {
  testWidgets('empty family shows an empty state, not a blank area', (
    tester,
  ) async {
    await pumpBudget(tester, categories: const []);

    expect(find.text('BY CATEGORY'), findsOneWidget);
    expect(
      find.text('No categories yet'),
      findsOneWidget,
      reason: 'an empty family must see an explanation, not a blank region',
    );
    // The admin can create the first category straight from the empty state.
    expect(find.text('Add your first category'), findsOneWidget);
  });

  testWidgets('admin CTA in the empty state opens the add-category sheet', (
    tester,
  ) async {
    await pumpBudget(tester, categories: const []);

    await tester.tap(find.text('Add your first category'));
    await tester.pumpAndSettle();

    // The sheet opens with its emoji picker, name and budget fields.
    expect(find.text('Icon'), findsOneWidget);
    expect(
      find.widgetWithText(TextField, 'e.g. Travel'),
      findsOneWidget,
      reason: 'the add-category sheet should be open with a name field',
    );
    expect(find.text('Save Category'), findsOneWidget);
  });

  testWidgets('a member (non-admin) sees guidance without an admin CTA', (
    tester,
  ) async {
    await pumpBudget(
      tester,
      categories: const [],
      role: MemberRole.member,
    );

    expect(find.text('No categories yet'), findsOneWidget);
    expect(
      find.text('Ask a family admin to add a category so expenses can be tracked here.'),
      findsOneWidget,
    );
    expect(
      find.text('Add Category'),
      findsNothing,
      reason: 'members must not see the admin-only create action',
    );
  });

  testWidgets('no empty state once a category exists', (tester) async {
    await pumpBudget(
      tester,
      categories: const [
        Category(
          id: 'cat_1',
          familyGroupId: 'fam_1',
          name: 'Groceries',
          icon: '🛒',
          budgetLimit: 5000,
          color: '#5B5EF4',
        ),
      ],
    );

    expect(find.text('No categories yet'), findsNothing);
    expect(find.text('Groceries'), findsOneWidget);
  });
}