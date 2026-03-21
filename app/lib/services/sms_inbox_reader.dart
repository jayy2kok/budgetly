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

  /// Reads the SMS inbox and returns [Message] objects for all messages that:
  /// - Matched a cached pattern (financial, regex-parsed), OR
  /// - Came from a known sender but had no pattern match (unprocessed/LLM queue)
  ///
  /// Non-financial messages from unknown senders are silently skipped.
  ///
  /// [userId] is required so the backend can associate messages with the user.
  /// [since] filters out messages older than the given timestamp.
  /// [limit] is the max number of SMS to scan (most recent first).
  Future<List<Message>> readInbox({
    required String userId,
    DateTime? since,
    int limit = 500,
  }) async {
    if (!await hasPermission()) return [];

    await _cache.loadPatterns();
    final patterns = _cache.patterns;
    final knownSenders = patterns.map((p) => p.sender.toUpperCase()).toSet();

    final smsList = await _query.querySms(
      kinds: [SmsQueryKind.inbox],
      count: limit,
    );

    final result = <Message>[];

    for (final sms in smsList) {
      final receivedAt = sms.dateSent ?? DateTime.now();
      
      // Since smsList is sorted descending, we can break early if we hit an old message
      if (since != null && receivedAt.isBefore(since)) {
        break;
      }

      final sender = (sms.sender ?? '').toUpperCase();
      final body = sms.body ?? '';
      final id = 'sms_${sms.id ?? '${sender}_${sms.dateSent}'}';

      // Only process messages from known bank/financial senders
      if (!knownSenders.contains(sender)) continue;

      final senderPatterns =
          patterns.where((p) => p.sender.toUpperCase() == sender).toList();
      final parseResult = _parser.parseMessage(sender, body, senderPatterns);



      if (parseResult != null) {
        // Pattern matched — regex-parsed, may still be incomplete
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
        // Known sender, no regex match — queue for LLM analysis
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

    return result;
  }
}
