import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:budgetly/config/budgetly_colors.dart';
import 'package:budgetly/data/message_service.dart';
import 'package:budgetly/models/message.dart';
import 'package:budgetly/models/sms_pattern.dart';
import 'package:budgetly/providers/message_provider.dart';
import 'package:budgetly/providers/service_providers.dart';
import 'package:budgetly/screens/settings/pattern_builder_screen.dart';
import 'package:budgetly/services/pattern_cache_service.dart';

/// A [PatternCacheService] that records createPattern calls instead of hitting
/// Dio. It must pass an explicit Dio because [ApiClient.instance] is not
/// initialized in widget tests.
class _FakePatternCacheService extends PatternCacheService {
  _FakePatternCacheService() : super(dio: Dio());

  final List<Map<String, dynamic>> created = [];

  @override
  Future<SmsPattern> createPattern({
    required String sender,
    required String template,
    required ExtractionMap extractionMap,
    required String sampleMessage,
    String? categoryName,
  }) async {
    created.add({
      'sender': sender,
      'template': template,
      'extractionMap': extractionMap,
      'sampleMessage': sampleMessage,
      'categoryName': categoryName,
    });
    return SmsPattern(
      id: 'created-1',
      sender: sender,
      template: template,
      extractionMap: extractionMap,
      sampleMessage: sampleMessage,
      scope: PatternScope.family,
      source: PatternSource.user,
      createdAt: DateTime.utc(2026, 11, 20),
    );
  }
}

/// A [MessageService] whose failed list is fixed so the message under test is
/// resolvable by the builder screen.
class _FakeMessageService implements MessageService {
  _FakeMessageService(this._failed);

  final List<Message> _failed;

  @override
  Future<List<Message>> getPendingMessages() async => const [];

  @override
  Future<List<Message>> getIgnoredMessages() async => const [];

  @override
  Future<List<Message>> getFailedMessages({int page = 0, int size = 20}) async =>
      _failed;

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
      throw UnimplementedError();
}

const _rawText = 'Spent Rs 500.50 at Grocery Mart on 01/10/2026';

Message _failedMessage({String id = 'msg-1'}) => Message(
      id: id,
      userId: 'user-1',
      sender: 'HDFCBK',
      rawText: _rawText,
      status: MessageStatus.failed,
      errorMessage: 'LLM analysis failed: upstream provider timeout',
      receivedAt: DateTime.utc(2026, 11, 20, 9),
    );

/// Pumps the builder screen, optionally with the failed message loaded so the
/// post-frame lookup resolves it. Returns the recording cache service.
Future<_FakePatternCacheService> _pumpBuilderScreen(
  WidgetTester tester, {
  List<Message> failed = const [],
  String messageId = 'msg-1',
}) async {
  GoogleFonts.config.allowRuntimeFetching = false;

  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final cache = _FakePatternCacheService();
  final container = ProviderContainer(
    overrides: [
      messageServiceProvider.overrideWithValue(_FakeMessageService(failed)),
      patternCacheServiceProvider.overrideWithValue(cache),
    ],
  );
  addTearDown(container.dispose);

  // Seed the message state the builder reads on first frame.
  final notifier = container.read(messageProvider.notifier);
  notifier.state = MessageState(failedMessages: failed, totalFailed: failed.length);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: ThemeData(extensions: [BudgetlyColors.dark]),
        home: PatternBuilderScreen(messageId: messageId),
      ),
    ),
  );
  await tester.pumpAndSettle();

  return cache;
}

/// Selects the text range [start, end) inside the builder's SelectableText and
/// taps the tag chip for [field].
Future<void> _tagSpan(
  WidgetTester tester, {
  required int start,
  required int end,
  required String chipLabel,
}) async {
  final selectable = find.byKey(const Key('pattern-source-text'));
  final editable = tester.widget<EditableText>(
    find.descendant(of: selectable, matching: find.byType(EditableText)),
  );
  editable.controller.selection =
      TextSelection(baseOffset: start, extentOffset: end);
  await tester.pumpAndSettle();

  await tester.tap(find.widgetWithText(ActionChip, chipLabel));
  await tester.pumpAndSettle();
}

