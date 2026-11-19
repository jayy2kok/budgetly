import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:budgetly/data/budget_service.dart';
import 'package:budgetly/data/message_service.dart';
import 'package:budgetly/models/category.dart';
import 'package:budgetly/models/family_group.dart';
import 'package:budgetly/models/message.dart';
import 'package:budgetly/models/sms_pattern.dart';
import 'package:budgetly/models/transaction.dart';
import 'package:budgetly/models/user.dart';
import 'package:budgetly/providers/auth_provider.dart';
import 'package:budgetly/providers/category_provider.dart';
import 'package:budgetly/providers/family_provider.dart';
import 'package:budgetly/providers/message_provider.dart';
import 'package:budgetly/providers/service_providers.dart';
import 'package:budgetly/providers/sms_provider.dart';
import 'package:budgetly/providers/transaction_provider.dart';
import 'package:budgetly/services/pattern_cache_service.dart';
import 'package:budgetly/services/sms_inbox_reader.dart';

import '../helpers/inbox_fakes.dart';

/// The checkpoint key written after each processed message.
const kCheckpointKey = 'last_processed_sms_timestamp';

// ── Fakes ─────────────────────────────────────────────────────────

class FakePermissionHandler extends PermissionHandlerPlatform {
  final PermissionStatus status;
  FakePermissionHandler({required this.status});

  @override
  Future<PermissionStatus> checkPermissionStatus(Permission permission) async =>
      status;

  @override
  Future<Map<Permission, PermissionStatus>> requestPermissions(
    List<Permission> permissions,
  ) async => {for (final p in permissions) p: status};
}

/// A [MessageService] that never touches the network and records submissions.
class RecordingMessageService implements MessageService {
  final List<Map<String, dynamic>> processCalls = [];
  Map<String, dynamic> processResponse = {};

  /// Bulk submissions, each recorded as
  /// `{'familyGroupId': String, 'messages': [{'sender', 'rawText', 'receivedAt'}, ...]}`.
  final List<Map<String, dynamic>> bulkCalls = [];

  @override
  Future<Map<String, dynamic>> processMessage(Map<String, dynamic> data) async {
    processCalls.add(data);
    return processResponse;
  }

  @override
  Future<int> bulkInsertMessages({
    required String familyGroupId,
    required List<Map<String, String>> messages,
  }) async {
    bulkCalls.add({'familyGroupId': familyGroupId, 'messages': messages});
    return messages.length;
  }

  @override
  Future<List<Message>> getPendingMessages() async => [];

  @override
  Future<List<Message>> getIgnoredMessages() async => [];

  @override
  Future<Message> confirmMessage(String messageId) =>
      throw UnimplementedError();

  @override
  Future<Message> rejectMessage(String messageId) =>
      throw UnimplementedError();

  @override
  Future<Message> restoreMessage(String messageId) =>
      throw UnimplementedError();
}

/// A [PatternCacheService] that records refreshPatterns() calls.
class RecordingPatternCache extends PatternCacheService {
  RecordingPatternCache({this.matchedPattern}) : super(dio: Dio());

  int refreshCalls = 0;

  /// Optional pattern returned by [patternById] (simulates a cached template).
  SmsPattern? matchedPattern;

  @override
  Future<void> loadPatterns() async {}

  @override
  Future<void> refreshPatterns() async {
    refreshCalls++;
  }

  @override
  SmsPattern? patternById(String? id) => matchedPattern;
}

/// An [SmsInboxReader] that returns canned messages instead of the OS inbox.
class CannedInboxReader extends SmsInboxReader {
  List<Message> canned;
  int readCalls = 0;

  /// When true, [readInbox] throws — exercises the sync error path.
  bool failRead = false;

  CannedInboxReader(this.canned) : super(cache: FakePatternCache());

  @override
  Future<List<Message>> readInbox({
    required String userId,
    DateTime? since,
    int limit = 500,
  }) async {
    readCalls++;
    if (failRead) throw Exception('inbox read exploded');
    return canned;
  }
}

class FakeAuthNotifier extends AuthNotifier {
  final User? user;
  FakeAuthNotifier(this.user);

  @override
  AuthState build() => AuthState(
        status: user == null
            ? AuthStatus.unauthenticated
            : AuthStatus.authenticated,
        user: user,
      );
}

class FakeFamilyNotifier extends FamilyNotifier {
  final FamilyGroup? family;
  FakeFamilyNotifier(this.family);

  @override
  FamilyState build() => FamilyState(currentFamily: family);
}

