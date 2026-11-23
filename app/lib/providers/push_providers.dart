import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/device_service.dart';
import '../data/mock/noop_device_service.dart';
import '../data/remote/remote_device_service.dart';
import '../services/push/push_messaging_service.dart';
import 'service_providers.dart';

/// Push transport. Swap the no-op for a real adapter (e.g. Firebase
/// Messaging) once a project configuration exists — the controller and UI
/// below stay untouched.
final pushMessagingServiceProvider = Provider<PushMessagingService>((ref) {
  return const NoopPushMessagingService();
});

/// Device-token registration API.
final deviceServiceProvider = Provider<DeviceService>((ref) {
  return useRealApi ? RemoteDeviceService() : const NoopDeviceService();
});

/// What the app currently has registered with the backend.
class PushState {
  const PushState({this.token, this.registeredUserId});

  /// Provider registration token, or null before registration.
  final String? token;

  /// User the token is registered against, or null when not registered.
  final String? registeredUserId;

  bool get isRegistered => token != null && registeredUserId != null;
}

/// Keeps the signed-in user's device token in sync with auth lifecycle.
///
/// Registration and removal are best-effort: a provider or network failure is
/// logged and never blocks sign-in or sign-out.
class PushController extends Notifier<PushState> {
  StreamSubscription<String>? _refreshSub;
  String? _token;
  String? _userId;

  PushMessagingService get _messaging => ref.read(pushMessagingServiceProvider);
  DeviceService get _devices => ref.read(deviceServiceProvider);

  @override
  PushState build() {
    _refreshSub = _messaging.onTokenRefresh.listen(_onTokenRefresh);
    ref.onDispose(() {
      _refreshSub?.cancel();
      _refreshSub = null;
    });
    return const PushState();
  }

  /// Obtains the token and registers it for [userId].
  ///
  /// Safe to call after every sign-in: a repeat call for the same user and
  /// token is a no-op.
  Future<void> registerForUser(String userId) async {
    if (_userId == userId && _token != null) return;

    String? token;
    try {
      token = await _messaging.getToken();
    } catch (e) {
      debugPrint('Push token unavailable: $e');
      return;
    }
    if (token == null || token.isEmpty) return;

    // Same device handed to another account: drop the previous owner first.
    if (_userId != null && _userId != userId && _token != null) {
      await _safeUnregister(_token!);
    }

    _token = token;
    _userId = userId;
    await _register(token, userId);
  }

  /// Removes this device's token on sign-out, while the session is still
  /// valid. Idempotent: calling it again with no token does nothing.
  Future<void> unregisterCurrentToken() async {
    final token = _token;
    _token = null;
    _userId = null;
    state = const PushState();
    if (token != null) {
      await _safeUnregister(token);
    }
  }

  Future<void> _onTokenRefresh(String token) async {
    if (token.isEmpty) return;
    _token = token;
    final userId = _userId;
    if (userId == null) return; // No signed-in user yet — register on sign-in.
    await _register(token, userId);
  }

  Future<void> _register(String token, String userId) async {
    try {
      await _devices.registerDevice(
        token: token,
        platform: devicePlatformValue(),
      );
      state = PushState(token: token, registeredUserId: userId);
    } catch (e) {
      debugPrint('Push token registration failed: $e');
      state = PushState(token: token);
    }
  }

  Future<void> _safeUnregister(String token) async {
    try {
      await _devices.unregisterDevice(token);
    } catch (e) {
      debugPrint('Push token removal failed: $e');
    }
  }
}

final pushControllerProvider = NotifierProvider<PushController, PushState>(
  PushController.new,
);

/// Wire value for the backend's `DevicePlatform` enum.
String devicePlatformValue() {
  if (kIsWeb) return 'WEB';
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return 'ANDROID';
    case TargetPlatform.iOS:
      return 'IOS';
    default:
      // Desktop dev builds; mobile is the supported target.
      return 'ANDROID';
  }
}
