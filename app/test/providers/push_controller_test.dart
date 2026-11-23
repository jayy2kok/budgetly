import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:budgetly/data/device_service.dart';
import 'package:budgetly/providers/push_providers.dart';
import 'package:budgetly/services/push/push_messaging_service.dart';

class _FakePushMessaging implements PushMessagingService {
  _FakePushMessaging({this.token});

  String? token;
  final StreamController<String> refresh = StreamController.broadcast();
  final StreamController<PushNotificationPayload> opened =
      StreamController.broadcast();
  final StreamController<PushNotificationPayload> foreground =
      StreamController.broadcast();

  @override
  Future<String?> getToken() async => token;

  @override
  Stream<String> get onTokenRefresh => refresh.stream;

  @override
  Stream<PushNotificationPayload> get onMessageOpened => opened.stream;

  @override
  Stream<PushNotificationPayload> get onForegroundMessage => foreground.stream;
}

class _FakeDeviceService implements DeviceService {
  final List<({String token, String platform})> registrations = [];
  final List<String> unregistered = [];
  bool failRegistration = false;

  @override
  Future<void> registerDevice({
    required String token,
    required String platform,
    String? deviceId,
  }) async {
    if (failRegistration) {
      throw StateError('registration failed');
    }
    registrations.add((token: token, platform: platform));
  }

  @override
  Future<void> unregisterDevice(String token) async {
    unregistered.add(token);
  }
}

void main() {
  late _FakePushMessaging messaging;
  late _FakeDeviceService devices;
  late ProviderContainer container;

  PushController controller() =>
      container.read(pushControllerProvider.notifier);

  setUp(() {
    messaging = _FakePushMessaging(token: 'fcm-token-1');
    devices = _FakeDeviceService();
    container = ProviderContainer(
      overrides: [
        pushMessagingServiceProvider.overrideWithValue(messaging),
        deviceServiceProvider.overrideWithValue(devices),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(messaging.refresh.close);
    addTearDown(messaging.opened.close);
    addTearDown(messaging.foreground.close);
  });

  test('registers the token for the signed-in user', () async {
    await controller().registerForUser('user-1');

    expect(devices.registrations, hasLength(1));
    expect(devices.registrations.single.token, 'fcm-token-1');
    expect(devices.registrations.single.platform, isNotEmpty);
    expect(container.read(pushControllerProvider).registeredUserId, 'user-1');
  });

  test('does not register twice for the same user and token', () async {
    await controller().registerForUser('user-1');
    await controller().registerForUser('user-1');

    expect(devices.registrations, hasLength(1));
  });

  test('skips registration when no token is available', () async {
    messaging.token = null;

    await controller().registerForUser('user-1');

    expect(devices.registrations, isEmpty);
    expect(container.read(pushControllerProvider).isRegistered, isFalse);
  });

  test('unregisters the token on sign-out', () async {
    await controller().registerForUser('user-1');

    await controller().unregisterCurrentToken();

    expect(devices.unregistered, ['fcm-token-1']);
    expect(container.read(pushControllerProvider).isRegistered, isFalse);
  });

  test('sign-out without a registration is a no-op', () async {
    await controller().unregisterCurrentToken();

    expect(devices.unregistered, isEmpty);
  });

  test('re-registers when the provider rotates the token', () async {
    await controller().registerForUser('user-1');

    messaging.refresh.add('fcm-token-2');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(devices.registrations.map((r) => r.token),
        ['fcm-token-1', 'fcm-token-2']);
    expect(container.read(pushControllerProvider).token, 'fcm-token-2');
  });

  test('ignores token rotation before sign-in', () async {
    messaging.refresh.add('fcm-token-early');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(devices.registrations, isEmpty);
  });

  test('moves the token when another account signs in on the same device',
      () async {
    await controller().registerForUser('user-1');

    await controller().registerForUser('user-2');

    expect(devices.unregistered, ['fcm-token-1']);
    expect(devices.registrations, hasLength(2));
    expect(container.read(pushControllerProvider).registeredUserId, 'user-2');
  });

  test('a provider failure never escapes or claims registration', () async {
    devices.failRegistration = true;

    await controller().registerForUser('user-1');

    expect(container.read(pushControllerProvider).isRegistered, isFalse);
  });
}
