import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:budgetly/config/budgetly_colors.dart';
import 'package:budgetly/data/category_service.dart';
import 'package:budgetly/models/category.dart';
import 'package:budgetly/models/family_group.dart';
import 'package:budgetly/models/message.dart';
import 'package:budgetly/models/sms_pattern.dart';
import 'package:budgetly/providers/family_provider.dart';
import 'package:budgetly/providers/inbox_provider.dart';
import 'package:budgetly/providers/service_providers.dart';
import 'package:budgetly/providers/sms_provider.dart';
import 'package:budgetly/screens/settings/pattern_builder_screen.dart';
import 'package:budgetly/services/pattern_cache_service.dart';

/// A [PatternCacheService] that records create/update calls instead of hitting
/// Dio and keeps its in-memory list in sync the way the real service's
/// refresh-after-mutation does.
class _FakePatternCacheService extends PatternCacheService {
  _FakePatternCacheService([List<SmsPattern> seeded = const []])
      : super(dio: Dio()) {
    debugSetPatterns(seeded);
  }

  final List<Map<String, dynamic>> created = [];
  final List<Map<String, dynamic>> updated = [];

  @override
  Future<void> loadPatterns() async {}

  @override
  Future<void> refreshPatterns() async {}

  @override
  Future<SmsPattern> createPattern({
    required String sender,
    required String template,
    required ExtractionMap extractionMap,
    Map<String, String> fixedValues = const {},
    required String sampleMessage,
    String? categoryName,
  }) async {
    created.add({
      'sender': sender,
      'template': template,
      'extractionMap': extractionMap,
      'fixedValues': fixedValues,
      'sampleMessage': sampleMessage,
      'categoryName': categoryName,
    });
    final pattern = SmsPattern(
      id: 'created-1',
      sender: sender,
      template: template,
      extractionMap: extractionMap,
      fixedValues: fixedValues,
      sampleMessage: sampleMessage,
      categoryName: categoryName,
      scope: PatternScope.family,
      source: PatternSource.user,
      createdAt: DateTime.utc(2026, 11, 20),
    );
    debugSetPatterns([...patterns, pattern]);
    return pattern;
  }

  @override
  Future<SmsPattern> updatePattern(
    String patternId, {
    String? sender,
    String? template,
    ExtractionMap? extractionMap,
    Map<String, String>? fixedValues,
    String? sampleMessage,
    String? categoryName,
  }) async {
    updated.add({
      'patternId': patternId,
      'sender': sender,
      'template': template,
      'extractionMap': extractionMap,
      'fixedValues': fixedValues,
      'sampleMessage': sampleMessage,
      'categoryName': categoryName,
    });
    return SmsPattern(
      id: 'copy-for-family',
      sender: sender ?? 'HDFCBK',
      template: template ?? 'Spent Rs {amount}',
      extractionMap: extractionMap ?? const ExtractionMap(amount: 'amount'),
      fixedValues: fixedValues ?? const {},
      sampleMessage: sampleMessage ?? '',
      categoryName: categoryName,
      scope: PatternScope.family,
      source: PatternSource.user,
      createdAt: DateTime.utc(2026, 11, 20),
    );
  }
}

/// An [InboxNotifier] seeded with a fixed state; [refresh] is a no-op so the
/// builder resolves the message on the first frame.
class _FakeInboxNotifier extends InboxNotifier {
  _FakeInboxNotifier(this._state);

  final InboxState _state;

  @override
  InboxState build() => _state;

  @override
  Future<void> refresh() async {}
}

/// An [SmsNotifier] that records [recordLocally] calls instead of parsing and
/// posting a transaction.
class _FakeSmsNotifier extends SmsNotifier {
  _FakeSmsNotifier({this.recorded = true});

  final bool recorded;
  final List<Message> recordedMessages = [];

  @override
  SmsState build() => const SmsState();

  @override
  Future<bool> recordLocally(Message message) async {
    recordedMessages.add(message);
    return recorded;
  }
}

class _FakeCategoryService implements CategoryService {
  _FakeCategoryService(this._categories);

  final List<Category> _categories;

  @override
  Future<List<Category>> getCategories(String familyGroupId) async =>
      _categories;

  @override
  Future<Category> createCategory(
    String familyGroupId,
    Map<String, dynamic> data,
  ) async => throw UnimplementedError();

  @override
  Future<Category> updateCategory(
    String familyGroupId,
    String id,
    Map<String, dynamic> data,
  ) async => throw UnimplementedError();

  @override
  Future<void> deleteCategory(String familyGroupId, String id) async {}
}

