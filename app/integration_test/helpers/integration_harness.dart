import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:budgetly/app.dart';
import 'package:budgetly/data/mock/mock_auth_service.dart';
import 'package:budgetly/data/mock/mock_budget_service.dart';
import 'package:budgetly/data/mock/mock_category_service.dart';
import 'package:budgetly/data/mock/mock_message_service.dart';
import 'package:budgetly/data/mock/sample_data.dart';
import 'package:budgetly/data/transaction_service.dart';
import 'package:budgetly/models/sms_pattern.dart';
import 'package:budgetly/models/transaction.dart';
import 'package:budgetly/providers/auth_provider.dart';
import 'package:budgetly/providers/family_provider.dart';
import 'package:budgetly/providers/service_providers.dart';
import 'package:budgetly/providers/sms_provider.dart';
import 'package:budgetly/services/pattern_cache_service.dart';
import 'package:budgetly/services/sms_inbox_reader.dart';

// ── Cross-test setup ─────────────────────────────────────────────

/// Wipes persisted preferences so a run always behaves like a first launch.
///
/// Passing `sms_consent_prompted` keeps the dashboard's 500 ms consent check
/// from opening a modal sheet over the UI under test.
void resetIntegrationPreferences({
  Map<String, Object> values = const {'sms_consent_prompted': true},
}) {
  SharedPreferences.setMockInitialValues(values);
}

/// Replaces the OS permission layer with a deterministic answer.
void installPermissionHandler(PermissionStatus status) {
  PermissionHandlerPlatform.instance = TestPermissionHandler(status);
}

class TestPermissionHandler extends PermissionHandlerPlatform {
  TestPermissionHandler(this.status);

  final PermissionStatus status;

  @override
  Future<PermissionStatus> checkPermissionStatus(Permission permission) async =>
      status;

  @override
  Future<Map<Permission, PermissionStatus>> requestPermissions(
    List<Permission> permissions,
  ) async => {for (final permission in permissions) permission: status};
}

// ── SMS inbox doubles ────────────────────────────────────────────

/// Method channel used by the flutter_sms_inbox plugin (JSON codec — the mock
/// reply must use the codec the plugin decodes with).
const MethodChannel _smsQueryChannel = MethodChannel(
  'plugins.juliusgithaiga.com/querySMS',
  JSONMethodCodec(),
);

/// Builds an [SmsMessage] with the plugin's map shape.
SmsMessage deviceSms({
  required int id,
  required String sender,
  required String body,
  required DateTime sentAt,
  DateTime? receivedAt,
}) =>
    SmsMessage.fromJson({
      '_id': id,
      'address': sender,
      'body': body,
      'date': (receivedAt ?? sentAt).millisecondsSinceEpoch,
      'date_sent': sentAt.millisecondsSinceEpoch,
    });

/// Makes the real [SmsInboxReader] read [messages] (newest first) from the
/// stubbed device inbox instead of the OS.
void stubDeviceInbox(List<SmsMessage> messages) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_smsQueryChannel, (MethodCall call) async {
    return [
      for (final message in messages)
        <String, dynamic>{
          '_id': message.id,
          'address': message.address,
          'body': message.body,
          if (message.date != null)
            'date': message.date!.millisecondsSinceEpoch,
          if (message.dateSent != null)
            'date_sent': message.dateSent!.millisecondsSinceEpoch,
        },
    ];
  });
}

void resetDeviceInbox() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_smsQueryChannel, null);
}

/// Real reader with only the permission check stubbed, so the anchor parser
/// and message-to-[Message] conversion under test still execute.
class FakeSmsInboxReader extends SmsInboxReader {
  FakeSmsInboxReader({required this.granted, required PatternCacheService cache})
      : super(cache: cache);

  final bool granted;

  @override
  Future<bool> hasPermission() async => granted;
}

