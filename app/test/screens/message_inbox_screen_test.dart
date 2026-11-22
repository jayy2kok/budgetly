import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:budgetly/config/budgetly_colors.dart';
import 'package:budgetly/models/message.dart';
import 'package:budgetly/models/transaction.dart';
import 'package:budgetly/providers/inbox_provider.dart';
import 'package:budgetly/providers/sms_provider.dart';
import 'package:budgetly/screens/messages/message_inbox_screen.dart';
import 'package:budgetly/screens/settings/pattern_builder_screen.dart';

/// Inbox state fixed at construction; [refresh] is a no-op so the screen shows
/// exactly the seeded messages.
class _FakeInboxNotifier extends InboxNotifier {
  _FakeInboxNotifier(this._state);

  final InboxState _state;

  @override
  InboxState build() => _state;

  @override
  Future<void> refresh() async {}
}

/// SmsNotifier with SMS permission already granted; sync is a no-op.
class _FakeSmsNotifier extends SmsNotifier {
  @override
  SmsState build() => const SmsState(smsPermissionGranted: true);

  @override
  Future<void> recheckPermission() async {}

  @override
  Future<void> syncInboxMessages() async {}
}

const _recordedBody = 'Rs.500 debited at Grocery Mart';
const _nonTransactionBody = 'Your OTP for login is 482913';

/// Local time so the screen's `toLocal()` formatting is deterministic.
final _receivedAt = DateTime(2026, 11, 20, 12);

Message _message(String id, String body) => Message(
      id: id,
      userId: 'u1',
      sender: 'HDFCBK',
      rawText: body,
      status: MessageStatus.pending,
      receivedAt: _receivedAt,
    );

Transaction _transaction() => Transaction(
      id: 'tx-1',
      familyGroupId: 'fam-1',
      createdByUserId: 'u1',
      amount: 500,
      merchant: 'Grocery Mart',
      type: TransactionType.expense,
      sourceType: SourceType.regexLocal,
      sourceRawText: _recordedBody,
      transactionDate: _receivedAt,
      createdAt: _receivedAt,
    );

InboxState _seededInbox() {
  final recorded = _message('sms_1', _recordedBody);
  return InboxState(
    recordedMessages: [recorded],
    nonTransactions: [_message('sms_2', _nonTransactionBody)],
    transactionByMessageId: {'sms_1': _transaction()},
  );
}

Future<void> _pumpInboxScreen(
  WidgetTester tester, {
  InboxState? state,
}) async {
  GoogleFonts.config.allowRuntimeFetching = false;

  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: [
      inboxProvider.overrideWith(() => _FakeInboxNotifier(state ?? _seededInbox())),
      smsProvider.overrideWith(_FakeSmsNotifier.new),
    ],
  );
  addTearDown(container.dispose);

  final router = GoRouter(
    initialLocation: '/messages',
    routes: [
      GoRoute(
        path: '/messages',
        builder: (context, _) => const MessageInboxScreen(),
      ),
      GoRoute(
        path: '/settings/patterns/new',
        builder: (context, state) => PatternBuilderScreen(
          messageId: state.uri.queryParameters['messageId'],
        ),
      ),
      GoRoute(
        path: '/transaction/:id',
        builder: (context, state) {
          final transaction = state.extra as Transaction?;
          return Scaffold(
            body: Text(
              'detail ${state.pathParameters['id']} '
              '${transaction?.merchant ?? ''}',
            ),
          );
        },
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: ThemeData(extensions: [BudgetlyColors.dark]),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Switches to the Non-Transactions tab.
Future<void> _openNonTransactions(WidgetTester tester) async {
  await tester.tap(find.text('Non-Transactions (1)'));
  await tester.pumpAndSettle();
}

void main() {
  group('MessageInboxScreen', () {
    testWidgets('has exactly two tabs with counts', (tester) async {
      await _pumpInboxScreen(tester);

      expect(find.byType(Tab), findsNWidgets(2));
      expect(find.text('Recorded (1)'), findsOneWidget);
      expect(find.text('Non-Transactions (1)'), findsOneWidget);
      // The old triage tabs are gone.
      expect(find.textContaining('Incomplete'), findsNothing);
      expect(find.textContaining('Unprocessed'), findsNothing);
      expect(find.textContaining('Ignored'), findsNothing);
    });

    testWidgets('recorded messages show their transaction summary', (
      tester,
    ) async {
      await _pumpInboxScreen(tester);

      expect(find.text(_recordedBody), findsOneWidget);
      expect(find.text('Grocery Mart'), findsOneWidget);
      expect(find.text('-₹500'), findsOneWidget);
      expect(find.text('Recorded'), findsOneWidget);
    });

    testWidgets('tapping a recorded message opens the transaction', (
      tester,
    ) async {
      await _pumpInboxScreen(tester);

      await tester.tap(find.text(_recordedBody));
      await tester.pumpAndSettle();

      // The card hands the transaction to the detail screen so it renders
      // even when the transaction is older than the feed's first page.
      expect(find.text('detail tx-1 Grocery Mart'), findsOneWidget);
    });

    testWidgets('a non-transaction offers only the Define pattern action', (
      tester,
    ) async {
      await _pumpInboxScreen(tester);
      await _openNonTransactions(tester);

      expect(find.text(_nonTransactionBody), findsOneWidget);
      expect(find.text('20 Nov 2026, 12:00'), findsOneWidget);
      expect(find.byKey(const Key('define-pattern-button')), findsOneWidget);
      expect(find.text('Define pattern'), findsOneWidget);
      // No triage or completion workflow remains on the card.
      expect(find.text('Complete'), findsNothing);
      expect(find.text('Confirm'), findsNothing);
      expect(find.text('Ignore'), findsNothing);
      expect(find.text('Reject'), findsNothing);
      expect(find.text('Submit to server'), findsNothing);
    });

    testWidgets('Define pattern opens the builder prefilled with the message', (
      tester,
    ) async {
      await _pumpInboxScreen(tester);
      await _openNonTransactions(tester);

      await tester.tap(find.byKey(const Key('define-pattern-button')));
      await tester.pumpAndSettle();

      expect(find.text('New Pattern'), findsOneWidget);
      expect(find.text(_nonTransactionBody), findsOneWidget);
      expect(find.byKey(const Key('pattern-save-button')), findsOneWidget);
    });

    testWidgets('an empty non-transaction tab explains the split', (
      tester,
    ) async {
      await _pumpInboxScreen(
        tester,
        state: InboxState(
          recordedMessages: [_message('sms_1', _recordedBody)],
          transactionByMessageId: {'sms_1': _transaction()},
        ),
      );

      await tester.tap(find.text('Non-Transactions (0)'));
      await tester.pumpAndSettle();

      expect(find.text('No non-transaction messages'), findsOneWidget);
    });
  });
}