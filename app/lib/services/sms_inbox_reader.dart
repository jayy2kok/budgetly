import 'package:flutter/foundation.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';

import '../config/api_config.dart';
import '../models/message.dart';
import 'pattern_cache_service.dart';
import 'sms_parser_service.dart';

/// Reads the Android SMS inbox and converts financial messages into [Message]
/// objects that feed into the message-processing pipeline.
class SmsInboxReader {
  final PatternCacheService _cache;
  final SmsParserService _parser;
  final SmsQuery _query;

  SmsInboxReader({
    PatternCacheService? cache,
    SmsParserService? parser,
    SmsQuery? query,
  })  : _cache = cache ?? PatternCacheService(),
        _parser = parser ?? SmsParserService(),
        _query = query ?? SmsQuery();

  /// Returns true if the app currently holds SMS read permission.
  Future<bool> hasPermission() async {
    return (await Permission.sms.status).isGranted;
  }

  /// Reads the device SMS inbox and returns one [Message] per SMS, newest
  /// first, regardless of sender or content.
  ///
  /// This is the inbox screen's source of truth: it mirrors the phone's SMS
  /// app, so OTPs, promos, delivery notices and personal texts are included.
  /// [limit] caps the display window (defaults to
  /// [ApiConfig.smsInboxDisplayLimit]).
  Future<List<Message>> readAllInbox({
    required String userId,
    int limit = ApiConfig.smsInboxDisplayLimit,
  }) async {
    if (!await hasPermission()) {
      debugPrint('[SmsInboxReader] No SMS permission — skipping inbox read.');
      return [];
    }

    List<SmsMessage> smsList;
    try {
      smsList = await _query.querySms(
        kinds: [SmsQueryKind.inbox],
        count: limit,
      );
    } catch (e) {
      debugPrint('[SmsInboxReader] Failed to query SMS inbox: $e');
      return [];
    }

    final result = <Message>[];
    for (final sms in smsList) {
      final sender = (sms.sender ?? '').trim();
      final body = sms.body ?? '';
      if (sender.isEmpty || body.isEmpty) continue;

      // The received date (not dateSent) is the message's arrival time; it
      // completes date-only timestamps in the body.
      final receivedAt = sms.date ?? sms.dateSent ?? DateTime.now();
      result.add(Message(
        id: _messageId(sms, sender, receivedAt),
        userId: userId,
        sender: sender,
        rawText: body,
        receivedAt: receivedAt,
        status: MessageStatus.pending,
      ));
    }

    debugPrint('[SmsInboxReader] Read ${result.length} messages from the inbox.');
    return result;
  }

