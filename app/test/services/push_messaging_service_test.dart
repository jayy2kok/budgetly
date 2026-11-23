import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:budgetly/services/push/push_messaging_service.dart';

void main() {
  group('pushTapLocation', () {
    test('routes an expense alert to the transaction detail screen', () {
      final payload = PushNotificationPayload(
        data: const {
          'type': 'EXPENSE_ALERT',
          'transactionId': 'tx-42',
          'familyGroupId': 'fam-1',
        },
      );

      expect(pushTapLocation(payload), '/transaction/tx-42');
    });

    test('ignores alerts without a transaction id', () {
      final payload = PushNotificationPayload(
        data: const {'type': 'EXPENSE_ALERT'},
      );

      expect(pushTapLocation(payload), isNull);
    });

    test('ignores unrelated payloads', () {
      final payload = PushNotificationPayload(
        data: const {'type': 'SOMETHING_ELSE', 'transactionId': 'tx-42'},
      );

      expect(pushTapLocation(payload), isNull);
    });
  });

  group('PushTapHandler', () {
    test('navigates for routable taps and ignores the rest', () async {
      final controller = StreamController<PushNotificationPayload>.broadcast();
      addTearDown(controller.close);
      final navigated = <String>[];

      final handler = PushTapHandler(
        taps: controller.stream,
        onNavigate: navigated.add,
      );
      addTearDown(handler.dispose);

      controller
        ..add(PushNotificationPayload(
          data: const {'type': 'EXPENSE_ALERT', 'transactionId': 'tx-1'},
        ))
        ..add(PushNotificationPayload(
          data: const {'type': 'EXPENSE_ALERT'},
        ))
        ..add(PushNotificationPayload(data: const {'type': 'OTHER'}));
      await pumpEventQueue();

      expect(navigated, ['/transaction/tx-1']);
    });
  });
}