void main() {
  group('PatternBuilderScreen', () {
    testWidgets('shows the source message and its failure reason', (
      tester,
    ) async {
      await _pumpBuilderScreen(tester, failed: [_failedMessage()]);

      expect(find.text('HDFCBK'), findsOneWidget);
      expect(find.text('Failed'), findsOneWidget);
      expect(find.textContaining('Amount'), findsWidgets);
      expect(find.byKey(const Key('pattern-save-button')), findsOneWidget);
    });

    testWidgets('save with no tags is blocked with a snackbar', (
      tester,
    ) async {
      final cache = await _pumpBuilderScreen(tester, failed: [_failedMessage()]);

      await tester.tap(find.byKey(const Key('pattern-save-button')));
      await tester.pumpAndSettle();

      expect(cache.created, isEmpty);
      expect(find.text('Highlight and tag at least one field'), findsOneWidget);
    });

    testWidgets('save is blocked when {amount} is not tagged', (tester) async {
      final cache = await _pumpBuilderScreen(tester, failed: [_failedMessage()]);

      // Tag only the merchant (no amount).
      await _tagSpan(
        tester,
        start: 19,
        end: 31,
        chipLabel: 'Merchant',
      );

      await tester.tap(find.byKey(const Key('pattern-save-button')));
      await tester.pumpAndSettle();

      expect(cache.created, isEmpty);
      expect(find.text('Missing required {amount} tag'), findsOneWidget);
      expect(find.text('Tag the amount — it is required'), findsOneWidget);
    });

    testWidgets('tagging amount + merchant derives the template and saves', (
      tester,
    ) async {
      final cache = await _pumpBuilderScreen(tester, failed: [_failedMessage()]);

      await _tagSpan(tester, start: 9, end: 15, chipLabel: 'Amount');
      await _tagSpan(tester, start: 19, end: 31, chipLabel: 'Merchant');

      // The derived template is shown in the preview banner as OK.
      expect(find.text('Preview OK — pattern will parse this message'), findsOneWidget);

      await tester.tap(find.byKey(const Key('pattern-save-button')));
      await tester.pumpAndSettle();

      expect(cache.created, hasLength(1));
      final created = cache.created.single;
      expect(created['sender'], 'HDFCBK');
      expect(created['template'], 'Spent Rs {amount} at {merchant} on 01/10/2026');
      final map = created['extractionMap'] as ExtractionMap;
      expect(map.amount, 'amount');
      expect(map.merchant, 'merchant');
      expect(map.timestamp, isNull);
      expect(created['sampleMessage'], _rawText);
    });

    testWidgets('manually typed template falls back to server validation', (
      tester,
    ) async {
      final cache = await _pumpBuilderScreen(tester, failed: [_failedMessage()]);

      // Type a hand-authored template (amount-only) directly.
      await tester.enterText(
        find.byKey(const Key('pattern-template-field')),
        'Spent Rs {amount} at Grocery Mart on 01/10/2026',
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Manual template — server will validate on save'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('pattern-save-button')));
      await tester.pumpAndSettle();

      expect(cache.created, hasLength(1));
      final created = cache.created.single;
      expect(created['template'], 'Spent Rs {amount} at Grocery Mart on 01/10/2026');
      final map = created['extractionMap'] as ExtractionMap;
      expect(map.amount, 'amount');
      expect(map.merchant, isNull);
    });

    testWidgets('manual template without {amount} is blocked', (tester) async {
      final cache = await _pumpBuilderScreen(tester, failed: [_failedMessage()]);

      await tester.enterText(
        find.byKey(const Key('pattern-template-field')),
        'Spent Rs 500 at Grocery Mart',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('pattern-save-button')));
      await tester.pumpAndSettle();

      expect(cache.created, isEmpty);
      expect(find.text('Missing required {amount} tag'), findsOneWidget);
    });

    testWidgets('a missing message shows an empty state, not a crash', (
      tester,
    ) async {
      await _pumpBuilderScreen(
        tester,
        failed: [_failedMessage()],
        messageId: 'does-not-exist',
      );

      expect(find.text('Message not found'), findsOneWidget);
    });
  });
}