  /// Reads the SMS inbox and returns [Message] objects for all financial-looking messages.
  ///
  /// Strategy (two-pass):
  /// 1. Try matching against cached patterns (regex-local path).
  /// 2. If no cached patterns exist for a sender, use keyword heuristics to
  ///    detect financial messages and queue them for LLM analysis.
  ///
  /// [userId] is required so the backend can associate messages with the user.
  /// [since] filters out messages older than the given timestamp.
  /// [limit] is the max number of SMS to scan (most recent first).
  Future<List<Message>> readInbox({
    required String userId,
    DateTime? since,
    int limit = 500,
  }) async {
    if (!await hasPermission()) {
      debugPrint('[SmsInboxReader] No SMS permission — skipping inbox read.');
      return [];
    }

    await _cache.loadPatterns();
    final patterns = _cache.matchablePatterns;
    final knownSenders = patterns.map((p) => p.sender.toUpperCase()).toSet();

    debugPrint(
        '[SmsInboxReader] Loaded ${patterns.length} cached patterns. Known senders: $knownSenders');
    debugPrint('[SmsInboxReader] Reading inbox since: $since');

    List<SmsMessage> smsList;
    try {
      smsList = await _query.querySms(
        kinds: [SmsQueryKind.inbox],
        count: limit,
      );
    } catch (e) {
      debugPrint('[SmsInboxReader] Failed to query SMS inbox: $e');
      return [];
    }

    debugPrint('[SmsInboxReader] Found ${smsList.length} total SMS in inbox.');

    final result = <Message>[];

    for (final sms in smsList) {
      // The received date is the SMS's arrival time; dateSent can predate it.
      final receivedAt = sms.date ?? sms.dateSent ?? DateTime.now();

      // Since smsList is sorted descending, stop at the checkpoint message.
      // The cutoff is EXCLUSIVE: the checkpoint's own message (receivedAt ==
      // since) was already processed last sync and must not be re-ingested.
      if (since != null && !receivedAt.isAfter(since)) {
        debugPrint(
            '[SmsInboxReader] Reached messages at/before cutoff ($since). Stopping.');
        break;
      }

      // Testing cap: stop once we've collected enough financial messages.
      // Kept configurable (SMS_SYNC_MAX_MESSAGES) so it can be raised/removed.
      if (result.length >= ApiConfig.smsSyncMaxMessages) {
        debugPrint(
            '[SmsInboxReader] Reached financial-message cap (${ApiConfig.smsSyncMaxMessages}). Stopping.');
        break;
      }

      final sender = (sms.sender ?? '').toUpperCase().trim();
      final body = sms.body ?? '';
      final id = _messageId(sms, sender, receivedAt);

      if (sender.isEmpty || body.isEmpty) continue;

      // --- Strategy 1: Known sender with cached patterns ---
      if (knownSenders.contains(sender)) {
        final senderPatterns =
            patterns.where((p) => p.sender.toUpperCase() == sender).toList();
        final parseResult = _parser.parseMessage(sender, body, senderPatterns);

        if (parseResult != null) {
          result.add(Message(
            id: id,
            userId: userId,
            sender: sms.sender ?? '',
            rawText: body,
            receivedAt: receivedAt,
            status: MessageStatus.pending,
            parseSource: ParseSource.regexLocal,
            matchedPatternId: parseResult.matchedPatternId,
            extractedData: parseResult.extractedFields.isNotEmpty
                ? parseResult.extractedFields
                : null,
          ));
        } else {
          // Known sender but no pattern match — send to LLM
          result.add(Message(
            id: id,
            userId: userId,
            sender: sms.sender ?? '',
            rawText: body,
            receivedAt: receivedAt,
            status: MessageStatus.pending,
            parseSource: null,
            matchedPatternId: null,
            extractedData: null,
          ));
        }
        continue;
      }

      // --- Strategy 2: Unknown sender — use keyword heuristics ---
      // We queue messages that look financial so the LLM can decide and generate a pattern.
      if (_looksFinancial(body)) {
        debugPrint('[SmsInboxReader] Unknown sender $sender — looks financial, queuing for LLM.');
        result.add(Message(
          id: id,
          userId: userId,
          sender: sms.sender ?? '',
          rawText: body,
          receivedAt: receivedAt,
          status: MessageStatus.pending,
          parseSource: null,
          matchedPatternId: null,
          extractedData: null,
        ));
      }
    }

    debugPrint('[SmsInboxReader] Found ${result.length} financial messages to process.');
    return result;
  }

  /// Stable id for an SMS: the device row id when available, otherwise a
  /// sender+timestamp fallback. Shared by both readers so the same SMS has the
  /// same id in the inbox and in the sync pipeline.
  String _messageId(SmsMessage sms, String sender, DateTime receivedAt) =>
      'sms_${sms.id ?? '${sender}_${receivedAt.millisecondsSinceEpoch}'}';

  /// Returns true if the SMS body contains keywords commonly found in bank transaction alerts.
  bool _looksFinancial(String body) {
    const keywords = [
      'debited', 'credited', 'spent', 'txn', 'transaction',
      'upi', 'imps', 'neft', 'rtgs', 'payment', 'transfer',
      'withdrawn', 'balance', 'a/c', 'acct', 'account',
      'rs.', 'inr', '₹',
    ];
    final lower = body.toLowerCase();
    return keywords.any((kw) => lower.contains(kw));
  }
}
