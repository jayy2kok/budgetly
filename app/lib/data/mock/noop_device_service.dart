import '../device_service.dart';

/// Device service used when the app runs against mock data: there is no
/// backend to register against, so every call is a no-op.
class NoopDeviceService implements DeviceService {
  const NoopDeviceService();

  @override
  Future<void> registerDevice({
    required String token,
    required String platform,
    String? deviceId,
  }) async {}

  @override
  Future<void> unregisterDevice(String token) async {}
}
