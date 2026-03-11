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

  /// Simulate sending an unprocessed message to the server for LLM analysis.
  Future<Message> submitToServer(Message message) async {
    // Simulate network + LLM processing time
    await Future.delayed(const Duration(seconds: 2));

    // Simulate LLM result: mark as a financial message with extracted data
    return Message(
      id: message.id,
      userId: message.userId,
      familyGroupId: message.familyGroupId,
      sender: message.sender,
      rawText: message.rawText,
      status: MessageStatus.confirmed,
      parseSource: ParseSource.llmServer,
      extractedData: {
        'amount': '1,850',
        'merchant': 'Swiggy',
        'timestamp': '02-Mar-26',
      },
      linkedTransactionId: 'txn_auto_${message.id}',
      receivedAt: message.receivedAt,
    );
  }
}
