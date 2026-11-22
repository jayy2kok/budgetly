import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:budgetly/config/budgetly_colors.dart';
import 'package:budgetly/data/category_service.dart';
import 'package:budgetly/data/transaction_service.dart';
import 'package:budgetly/models/category.dart';
import 'package:budgetly/models/family_group.dart';
import 'package:budgetly/models/transaction.dart';
import 'package:budgetly/models/user.dart';
import 'package:budgetly/providers/auth_provider.dart';
import 'package:budgetly/providers/category_provider.dart';
import 'package:budgetly/providers/family_provider.dart';
import 'package:budgetly/providers/service_providers.dart';
import 'package:budgetly/providers/transaction_provider.dart';
import 'package:budgetly/screens/expense/transaction_detail_screen.dart';

/// Regression test for: "New families get zero categories — the detail-screen
/// category sheet only offers 'Uncategorized'".
///
/// A family created by the API now starts with the eight default categories.
/// The detail screen must render them all, show the current selection, and
/// persist a pick through the transaction service.

class _FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState(
    status: AuthStatus.authenticated,
    user: User(
      id: 'user_001',
      googleId: 'google_001',
      displayName: 'Test User',
      email: 'test@budgetly.dev',
      createdAt: DateTime.utc(2026, 1, 1),
    ),
  );
}

class _FakeFamilyNotifier extends FamilyNotifier {
  _FakeFamilyNotifier(this._state);

  final FamilyState _state;

  @override
  FamilyState build() => _state;
}

class FakeCategoryService implements CategoryService {
  FakeCategoryService(this._categories);

  final List<Category> _categories;

  @override
  Future<List<Category>> getCategories(String familyGroupId) async =>
      _categories;

