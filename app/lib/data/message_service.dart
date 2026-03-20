import '../models/message.dart';

/// Contract for message (SMS triage) operations.
abstract class MessageService {
  Future<List<Message>> getPendingMessages();
  Future<List<Message>> getIgnoredMessages();

  /// Submit an unprocessed SMS for LLM analysis. Returns parsed result.
  Future<Map<String, dynamic>> processMessage(Map<String, dynamic> data);

  Future<Message> confirmMessage(String messageId);
  Future<Message> rejectMessage(String messageId);
  Future<Message> restoreMessage(String messageId);
}
