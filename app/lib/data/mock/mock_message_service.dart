import '../message_service.dart';

/// Mock message service for offline development.
class MockMessageService implements MessageService {
  @override
  Future<int> bulkInsertMessages({
    required String familyGroupId,
    required List<Map<String, String>> messages,
  }) async {
    // Mock: acknowledge everything after a simulated server round-trip.
    await Future.delayed(const Duration(milliseconds: 100));
    return messages.length;
  }
}