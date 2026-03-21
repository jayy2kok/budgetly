import 'package:flutter/foundation.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';

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
    final patterns = _cache.patterns;
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
      final receivedAt = sms.dateSent ?? DateTime.now();

      // Since smsList is sorted descending, break early for older messages
      if (since != null && receivedAt.isBefore(since)) {
        debugPrint(
            '[SmsInboxReader] Reached messages before cutoff ($since). Stopping.');
        break;
      }

      final sender = (sms.sender ?? '').toUpperCase().trim();
      final body = sms.body ?? '';
      final id = 'sms_${sms.id ?? '${sender}_${receivedAt.millisecondsSinceEpoch}'}';

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