/// Cached patterns that never hit the network.
class OfflinePatternCache extends PatternCacheService {
  OfflinePatternCache([List<SmsPattern> seeded = const []])
      : _seeded = List.of(seeded),
        super(dio: Dio());

  final List<SmsPattern> _seeded;

  @override
  int get patternCount => _seeded.length;

  @override
  List<SmsPattern> get patterns => List.unmodifiable(_seeded);

  @override
  List<SmsPattern> get matchablePatterns =>
      _seeded.where((pattern) => pattern.isEnabledForFamily).toList();

  @override
  SmsPattern? patternById(String? id) {
    if (id == null) return null;
    for (final pattern in _seeded) {
      if (pattern.id == id) return pattern;
    }
    return null;
  }

  @override
  Future<void> loadPatterns() async {}

  @override
  Future<void> refreshPatterns() async {}
}

// ── Seeded state ─────────────────────────────────────────────────

/// Already-signed-in auth state (no Google account or backend required).
class SeededAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState(
        status: AuthStatus.authenticated,
        user: SampleData.user1,
        accessToken: 'integration-access-token',
      );
}

/// The sample family, without constructing a family service.
class SeededFamilyNotifier extends FamilyNotifier {
  static final FamilyState _state = FamilyState(
    currentFamily: SampleData.familyGroup,
    members: SampleData.members,
  );

  @override
  FamilyState build() => _state;

  @override
  Future<void> loadMyFamily() async {
    state = _state;
  }

  @override
  Future<void> loadFamily(String familyGroupId) async {
    state = _state;
  }
}

/// SMS settings state that never reads the OS or preferences.
class SeededSmsNotifier extends SmsNotifier {
  SeededSmsNotifier(this._state);

  final SmsState _state;

  @override
  SmsState build() => _state;
}

// ── Service doubles ──────────────────────────────────────────────

/// In-memory transaction store that records every payload the app posts and
/// echoes it back as a real [Transaction] (so list/inbox pairing works).
class RecordingTransactionService implements TransactionService {
  RecordingTransactionService({List<Transaction> seed = const []})
      : _seed = List.of(seed);

  final List<Transaction> _seed;
  final List<Transaction> _created = [];
  final List<Map<String, dynamic>> createCalls = [];

  @override
  Future<List<Transaction>> getTransactions(
    String familyGroupId, {
    int page = 0,
    int size = 20,
    TransactionType? type,
  }) async {
    var result = [..._created, ..._seed];
    if (type != null) {
      result = result.where((transaction) => transaction.type == type).toList();
    }
    return result;
  }

  @override
  Future<Transaction> getTransaction(String familyGroupId, String id) async =>
      [..._created, ..._seed].firstWhere((transaction) => transaction.id == id);

  @override
  Future<Transaction> createTransaction(
    String familyGroupId,
    Map<String, dynamic> data,
  ) async {
    createCalls.add(Map<String, dynamic>.of(data));
    final created = _fromPayload(familyGroupId, data);
    _created.insert(0, created);
    return created;
  }

  @override
  Future<Transaction> updateTransaction(
    String familyGroupId,
    String id,
    Map<String, dynamic> data,
  ) async {
    final updated = _fromPayload(familyGroupId, data, id: id);
    final index = _created.indexWhere((transaction) => transaction.id == id);
    if (index >= 0) {
      _created[index] = updated;
    } else {
      final seedIndex = _seed.indexWhere((transaction) => transaction.id == id);
      _seed[seedIndex] = updated;
    }
    return updated;
  }

  @override
  Future<void> deleteTransaction(String familyGroupId, String id) async {
    _created.removeWhere((transaction) => transaction.id == id);
    _seed.removeWhere((transaction) => transaction.id == id);
  }

