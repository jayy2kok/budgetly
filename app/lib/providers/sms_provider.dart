import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../providers/auth_provider.dart';
import '../providers/message_provider.dart';
import '../services/pattern_cache_service.dart';
import '../services/sms_inbox_reader.dart';

/// State for SMS parsing settings and pattern cache.
class SmsState {
  final bool smsPermissionGranted;
  final bool backgroundServiceEnabled;
  final int cachedPatternCount;
  final DateTime? lastSyncTime;
  final bool isRefreshing;
  final bool permissionPermanentlyDenied;

  const SmsState({
    this.smsPermissionGranted = false,
    this.backgroundServiceEnabled = true,
    this.cachedPatternCount = 0,
    this.lastSyncTime,
    this.isRefreshing = false,
    this.permissionPermanentlyDenied = false,
  });

  SmsState copyWith({
    bool? smsPermissionGranted,
    bool? backgroundServiceEnabled,
    int? cachedPatternCount,
    DateTime? lastSyncTime,
    bool? isRefreshing,
    bool? permissionPermanentlyDenied,
  }) {
    return SmsState(
      smsPermissionGranted: smsPermissionGranted ?? this.smsPermissionGranted,
      backgroundServiceEnabled:
          backgroundServiceEnabled ?? this.backgroundServiceEnabled,
      cachedPatternCount: cachedPatternCount ?? this.cachedPatternCount,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      permissionPermanentlyDenied:
          permissionPermanentlyDenied ?? this.permissionPermanentlyDenied,
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
    _init();
    return const SmsState();
  }

  Future<void> _init() async {
    // Load cached patterns
    await _cache.loadPatterns();

    // Check real SMS permission status from the OS
    final status = await Permission.sms.status;
    state = state.copyWith(
      smsPermissionGranted: status.isGranted,
      permissionPermanentlyDenied: status.isPermanentlyDenied,
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

  /// Request SMS permission from the OS.
  ///
  /// Returns true if the permission is granted after the request.
  /// If permanently denied, the user must go to app settings.
  Future<bool> requestPermission() async {
    // Already granted
    if (state.smsPermissionGranted) return true;

    if (state.permissionPermanentlyDenied) {
      // Can't prompt again — user must enable from system Settings
      await openAppSettings();
      return false;
    }

    final result = await Permission.sms.request();
    final granted = result.isGranted;
    state = state.copyWith(
      smsPermissionGranted: granted,
      permissionPermanentlyDenied: result.isPermanentlyDenied,
    );
    return granted;
  }

  /// Re-check permission status (e.g. after returning from Settings).
  Future<void> recheckPermission() async {
    final status = await Permission.sms.status;
    state = state.copyWith(
      smsPermissionGranted: status.isGranted,
      permissionPermanentlyDenied: status.isPermanentlyDenied,
    );
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

  /// Reads the on-device SMS inbox and merges results into the message pipeline.
  ///
  /// Only processes messages from senders in the pattern cache (known banks).
  /// Matched messages are added as regex-parsed; unmatched go to the LLM queue.
  Future<void> loadAndMergeInboxMessages() async {
    if (!state.smsPermissionGranted) return;

    final userId = ref.read(authProvider).user?.id;
    if (userId == null) return; // Not authenticated yet

    final reader = SmsInboxReader(cache: _cache);
    final messages = await reader.readInbox(userId: userId);

    if (messages.isNotEmpty) {
      ref.read(messageProvider.notifier).mergeLocalMessages(messages);
    }
  }
}

final smsProvider = NotifierProvider<SmsNotifier, SmsState>(
  SmsNotifier.new,
);
