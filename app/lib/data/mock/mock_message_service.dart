import '../../models/message.dart';
import '../message_service.dart';
import 'sample_data.dart';

/// Mock message service for Phase 2 / offline development.
class MockMessageService implements MessageService {
  @override
  Future<List<Message>> getPendingMessages() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return SampleData.messages
        .where((m) => m.status == MessageStatus.pending)
        .toList();
  }

  @override
  Future<List<Message>> getIgnoredMessages() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return SampleData.messages
        .where((m) =>
            m.status == MessageStatus.ignored ||
            m.status == MessageStatus.rejected)
        .toList();
  }

  @override
  Future<Map<String, dynamic>> processMessage(
      Map<String, dynamic> data) async {
    // Simulate LLM processing time
    await Future.delayed(const Duration(seconds: 2));
    return {
      'isFinancial': true,
      'transactionId': 'txn_mock_auto',
      'message': {
        'id': 'msg_mock',
        'status': 'CONFIRMED',
        'sender': data['sender'],
        'rawText': data['rawText'],
      },
      'parsedData': {
        'amount': 1850.0,
        'merchant': 'Swiggy',
        'type': 'EXPENSE',
      },
    };
  }

  @override
  Future<Message> confirmMessage(String messageId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final msg = SampleData.messages.firstWhere((m) => m.id == messageId);
    return Message(
      id: msg.id,
      userId: msg.userId,
      familyGroupId: msg.familyGroupId,
      sender: msg.sender,
      rawText: msg.rawText,
      status: MessageStatus.confirmed,
      parseSource: msg.parseSource,
      receivedAt: msg.receivedAt,
    );
  }

  @override
  Future<Message> rejectMessage(String messageId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final msg = SampleData.messages.firstWhere((m) => m.id == messageId);
    return Message(
      id: msg.id,
      userId: msg.userId,
      familyGroupId: msg.familyGroupId,
      sender: msg.sender,
      rawText: msg.rawText,
      status: MessageStatus.rejected,
      parseSource: msg.parseSource,
      receivedAt: msg.receivedAt,
    );
  }

  @override
  Future<Message> restoreMessage(String messageId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final msg = SampleData.messages.firstWhere((m) => m.id == messageId);
    return Message(
      id: msg.id,
      userId: msg.userId,
      familyGroupId: msg.familyGroupId,
      sender: msg.sender,
      rawText: msg.rawText,
      status: MessageStatus.pending,
      parseSource: msg.parseSource,
      receivedAt: msg.receivedAt,
    );
  }
}