  Transaction _fromPayload(
    String familyGroupId,
    Map<String, dynamic> data, {
    String? id,
  }) {
    final rawType = (data['type'] as String?)?.toUpperCase();
    final rawSource = (data['sourceType'] as String?)?.toUpperCase();
    return Transaction(
      id: id ?? 'tx-e2e-${createCalls.length}',
      familyGroupId: familyGroupId,
      createdByUserId:
          (data['createdByUserId'] as String?) ?? SampleData.user1.id,
      categoryId: data['categoryId'] as String?,
      amount: (data['amount'] as num).toDouble(),
      currency: (data['currency'] as String?) ?? 'INR',
      merchant: data['merchant'] as String,
      description: data['description'] as String?,
      type: switch (rawType) {
        'INCOME' => TransactionType.income,
        'SUBSCRIPTION' => TransactionType.subscription,
        _ => TransactionType.expense,
      },
      sourceType: switch (rawSource) {
        'REGEX_LOCAL' => SourceType.regexLocal,
        'LLM_SERVER' => SourceType.llmServer,
        _ => SourceType.manual,
      },
      sourceRawText: data['sourceRawText'] as String?,
      matchedPatternId: data['matchedPatternId'] as String?,
      accountLast4: data['accountLast4'] as String?,
      bankName: data['bankName'] as String?,
      notes: data['notes'] as String?,
      transactionDate: DateTime.parse(data['transactionDate'] as String),
      createdAt: DateTime.now(),
    );
  }
}

// ── App pump ─────────────────────────────────────────────────────

/// Pumps frames across [duration] of real time so in-flight timers and
/// simulated service delays complete before assertions.
///
/// The live integration binding stops settling as soon as no frame is queued,
/// so a bare [WidgetTester.pumpAndSettle] can return while a `Future.delayed`
/// (mock services use 100–500 ms) is still pending.
Future<void> settleFor(
  WidgetTester tester, [
  Duration duration = const Duration(seconds: 2),
]) async {
  final deadline = DateTime.now().add(duration);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}

class IntegrationHarness {
  IntegrationHarness({
    required this.container,
    required this.transactions,
    required this.patternCache,
  });

  final ProviderContainer container;
  final RecordingTransactionService transactions;
  final OfflinePatternCache patternCache;
}

/// Boots the real [BudgetlyApp] with every network seam replaced by an
/// in-memory double.
///
/// [authenticated] seeds the auth state; pass false to exercise the login
/// screen and sign-in flow. [seedSmsState] keeps the dashboard's consent timer
/// quiet for flows that do not exercise SMS.
Future<IntegrationHarness> pumpIntegrationApp(
  WidgetTester tester, {
  String? initialLocation,
  bool authenticated = true,
  bool seedSmsState = true,
  RecordingTransactionService? transactions,
  OfflinePatternCache? patternCache,
  SmsInboxReader? smsInboxReader,
}) async {
  final transactionService = transactions ??
      RecordingTransactionService(seed: SampleData.transactions);
  final cache = patternCache ?? OfflinePatternCache();
  final reader =
      smsInboxReader ?? FakeSmsInboxReader(granted: false, cache: cache);

  final container = ProviderContainer(
    overrides: [
      authServiceProvider.overrideWithValue(MockAuthService()),
      transactionServiceProvider.overrideWithValue(transactionService),
      categoryServiceProvider.overrideWithValue(MockCategoryService()),
      budgetServiceProvider.overrideWithValue(MockBudgetService()),
      messageServiceProvider.overrideWithValue(MockMessageService()),
      patternCacheServiceProvider.overrideWithValue(cache),
      smsInboxReaderProvider.overrideWithValue(reader),
      familyProvider.overrideWith(SeededFamilyNotifier.new),
      if (authenticated) authProvider.overrideWith(SeededAuthNotifier.new),
      if (seedSmsState)
        smsProvider.overrideWith(
          () => SeededSmsNotifier(
            const SmsState(hasPromptedForConsent: true),
          ),
        ),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: BudgetlyApp(initialDeepLink: initialLocation),
    ),
  );
  await tester.pump();

  return IntegrationHarness(
    container: container,
    transactions: transactionService,
    patternCache: cache,
  );
}
