import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:integration_test/integration_test.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';

import 'package:budgetly/config/routes.dart';
import 'package:budgetly/models/sms_pattern.dart';

import 'helpers/integration_harness.dart';

/// SMS flow: the device inbox is read, a bank SMS is anchor-parsed locally and
/// auto-posted as a transaction, while a non-financial SMS stays unrecorded.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() {
    resetIntegrationPreferences(values: const {});
    installPermissionHandler(PermissionStatus.granted);
  });

  tearDown(resetDeviceInbox);

  testWidgets('sync auto-posts a parsed bank SMS and ignores an OTP', (
    tester,
  ) async {
    const body =
        'Spent Rs 250 at Integration Coffee on 01/10/2026';
    const otpBody = 'Your OTP is 4821. Do not share it.';

    final cache = OfflinePatternCache([_hdfcSpentPattern()]);
    final reader = FakeSmsInboxReader(granted: true, cache: cache);
    final now = DateTime.now();

    stubDeviceInbox([
      deviceSms(
        id: 1,
        sender: 'HDFCBK',
        body: body,
        sentAt: now.subtract(const Duration(minutes: 5)),
      ),
      deviceSms(
        id: 2,
        sender: 'VK-OTP',
        body: otpBody,
        sentAt: now.subtract(const Duration(minutes: 10)),
      ),
    ]);

    final harness = await pumpIntegrationApp(
      tester,
      initialLocation: AppRoutes.messageInbox,
      patternCache: cache,
      smsInboxReader: reader,
      seedSmsState: false,
      transactions: RecordingTransactionService(),
    );
    await settleFor(tester);

    // The bank SMS moved to Recorded; the OTP stayed a non-transaction.
    expect(find.text('Recorded (1)'), findsOneWidget);
    expect(find.text('Non-Transactions (1)'), findsOneWidget);
    expect(find.textContaining('Integration Coffee'), findsWidgets);

    // Exactly one transaction was auto-posted, from the local regex path.
    expect(harness.transactions.createCalls, hasLength(1));
    final posted = harness.transactions.createCalls.single;
    expect(posted['amount'], 250.0);
    expect(posted['merchant'], 'Integration Coffee');
    expect(posted['sourceType'], 'REGEX_LOCAL');
    expect(posted['sourceRawText'], body);
  });
}

SmsPattern _hdfcSpentPattern() => SmsPattern(
      id: 'p-hdfc-e2e',
      sender: 'HDFCBK',
      template: 'Spent Rs {amount} at {merchant} on {timestamp}',
      extractionMap: const ExtractionMap(
        amount: 'amount',
        merchant: 'merchant',
        timestamp: 'timestamp',
      ),
      sampleMessage: 'Spent Rs 250 at Integration Coffee on 01/10/2026',
      createdAt: DateTime.utc(2026, 1, 1),
    );
