import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../providers/auth_provider.dart';
import '../providers/message_provider.dart';
import '../services/pattern_cache_service.dart';
import '../services/sms_inbox_reader.dart';

import '../providers/family_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/service_providers.dart';
import '../models/message.dart';
import 'package:shared_preferences/shared_preferences.dart';



/// State for SMS parsing settings and pattern cache.
class SmsState {
  final bool smsPermissionGranted;
  final bool backgroundServiceEnabled;
  final int cachedPatternCount;
  final DateTime? lastSyncTime;
  final bool isRefreshing;
  final bool permissionPermanentlyDenied;
  final bool hasPromptedForConsent;
  final int? lastProcessedSmsTimestamp;
  final bool isSyncing;

  const SmsState({
    this.smsPermissionGranted = false,
    this.backgroundServiceEnabled = true,
    this.cachedPatternCount = 0,
    this.lastSyncTime,
    this.isRefreshing = false,
    this.permissionPermanentlyDenied = false,
    this.hasPromptedForConsent = false,
    this.lastProcessedSmsTimestamp,
    this.isSyncing = false,
  });

  SmsState copyWith({
    bool? smsPermissionGranted,
    bool? backgroundServiceEnabled,
    int? cachedPatternCount,
    DateTime? lastSyncTime,
    bool? isRefreshing,
    bool? permissionPermanentlyDenied,
    bool? hasPromptedForConsent,
    int? lastProcessedSmsTimestamp,
    bool? isSyncing,
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
      hasPromptedForConsent:
          hasPromptedForConsent ?? this.hasPromptedForConsent,
      lastProcessedSmsTimestamp:
          lastProcessedSmsTimestamp ?? this.lastProcessedSmsTimestamp,
      isSyncing: isSyncing ?? this.isSyncing,
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
    final prefs = await SharedPreferences.getInstance();
    final prompted = prefs.getBool('sms_consent_prompted') ?? false;
    final lastTimestamp = prefs.getInt('last_processed_sms_timestamp');

    state = state.copyWith(
      smsPermissionGranted: status.isGranted,
      permissionPermanentlyDenied: status.isPermanentlyDenied,
      cachedPatternCount: _cache.patternCount,
      lastSyncTime: _cache.lastSyncTime,
      hasPromptedForConsent: prompted,
      lastProcessedSmsTimestamp: lastTimestamp,
    );
  }

  Future<void> markConsentPrompted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sms_consent_prompted', true);
    state = state.copyWith(hasPromptedForConsent: true);
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

  /// Sync new messages iteratively in the background.
  Future<void> syncInboxMessages() async {
    if (!state.smsPermissionGranted || state.isSyncing) return;

    final userId = ref.read(authProvider).user?.id;
    final familyId = ref.read(familyProvider).currentFamily?.id;
    if (userId == null || familyId == null) return;

    state = state.copyWith(isSyncing: true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final lastTimestamp = prefs.getInt('last_processed_sms_timestamp');
      DateTime? since;

      if (lastTimestamp != null) {
        since = DateTime.fromMillisecondsSinceEpoch(lastTimestamp);
      } else {
        // First run: only process the last 30 days to avoid overloading
        since = DateTime.now().subtract(const Duration(days: 30));
      }

      final reader = SmsInboxReader(cache: _cache);
      final messages = await reader.readInbox(userId: userId, since: since);

      // readInbox returns newest first. We process oldest first (reversed)
      // to properly keep track of chronological progress if interrupted.
      for (final msg in messages.reversed) {
        if (msg.parseSource == ParseSource.regexLocal) {
          if (msg.isIncomplete) {
            // Found via local regex but missing mandatory fields.
            // Send to LLM to parse/save.
            await ref.read(messageServiceProvider).processMessage({
              'sender': msg.sender,
              'rawText': msg.rawText,
              'familyGroupId': familyId,
            });
          } else {
            // Fully parsed locally! Convert to transaction immediately.
            final txData = {
              'amount': double.parse(msg.extractedData!['amount']!),
              'merchantName': msg.extractedData!['merchant'],
              'transactionDate': msg.extractedData!['timestamp'] ??
                  msg.receivedAt.toIso8601String(),
              'type': msg.extractedData!['type']?.toUpperCase() ?? 'EXPENSE',
              'description': 'Auto-parsed from SMS',
            };
            await ref.read(transactionProvider.notifier).addTransaction(txData);
          }
        } else {
          // No local match. Send to backend LLM server.
          final response = await ref.read(messageServiceProvider).processMessage({
            'sender': msg.sender,
            'rawText': msg.rawText,
            'familyGroupId': familyId,
          });

          // If the LLM successfully generated a new pattern, reload the cache instantly.
          if (response['generatedPattern'] != null) {
            await refreshPatterns();
          }
        }

        // Successfully processed this message. Save checkpoint.
        prefs.setInt(
            'last_processed_sms_timestamp', msg.receivedAt.millisecondsSinceEpoch);
        state = state.copyWith(
            lastProcessedSmsTimestamp: msg.receivedAt.millisecondsSinceEpoch);
      }
    } catch (_) {
      // Background task silently recovers on next run
    } finally {
      state = state.copyWith(isSyncing: false);
      ref.read(messageProvider.notifier).loadMessages();
    }
  }

}

final smsProvider = NotifierProvider<SmsNotifier, SmsState>(
  SmsNotifier.new,
);
