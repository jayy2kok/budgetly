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
  /// Attempt to parse a message against anchor templates for its sender.
  ParseResult? parseMessage(
    String sender,
    String rawText,
    List<SmsPattern> patterns,
  ) {
    // Filter patterns for this sender (case-insensitive)
    final senderPatterns =
        patterns.where((p) => p.sender.toUpperCase() == sender.toUpperCase()).toList();

    for (final pattern in senderPatterns) {
      try {
        final extracted = _parseAnchorTemplate(pattern.template, rawText);
        if (extracted != null && extracted.isNotEmpty) {
          final fields = <String, String>{};

          // Extract using extraction map
          final map = pattern.extractionMap;
          if (extracted.containsKey(map.amount)) fields['amount'] = extracted[map.amount]!;
          if (extracted.containsKey(map.merchant)) fields['merchant'] = extracted[map.merchant]!;
          if (extracted.containsKey(map.timestamp)) fields['timestamp'] = extracted[map.timestamp]!;
          if (map.accountLast4 != null && extracted.containsKey(map.accountLast4)) {
            fields['accountLast4'] = extracted[map.accountLast4]!;
          }
          if (map.type != null && extracted.containsKey(map.type)) {
            fields['type'] = extracted[map.type]!;
          }

          if (fields.isNotEmpty) {
            return ParseResult(
              matchedPatternId: pattern.id,
              extractedFields: fields,
            );
          }
        }
      } catch (_) {
        // Skip malformed template
        continue;
      }
    }
    return null;
  }

  /// Extracts variable tokens using left/right literal anchors.
  Map<String, String>? _parseAnchorTemplate(String template, String smsText) {
    final tokenPattern = RegExp(r'\{([^}]+)\}');
    final matches = tokenPattern.allMatches(template).toList();
    if (matches.isEmpty) return null;

    final List<String> literals = [];
    final List<String> tokens = [];
    int lastEnd = 0;

    for (final match in matches) {
      literals.add(template.substring(lastEnd, match.start));
      tokens.add(match.group(1)!);
      lastEnd = match.end;
    }
    literals.add(template.substring(lastEnd));

    final Map<String, String> results = {};
    int currentIndex = 0;

    for (int i = 0; i < tokens.length; i++) {
      final leftLiteral = literals[i];
      final rightLiteral = literals[i + 1];
      final tokenName = tokens[i];

      final leftIndex = smsText.indexOf(leftLiteral, currentIndex);
      if (leftIndex == -1) {
        return null; // Left anchor mismatch
      }
      final valueStart = leftIndex + leftLiteral.length;

      int valueEnd;
      if (rightLiteral.isEmpty) {
        valueEnd = smsText.length;
      } else {
        valueEnd = smsText.indexOf(rightLiteral, valueStart);
        if (valueEnd == -1) {
          return null; // Right anchor mismatch
        }
      }

      final extractedValue = smsText.substring(valueStart, valueEnd).trim();
      results[tokenName] = extractedValue;
      currentIndex = valueEnd;
    }

    return results;
  }
}
