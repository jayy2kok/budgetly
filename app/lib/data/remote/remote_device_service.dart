import 'package:dio/dio.dart';

import '../device_service.dart';
import 'api_client.dart';

/// Real API implementation of [DeviceService].
class RemoteDeviceService implements DeviceService {
  final Dio _dio = ApiClient.instance.dio;

  @override
  Future<void> registerDevice({
    required String token,
    required String platform,
    String? deviceId,
  }) async {
    await _dio.post('/devices', data: {
      'token': token,
      'platform': platform,
      'deviceId': ?deviceId,
    });
  }

  @override
  Future<void> unregisterDevice(String token) async {
    await _dio.delete('/devices/${Uri.encodeComponent(token)}');
  }
}
