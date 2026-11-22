import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:budgetly/config/api_config.dart';
import 'package:budgetly/models/message.dart';

import '../fixtures/sample_inbox.dart';
import '../helpers/inbox_fakes.dart';

/// Mirror of the keyword heuristic in `SmsInboxReader._looksFinancial`.
///
/// Kept here intentionally so the suite verifies that the *real* fixture flows
/// through the same rule the app applies to unknown senders. Update both
/// together if the heuristic changes.
const List<String> _financialKeywords = [
  'debited', 'credited', 'spent', 'txn', 'transaction',
  'upi', 'imps', 'neft', 'rtgs', 'payment', 'transfer',
  'withdrawn', 'balance', 'a/c', 'acct', 'account',
  'rs.', 'inr', '₹',
];

bool _looksFinancial(String body) {
  final lower = body.toLowerCase();
  return _financialKeywords.any(lower.contains);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('real sample inbox fixture', () {
    test('is a well-formed snapshot of 100 newest-first messages', () {
      final inbox = loadSampleInbox();

      expect(inbox.messages, hasLength(100));
      expect(inbox.device.trim(), isNotEmpty);
      expect(inbox.capturedAt.trim(), isNotEmpty);
      expect(inbox.source, contains('content://sms'));
      expect(
        inbox.messages
            .every((m) => m.sender.trim().isNotEmpty && m.body.trim().isNotEmpty),
        isTrue,
      );
      expect(
        inbox.messages.map((m) => m.id).toSet(),
        hasLength(inbox.messages.length),
        reason: 'fixture ids must be unique',
      );
      for (var i = 0; i < inbox.messages.length - 1; i++) {
        expect(
          inbox.messages[i].dateSent.isBefore(inbox.messages[i + 1].dateSent),
          isFalse,
          reason: 'fixture must be newest-first '
              '(ids ${inbox.messages[i].id}/${inbox.messages[i + 1].id})',
        );
      }
    });
  });

  group('SmsInboxReader over the real sample inbox', () {
    late SampleInbox inbox;
    late List<SampleInboxMessage> financial;
    late Map<String, SampleInboxMessage> byMessageId;

    setUp(() {
      inbox = loadSampleInbox();
      financial = inbox.messages.where((m) => _looksFinancial(m.body)).toList();
      byMessageId = {
        for (final message in inbox.messages) 'sms_${message.id}': message,
      };
    });

    Future<List<Message>> readInbox() async {
      stubSmsInbox(inbox.toSmsMessages());
      addTearDown(resetSmsInbox);
      final reader = TestSmsInboxReader(
        granted: true,
        cache: FakePatternCache(),
      );
      return reader.readInbox(
        userId: 'sample-user',
        limit: inbox.messages.length,
      );
    }

    test('queues only financial-looking messages, up to the sync budget',
        () async {
      expect(financial, isNotEmpty);

      final messages = await readInbox();
      final expectedCount =
          math.min(financial.length, ApiConfig.smsSyncMaxMessages);

      expect(messages, hasLength(expectedCount));
      expect(
        messages.map((m) => m.id).toList(),
        financial.take(expectedCount).map((m) => 'sms_${m.id}').toList(),
        reason: 'reader should walk the inbox newest-first and stop at the cap',
      );
    });

    test('maps sender, raw text and received time back to the fixture',
        () async {
      final messages = await readInbox();
      expect(messages, isNotEmpty);

      for (final message in messages) {
        final sample = byMessageId[message.id];
        expect(sample, isNotNull, reason: 'unknown message id ${message.id}');
        expect(message.sender, sample!.sender);
        expect(message.rawText, sample.body);
        expect(
          message.receivedAt.millisecondsSinceEpoch,
          sample.dateSent.millisecondsSinceEpoch,
        );
      }
    });

    test('never queues messages that fail the financial heuristic', () async {
      final messages = await readInbox();
      final queuedIds = messages.map((m) => m.id).toSet();

      for (final entry in byMessageId.entries) {
        if (!_looksFinancial(entry.value.body)) {
          expect(queuedIds, isNot(contains(entry.key)),
              reason: 'non-financial message ${entry.key} was queued');
        }
      }
    });

    test('leaves queued messages pending for server-side analysis', () async {
      final messages = await readInbox();
      expect(messages, isNotEmpty);

      for (final message in messages) {
        expect(message.status, MessageStatus.pending);
        expect(message.parseSource, isNull);
        expect(message.extractedData, isNull);
        expect(message.isIncomplete, isFalse);
      }
    });

    test('readAllInbox returns the whole device inbox, newest first',
        () async {
      stubSmsInbox(inbox.toSmsMessages());
      addTearDown(resetSmsInbox);
      final reader = TestSmsInboxReader(
        granted: true,
        cache: FakePatternCache(),
      );

      final messages = await reader.readAllInbox(
        userId: 'sample-user',
        limit: inbox.messages.length,
      );

      expect(messages, hasLength(inbox.messages.length));
      expect(
        messages.map((m) => m.id).toList(),
        inbox.messages.map((m) => 'sms_${m.id}').toList(),
        reason: 'every SMS on the device belongs to the inbox view',
      );
      expect(
        messages.map((m) => m.rawText).toList(),
        inbox.messages.map((m) => m.body).toList(),
      );
      // Non-financial messages (OTP, promo, personal) are included too.
      expect(
        messages.any((m) => !_looksFinancial(m.rawText)),
        isTrue,
        reason: 'fixture should contain non-financial SMS',
      );
    });
  });
}
