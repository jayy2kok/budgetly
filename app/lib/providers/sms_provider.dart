import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../providers/auth_provider.dart';
import '../providers/category_provider.dart';
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
  late final SmsInboxReader _reader;

  /// Minimum gap between automatic (background) inbox syncs. Manual syncs and
  /// the consent-granted sync are not debounced.
  static const Duration backgroundSyncMinInterval = Duration(seconds: 30);

  /// Key under which the background-service toggle is persisted.
  static const String backgroundServicePrefsKey = 'background_sms_service_enabled';

  DateTime? _lastBackgroundSyncAt;

  @override
  SmsState build() {
    _cache = ref.watch(patternCacheServiceProvider);
    _reader = ref.watch(smsInboxReaderProvider);
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
    final backgroundEnabled =
        prefs.getBool(backgroundServicePrefsKey) ?? true;

    state = state.copyWith(
      smsPermissionGranted: status.isGranted,
      permissionPermanentlyDenied: status.isPermanentlyDenied,
      cachedPatternCount: _cache.patternCount,
      lastSyncTime: _cache.lastSyncTime,
      hasPromptedForConsent: prompted,
      lastProcessedSmsTimestamp: lastTimestamp,
      backgroundServiceEnabled: backgroundEnabled,
    );
  }

  Future<void> markConsentPrompted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sms_consent_prompted', true);
    state = state.copyWith(hasPromptedForConsent: true);
  }


  /// Toggle background SMS service (persisted across launches).
  Future<void> toggleBackgroundService() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
        backgroundServicePrefsKey, !state.backgroundServiceEnabled);
    state = state.copyWith(
      backgroundServiceEnabled: !state.backgroundServiceEnabled,
    );
  }

  /// Background-triggered inbox sync, safe to call from launch/return-to-app
  /// flows. Respects the toggle, debounces to [backgroundSyncMinInterval],
  /// and skips entirely when SMS permission is not granted. On-demand syncs
  /// should call [syncInboxMessages] directly (no debounce, no toggle gate).
  Future<void> triggerBackgroundSync() async {
    if (!state.smsPermissionGranted || !state.backgroundServiceEnabled) return;

    final last = _lastBackgroundSyncAt;
    if (last != null &&
        DateTime.now().difference(last) < backgroundSyncMinInterval) {
      debugPrint('[SmsSync] Background sync skipped (debounced).');
      return;
    }
    _lastBackgroundSyncAt = DateTime.now();
    await syncInboxMessages();
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

  /// Persist the highest-processed message timestamp and mirror it to state.
  Future<void> _checkpoint(Message msg, SharedPreferences prefs) async {
    await prefs.setInt(
      'last_processed_sms_timestamp',
      msg.receivedAt.millisecondsSinceEpoch,
    );
    state = state.copyWith(
      lastProcessedSmsTimestamp: msg.receivedAt.millisecondsSinceEpoch,
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

    final messages = await _reader.readInbox(userId: userId);

    if (messages.isNotEmpty) {
      ref.read(messageProvider.notifier).mergeLocalMessages(messages);
    }
  }

  /// Sync new messages iteratively in the background.
  Future<void> syncInboxMessages() async {
    if (!state.smsPermissionGranted || state.isSyncing) return;

    final userId = ref.read(authProvider).user?.id;
    final familyId = ref.read(familyProvider).currentFamily?.id;
    if (userId == null) {
      debugPrint('[SmsSyncMessage] Aborting: user not authenticated.');
      state = state.copyWith(isSyncing: false);
      return;
    }
    if (familyId == null) {
      debugPrint('[SmsSyncMessage] Aborting: no family loaded yet.');
      state = state.copyWith(isSyncing: false);
      return;
    }
    debugPrint('[SmsSync] Starting inbox sync for user=$userId, family=$familyId');

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

      final messages = await _reader.readInbox(userId: userId, since: since);

      // readInbox returns newest first. We process oldest first (reversed)
      // to properly keep track of chronological progress if interrupted.
      const maxBatchSize = 500; // backend budgetly.change-stream.max-batch-size
      final serverQueue = <Message>[];

      for (final msg in messages.reversed) {
        if (msg.parseSource == ParseSource.regexLocal && !msg.isIncomplete) {
          // Fully parsed locally! Convert to transaction immediately.
          debugPrint('[SmsSync] Regex-parsed fully, creating transaction for msg id=${msg.id}');

          // Resolve the template's user-overridden category (if any) to this
          // family's category id so future transactions inherit the override.
          String? resolvedCategoryId;
          final matchedPattern = _cache.patternById(msg.matchedPatternId);
          final overrideName = matchedPattern?.categoryName?.trim();
          if (overrideName != null && overrideName.isNotEmpty) {
            final name = overrideName.toLowerCase();
            final familyCategories = ref.read(categoryProvider).categories;
            for (final c in familyCategories) {
              if (c.name.trim().toLowerCase() == name) {
                resolvedCategoryId = c.id;
                break;
              }
            }
          }

          final txData = {
            'amount': double.parse(
              msg.extractedData!['amount']!.replaceAll(',', '').trim(),
            ),
            'merchant': msg.extractedData!['merchant'],
            // Prefer the SMS's authoritative receivedAt (a correct absolute
            // instant). The extracted timestamp is only a fallback: it carries
            // no offset and would be misread, and the backend rejects its
            // non-ISO date formats (e.g. "14-11-2026 19:32:24").
            'transactionDate': msg.receivedAt.toUtc().toIso8601String(),
            'type': msg.extractedData!['type']?.toUpperCase() ?? 'EXPENSE',
            'description': 'Auto-parsed from SMS',
            'sourceType': 'REGEX_LOCAL',
            'sourceRawText': msg.rawText,
            'matchedPatternId': msg.matchedPatternId,
            'categoryId': ?resolvedCategoryId,
          };
          await ref.read(transactionProvider.notifier).addTransaction(txData);

          // Successfully processed this message. Save checkpoint.
          await _checkpoint(msg, prefs);
        } else {
          // Incomplete regex, or no local match — bulk-queue for the server
          // change-stream pipeline (listener runs anchor-match/LLM).
          serverQueue.add(msg);
        }
      }

      // Batch-insert everything the server must look at, <=500 per request.
      for (var i = 0; i < serverQueue.length; i += maxBatchSize) {
        final end = (i + maxBatchSize < serverQueue.length)
            ? i + maxBatchSize
            : serverQueue.length;
        final batch = serverQueue.sublist(i, end);
        debugPrint('[SmsSync] Bulk-submitting ${batch.length} msgs to server (batch $i..$end).');
        await ref.read(messageServiceProvider).bulkInsertMessages(
              familyGroupId: familyId,
              messages: [
                for (final m in batch)
                  {
                    'sender': m.sender,
                    'rawText': m.rawText,
                    'receivedAt': m.receivedAt.toUtc().toIso8601String(),
                  },
              ],
            );

        // Checkpoint the newest message of this batch only after acceptance,
        // so a failed batch is retried on the next sync.
        await _checkpoint(batch.last, prefs);
      }

      // The listener may have registered new patterns while processing the
      // batch — refresh once so the next sync can anchor-match locally.
      if (serverQueue.isNotEmpty) {
        await refreshPatterns();
      }
    } catch (e, stack) {
      debugPrint('[SmsSync] Error during sync: $e\n$stack');
    } finally {
      state = state.copyWith(isSyncing: false);
      ref.read(messageProvider.notifier).loadMessages();
    }
  }

}

final smsProvider = NotifierProvider<SmsNotifier, SmsState>(
  SmsNotifier.new,
);
