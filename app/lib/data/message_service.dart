/// Contract for message ingestion.
abstract class MessageService {
  /// Bulk-ingest raw SMS for the async change-stream pipeline
  /// (POST /messages/bulk, 202 ACCEPTED). Returns the accepted count.
  Future<int> bulkInsertMessages({
    required String familyGroupId,
    required List<Map<String, String>> messages,
  });
}