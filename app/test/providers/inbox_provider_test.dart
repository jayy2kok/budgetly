import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:budgetly/data/transaction_service.dart';
import 'package:budgetly/models/family_group.dart';
import 'package:budgetly/models/message.dart';
import 'package:budgetly/models/transaction.dart';
import 'package:budgetly/models/user.dart';
import 'package:budgetly/providers/auth_provider.dart';
import 'package:budgetly/providers/family_provider.dart';
import 'package:budgetly/providers/inbox_provider.dart';
import 'package:budgetly/providers/service_providers.dart';
import 'package:budgetly/services/sms_inbox_reader.dart';

import '../helpers/inbox_fakes.dart';

class _FakeReader extends SmsInboxReader {
  _FakeReader({required this.granted, this.messages = const []})
      : super(cache: FakePatternCache());

  final bool granted;
  final List<Message> messages;
  int readCalls = 0;

  @override
  Future<bool> hasPermission() async => granted;

  @override
  Future<List<Message>> readAllInbox({
    required String userId,
    int limit = 300,
  }) async {
    readCalls++;
    return messages;
  }
}

class _FakeTransactionService implements TransactionService {
  _FakeTransactionService(this.pages);

  final List<List<Transaction>> pages;
  final List<int> requestedPages = [];

  @override
  Future<List<Transaction>> getTransactions(
    String familyGroupId, {
    int page = 0,
    int size = 20,
    TransactionType? type,
  }) async {
    requestedPages.add(page);
    if (page >= pages.length) return const [];
    return pages[page];
  }

  @override
  Future<Transaction> getTransaction(String familyGroupId, String id) =>
      throw UnimplementedError();

  @override
  Future<Transaction> createTransaction(
    String familyGroupId,
    Map<String, dynamic> data,
  ) =>
      throw UnimplementedError();

  @override
  Future<Transaction> updateTransaction(
    String familyGroupId,
    String id,
    Map<String, dynamic> data,
  ) =>
      throw UnimplementedError();

  @override
  Future<void> deleteTransaction(String familyGroupId, String id) async {}
}

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this._user);

  final User? _user;

  @override
  AuthState build() => AuthState(
        status: _user == null
            ? AuthStatus.unauthenticated
            : AuthStatus.authenticated,
        user: _user,
      );
}

class _FakeFamilyNotifier extends FamilyNotifier {
  _FakeFamilyNotifier(this._state);

  final FamilyState _state;

  @override
  FamilyState build() => _state;
}

final _user = User(
  id: 'u1',
  googleId: 'g-u1',
  displayName: 'Jay',
  email: 'jay@budgetly.app',
  createdAt: DateTime.utc(2026, 1, 1),
);

final _family = FamilyGroup(
  id: 'fam-1',
  name: 'Home',
  monthlyBudgetLimit: 50000,
  createdByUserId: 'u1',
  createdAt: DateTime.utc(2026, 1, 1),
);

final _now = DateTime.utc(2026, 11, 20, 12);

Message _sms(int id, String body, {DateTime? at}) => Message(
      id: 'sms_$id',
      userId: 'u1',
      sender: 'HDFCBK',
      rawText: body,
      status: MessageStatus.pending,
      receivedAt: at ?? _now,
    );

Transaction _tx(
  String id, {
  required String? rawText,
  required DateTime date,
  SourceType sourceType = SourceType.regexLocal,
}) =>
    Transaction(
      id: id,
      familyGroupId: 'fam-1',
      createdByUserId: 'u1',
      amount: 500,
      merchant: 'Grocery Mart',
      type: TransactionType.expense,
      sourceType: sourceType,
      sourceRawText: rawText,
      transactionDate: date,
      createdAt: date,
    );

