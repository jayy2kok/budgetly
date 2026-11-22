import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/sms_pattern.dart';
import '../services/pattern_cache_service.dart';
import 'service_providers.dart';

/// State for the pattern registry viewer.
class PatternRegistryState {
  /// All patterns visible to the caller's family: global + family-authored.
  final List<SmsPattern> patterns;

  /// Patterns currently being mutated (create / update / disable / promote).
  final Set<String> busyPatternIds;

  final bool isLoading;
  final String? error;

  const PatternRegistryState({
    this.patterns = const [],
    this.busyPatternIds = const {},
    this.isLoading = false,
    this.error,
  });

  PatternRegistryState copyWith({
    List<SmsPattern>? patterns,
    Set<String>? busyPatternIds,
    bool? isLoading,
    String? error,
  }) {
    return PatternRegistryState(
      patterns: patterns ?? this.patterns,
      busyPatternIds: busyPatternIds ?? this.busyPatternIds,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class PatternRegistryNotifier extends Notifier<PatternRegistryState> {
  late final PatternCacheService _cache;

  @override
  PatternRegistryState build() {
    _cache = ref.watch(patternCacheServiceProvider);
    return const PatternRegistryState();
  }

  /// Loads patterns from the shared cache (server-synced).
  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _cache.refreshPatterns();
      state = state.copyWith(patterns: _cache.patterns, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Creates a family-scoped pattern authored from a highlighted SMS.
  Future<SmsPattern> createPattern({
    required String sender,
    required String template,
    required ExtractionMap extractionMap,
    Map<String, String> fixedValues = const {},
    required String sampleMessage,
    String? categoryName,
  }) async {
    final created = await _cache.createPattern(
      sender: sender,
      template: template,
      extractionMap: extractionMap,
      fixedValues: fixedValues,
      sampleMessage: sampleMessage,
      categoryName: categoryName,
    );
    state = state.copyWith(patterns: _cache.patterns);
    return created;
  }

  /// Updates a family pattern in place. Updating a GLOBAL pattern creates (or
  /// updates) this family's copy and hides the global for the family, so the
  /// server returns the family copy.
  Future<SmsPattern> updatePattern(
    String patternId, {
    String? sender,
    String? template,
    ExtractionMap? extractionMap,
    Map<String, String>? fixedValues,
    String? sampleMessage,
    String? categoryName,
  }) async {
    final updated = await _cache.updatePattern(
      patternId,
      sender: sender,
      template: template,
      extractionMap: extractionMap,
      fixedValues: fixedValues,
      sampleMessage: sampleMessage,
      categoryName: categoryName,
    );
    state = state.copyWith(patterns: _cache.patterns);
    return updated;
  }

  /// Hides a GLOBAL pattern for this family, or deactivates a FAMILY pattern.
  Future<void> disablePattern(String patternId) => _toggle(
        patternId,
        () => _cache.disablePattern(patternId),
      );

  /// Restores a pattern: un-hides a GLOBAL for this family, or reactivates a
  /// FAMILY pattern.
  Future<void> enablePattern(String patternId) => _toggle(
        patternId,
        () => _cache.enablePattern(patternId),
      );

  Future<void> _toggle(
    String patternId,
    Future<SmsPattern> Function() action,
  ) async {
    state = state.copyWith(
      busyPatternIds: {...state.busyPatternIds, patternId},
    );
    try {
      await action();
      state = state.copyWith(patterns: _cache.patterns);
    } finally {
      final ids = {...state.busyPatternIds}..remove(patternId);
      state = state.copyWith(busyPatternIds: ids);
    }
  }

  /// Promotes a family pattern to the global registry (family admin only).
  Future<SmsPattern> promotePattern(String patternId) async {
    final promoted = await _cache.promotePattern(patternId);
    state = state.copyWith(patterns: _cache.patterns);
    return promoted;
  }
}

final patternRegistryProvider =
    NotifierProvider<PatternRegistryNotifier, PatternRegistryState>(
      PatternRegistryNotifier.new,
    );