  @override
  Future<Category> createCategory(
    String familyGroupId,
    Map<String, dynamic> data,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<Category> updateCategory(
    String familyGroupId,
    String id,
    Map<String, dynamic> data,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteCategory(String familyGroupId, String id) async {}
}

class RecordingTransactionService implements TransactionService {
  RecordingTransactionService(this._initial);

  final List<Transaction> _initial;
  final List<Map<String, dynamic>> updates = [];

  @override
  Future<List<Transaction>> getTransactions(
    String familyGroupId, {
    int page = 0,
    int size = 20,
    TransactionType? type,
  }) async => _initial;

  @override
  Future<Transaction> getTransaction(String familyGroupId, String id) async =>
      _initial.firstWhere((t) => t.id == id);

  @override
  Future<Transaction> createTransaction(
    String familyGroupId,
    Map<String, dynamic> data,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<Transaction> updateTransaction(
    String familyGroupId,
    String id,
    Map<String, dynamic> data,
  ) async {
    debugPrint('MOCK SERVICE: updateTransaction called with data=$data');
    updates.add(data);
    final index = _initial.indexWhere((t) => t.id == id);
    final updated = Transaction(
      id: _initial[index].id,
      familyGroupId: _initial[index].familyGroupId,
      createdByUserId: _initial[index].createdByUserId,
      categoryId: (data['categoryId'] as String?)?.isEmpty ?? true
          ? null
          : data['categoryId'] as String?,
      amount: _initial[index].amount,
      currency: _initial[index].currency,
      merchant: _initial[index].merchant,
      type: _initial[index].type,
      sourceType: _initial[index].sourceType,
      transactionDate: _initial[index].transactionDate,
      createdAt: _initial[index].createdAt,
    );
    _initial[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteTransaction(String familyGroupId, String id) async {}
}

/// The eight categories the API seeds for every new family.
final _seededCategories = <Category>[
  Category(
    id: 'cat_groceries',
    familyGroupId: 'family_1',
    name: 'Groceries',
    icon: '🛒',
    budgetLimit: 0,
    color: '#34D399',
  ),
  Category(
    id: 'cat_dining',
    familyGroupId: 'family_1',
    name: 'Dining',
    icon: '🍽️',
    budgetLimit: 0,
    color: '#FB7185',
  ),
  Category(
    id: 'cat_transport',
    familyGroupId: 'family_1',
    name: 'Transport',
    icon: '🚗',
    budgetLimit: 0,
    color: '#60A5FA',
  ),
  Category(
    id: 'cat_housing',
    familyGroupId: 'family_1',
    name: 'Housing',
    icon: '🏠',
    budgetLimit: 0,
    color: '#FBBF24',
  ),
  Category(
    id: 'cat_bills',
    familyGroupId: 'family_1',
    name: 'Bills',
    icon: '📄',
    budgetLimit: 0,
    color: '#A78BFA',
  ),
  Category(
    id: 'cat_health',
    familyGroupId: 'family_1',
    name: 'Health',
    icon: '💊',
    budgetLimit: 0,
    color: '#2DD4BF',
  ),
  Category(
    id: 'cat_entertainment',
    familyGroupId: 'family_1',
    name: 'Entertainment',
    icon: '🎬',
    budgetLimit: 0,
    color: '#F472B6',
  ),
  Category(
    id: 'cat_shopping',
    familyGroupId: 'family_1',
    name: 'Shopping',
    icon: '🛍️',
    budgetLimit: 0,
    color: '#FB923C',
  ),
];

final _family = FamilyGroup(
  id: 'family_1',
  name: 'Test Family',
  monthlyBudgetLimit: 0,
  createdByUserId: 'user_001',
  createdAt: DateTime.utc(2026, 1, 1),
);

Transaction _uncategorizedTransaction({
  String? accountLast4,
  String? bankName,
}) => Transaction(
  id: 'txn_1',
  familyGroupId: 'family_1',
  createdByUserId: 'user_001',
  amount: 4710,
  currency: 'INR',
  merchant: 'AMAZON PAY IN U',
  type: TransactionType.expense,
  sourceType: SourceType.llmServer,
  accountLast4: accountLast4,
  bankName: bankName,
  transactionDate: DateTime.utc(2026, 11, 18),
  createdAt: DateTime.utc(2026, 11, 18),
);

Future<ProviderContainer> pumpTransactionDetail(
  WidgetTester tester,
  RecordingTransactionService transactionServiceParam, {
  Transaction? transaction,
}) async {
  GoogleFonts.config.allowRuntimeFetching = false;

  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final transactions = [transaction ?? _uncategorizedTransaction()];
  final transactionService = RecordingTransactionService(transactions);

  final container = ProviderContainer(
    overrides: [
      authProvider.overrideWith(_FakeAuthNotifier.new),
      familyProvider.overrideWith(
        () => _FakeFamilyNotifier(
          FamilyState(currentFamily: _family, members: const []),
        ),
      ),
      categoryServiceProvider.overrideWithValue(
        FakeCategoryService(_seededCategories),
      ),
      transactionServiceProvider.overrideWithValue(transactionService),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: ThemeData(extensions: [BudgetlyColors.dark]),
        home: const TransactionDetailScreen(transactionId: 'txn_1'),
      ),
    ),
  );
  await tester.pumpAndSettle();

  // Seed the state both screens read: the transaction list and the category
  // list loaded from the (now-seeded) family.
  container.read(transactionProvider.notifier).state = TransactionState(
    transactions: transactions,
  );
  container.read(categoryProvider.notifier).state = CategoryState(
    categories: _seededCategories,
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('category sheet lists the seeded default categories', (
    tester,
  ) async {
    final transactionService = RecordingTransactionService([
      _uncategorizedTransaction(),
    ]);
    await pumpTransactionDetail(tester, transactionService);

    expect(find.text('Uncategorized'), findsOneWidget);

    await tester.tap(find.text('Uncategorized'));
    await tester.pumpAndSettle();

    expect(find.text('Category'), findsWidgets);
    for (final category in _seededCategories) {
      expect(
        find.text(category.name),
        findsOneWidget,
        reason: 'the picker must offer ${category.name}',
      );
    }
  });

  testWidgets('shows the masked account and bank when present', (
    tester,
  ) async {
    final transactionService = RecordingTransactionService([
      _uncategorizedTransaction(accountLast4: '1234', bankName: 'HDFC Bank'),
    ]);
    await pumpTransactionDetail(
      tester,
      transactionService,
      transaction: _uncategorizedTransaction(
        accountLast4: '1234',
        bankName: 'HDFC Bank',
      ),
    );

    expect(find.text('Account'), findsOneWidget);
    expect(find.text('A/C •••• 1234'), findsOneWidget);
    expect(find.text('Bank'), findsOneWidget);
    expect(find.text('HDFC Bank'), findsOneWidget);
  });

  testWidgets('picking a category from the sheet persists it', (tester) async {
    final transactionService = RecordingTransactionService([
      _uncategorizedTransaction(),
    ]);
    final container = await pumpTransactionDetail(tester, transactionService);

    await tester.tap(find.text('Uncategorized'));
    await tester.pumpAndSettle();
    // Verify sheet is open
    expect(find.text('Category'), findsWidgets);
    debugPrint('Sheet open, looking for Groceries');

    // Watch for any state changes
    debugPrint(
      'Before tap, transaction state: ${container.read(transactionProvider).transactions.map((t) => t.categoryId).toList()}',
    );

    await tester.tap(
      find.ancestor(
        of: find.text('Groceries'),
        matching: find.byType(ListTile),
      ),
    );
    await tester.pumpAndSettle();

    // Check provider state directly - that's the real test
    final updatedTxn = container
        .read(transactionProvider)
        .transactions
        .firstWhere((t) => t.id == 'txn_1');
    expect(updatedTxn.categoryId, 'cat_groceries');
    expect(
      find.text('Groceries'),
      findsOneWidget,
      reason: 'the detail row shows the newly picked category',
    );
  });
}
