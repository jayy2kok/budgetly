import '../models/sms_pattern.dart';

/// In-memory mock cache for SMS regex patterns.
///
/// In production this would persist to sqflite/SharedPreferences
/// and sync with the server via GET /patterns?since=...
class PatternCacheService {
  // ignore: prefer_final_fields
  List<SmsPattern> _patterns = [];
  DateTime? _lastSyncTime;

  /// Number of cached patterns.
  int get patternCount => _patterns.length;

  /// When the cache was last synced.
  DateTime? get lastSyncTime => _lastSyncTime;

  /// All cached patterns.
  List<SmsPattern> get patterns => List.unmodifiable(_patterns);

  /// Loads patterns from the local on-disk cache or returns empty if none.
  ///
  /// Real patterns are fetched from the server via [refreshPatterns].
  /// Calling [loadPatterns] without a prior sync will return an empty list,
  /// which causes all SMS to be treated as unknown senders and sent to the
  /// LLM backend for classification and pattern generation.
  Future<void> loadPatterns() async {
    await Future.delayed(const Duration(milliseconds: 50));
    // On first run _patterns is already [] — no hardcoded mocks.
    // After refreshPatterns() has run at least once, _patterns will be populated.
    _lastSyncTime = _patterns.isNotEmpty ? _lastSyncTime : null;
  }

  /// Refresh patterns from server (simulates delta sync).
  Future<void> refreshPatterns() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _lastSyncTime = DateTime.now();
    // In production: fetch from GET /patterns?since=_lastSyncTime
  }

  /// Get patterns for a specific sender.
  List<SmsPattern> getPatternsBySender(String sender) {
    return _patterns.where((p) => p.sender == sender).toList();
  }

}
