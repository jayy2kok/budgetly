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
  /// Fields a user may pin to a literal value (mirrors server validation).
  static const _fixableFields = {
    'merchant',
    'accountLast4',
    'bankName',
    'notes',
  };

  /// Attempt to parse a message against anchor templates for its sender.
  ParseResult? parseMessage(
    String sender,
    String rawText,
    List<SmsPattern> patterns,
  ) {
    // Filter patterns for this sender (case-insensitive). Disabled and
    // hidden-for-family patterns never match, even if a caller passes the full
    // registry list.
    final senderPatterns = patterns
        .where((p) =>
            p.isEnabledForFamily &&
            p.sender.toUpperCase() == sender.toUpperCase())
        .toList();

    for (final pattern in _inPrecedenceOrder(senderPatterns)) {
      try {
        final extracted = _parseAnchorTemplate(pattern.template, rawText);
        if (extracted != null && extracted.isNotEmpty) {
          final fields = <String, String>{};

          // Extract using extraction map
          final map = pattern.extractionMap;
          if (extracted.containsKey(map.amount)) {
            fields['amount'] = extracted[map.amount]!;
          }
          if (map.merchant != null && extracted.containsKey(map.merchant)) {
            fields['merchant'] = extracted[map.merchant]!;
          }
          if (map.timestamp != null && extracted.containsKey(map.timestamp)) {
            fields['timestamp'] = extracted[map.timestamp]!;
          }
          if (map.accountLast4 != null &&
              extracted.containsKey(map.accountLast4)) {
            fields['accountLast4'] = extracted[map.accountLast4]!;
          }
          if (map.type != null && extracted.containsKey(map.type)) {
            fields['type'] = extracted[map.type]!;
          }
          if (map.notes != null && extracted.containsKey(map.notes)) {
            fields['notes'] = extracted[map.notes]!;
          }

          // A user-pinned fixed value wins over the extracted value.
          for (final entry in pattern.fixedValues.entries) {
            if (!_fixableFields.contains(entry.key)) continue;
            final value = entry.value.trim();
            if (value.isNotEmpty) fields[entry.key] = value;
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

  /// Orders patterns by match precedence: family-scoped first, then global,
  /// newest `updatedAt` first within each scope (mirrors the backend's
  /// `PatternRegistryService.findActiveBySender`). Ties keep their input order
  /// so the caller's list is only reordered, never otherwise disturbed.
  List<SmsPattern> _inPrecedenceOrder(List<SmsPattern> patterns) {
    final indexed = [
      for (var i = 0; i < patterns.length; i++) (i, patterns[i]),
    ];
    indexed.sort((a, b) {
      final byScope = _scopeRank(a.$2) - _scopeRank(b.$2);
      if (byScope != 0) return byScope;
      final aTime = a.$2.updatedAt;
      final bTime = b.$2.updatedAt;
      if (aTime != null && bTime != null) {
        final byTime = bTime.compareTo(aTime);
        if (byTime != 0) return byTime;
      } else if (aTime == null && bTime != null) {
        return 1; // Nulls last, like the backend comparator.
      } else if (aTime != null && bTime == null) {
        return -1;
      }
      return a.$1 - b.$1;
    });
    return [for (final entry in indexed) entry.$2];
  }

  static int _scopeRank(SmsPattern pattern) =>
      pattern.scope == PatternScope.family ? 0 : 1;

  /// Dry-runs a draft [template] against [smsText] — the client-side half of
  /// the builder's validation (the server re-validates with the same logic).
  ///
  /// Returns the extracted token map, or null when the template has no tokens
  /// or does not match the sample.
  Map<String, String>? dryRunTemplate(String template, String smsText) {
    return _parseAnchorTemplate(template, smsText);
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