final _family = FamilyGroup(
  id: 'family-1',
  name: 'Test Family',
  monthlyBudgetLimit: 50000,
  createdByUserId: 'user-1',
  createdAt: DateTime.utc(2026, 1, 1),
);

class _FakeFamilyNotifier extends FamilyNotifier {
  _FakeFamilyNotifier(this._state);

  final FamilyState _state;

  @override
  FamilyState build() => _state;
}

final _categories = <Category>[
  const Category(
    id: 'cat_groceries',
    familyGroupId: 'family-1',
    name: 'Groceries',
    icon: '🛒',
    budgetLimit: 0,
    color: '#34D399',
  ),
];

const _rawText = 'Spent Rs 500.50 at Grocery Mart on 01/10/2026';

Message _nonTransaction({String id = 'msg-1'}) => Message(
  id: id,
  userId: 'user-1',
  sender: 'HDFCBK',
  rawText: _rawText,
  status: MessageStatus.pending,
  receivedAt: DateTime.utc(2026, 11, 20, 9),
);

SmsPattern _globalPattern() => SmsPattern(
  id: 'p-global',
  sender: 'HDFCBK',
  template: 'Spent Rs {amount} at {merchant} on 01/10/2026',
  extractionMap: const ExtractionMap(amount: 'amount', merchant: 'merchant'),
  sampleMessage: _rawText,
  source: PatternSource.llm,
  createdAt: DateTime.utc(2026, 1, 1),
);

class _BuilderHarness {
  final _FakePatternCacheService cache;
  final _FakeSmsNotifier sms;

  const _BuilderHarness(this.cache, this.sms);
}

/// Pumps the builder screen with the inbox, SMS and pattern services faked.
Future<_BuilderHarness> _pumpBuilderScreen(
  WidgetTester tester, {
  List<Message> nonTransactions = const [],
  List<SmsPattern> patterns = const [],
  String? messageId = 'msg-1',
  String? patternId,
  bool recorded = true,
}) async {
  GoogleFonts.config.allowRuntimeFetching = false;

  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final cache = _FakePatternCacheService(patterns);
  final sms = _FakeSmsNotifier(recorded: recorded);
  final container = ProviderContainer(
    overrides: [
      patternCacheServiceProvider.overrideWithValue(cache),
      inboxProvider.overrideWith(
        () => _FakeInboxNotifier(
          InboxState(nonTransactions: nonTransactions),
        ),
      ),
      smsProvider.overrideWith(() => sms),
      familyProvider.overrideWith(
        () => _FakeFamilyNotifier(
          FamilyState(currentFamily: _family, members: const []),
        ),
      ),
      categoryServiceProvider.overrideWithValue(
        _FakeCategoryService(_categories),
      ),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: ThemeData(extensions: [BudgetlyColors.dark]),
        home: PatternBuilderScreen(messageId: messageId, patternId: patternId),
      ),
    ),
  );
  await tester.pumpAndSettle();

  return _BuilderHarness(cache, sms);
}

/// Selects the text range [start, end) inside the builder's source field and
/// taps the tag chip for [field].
Future<void> _tagSpan(
  WidgetTester tester, {
  required int start,
  required int end,
  required String chipLabel,
}) async {
  final source = find.byKey(const Key('pattern-source-text'));
  final editable = tester.widget<EditableText>(
    find.descendant(of: source, matching: find.byType(EditableText)),
  );
  editable.controller.selection = TextSelection(
    baseOffset: start,
    extentOffset: end,
  );
  await tester.pumpAndSettle();

  await tester.tap(find.widgetWithText(ActionChip, chipLabel));
  await tester.pumpAndSettle();
}

