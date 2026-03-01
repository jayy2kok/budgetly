import '../../models/message.dart';
import 'sample_data.dart';

/// Mock message service for Phase 2.
class MockMessageService {
  Future<List<Message>> getMessages(String userId) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return SampleData.messages.where((m) => m.userId == userId).toList();
  }

  Future<List<Message>> getPendingMessages(String userId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return SampleData.messages
        .where((m) => m.status == MessageStatus.pending && m.userId == userId)
        .toList();
  }

  Future<List<Message>> getIgnoredMessages(String userId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return SampleData.messages
        .where((m) => m.status == MessageStatus.ignored && m.userId == userId)
        .toList();
  }
}