class FakeCategoryNotifier extends CategoryNotifier {
  final List<Category> categories;
  FakeCategoryNotifier(this.categories);

  @override
  CategoryState build() => CategoryState(categories: categories);
}

/// RecordingTransactionNotifier; counts addTransaction calls and
/// loadTransactions calls so the post-sync reload can be asserted without
/// touching the network.
class RecordingTransactionNotifier extends TransactionNotifier {
  final List<Map<String, dynamic>> addCalls = [];
  int loadCalls = 0;
  List<Transaction> getTransactionsResult = const [];

  @override
  TransactionState build() => const TransactionState();

  @override
  Future<void> addTransaction(Map<String, dynamic> data) async {
    addCalls.add(data);
  }

  @override
  Future<void> loadTransactions({TransactionType? type}) async {
    loadCalls++;
    state = state.copyWith(
      isLoading: false,
      transactions: getTransactionsResult,
    );
  }
}

/// MessageNotifier whose loadMessages is a no-op counter.
class FakeMessageNotifier extends MessageNotifier {
  int loadCalls = 0;

  @override
  MessageState build() => const MessageState();

  @override
  Future<void> loadMessages() async {
    loadCalls++;
    state = const MessageState();
  }
}

/// BudgetService that records dashboard reloads and never touches the network.
class RecordingBudgetService implements BudgetService {
  int loadDashboardCalls = 0;

  @override
  Future<Map<String, dynamic>> getDashboardData(String familyGroupId) async {
    loadDashboardCalls++;
    return {
      'monthlyBudgetLimit': 50000,
      'totalSpent': 500,
      'dailyAverage': 50,
      'projectedSpend': 1500,
      'estimatedSavings': 1000,
    };
  }

  @override
  Future<Map<String, dynamic>> getBudgetSummary(
          String familyGroupId, String? month) async =>
      {};

  @override
  Future<void> updateBudgetLimit(String familyGroupId, double limit) async {}
}

// ── Fixtures ──────────────────────────────────────────────────────

User kUser() => User(
      id: 'u1',
      googleId: 'google-u1',
      displayName: 'Jay',
      email: 'jay@budgetly.app',
      createdAt: DateTime.utc(2026, 1, 1),
    );

FamilyGroup kFamily() => FamilyGroup(
      id: 'fam-1',
      name: 'Home',
      monthlyBudgetLimit: 50000,
      createdByUserId: 'u1',
      createdAt: DateTime.utc(2026, 1, 1),
    );

Message smsMsg({
  required int id,
  String sender = 'HDFCBK',
  required String body,
  required DateTime at,
  ParseSource? parseSource,
  Map<String, String>? extractedData,
  String? matchedPatternId,
}) =>
    Message(
      id: 'sms_$id',
      userId: 'u1',
      sender: sender,
      rawText: body,
      status: MessageStatus.pending,
      parseSource: parseSource,
      extractedData: extractedData,
      matchedPatternId: matchedPatternId,
      receivedAt: at,
    );

Map<String, String> fullExtraction() => {
      'amount': '500',
      'merchant': 'Grocery Mart',
      'timestamp': '01/10/2026',
    };

SmsPattern kPattern({String? categoryName}) => SmsPattern(
      id: 'p-hdfc',
      sender: 'HDFCBK',
      template: 'Spent Rs {amount} at {merchant} on {timestamp}',
      extractionMap: const ExtractionMap(
        amount: 'amount',
        merchant: 'merchant',
        timestamp: 'timestamp',
      ),
      sampleMessage: 'Spent Rs 500 at Grocery Mart on 01/10/2026',
      categoryName: categoryName,
      createdAt: DateTime.utc(2026, 1, 1),
    );

Category kCategory({required String id, required String name}) => Category(
      id: id,
      familyGroupId: 'fam-1',
      name: name,
      icon: '🛒',
      budgetLimit: 0,
      color: '#5B5EF4',
    );

// ── Test rig ──────────────────────────────────────────────────────

