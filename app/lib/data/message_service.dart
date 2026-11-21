import '../models/message.dart';

/// Contract for message (SMS triage) operations.
abstract class MessageService {
  Future<List<Message>> getPendingMessages();
  Future<List<Message>> getIgnoredMessages();

  /// Server-persisted FAILED messages (LLM outage / template mismatch),
  /// paginated. The builder's main source surface.
  Future<List<Message>> getFailedMessages({int page, int size});

  /// Submit an unprocessed SMS for LLM analysis. Returns parsed result.
  Future<Map<String, dynamic>> processMessage(Map<String, dynamic> data);

  /// Bulk-ingest raw SMS for the async change-stream pipeline
  /// (POST /messages/bulk, 202 ACCEPTED). Returns the accepted count.
  Future<int> bulkInsertMessages({
    required String familyGroupId,
    required List<Map<String, String>> messages,
  });

  Future<Message> confirmMessage(String messageId);
  Future<Message> rejectMessage(String messageId);
  Future<Message> restoreMessage(String messageId);
}
