import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:budgetly/config/budgetly_colors.dart';
import 'package:budgetly/data/mock/sample_data.dart';
import 'package:budgetly/data/transaction_service.dart';
import 'package:budgetly/models/transaction.dart';
import 'package:budgetly/providers/auth_provider.dart';
import 'package:budgetly/providers/category_provider.dart';
import 'package:budgetly/providers/family_provider.dart';
import 'package:budgetly/providers/service_providers.dart';
import 'package:budgetly/screens/expense/add_expense_screen.dart';

/// TransactionService that records create calls instead of hitting the network.
class _RecordingTransactionService implements TransactionService {
  _RecordingTransactionService({this.error});

  final Object? error;
  int createCalls = 0;
  Map<String, dynamic>? lastPayload;

  @override
  Future<List<Transaction>> getTransactions(
    String familyGroupId, {
    int page = 0,
    int size = 20,
    TransactionType? type,
  }) async =>
      [];

  @override
  Future<Transaction> getTransaction(String familyGroupId, String id) async =>
      throw UnimplementedError();

  @override
  Future<Transaction> createTransaction(
      String familyGroupId, Map<String, dynamic> data) async {
    createCalls++;
    lastPayload = data;
    if (error != null) throw error!;
    return Transaction(
      id: 'txn_new',
      familyGroupId: familyGroupId,
      amount: (data['amount'] as num).toDouble(),
      currency: data['currency'] as String? ?? 'INR',
      merchant: data['merchant'] as String? ?? 'Unknown',
      type: TransactionType.expense,
      categoryId: data['categoryId'] as String?,
      transactionDate: DateTime.now(),
      createdByUserId: data['createdByUserId'] as String? ?? 'user_001',
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<Transaction> updateTransaction(
      String familyGroupId, String id, Map<String, dynamic> data) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteTransaction(String familyGroupId, String id) async {}
}

class _FakeCategoryNotifier extends CategoryNotifier {
  _FakeCategoryNotifier(this._state);

  final CategoryState _state;

  @override
  CategoryState build() => _state;
}

class _FakeFamilyNotifier extends FamilyNotifier {
  _FakeFamilyNotifier(this._state);

  final FamilyState _state;

  @override
  FamilyState build() => _state;
}

class _FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState(
        status: AuthStatus.authenticated,
        user: SampleData.user1,
      );
}

// Returns the recording service so tests can assert on create calls.
// ignore: library_private_types_in_public_api
Future<_RecordingTransactionService> pumpScreen(
  WidgetTester tester, {
  Object? saveError,
}) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  final service = _RecordingTransactionService(error: saveError);
  // `context.pop()` needs a GoRouter ancestor, so drive the screen through a
  // real GoRouter with a home route to pop back to.
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: Text('home')),
      ),
      GoRoute(
        path: '/add-expense',
        builder: (context, state) => const AddExpenseScreen(),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        transactionServiceProvider.overrideWithValue(service),
        categoryProvider.overrideWith(
          () => _FakeCategoryNotifier(
            CategoryState(categories: SampleData.categories),
          ),
        ),
        familyProvider.overrideWith(
          () => _FakeFamilyNotifier(
            FamilyState(
              currentFamily: SampleData.familyGroup,
              members: SampleData.members,
            ),
          ),
        ),
        authProvider.overrideWith(_FakeAuthNotifier.new),
      ],
      child: MaterialApp.router(
        theme: ThemeData(extensions: [BudgetlyColors.dark]),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  // Push the screen under test on top of the home route so a successful save
  // has somewhere to pop back to (go() would replace the stack).
  router.push('/add-expense');
  await tester.pumpAndSettle();
  return service;
}

/// Scrolls the CTA into view and taps it (it sits below the fold on the
/// default 800x600 test surface).
Future<void> tapSave(WidgetTester tester) async {
  await tester.ensureVisible(find.byType(ElevatedButton));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(ElevatedButton), warnIfMissed: false);
  await tester.pump();
}

void main() {
  testWidgets('empty amount shows an inline error and does not save',
      (tester) async {
    final service = await pumpScreen(tester);

    await tapSave(tester);

    expect(find.text('Enter an amount'), findsOneWidget);
    expect(service.createCalls, 0);
  });

  testWidgets('zero amount shows an inline error', (tester) async {
    final service = await pumpScreen(tester);

    await tester.enterText(find.byType(TextField).first, '0');
    await tester.pump();
    await tapSave(tester);

    expect(find.text('Enter a valid amount'), findsOneWidget);
    expect(service.createCalls, 0);
  });

  testWidgets('garbage amount text is rejected with an inline error',
      (tester) async {
    final service = await pumpScreen(tester);

    // The amount field only accepts [\d.] characters, so non-numeric input
    // is stripped by the formatter — the field ends up empty.
    await tester.enterText(find.byType(TextField).first, 'abc');
    await tester.pump();
    await tapSave(tester);

    expect(find.text('Enter an amount'), findsOneWidget);
    expect(service.createCalls, 0);
  });

  testWidgets('valid amount submits and pops', (tester) async {
    final service = await pumpScreen(tester);

    await tester.enterText(find.byType(TextField).first, '123.45');
    await tester.pump();
    await tester.enterText(find.byType(TextField).last, 'Cafe');
    await tester.pump();
    await tapSave(tester);
    await tester.pumpAndSettle();

    expect(service.createCalls, 1);
    expect(service.lastPayload!['amount'], 123.45);
    expect(service.lastPayload!['type'], 'EXPENSE');
    expect(service.lastPayload!['merchant'], 'Cafe');
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('empty merchant name shows an inline error', (tester) async {
    final service = await pumpScreen(tester);

    await tester.enterText(find.byType(TextField).first, '123.45');
    await tester.pump();
    await tapSave(tester);

    expect(find.text('Enter a merchant name'), findsOneWidget);
    expect(service.createCalls, 0);
  });

  testWidgets('save failure shows an error and stays on the screen',
      (tester) async {
    final service = await pumpScreen(tester, saveError: Exception('boom'));

    await tester.enterText(find.byType(TextField).first, '50');
    await tester.pump();
    await tester.enterText(find.byType(TextField).last, 'Cafe');
    await tester.pump();
    await tapSave(tester);
    await tester.pumpAndSettle();

    expect(service.createCalls, 1);
    expect(find.text('Could not save expense. Please try again.'),
        findsOneWidget);
    // The Add Expense screen is still mounted.
    expect(find.byType(ElevatedButton), findsOneWidget);
  });

  testWidgets('error clears when the user edits the amount', (tester) async {
    await pumpScreen(tester);

    await tapSave(tester);
    expect(find.text('Enter an amount'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '10');
    await tester.pump();
    expect(find.text('Enter an amount'), findsNothing);
  });

  testWidgets('error clears when the user edits the merchant', (tester) async {
    await pumpScreen(tester);

    await tester.enterText(find.byType(TextField).first, '10');
    await tester.pump();
    await tapSave(tester);

    expect(find.text('Enter a merchant name'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'Cafe');
    await tester.pump();
    expect(find.text('Enter a merchant name'), findsNothing);
  });
}