ProviderContainer buildContainer({
  required CannedInboxReader reader,
  required RecordingMessageService messageService,
  required RecordingTransactionNotifier transactions,
  required RecordingPatternCache cache,
  User? user,
  FamilyGroup? family,
  List<Category>? categories,
  BudgetService? budgetService,
}) {
  return ProviderContainer(
    overrides: [
      patternCacheServiceProvider.overrideWithValue(cache),
      smsInboxReaderProvider.overrideWithValue(reader),
      authProvider.overrideWith(() => FakeAuthNotifier(user)),
      familyProvider.overrideWith(() => FakeFamilyNotifier(family)),
      categoryProvider.overrideWith(() => FakeCategoryNotifier(categories ?? [])),
      messageServiceProvider.overrideWithValue(messageService),
      if (budgetService != null)
        budgetServiceProvider.overrideWithValue(budgetService),
      transactionProvider.overrideWith(() => transactions),
      messageProvider.overrideWith(() => FakeMessageNotifier()),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CannedInboxReader reader;
  late RecordingMessageService messageService;
  late RecordingTransactionNotifier transactions;
  late RecordingPatternCache cache;
  late ProviderContainer container;
  final now = DateTime.utc(2026, 11, 1, 12);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PermissionHandlerPlatform.instance =
        FakePermissionHandler(status: PermissionStatus.granted);

    reader = CannedInboxReader(const []);
    messageService = RecordingMessageService();
    transactions = RecordingTransactionNotifier();
    cache = RecordingPatternCache();
    container = buildContainer(
      reader: reader,
      messageService: messageService,
      transactions: transactions,
      cache: cache,
      user: kUser(),
      family: kFamily(),
    );
    addTearDown(container.dispose);
  });

  /// _init() is fire-and-forget from build(); settle until the async
  /// permission check has landed so sync() saw the granted state.
  Future<void> settleInit() async {
    for (var i = 0; i < 100; i++) {
      if (container.read(smsProvider).smsPermissionGranted) return;
      await pumpEventQueue();
    }
    fail('SmsNotifier._init() never observed granted SMS permission');
  }

  Future<void> sync() async {
    await settleInit();
    await container.read(smsProvider.notifier).syncInboxMessages();
  }

  group('syncInboxMessages — regexLocal fully parsed', () {
    test('turns the message into a transaction directly, no server call',
        () async {
      reader.canned = [
        smsMsg(
          id: 1,
          body: 'Spent Rs 500 at Grocery Mart on 01/10/2026',
          at: now,
          parseSource: ParseSource.regexLocal,
          extractedData: fullExtraction(),
          matchedPatternId: 'p-hdfc',
        ),
      ];

      await sync();

      expect(transactions.addCalls, hasLength(1));
      final tx = transactions.addCalls.single;
      expect(tx['amount'], 500.0);
      expect(tx['merchant'], 'Grocery Mart');
      expect(tx['type'], 'EXPENSE');
      expect(tx['sourceType'], 'REGEX_LOCAL');
      expect(tx['sourceRawText'], 'Spent Rs 500 at Grocery Mart on 01/10/2026');
      expect(tx['matchedPatternId'], 'p-hdfc');
      // No category override on the pattern → no categoryId key.
      expect(tx.containsKey('categoryId'), isFalse);

      expect(messageService.processCalls, isEmpty);
      expect(messageService.bulkCalls, isEmpty);
      // No server-bound messages → no pattern refresh (avoids a wasted round-trip).
      expect(cache.refreshCalls, 0);
      expect(reader.readCalls, 1);
    });

    test('resolves the template categoryName override to a family category id',
        () async {
      cache.matchedPattern = kPattern(categoryName: 'Groceries');

      final overrideContainer = buildContainer(
        reader: reader,
        messageService: messageService,
        transactions: transactions,
        cache: cache,
        user: kUser(),
        family: kFamily(),
        categories: [kCategory(id: 'cat-1', name: 'Groceries')],
      );
      addTearDown(overrideContainer.dispose);

      reader.canned = [
        smsMsg(
          id: 1,
          body: 'Spent Rs 500 at Grocery Mart on 01/10/2026',
          at: now,
          parseSource: ParseSource.regexLocal,
          extractedData: fullExtraction(),
          matchedPatternId: 'p-hdfc',
        ),
      ];

      await settleInitFor(overrideContainer);
      await overrideContainer.read(smsProvider.notifier).syncInboxMessages();

      expect(transactions.addCalls, hasLength(1));
      expect(transactions.addCalls.single['categoryId'], 'cat-1');
    });
  });

  group('syncInboxMessages — regexLocal incomplete', () {
    test('bulk-queues incomplete regex messages for the server', () async {
      reader.canned = [
        smsMsg(
          id: 2,
          body: 'Spent Rs 500 (bill on its way)',
          at: now,
          parseSource: ParseSource.regexLocal,
          extractedData: {'amount': '500'}, // merchant + timestamp missing
          matchedPatternId: 'p-hdfc',
        ),
      ];

      await sync();

      // No per-message LLM call anymore — goes through POST /messages/bulk.
      expect(messageService.processCalls, isEmpty);
      expect(messageService.bulkCalls, hasLength(1));
      final call = messageService.bulkCalls.single;
      expect(call['familyGroupId'], 'fam-1');
      expect(call['messages'], [
        {
          'sender': 'HDFCBK',
          'rawText': 'Spent Rs 500 (bill on its way)',
          'receivedAt': now.toIso8601String(),
        },
      ]);
      expect(transactions.addCalls, isEmpty);
      // A submitted batch triggers one pattern refresh for the next sync.
      expect(cache.refreshCalls, 1);
    });
  });

  group('syncInboxMessages — unprocessed (queued for server)', () {
    test('bulk-submits unmatched messages and refreshes patterns once',
        () async {
      reader.canned = [
        smsMsg(
          id: 3,
          sender: 'SBIUPI',
          body: 'Rs.750 debited from a/c 4321 for Swiggy.',
          at: now,
        ),
      ];

      await sync();

      expect(messageService.processCalls, isEmpty);
      expect(messageService.bulkCalls, hasLength(1));
      final call = messageService.bulkCalls.single;
      expect(call['familyGroupId'], 'fam-1');
      expect(call['messages'], [
        {
          'sender': 'SBIUPI',
          'rawText': 'Rs.750 debited from a/c 4321 for Swiggy.',
          'receivedAt': now.toIso8601String(),
        },
      ]);
      expect(transactions.addCalls, isEmpty);
      // The server pipeline may have registered new patterns while processing
      // the batch — the client refreshes its local cache once afterwards.
      expect(cache.refreshCalls, 1);
    });

    test('chunks large inboxes into bulk batches of at most 500', () async {
      reader.canned = [
        for (var i = 0; i < 1001; i++)
          smsMsg(
            id: 1000 + i,
            sender: 'AXISBK',
            body: 'Dear customer, Rs.${i + 1} debited at Store $i.',
            at: now,
          ),
      ];

      await sync();

      // 1001 > 2×500, so three requests: 500 + 500 + 1.
      expect(messageService.bulkCalls, hasLength(3));
      expect(messageService.bulkCalls[0]['messages'], hasLength(500));
      expect(messageService.bulkCalls[1]['messages'], hasLength(500));
      expect(messageService.bulkCalls[2]['messages'], hasLength(1));
      // Exactly one pattern refresh for the whole sync, not per batch.
      expect(cache.refreshCalls, 1);
      expect(transactions.addCalls, isEmpty);
    });
  });

  group('syncInboxMessages — abort guards', () {
    test('unauthenticated user → no inbox read, no processing', () async {
      final unauthed = buildContainer(
        reader: reader,
        messageService: messageService,
        transactions: transactions,
        cache: cache,
        user: null,
        family: kFamily(),
      );
      addTearDown(unauthed.dispose);
      await settleInitFor(unauthed);
      await unauthed.read(smsProvider.notifier).syncInboxMessages();

      expect(reader.readCalls, 0);
      expect(messageService.processCalls, isEmpty);
      expect(messageService.bulkCalls, isEmpty);
      expect(transactions.addCalls, isEmpty);
      expect(unauthed.read(smsProvider).isSyncing, isFalse);
    });

    test('no family loaded → no inbox read, no processing', () async {
      final noFamily = buildContainer(
        reader: reader,
        messageService: messageService,
        transactions: transactions,
        cache: cache,
        user: kUser(),
        family: null,
      );
      addTearDown(noFamily.dispose);
      await settleInitFor(noFamily);
      await noFamily.read(smsProvider.notifier).syncInboxMessages();

      expect(reader.readCalls, 0);
      expect(messageService.processCalls, isEmpty);
      expect(messageService.bulkCalls, isEmpty);
      expect(transactions.addCalls, isEmpty);
      expect(noFamily.read(smsProvider).isSyncing, isFalse);
    });
  });

  group('syncInboxMessages — checkpoint bookkeeping', () {
    test('checkpoint advances to the newest processed message', () async {
      final older = now.subtract(const Duration(days: 2));
      reader.canned = [
        smsMsg(
          id: 10,
          body: 'Spent Rs 100 at Store A on 01/10/2026',
          at: now,
          parseSource: ParseSource.regexLocal,
          extractedData: fullExtraction(),
        ),
        smsMsg(
          id: 11,
          body: 'Spent Rs 200 at Store B on 01/10/2026',
          at: older,
          parseSource: ParseSource.regexLocal,
          extractedData: fullExtraction(),
        ),
      ];

      await sync();
      await pumpEventQueue();

      // readInbox returns newest first; sync processes oldest first, so the
      // final checkpoint is the newest message's timestamp.
      expect(transactions.addCalls, hasLength(2));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(kCheckpointKey), now.millisecondsSinceEpoch);
      expect(container.read(smsProvider).lastProcessedSmsTimestamp,
          now.millisecondsSinceEpoch);
    });

    test('isSyncing resets and messages reload even when the sync throws',
        () async {
      reader.failRead = true;

      await sync();

      expect(reader.readCalls, 1);
      final state = container.read(smsProvider);
      expect(state.isSyncing, isFalse);
      // The finally block still reloads the message list on the failure path.
      final fakeMsg =
          container.read(messageProvider.notifier) as FakeMessageNotifier;
      expect(fakeMsg.loadCalls, 1);
    });
  });

  group('syncInboxMessages — dashboard refresh', () {
    test('reloads transactions and budget after a successful sync', () async {
      final budgetService = RecordingBudgetService();

      transactions.getTransactionsResult = [
        Transaction(
          id: 'tx-1',
          familyGroupId: 'fam-1',
          createdByUserId: 'u1',
          amount: 500,
          merchant: 'Grocery Mart',
          type: TransactionType.expense,
          transactionDate: now,
          createdAt: now,
        ),
      ];

      final refreshContainer = buildContainer(
        reader: reader,
        messageService: messageService,
        transactions: transactions,
        cache: cache,
        user: kUser(),
        family: kFamily(),
        budgetService: budgetService,
      );
      addTearDown(refreshContainer.dispose);

      reader.canned = [
        smsMsg(
          id: 30,
          sender: 'SBIUPI',
          body: 'Rs.750 debited from a/c 4321.',
          at: now,
        ),
      ];

      await settleInitFor(refreshContainer);
      await refreshContainer.read(smsProvider.notifier).syncInboxMessages();

      // A server-bound message reloads the transaction list and the budget
      // dashboard so Home surfaces server-parsed transactions.
      expect(messageService.bulkCalls, hasLength(1));
      expect(transactions.loadCalls, 1);
      expect(budgetService.loadDashboardCalls, 1);
      expect(refreshContainer.read(transactionProvider).transactions,
          hasLength(1));
    });
  });

  group('syncInboxMessages — background sync toggle (WORK-203)', () {
    test('toggle persists the preference and is restored on next launch',
        () async {
      // Default is enabled.
      await settleInit();
      expect(container.read(smsProvider).backgroundServiceEnabled, isTrue);

      await container.read(smsProvider.notifier).toggleBackgroundService();
      expect(container.read(smsProvider).backgroundServiceEnabled, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('background_sms_service_enabled'), isFalse);

      // A fresh container (same persisted prefs) restores the off state.
      final restarted = buildContainer(
        reader: reader,
        messageService: messageService,
        transactions: transactions,
        cache: cache,
        user: kUser(),
        family: kFamily(),
      );
      addTearDown(restarted.dispose);
      await settleInitFor(restarted);
      expect(restarted.read(smsProvider).backgroundServiceEnabled, isFalse);
    });

    test('background sync is skipped while the toggle is off', () async {
      await settleInit();
      await container.read(smsProvider.notifier).toggleBackgroundService();

      await container.read(smsProvider.notifier).triggerBackgroundSync();

      // Toggle-gated: no inbox read, no bulk submission.
      expect(reader.readCalls, 0);
      expect(messageService.bulkCalls, isEmpty);
    });

    test('background sync is debounced to one run per 30s', () async {
      await settleInit();
      reader.canned = [
        smsMsg(
          id: 20,
          sender: 'SBIUPI',
          body: 'Rs.750 debited from a/c 4321.',
          at: now,
        ),
      ];

      final notifier = container.read(smsProvider.notifier);
      await notifier.triggerBackgroundSync();
      await notifier.triggerBackgroundSync();
      await notifier.triggerBackgroundSync();

      // First call ran the sync; the next two were debounced.
      expect(reader.readCalls, 1);
      expect(messageService.bulkCalls, hasLength(1));
    });
  });
}

/// Perm-settle helper for separate containers (see [settleInit]).
Future<void> settleInitFor(ProviderContainer c) async {
  for (var i = 0; i < 100; i++) {
    if (c.read(smsProvider).smsPermissionGranted) return;
    await pumpEventQueue();
  }
  fail('SmsNotifier._init() never observed granted SMS permission');
}