void main() {
  group('PatternBuilderScreen — create from a message', () {
    testWidgets('prefills the sender and source, and offers no status tag', (
      tester,
    ) async {
      await _pumpBuilderScreen(tester, nonTransactions: [_nonTransaction()]);

      expect(find.text('New Pattern'), findsOneWidget);
      expect(find.text('HDFCBK'), findsOneWidget);
      expect(find.text(_rawText), findsOneWidget);
      expect(find.text('Failed'), findsNothing);
      expect(find.byKey(const Key('pattern-template-field')), findsOneWidget);
      expect(find.byKey(const Key('pattern-save-button')), findsOneWidget);
    });

    testWidgets('save with no tags is blocked with a snackbar', (tester) async {
      final harness = await _pumpBuilderScreen(
        tester,
        nonTransactions: [_nonTransaction()],
      );

      await tester.tap(find.byKey(const Key('pattern-save-button')));
      await tester.pumpAndSettle();

      expect(harness.cache.created, isEmpty);
      expect(find.text('Highlight and tag at least one field'), findsOneWidget);
    });

    testWidgets('save is blocked when {amount} is not tagged', (tester) async {
      final harness = await _pumpBuilderScreen(
        tester,
        nonTransactions: [_nonTransaction()],
      );

      // Tag only the merchant (no amount).
      await _tagSpan(tester, start: 19, end: 31, chipLabel: 'Merchant');

      await tester.tap(find.byKey(const Key('pattern-save-button')));
      await tester.pumpAndSettle();

      expect(harness.cache.created, isEmpty);
      expect(find.text('Missing required {amount} tag'), findsOneWidget);
      expect(find.text('Tag the amount — it is required'), findsOneWidget);
    });

    testWidgets('tagging amount + merchant derives the template and saves', (
      tester,
    ) async {
      final harness = await _pumpBuilderScreen(
        tester,
        nonTransactions: [_nonTransaction()],
      );

      await _tagSpan(tester, start: 9, end: 15, chipLabel: 'Amount');
      await _tagSpan(tester, start: 19, end: 31, chipLabel: 'Merchant');

      expect(
        find.text('Preview OK — pattern will parse this message'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('pattern-save-button')));
      await tester.pumpAndSettle();

      expect(harness.cache.created, hasLength(1));
      final created = harness.cache.created.single;
      expect(created['sender'], 'HDFCBK');
      expect(
        created['template'],
        'Spent Rs {amount} at {merchant} on 01/10/2026',
      );
      final map = created['extractionMap'] as ExtractionMap;
      expect(map.amount, 'amount');
      expect(map.merchant, 'merchant');
      expect(map.timestamp, isNull);
      expect(created['sampleMessage'], _rawText);

      // The source message is recorded immediately from the fresh cache.
      expect(harness.sms.recordedMessages.single.id, 'msg-1');
    });

    testWidgets('manually typed template falls back to server validation', (
      tester,
    ) async {
      final harness = await _pumpBuilderScreen(
        tester,
        nonTransactions: [_nonTransaction()],
      );

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

      expect(harness.cache.created, hasLength(1));
      final created = harness.cache.created.single;
      expect(
        created['template'],
        'Spent Rs {amount} at Grocery Mart on 01/10/2026',
      );
      final map = created['extractionMap'] as ExtractionMap;
      expect(map.amount, 'amount');
      expect(map.merchant, isNull);
    });

    testWidgets('manual template without {amount} is blocked', (tester) async {
      final harness = await _pumpBuilderScreen(
        tester,
        nonTransactions: [_nonTransaction()],
      );

      await tester.enterText(
        find.byKey(const Key('pattern-template-field')),
        'Spent Rs 500 at Grocery Mart',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('pattern-save-button')));
      await tester.pumpAndSettle();

      expect(harness.cache.created, isEmpty);
      expect(find.text('Missing required {amount} tag'), findsOneWidget);
    });

    testWidgets('fixed values are sent and override extracted fields', (
      tester,
    ) async {
      final harness = await _pumpBuilderScreen(
        tester,
        nonTransactions: [_nonTransaction()],
      );

      await _tagSpan(tester, start: 9, end: 15, chipLabel: 'Amount');
      await tester.enterText(
        find.byKey(const Key('pattern-fixed-merchant')),
        'Pan Shop',
      );
      await tester.enterText(
        find.byKey(const Key('pattern-fixed-account')),
        '1234',
      );
      await tester.enterText(
        find.byKey(const Key('pattern-fixed-bank')),
        'HDFC Bank',
      );
      await tester.enterText(
        find.byKey(const Key('pattern-fixed-notes')),
        'Monthly groceries',
      );
      await tester.tap(find.byKey(const Key('pattern-save-button')));
      await tester.pumpAndSettle();

      expect(harness.cache.created, hasLength(1));
      expect(harness.cache.created.single['fixedValues'], {
        'merchant': 'Pan Shop',
        'accountLast4': '1234',
        'bankName': 'HDFC Bank',
        'notes': 'Monthly groceries',
      });
    });

    testWidgets('a category picked from the sheet is saved with the pattern', (
      tester,
    ) async {
      final harness = await _pumpBuilderScreen(
        tester,
        nonTransactions: [_nonTransaction()],
      );

      // Open the category sheet; categories load lazily from the family.
      await tester.tap(find.byKey(const Key('pattern-category-row')));
      await tester.pumpAndSettle();
      expect(find.text('Uncategorized'), findsWidgets);

      await tester.tap(find.byKey(const Key('category-option-cat_groceries')));
      await tester.pumpAndSettle();
      expect(find.text('Groceries'), findsOneWidget);

      await _tagSpan(tester, start: 9, end: 15, chipLabel: 'Amount');
      await tester.tap(find.byKey(const Key('pattern-save-button')));
      await tester.pumpAndSettle();

      expect(harness.cache.created, hasLength(1));
      expect(harness.cache.created.single['categoryName'], 'Groceries');
      expect(harness.cache.created.single['fixedValues'], isEmpty);
    });

    testWidgets('an unparsed message keeps the saved-pattern snackbar', (
      tester,
    ) async {
      await _pumpBuilderScreen(
        tester,
        nonTransactions: [_nonTransaction()],
        recorded: false,
      );

      await _tagSpan(tester, start: 9, end: 15, chipLabel: 'Amount');
      await tester.tap(find.byKey(const Key('pattern-save-button')));
      await tester.pumpAndSettle();

      expect(find.text('Pattern saved for HDFCBK'), findsOneWidget);
    });

    testWidgets('a missing message shows an empty state, not a crash', (
      tester,
    ) async {
      await _pumpBuilderScreen(
        tester,
        nonTransactions: [_nonTransaction()],
        messageId: 'does-not-exist',
      );

      expect(find.text('Message not found'), findsOneWidget);
    });
  });

  group('PatternBuilderScreen — edit an existing pattern', () {
    testWidgets('prefills the pattern and hides span tagging', (tester) async {
      await _pumpBuilderScreen(
        tester,
        patterns: [_globalPattern()],
        messageId: null,
        patternId: 'p-global',
      );

      expect(find.text('Customize for family'), findsOneWidget);
      expect(
        find.textContaining('hides this global pattern for your family'),
        findsOneWidget,
      );
      final template = tester.widget<TextField>(
        find.byKey(const Key('pattern-template-field')),
      );
      expect(
        template.controller!.text,
        'Spent Rs {amount} at {merchant} on 01/10/2026',
      );
      final source = tester.widget<TextField>(
        find.byKey(const Key('pattern-source-text')),
      );
      expect(
        source.controller!.text,
        _rawText,
        reason: 'the saved sample message is shown in edit mode',
      );
      expect(find.byType(ActionChip), findsNothing);
      expect(find.text('Save for my family'), findsOneWidget);
    });

    testWidgets('saving a global pattern updates it into a family copy', (
      tester,
    ) async {
      final harness = await _pumpBuilderScreen(
        tester,
        patterns: [_globalPattern()],
        messageId: null,
        patternId: 'p-global',
      );

      await tester.tap(find.byKey(const Key('pattern-save-button')));
      await tester.pumpAndSettle();

      expect(harness.cache.created, isEmpty);
      expect(harness.cache.updated, hasLength(1));
      final updated = harness.cache.updated.single;
      expect(updated['patternId'], 'p-global');
      expect(
        updated['template'],
        'Spent Rs {amount} at {merchant} on 01/10/2026',
      );
      expect(updated['sampleMessage'], _rawText);
      // Editing does not re-record the source message.
      expect(harness.sms.recordedMessages, isEmpty);
    });

    testWidgets('a family pattern saves in place without the copy banner', (
      tester,
    ) async {
      final familyPattern = SmsPattern(
        id: 'p-family',
        sender: 'HDFCBK',
        template: 'Spent Rs {amount} at {merchant} on 01/10/2026',
        extractionMap: const ExtractionMap(
          amount: 'amount',
          merchant: 'merchant',
        ),
        sampleMessage: _rawText,
        scope: PatternScope.family,
        ownerFamilyGroupId: 'family-1',
        source: PatternSource.user,
        createdAt: DateTime.utc(2026, 1, 1),
      );

      final harness = await _pumpBuilderScreen(
        tester,
        patterns: [familyPattern],
        messageId: null,
        patternId: 'p-family',
      );

      expect(find.text('Edit Pattern'), findsOneWidget);
      expect(find.text('Save changes'), findsOneWidget);
      expect(
        find.textContaining('hides this global pattern'),
        findsNothing,
      );

      await tester.tap(find.byKey(const Key('pattern-save-button')));
      await tester.pumpAndSettle();

      expect(harness.cache.updated.single['patternId'], 'p-family');
    });

    testWidgets('a missing pattern shows an empty state, not a crash', (
      tester,
    ) async {
      await _pumpBuilderScreen(
        tester,
        patterns: const [],
        messageId: null,
        patternId: 'does-not-exist',
      );

      expect(find.text('Pattern not found'), findsOneWidget);
    });
  });
}