import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:budgetly/config/budgetly_colors.dart';
import 'package:budgetly/data/message_service.dart';
import 'package:budgetly/models/message.dart';
import 'package:budgetly/providers/service_providers.dart';
import 'package:budgetly/screens/messages/ignored_messages_screen.dart';

/// A [MessageService] whose ignored list is fixed at construction time so the
/// screen's `loadMessages()` call resolves deterministically in tests.
class _FakeMessageService implements MessageService {
  _FakeMessageService(this._ignored);

  final List<Message> _ignored;
  int loadCalls = 0;

  @override
  Future<List<Message>> getPendingMessages() async => const [];

  @override
  Future<List<Message>> getIgnoredMessages() async {
    loadCalls++;
    return _ignored;
  }

  @override
  Future<Map<String, dynamic>> processMessage(
          Map<String, dynamic> data) async =>
      const {};

  @override
  Future<int> bulkInsertMessages({
    required String familyGroupId,
    required List<Map<String, String>> messages,
  }) async =>
      messages.length;

  @override
  Future<Message> confirmMessage(String messageId) async =>
      throw UnimplementedError();

  @override
  Future<Message> rejectMessage(String messageId) async =>
      throw UnimplementedError();

  @override
  Future<Message> restoreMessage(String messageId) async =>
      _ignored.firstWhere((m) => m.id == messageId);
}

Message _ignoredMessage({
  required String id,
  required String sender,
  required String rawText,
  required NonFinancialCategory category,
}) =>
    Message(
      id: id,
      userId: 'user-1',
      sender: sender,
      rawText: rawText,
      status: MessageStatus.ignored,
      nonFinancialCategory: category,
      receivedAt: DateTime.utc(2026, 11, 10, 9),
    );

Future<_FakeMessageService> _pumpIgnoredScreen(
  WidgetTester tester, {
  List<Message> ignored = const [],
}) async {
  GoogleFonts.config.allowRuntimeFetching = false;

  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final service = _FakeMessageService(ignored);

  final container = ProviderContainer(
    overrides: [
      messageServiceProvider.overrideWithValue(service),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: ThemeData(extensions: [BudgetlyColors.dark]),
        home: const IgnoredMessagesScreen(),
      ),
    ),
  );
  // Let the post-frame loadMessages() complete.
  await tester.pumpAndSettle();

  return service;
}

void main() {
  testWidgets('Non-Financial tab lists ignored messages by category', (
    tester,
  ) async {
    await _pumpIgnoredScreen(
      tester,
      ignored: [
        _ignoredMessage(
          id: 'msg-otp',
          sender: 'SBIBNK',
          rawText: 'Your OTP is 482910. Valid for 5 mins.',
          category: NonFinancialCategory.otp,
        ),
        _ignoredMessage(
          id: 'msg-promo',
          sender: 'AMAZON',
          rawText: 'Flash Sale! Up to 80% off on electronics.',
          category: NonFinancialCategory.promo,
        ),
        _ignoredMessage(
          id: 'msg-delivery',
          sender: 'AMAZON',
          rawText: 'Your order has been delivered.',
          category: NonFinancialCategory.delivery,
        ),
      ],
    );

    // Both tabs show their real counts.
    expect(find.text('Non-Financial (3)'), findsOneWidget);
    expect(find.text('Deleted (0)'), findsOneWidget);

    // Every ignored message is rendered with its category label.
    expect(find.text('SBIBNK'), findsOneWidget);
    expect(find.text('OTP Code'), findsOneWidget);
    expect(find.text('AMAZON'), findsWidgets);
    expect(find.text('Promotional'), findsOneWidget);
    expect(find.text('Delivery'), findsOneWidget);

    // The empty state is NOT shown.
    expect(find.text('No non-financial messages'), findsNothing);
  });

  testWidgets('Deleted tab lists rejected messages', (tester) async {
    final rejected = Message(
      id: 'msg-del',
      userId: 'user-1',
      sender: 'TMBANK',
      rawText: 'Pre-approved personal loan up to 5L.',
      status: MessageStatus.rejected,
      nonFinancialCategory: NonFinancialCategory.promo,
      receivedAt: DateTime.utc(2026, 11, 10, 9),
    );

    await _pumpIgnoredScreen(tester, ignored: [rejected]);

    expect(find.text('Non-Financial (0)'), findsOneWidget);
    expect(find.text('Deleted (1)'), findsOneWidget);
    expect(find.text('No non-financial messages'), findsOneWidget);

    // Switch to the Deleted tab and confirm the row appears.
    await tester.tap(find.text('Deleted (1)'));
    await tester.pumpAndSettle();

    expect(find.text('TMBANK'), findsOneWidget);
  });

  testWidgets('empty list shows the empty state in the Non-Financial tab', (
    tester,
  ) async {
    await _pumpIgnoredScreen(tester);

    expect(find.text('Non-Financial (0)'), findsOneWidget);
    expect(find.text('No non-financial messages'), findsOneWidget);
    expect(find.text('Deleted (0)'), findsOneWidget);
  });

  testWidgets('loadMessages is called when the screen opens', (tester) async {
    // No initial data: any loaded message would render in the Non-Financial
    // tab, so a single successful post-frame load() is directly observable.
    final service = await _pumpIgnoredScreen(tester);

    // 1 call == exactly one post-frame loadMessages() from initState
    // (the empty tab list itself triggers no further loads).
    expect(
      service.loadCalls,
      equals(1),
      reason: 'the screen must refresh ignored messages on open (issue #28)',
    );
    expect(
      find.text('Non-Financial (0)'),
      findsOneWidget,
      reason: 'the post-frame load completed and rendered its result',
    );
  });
}