import 'package:dio/dio.dart';
import '../models/sms_pattern.dart';
import '../data/remote/api_client.dart';

/// Real pattern cache service that syncs SMS regex patterns with the server.
class PatternCacheService {
  final Dio _dio = ApiClient.instance.dio;
  List<SmsPattern> _patterns = [];
  DateTime? _lastSyncTime;

  /// Number of cached patterns.
  int get patternCount => _patterns.length;

  /// When the cache was last synced.
  DateTime? get lastSyncTime => _lastSyncTime;

  /// All cached patterns.
  List<SmsPattern> get patterns => List.unmodifiable(_patterns);

  /// Loads patterns from the server.
  Future<void> loadPatterns() async {
    try {
      await refreshPatterns();
    } catch (e) {
      // Fallback to empty if offline
      _patterns = [];
    }
  }

  /// Refresh patterns from server (fetches active patterns).
  Future<void> refreshPatterns() async {
    try {
      final response = await _dio.get('/patterns');
      final list = response.data as List<dynamic>;
      _patterns = list
          .map((json) => SmsPattern.fromJson(json as Map<String, dynamic>))
          .toList();
      _lastSyncTime = DateTime.now();
    } catch (e) {
      // Keep existing patterns if refresh fails
    }
  }

  /// Get patterns for a specific sender (case-insensitive).
  List<SmsPattern> getPatternsBySender(String sender) {
    return _patterns
        .where((p) => p.sender.toUpperCase() == sender.toUpperCase())
        .toList();
  }
}
