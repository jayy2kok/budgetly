import '../models/sms_pattern.dart';

/// Result of attempting to parse an SMS against cached regex patterns.
class ParseResult {
  /// ID of the pattern that matched.
  final String matchedPatternId;

  /// Extracted fields map (e.g. {'amount': '8942', 'merchant': 'Grocery Mart'}).
  final Map<String, String> extractedFields;

  /// Whether all mandatory fields (amount, merchant, timestamp) were extracted.
  bool get isComplete =>
      extractedFields.containsKey('amount') &&
      extractedFields.containsKey('merchant') &&
      extractedFields.containsKey('timestamp');

  const ParseResult({
    required this.matchedPatternId,
    required this.extractedFields,
  });
}

/// Simulates local regex parsing against cached patterns.
///
/// In production this would use real Dart RegExp matching;
/// for the prototype it uses simple string-contains matching.
class SmsParserService {
  /// Attempt to parse a message against patterns for its sender.
  ParseResult? parseMessage(
    String sender,
    String rawText,
    List<SmsPattern> patterns,
  ) {
    // Filter patterns for this sender
    final senderPatterns =
        patterns.where((p) => p.sender == sender).toList();

    for (final pattern in senderPatterns) {
      try {
        final regex = RegExp(pattern.regex);
        final match = regex.firstMatch(rawText);
        if (match != null) {
          final fields = <String, String>{};

          // Extract using named groups from the extraction map
          final map = pattern.extractionMap;
          _tryExtract(match, map.amount, 'amount', fields);
          _tryExtract(match, map.merchant, 'merchant', fields);
          _tryExtract(match, map.timestamp, 'timestamp', fields);
          if (map.accountLast4 != null) {
            _tryExtract(match, map.accountLast4!, 'accountLast4', fields);
          }
          if (map.type != null) {
            _tryExtract(match, map.type!, 'type', fields);
          }

          if (fields.isNotEmpty) {
            return ParseResult(
              matchedPatternId: pattern.id,
              extractedFields: fields,
            );
          }
        }
      } catch (_) {
        // Invalid regex — skip this pattern
        continue;
      }
    }
    return null;
  }

  void _tryExtract(
    RegExpMatch match,
    String groupName,
    String fieldName,
    Map<String, String> fields,
  ) {
    try {
      final value = match.namedGroup(groupName);
      if (value != null && value.isNotEmpty) {
        fields[fieldName] = value;
      }
    } catch (_) {
      // Named group doesn't exist in this pattern
    }
  }
}
