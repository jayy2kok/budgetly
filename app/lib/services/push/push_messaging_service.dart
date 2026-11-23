import 'dart:async';

import '../../config/routes.dart';

/// One push notification as the app receives it.
///
/// [title]/[body] are the visible fields from the provider's notification
/// payload; [data] carries the routing hints the backend attached
/// (`type`, `transactionId`, `familyGroupId`).
class PushNotificationPayload {
  const PushNotificationPayload({
    this.title,
    this.body,
    Map<String, String>? data,
  }) : data = data ?? const {};

  final String? title;
  final String? body;
  final Map<String, String> data;

  String? get type => data['type'];
  String? get transactionId => data['transactionId'];
  String? get familyGroupId => data['familyGroupId'];

  bool get isExpenseAlert => type == 'EXPENSE_ALERT';
}

/// Provider-agnostic push transport.
///
/// The app ships with [NoopPushMessagingService] because no Firebase project
/// (google-services.json) is configured for local builds. A real adapter
/// (e.g. a `firebase_messaging` implementation) only has to emit tokens and
/// payloads through this interface — nothing else in the app changes.
abstract class PushMessagingService {
  /// Current provider registration token, or null when push is unavailable.
  Future<String?> getToken();

  /// Emits when the provider rotates the registration token.
  Stream<String> get onTokenRefresh;

  /// Messages the user tapped (background/terminated taps).
  Stream<PushNotificationPayload> get onMessageOpened;

  /// Messages delivered while the app is in the foreground.
  Stream<PushNotificationPayload> get onForegroundMessage;
}

/// Default implementation: push disabled, every stream empty.
class NoopPushMessagingService implements PushMessagingService {
  const NoopPushMessagingService();

  @override
  Future<String?> getToken() async => null;

  @override
  Stream<String> get onTokenRefresh => const Stream.empty();

  @override
  Stream<PushNotificationPayload> get onMessageOpened => const Stream.empty();

  @override
  Stream<PushNotificationPayload> get onForegroundMessage =>
      const Stream.empty();
}

/// GoRouter location for a tapped notification, or null when the tap has no
/// in-app destination.
String? pushTapLocation(PushNotificationPayload payload) {
  if (!payload.isExpenseAlert) return null;
  final transactionId = payload.transactionId;
  if (transactionId == null || transactionId.isEmpty) return null;
  return '${AppRoutes.transactionDetail}/$transactionId';
}

/// Subscribes to notification taps and forwards the resolved route location.
///
/// Kept as a small class (rather than inline in the widget) so the tap →
/// navigation contract can be tested with a fake stream.
class PushTapHandler {
  PushTapHandler({
    required Stream<PushNotificationPayload> taps,
    required void Function(String location) onNavigate,
  }) {
    _subscription = taps.listen((payload) {
      final location = pushTapLocation(payload);
      if (location != null) onNavigate(location);
    });
  }

  late final StreamSubscription<PushNotificationPayload> _subscription;

  Future<void> dispose() => _subscription.cancel();
}
