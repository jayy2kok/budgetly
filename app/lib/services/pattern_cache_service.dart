import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/sms_pattern.dart';
import '../data/remote/api_client.dart';

/// Real pattern cache service that syncs SMS regex patterns with the server.
class PatternCacheService {
  final Dio _dio;

  PatternCacheService({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  List<SmsPattern> _patterns = [];
  DateTime? _lastSyncTime;

  /// Number of cached patterns.
  int get patternCount => _patterns.length;

  /// When the cache was last synced.
  DateTime? get lastSyncTime => _lastSyncTime;

  /// All cached patterns.
  List<SmsPattern> get patterns => List.unmodifiable(_patterns);

  /// Patterns that may match messages for the caller's family: active and not
  /// hidden. The full [patterns] list stays for the registry UI, which also
  /// shows disabled and hidden-for-family entries.
  List<SmsPattern> get matchablePatterns =>
      _patterns.where((p) => p.isEnabledForFamily).toList();

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

  /// Seeds the cache with a fixed pattern list (tests only).
  @visibleForTesting
  void debugSetPatterns(List<SmsPattern> patterns) {
    _patterns = List.of(patterns);
  }

  /// Get patterns for a specific sender (case-insensitive).
  List<SmsPattern> getPatternsBySender(String sender) {
    return _patterns
        .where((p) => p.sender.toUpperCase() == sender.toUpperCase())
        .toList();
  }

  /// Finds a cached pattern by id, or null if not present.
  SmsPattern? patternById(String? id) {
    if (id == null) return null;
    for (final p in _patterns) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Updates the category override for a template on the server and in cache.
  /// Errors propagate so the caller can surface them; the cache is refreshed so
  /// a GLOBAL override's family copy and hide marker arrive too.
  Future<void> updatePatternCategory(
    String patternId,
    String? categoryName,
  ) async {
    await _dio.patch(
      '/patterns/$patternId/category',
      data: {'categoryName': categoryName},
    );
    await refreshPatterns();
  }

  /// Creates a family-scoped pattern authored from a highlighted SMS.
  /// Returns the created pattern (also added to the local cache).
  Future<SmsPattern> createPattern({
    required String sender,
    required String template,
    required ExtractionMap extractionMap,
    Map<String, String>? fixedValues,
    required String sampleMessage,
    String? categoryName,
  }) async {
    final response = await _dio.post(
      '/patterns',
      data: {
        'sender': sender,
        'template': template,
        'extractionMap': extractionMap.toJson(),
        'fixedValues': fixedValues,
        'sampleMessage': sampleMessage,
        'categoryName': categoryName,
      },
    );
    final created = SmsPattern.fromJson(response.data as Map<String, dynamic>);
    await refreshPatterns();
    return created;
  }

  /// Updates a family pattern in place, or — for a GLOBAL pattern — creates
  /// or updates this family's copy and hides the global for the family only.
  /// The server returns the resulting FAMILY pattern; the cache is then
  /// refreshed so the hide marker is reflected too.
  ///
  /// The keys are sent even when null: JSON `null` fixedValues clears the
  /// stored literals and JSON `null` categoryName leaves it unchanged, while an
  /// empty string clears the category override (see the OpenAPI contract).
  Future<SmsPattern> updatePattern(
    String patternId, {
    String? sender,
    String? template,
    ExtractionMap? extractionMap,
    Map<String, String>? fixedValues,
    String? sampleMessage,
    String? categoryName,
  }) async {
    final response = await _dio.put(
      '/patterns/$patternId',
      data: {
        'sender': sender,
        'template': template,
        'extractionMap': extractionMap?.toJson(),
        'fixedValues': fixedValues,
        'sampleMessage': sampleMessage,
        'categoryName': categoryName,
      },
    );
    final updated = SmsPattern.fromJson(response.data as Map<String, dynamic>);
    await refreshPatterns();
    return updated;
  }

  /// Hides a GLOBAL pattern for this family, or deactivates a FAMILY pattern.
  Future<SmsPattern> disablePattern(String patternId) async {
    final response = await _dio.post('/patterns/$patternId/disable');
    final updated = SmsPattern.fromJson(response.data as Map<String, dynamic>);
    await refreshPatterns();
    return updated;
  }

  /// Un-hides a GLOBAL pattern for this family, or reactivates a FAMILY
  /// pattern (409 when another active template would collide).
  Future<SmsPattern> enablePattern(String patternId) async {
    final response = await _dio.post('/patterns/$patternId/enable');
    final updated = SmsPattern.fromJson(response.data as Map<String, dynamic>);
    await refreshPatterns();
    return updated;
  }

  /// Promotes a family pattern to the global registry (family admin only).
  Future<SmsPattern> promotePattern(String patternId) async {
    final response = await _dio.post('/patterns/$patternId/promote');
    final promoted = SmsPattern.fromJson(response.data as Map<String, dynamic>);
    await refreshPatterns();
    return promoted;
  }
}
