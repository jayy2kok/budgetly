import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:budgetly/models/sms_pattern.dart';
import 'package:budgetly/services/pattern_cache_service.dart';
import 'package:budgetly/services/sms_inbox_reader.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';

/// Method channel used by the flutter_sms_inbox plugin (JSON codec — the
/// registered mock must use the same codec the plugin decodes replies with).
const kSmsQueryChannel = MethodChannel(
  'plugins.juliusgithaiga.com/querySMS',
  JSONMethodCodec(),
);

/// Creates an [SmsMessage] (the flutter_sms_inbox model).
SmsMessage sms(int id, String sender, String body, DateTime sent) =>
    SmsMessage.fromJson({
      '_id': id,
      'address': sender,
      'body': body,
      'date_sent': sent.millisecondsSinceEpoch,
    });

/// Stubs the flutter_sms_inbox plugin so `SmsQuery().querySms(...)` returns
/// [messages] (assumed newest-first by the caller).
void stubSmsInbox(List<SmsMessage> messages) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(kSmsQueryChannel, (MethodCall call) async {
    // Build the plugin's raw JSON map directly: SmsMessage.toMap writes a
    // 'dateSent' key that SmsMessage.fromJson does not read back, which would
    // drop the timestamp on round-trip.
    return messages
        .map((m) => {
              '_id': m.id,
              'address': m.address,
              'body': m.body,
              'date_sent': m.dateSent?.millisecondsSinceEpoch,
            })
        .toList();
  });
}

void resetSmsInbox() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(kSmsQueryChannel, null);
}

/// A [PatternCacheService] that never touches the network but can be seeded.
class FakePatternCache extends PatternCacheService {
  FakePatternCache() : super(dio: Dio());

  @override
  Future<void> loadPatterns() async {}

  @override
  Future<void> refreshPatterns() async {}
}

/// A [SmsInboxReader] whose permission check is stubbed.
class TestSmsInboxReader extends SmsInboxReader {
  final bool granted;
  TestSmsInboxReader({required this.granted, required PatternCacheService cache})
      : super(cache: cache);

  @override
  Future<bool> hasPermission() async => granted;
}

/// Identity extraction map used by inbox tests.
const inboxIdentityMap = ExtractionMap(
  amount: 'amount',
  merchant: 'merchant',
  timestamp: 'timestamp',
  accountLast4: 'accountLast4',
);

/// A sample anchored pattern for a known sender.
SmsPattern hdfcPattern() => SmsPattern(
      id: 'p-hdfc',
      sender: 'HDFCBK',
      template: 'Spent Rs {amount} at {merchant} on {timestamp}',
      extractionMap: inboxIdentityMap,
      sampleMessage: 'Spent Rs 500 at Grocery Mart on 01/10/2026',
      createdAt: DateTime.utc(2026, 1, 1),
    );