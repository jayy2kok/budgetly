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
  Future<void> updatePatternCategory(
    String patternId,
    String? categoryName,
  ) async {
    try {
      final response = await _dio.patch(
        '/patterns/$patternId/category',
        data: {'categoryName': categoryName},
      );
      final updated = SmsPattern.fromJson(
        response.data as Map<String, dynamic>,
      );
      _patterns = _patterns
          .map((p) => p.id == patternId ? updated : p)
          .toList();
    } catch (e) {
      // Keep existing cache if the update fails.
    }
  }

  /// Creates a family-scoped pattern authored from a highlighted SMS.
  /// Returns the created pattern (also added to the local cache).
  Future<SmsPattern> createPattern({
    required String sender,
    required String template,
    required ExtractionMap extractionMap,
    Map<String, String> fixedValues = const {},
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
        'categoryName': ?categoryName,
      },
    );
    final created = SmsPattern.fromJson(response.data as Map<String, dynamic>);
    _patterns = [created, ..._patterns];
    return created;
  }

  /// Updates an authored family pattern (template / sample / extractionMap).
  Future<SmsPattern> updatePattern(
    String patternId, {
    String? template,
    ExtractionMap? extractionMap,
    Map<String, String>? fixedValues,
    String? sampleMessage,
    String? categoryName,
  }) async {
    final response = await _dio.put(
      '/patterns/$patternId',
      data: {
        'template': ?template,
        'extractionMap': ?extractionMap?.toJson(),
        'fixedValues': ?fixedValues,
        'sampleMessage': ?sampleMessage,
        'categoryName': ?categoryName,
      },
    );
    final updated = SmsPattern.fromJson(response.data as Map<String, dynamic>);
    _patterns = _patterns.map((p) => p.id == patternId ? updated : p).toList();
    return updated;
  }

  /// Deletes an authored family pattern (author or family admin only).
  Future<void> deletePattern(String patternId) async {
    await _dio.delete('/patterns/$patternId');
    _patterns = _patterns.where((p) => p.id != patternId).toList();
  }

  /// Promotes a family pattern to the global registry (family admin only).
  Future<SmsPattern> promotePattern(String patternId) async {
    final response = await _dio.post('/patterns/$patternId/promote');
    final promoted = SmsPattern.fromJson(response.data as Map<String, dynamic>);
    _patterns = _patterns.map((p) => p.id == patternId ? promoted : p).toList();
    return promoted;
  }
}
