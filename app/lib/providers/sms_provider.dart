import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/pattern_cache_service.dart';

/// State for SMS parsing settings and pattern cache.
class SmsState {
  final bool smsPermissionGranted;
  final bool backgroundServiceEnabled;
  final int cachedPatternCount;
  final DateTime? lastSyncTime;
  final bool isRefreshing;

  const SmsState({
    this.smsPermissionGranted = false,
    this.backgroundServiceEnabled = true,
    this.cachedPatternCount = 0,
    this.lastSyncTime,
    this.isRefreshing = false,
  });

  SmsState copyWith({
    bool? smsPermissionGranted,
    bool? backgroundServiceEnabled,
    int? cachedPatternCount,
    DateTime? lastSyncTime,
    bool? isRefreshing,
  }) {
    return SmsState(
      smsPermissionGranted: smsPermissionGranted ?? this.smsPermissionGranted,
      backgroundServiceEnabled:
          backgroundServiceEnabled ?? this.backgroundServiceEnabled,
      cachedPatternCount: cachedPatternCount ?? this.cachedPatternCount,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }

  /// Human-friendly label for last sync time.
  String get lastSyncLabel {
    if (lastSyncTime == null) return 'Never';
    final diff = DateTime.now().difference(lastSyncTime!);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class SmsNotifier extends Notifier<SmsState> {
  late final PatternCacheService _cache;

  @override
  SmsState build() {
    _cache = PatternCacheService();
    // Auto-load patterns on init
    _init();
    return const SmsState();
  }

  Future<void> _init() async {
    await _cache.loadPatterns();
    state = state.copyWith(
      smsPermissionGranted: true, // Mock: assume granted
      cachedPatternCount: _cache.patternCount,
      lastSyncTime: _cache.lastSyncTime,
    );
  }

  /// Toggle background SMS service.
  void toggleBackgroundService() {
    state = state.copyWith(
      backgroundServiceEnabled: !state.backgroundServiceEnabled,
    );
  }

  /// Request SMS permission (mock: always grants).
  Future<void> requestPermission() async {
    await Future.delayed(const Duration(milliseconds: 300));
    state = state.copyWith(smsPermissionGranted: true);
  }

  /// Refresh patterns from server.
  Future<void> refreshPatterns() async {
    state = state.copyWith(isRefreshing: true);
    await _cache.refreshPatterns();
    state = state.copyWith(
      cachedPatternCount: _cache.patternCount,
      lastSyncTime: _cache.lastSyncTime,
      isRefreshing: false,
    );
  }
}

final smsProvider = NotifierProvider<SmsNotifier, SmsState>(
  SmsNotifier.new,
);
