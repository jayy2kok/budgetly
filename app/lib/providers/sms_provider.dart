import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../providers/auth_provider.dart';
import '../providers/budget_provider.dart';
import '../providers/category_provider.dart';
import '../services/pattern_cache_service.dart';
import '../services/sms_inbox_reader.dart';
import '../services/sms_parser_service.dart';
import '../services/transaction_date_resolver.dart';

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
  static const String backgroundServicePrefsKey =
      'background_sms_service_enabled';

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
    final backgroundEnabled = prefs.getBool(backgroundServicePrefsKey) ?? true;

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
      backgroundServicePrefsKey,
      !state.backgroundServiceEnabled,
    );
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
    debugPrint(
      '[SmsSync] Starting inbox sync for user=$userId, family=$familyId',
    );

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
          debugPrint(
            '[SmsSync] Regex-parsed fully, creating transaction for msg id=${msg.id}',
          );
          await _postTransaction(msg, familyId);

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
        debugPrint(
          '[SmsSync] Bulk-submitting ${batch.length} msgs to server (batch $i..$end).',
        );
        await ref
            .read(messageServiceProvider)
            .bulkInsertMessages(
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
      await _refreshDashboard();
    }
  }

  /// Parses [message] against the current pattern cache and, when the result
  /// is complete, records the transaction immediately.
  ///
  /// Used by the pattern builder after saving: the sync checkpoint means an
  /// older SMS is never re-read, so the message that prompted the new pattern
  /// must be recorded right away. Returns true when a transaction was created.
  Future<bool> recordLocally(Message message) async {
    final familyId = ref.read(familyProvider).currentFamily?.id;
    if (familyId == null) return false;

    await _cache.loadPatterns();
    final parseResult = SmsParserService().parseMessage(
      message.sender,
      message.rawText,
      _cache.matchablePatterns,
    );
    if (parseResult == null) return false;

    final parsed = Message(
      id: message.id,
      userId: message.userId,
      familyGroupId: familyId,
      sender: message.sender,
      rawText: message.rawText,
      receivedAt: message.receivedAt,
      status: MessageStatus.pending,
      parseSource: ParseSource.regexLocal,
      matchedPatternId: parseResult.matchedPatternId,
      extractedData: parseResult.extractedFields,
    );
    if (parsed.isIncomplete) return false;

    try {
      await _postTransaction(parsed, familyId);
      await _refreshDashboard();
      return true;
    } catch (e) {
      debugPrint('[SmsSync] Failed to record message ${message.id}: $e');
      return false;
    }
  }

  /// Creates a transaction for a fully parsed message.
  Future<void> _postTransaction(Message msg, String familyId) async {
    // Resolve the template's user-overridden category (if any) to this
    // family's category id so future transactions inherit the override.
    String? resolvedCategoryId;
    final matchedPattern = _cache.patternById(msg.matchedPatternId);
    final overrideName = matchedPattern?.categoryName?.trim();
    if (overrideName != null && overrideName.isNotEmpty) {
      // The override resolves against the family's categories, which may not
      // have been loaded yet on a cold start.
      if (ref.read(categoryProvider).categories.isEmpty) {
        await ref.read(categoryProvider.notifier).loadCategories(familyId);
      }
      final name = overrideName.toLowerCase();
      for (final c in ref.read(categoryProvider).categories) {
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
      // The body's date is authoritative; a date-only body takes the SMS's
      // received time-of-day (see TransactionDateResolver).
      'transactionDate': const TransactionDateResolver()
          .resolve(msg.receivedAt, msg.extractedData!['timestamp'])
          .toUtc()
          .toIso8601String(),
      'type': msg.extractedData!['type']?.toUpperCase() ?? 'EXPENSE',
      'accountLast4': ?msg.extractedData!['accountLast4'],
      'bankName': ?msg.extractedData!['bankName'],
      'notes': ?msg.extractedData!['notes'],
      'description': 'Auto-parsed from SMS',
      'sourceType': 'REGEX_LOCAL',
      'sourceRawText': msg.rawText,
      'matchedPatternId': msg.matchedPatternId,
      'categoryId': ?resolvedCategoryId,
    };
    await ref.read(transactionProvider.notifier).addTransaction(txData);
  }

  /// Reload dashboard totals and the transaction list after a sync.
  ///
  /// Local regex-parsed messages already create transactions directly, but
  /// server-side processing of bulk-submitted messages happens asynchronously
  /// after the bulk response, so both views are reloaded to surface them.
  /// Errors are swallowed — a failed refresh must not surface as a sync
  /// failure, and the next sync or pull-to-refresh will retry.
  Future<void> _refreshDashboard() async {
    try {
      await ref.read(transactionProvider.notifier).loadTransactions();
      final familyId = ref.read(familyProvider).currentFamily?.id;
      if (familyId != null) {
        await ref.read(budgetProvider.notifier).loadDashboard(familyId);
      }
    } catch (e) {
      debugPrint('[SmsSync] Dashboard refresh failed: $e');
    }
  }
}

final smsProvider = NotifierProvider<SmsNotifier, SmsState>(SmsNotifier.new);
