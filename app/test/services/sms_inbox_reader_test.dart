import 'package:flutter_test/flutter_test.dart';

import 'package:budgetly/models/message.dart';
import 'package:budgetly/models/sms_pattern.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';

import '../helpers/inbox_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime.utc(2026, 11, 1, 12);

  FakePatternCache cacheWith([List<SmsPattern> patterns = const []]) {
    final cache = FakePatternCache();
    cache.debugSetPatterns(patterns);
    return cache;
  }

  TestSmsInboxReader reader({
    required bool granted,
    required FakePatternCache cache,
    List<SmsMessage> inbox = const [],
  }) {
    stubSmsInbox(inbox);
    return TestSmsInboxReader(granted: granted, cache: cache);
  }

  group('SmsInboxReader permission', () {
    test('returns no messages without SMS permission', () async {
      final r = reader(granted: false, cache: cacheWith([hdfcPattern()]));
      expect(await r.readInbox(userId: 'u1'), isEmpty);
    });

    test('readAllInbox also honours the permission gate', () async {
      final r = reader(granted: false, cache: cacheWith([]));
      expect(await r.readAllInbox(userId: 'u1'), isEmpty);
    });
  });

  group('SmsInboxReader all-inbox read', () {
    test('includes every SMS, financial or not', () async {
      final r = reader(
        granted: true,
        cache: cacheWith([hdfcPattern()]),
        inbox: [
          sms(1, 'HDFCBK', 'Spent Rs 500 at Grocery Mart on 01/10/2026', now),
          sms(2, 'ADVRT', 'Happy Diwali! Flat 20% off everything.', now),
          sms(3, 'OTPBNK', 'Your OTP for login is 482913. Do not share.', now),
        ],
      );

      final messages = await r.readAllInbox(userId: 'u1');

      expect(messages, hasLength(3));
      // The inbox view is raw: no parsing or sender filtering.
      expect(messages.every((m) => m.parseSource == null), isTrue);
      expect(messages.every((m) => m.status == MessageStatus.pending), isTrue);
      expect(messages.map((m) => m.rawText), [
        'Spent Rs 500 at Grocery Mart on 01/10/2026',
        'Happy Diwali! Flat 20% off everything.',
        'Your OTP for login is 482913. Do not share.',
      ]);
    });

    test('uses the received time, not the send time', () async {
      final sent = DateTime.utc(2026, 11, 1, 11);
      final received = DateTime.utc(2026, 11, 1, 12);
      final r = reader(
        granted: true,
        cache: cacheWith([]),
        inbox: [sms(1, 'HDFCBK', 'Rs.100 debited', sent, receivedAt: received)],
      );

      final messages = await r.readAllInbox(userId: 'u1');

      expect(
        messages.single.receivedAt.isAtSameMomentAs(received),
        isTrue,
        reason: 'the received (arrival) time must win over date_sent',
      );
      expect(messages.single.id, 'sms_1');
    });

    test('skips SMS with empty sender or body', () async {
      final r = reader(
        granted: true,
        cache: cacheWith([]),
        inbox: [
          sms(1, '', 'Rs.100 debited', now),
          sms(2, 'SBIUPI', '', now),
        ],
      );

      expect(await r.readAllInbox(userId: 'u1'), isEmpty);
    });
  });

  group('SmsInboxReader matchable patterns', () {
    test('a pattern hidden for the family does not parse messages', () async {
      final hidden = SmsPattern(
        id: 'p-hidden',
        sender: 'HDFCBK',
        template: 'Spent Rs {amount} at {merchant} on {timestamp}',
        extractionMap: inboxIdentityMap,
        sampleMessage: 'Spent Rs 500 at Grocery Mart on 01/10/2026',
        hiddenForFamily: true,
        createdAt: DateTime.utc(2026, 1, 1),
      );
      final r = reader(
        granted: true,
        cache: cacheWith([hidden]),
        inbox: [
          sms(1, 'HDFCBK', 'Spent Rs 500 at Grocery Mart on 01/10/2026', now),
        ],
      );

      final messages = await r.readInbox(userId: 'u1');

      // Hidden means the sender is no longer known locally; the financial
      // heuristic still queues the message for server analysis.
      expect(messages, hasLength(1));
      expect(messages.single.parseSource, isNull);
      expect(messages.single.matchedPatternId, isNull);
    });
  });

  group('SmsInboxReader known-sender strategy', () {
    test('known sender + matching template -> regexLocal with extracted data',
        () async {
      final r = reader(
        granted: true,
        cache: cacheWith([hdfcPattern()]),
        inbox: [
          sms(1, 'HDFCBK', 'Spent Rs 500 at Grocery Mart on 01/10/2026', now),
        ],
      );

      final messages = await r.readInbox(userId: 'u1');
      expect(messages, hasLength(1));
      final m = messages.single;
      expect(m.parseSource, ParseSource.regexLocal);
      expect(m.extractedData, {
        'amount': '500',
        'merchant': 'Grocery Mart',
        'timestamp': '01/10/2026',
      });
      expect(m.matchedPatternId, 'p-hdfc');
    });

    test('known sender + no template match -> queued for LLM (parseSource null)',
        () async {
      final r = reader(
        granted: true,
        cache: cacheWith([hdfcPattern()]),
        inbox: [
          sms(1, 'HDFCBK', 'Your OTP for login is 482913. Do not share.', now),
        ],
      );

      final messages = await r.readInbox(userId: 'u1');
      expect(messages, hasLength(1));
      expect(messages.single.parseSource, isNull);
      expect(messages.single.status, MessageStatus.pending);
    });

    test('sender matching is case-insensitive', () async {
      final r = reader(
        granted: true,
        cache: cacheWith([hdfcPattern()]),
        inbox: [
          sms(1, 'hdfcbk', 'Spent Rs 200 at Grocery Mart on 01/10/2026', now),
        ],
      );
      final messages = await r.readInbox(userId: 'u1');
      expect(messages, hasLength(1));
      expect(messages.single.parseSource, ParseSource.regexLocal);
    });
  });

  group('SmsInboxReader unknown-sender strategy', () {
    test('unknown sender with financial keywords -> queued for LLM', () async {
      final r = reader(
        granted: true,
        cache: cacheWith([]),
        inbox: [
          sms(1, 'SBIUPI', 'Rs.750 debited from your SBI account for Swiggy.',
              now),
        ],
      );

      final messages = await r.readInbox(userId: 'u1');
      expect(messages, hasLength(1));
      expect(messages.single.parseSource, isNull);
      expect(messages.single.status, MessageStatus.pending);
    });

    test('unknown sender with non-financial body -> skipped', () async {
      final r = reader(
        granted: true,
        cache: cacheWith([]),
        inbox: [
          sms(1, 'ADVRT', 'Happy Diwali from BigMart! Flat 20% off everything.',
              now),
        ],
      );

      expect(await r.readInbox(userId: 'u1'), isEmpty);
    });

    test(
        'OTP SMS mentioning "transaction"/"upi" are queued for LLM classification',
        () async {
      final r = reader(
        granted: true,
        cache: cacheWith([]),
        inbox: [
          sms(1, 'OTHERS', 'OTP 123456 for your transaction on Paytm.', now),
          sms(2, 'OTHERS', 'Your UPI PIN is sent via OTP.', now),
        ],
      );
      // The keyword heuristic is intentionally lenient; the LLM decides later.
      final messages = await r.readInbox(userId: 'u1');
      expect(messages, hasLength(2));
      expect(messages.every((m) => m.parseSource == null), isTrue);
    });
  });

  group('SmsInboxReader cutoffs and skips', () {
    test('messages older than `since` are not read (newest first, breaks)',
        () async {
      final r = reader(
        granted: true,
        cache: cacheWith([hdfcPattern()]),
        inbox: [
          sms(1, 'HDFCBK', 'Spent Rs 100 at Store A on 01/10/2026', now),
          sms(2, 'HDFCBK', 'Spent Rs 200 at Store B on 01/10/2026',
              now.subtract(const Duration(days: 40))),
        ],
      );

      final messages = await r.readInbox(
        userId: 'u1',
        since: now.subtract(const Duration(days: 30)),
      );
      expect(messages, hasLength(1));
      expect(messages.single.rawText, contains('Store A'));
    });

    test('skips SMS with empty sender or body', () async {
      final r = reader(
        granted: true,
        cache: cacheWith([]),
        inbox: [
          sms(1, '', 'Rs.100 debited', now),
          sms(2, 'SBIUPI', '', now),
        ],
      );
      expect(await r.readInbox(userId: 'u1'), isEmpty);
    });
  });
}