ProviderContainer _container({
  required _FakeReader reader,
  required _FakeTransactionService service,
  bool signedIn = true,
  bool hasFamily = true,
}) {
  final container = ProviderContainer(
    overrides: [
      smsInboxReaderProvider.overrideWithValue(reader),
      transactionServiceProvider.overrideWithValue(service),
      authProvider.overrideWith(
        () => _FakeAuthNotifier(signedIn ? _user : null),
      ),
      familyProvider.overrideWith(() => _FakeFamilyNotifier(
            FamilyState(
              currentFamily: hasFamily ? _family : null,
              members: const [],
            ),
          )),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('InboxNotifier.refresh', () {
    test('splits device SMS by whether a transaction matches', () async {
      const body = 'Rs.500 debited at Grocery Mart';
      final reader = _FakeReader(
        granted: true,
        messages: [
          _sms(1, body),
          _sms(2, 'Your OTP is 123456'),
          _sms(3, 'Happy Diwali from BigMart'),
        ],
      );
      final service = _FakeTransactionService([
        [
          _tx('tx-1', rawText: body, date: _now),
        ],
      ]);
      final container = _container(reader: reader, service: service);

      await container.read(inboxProvider.notifier).refresh();

      final state = container.read(inboxProvider);
      expect(state.recordedMessages.map((m) => m.id), ['sms_1']);
      expect(state.nonTransactions.map((m) => m.id), ['sms_2', 'sms_3']);
      expect(state.transactionByMessageId['sms_1']!.id, 'tx-1');
      expect(state.permissionDenied, isFalse);
      expect(state.error, isNull);
      expect(state.isLoading, isFalse);
    });

    test('matches bodies after trimming and collapsing whitespace', () async {
      final reader = _FakeReader(
        granted: true,
        messages: [_sms(1, '  Rs.500   debited\n at Grocery Mart ')],
      );
      final service = _FakeTransactionService([
        [
          _tx(
            'tx-1',
            rawText: 'Rs.500 debited at Grocery Mart',
            date: _now,
          ),
        ],
      ]);
      final container = _container(reader: reader, service: service);

      await container.read(inboxProvider.notifier).refresh();

      expect(
        container.read(inboxProvider).recordedMessages.single.id,
        'sms_1',
      );
    });

    test('duplicate bodies pair one-to-one with distinct transactions', () async {
      const body = 'Rs.500 debited at Grocery Mart';
      final older = _now.subtract(const Duration(hours: 1));
      final reader = _FakeReader(
        granted: true,
        messages: [_sms(1, body, at: _now), _sms(2, body, at: older)],
      );
      final service = _FakeTransactionService([
        [
          _tx(
            'tx-old',
            rawText: body,
            date: _now.subtract(const Duration(hours: 2)),
          ),
          _tx(
            'tx-new',
            rawText: body,
            date: _now.subtract(const Duration(minutes: 30)),
          ),
        ],
      ]);
      final container = _container(reader: reader, service: service);

      await container.read(inboxProvider.notifier).refresh();

      final state = container.read(inboxProvider);
      expect(state.recordedMessages, hasLength(2));
      expect(state.nonTransactions, isEmpty);
      // Newest SMS consumes the newest transaction.
      expect(state.transactionByMessageId['sms_1']!.id, 'tx-new');
      expect(state.transactionByMessageId['sms_2']!.id, 'tx-old');
    });

    test('manual and legacy rows never mark an SMS as recorded', () async {
      const body = 'Rs.500 debited at Grocery Mart';
      final reader = _FakeReader(granted: true, messages: [_sms(1, body)]);
      final service = _FakeTransactionService([
        [
          _tx('tx-manual', rawText: body, date: _now,
              sourceType: SourceType.manual),
          // Legacy SMS-sourced row created before sourceRawText existed.
          _tx('tx-legacy', rawText: null, date: _now),
        ],
      ]);
      final container = _container(reader: reader, service: service);

      await container.read(inboxProvider.notifier).refresh();

      expect(container.read(inboxProvider).recordedMessages, isEmpty);
      expect(container.read(inboxProvider).nonTransactions, hasLength(1));
    });

    test('permission denied clears both tabs and flags the state', () async {
      final reader = _FakeReader(granted: false);
      final service = _FakeTransactionService([]);
      final container = _container(reader: reader, service: service);

      await container.read(inboxProvider.notifier).refresh();

      final state = container.read(inboxProvider);
      expect(state.permissionDenied, isTrue);
      expect(state.recordedMessages, isEmpty);
      expect(state.nonTransactions, isEmpty);
      expect(reader.readCalls, 0);
    });

    test('stops paging on a short page', () async {
      final reader = _FakeReader(granted: true, messages: [_sms(1, 'hello')]);
      final service = _FakeTransactionService([
        [_tx('tx-1', rawText: 'other', date: _now)],
      ]);
      final container = _container(reader: reader, service: service);

      await container.read(inboxProvider.notifier).refresh();

      expect(service.requestedPages, [0]);
    });

    test('stops paging once transactions predate the oldest SMS', () async {
      final oldestSms = _now.subtract(const Duration(days: 3));
      final reader = _FakeReader(
        granted: true,
        messages: [_sms(1, 'hello', at: oldestSms)],
      );
      final fullPage = [
        for (var i = 0; i < 200; i++)
          _tx(
            'tx-$i',
            rawText: null,
            date: _now.subtract(Duration(days: 4, minutes: i)),
          ),
      ];
      final service = _FakeTransactionService([fullPage]);
      final container = _container(reader: reader, service: service);

      await container.read(inboxProvider.notifier).refresh();

      expect(service.requestedPages, [0]);
    });

    test('caps the fetch at five pages', () async {
      final reader = _FakeReader(
        granted: true,
        messages: [_sms(1, 'hello', at: _now.subtract(const Duration(days: 30)))],
      );
      List<Transaction> page(int p) => [
            for (var i = 0; i < 200; i++)
              _tx('tx-$p-$i', rawText: null, date: _now),
          ];
      final service = _FakeTransactionService([
        page(0),
        page(1),
        page(2),
        page(3),
        page(4),
        page(5),
      ]);
      final container = _container(reader: reader, service: service);

      await container.read(inboxProvider.notifier).refresh();

      expect(service.requestedPages, [0, 1, 2, 3, 4]);
    });

    test('a family-less user reads the inbox without fetching transactions',
        () async {
      final reader = _FakeReader(granted: true, messages: [_sms(1, 'hello')]);
      final service = _FakeTransactionService([]);
      final container =
          _container(reader: reader, service: service, hasFamily: false);

      await container.read(inboxProvider.notifier).refresh();

      expect(service.requestedPages, isEmpty);
      expect(container.read(inboxProvider).nonTransactions, hasLength(1));
    });

    test('an unauthenticated user gets an error, no inbox read', () async {
      final reader = _FakeReader(granted: true);
      final service = _FakeTransactionService([]);
      final container =
          _container(reader: reader, service: service, signedIn: false);

      await container.read(inboxProvider.notifier).refresh();

      final state = container.read(inboxProvider);
      expect(state.error, 'Not signed in');
      expect(reader.readCalls, 0);
    });
  });
}