/// Registers and removes push-notification tokens for the signed-in user.
///
/// The backend keys tokens by their provider value, so registering the same
/// token twice is an idempotent refresh rather than a duplicate.
abstract class DeviceService {
  Future<void> registerDevice({
    required String token,
    required String platform,
    String? deviceId,
  });

  Future<void> unregisterDevice(String token);
}
