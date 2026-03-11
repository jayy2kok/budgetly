import 'package:json_annotation/json_annotation.dart';

part 'sms_pattern.g.dart';

/// Maps regex capture group names to transaction fields.
@JsonSerializable()
class ExtractionMap {
  /// Capture group name for amount (mandatory).
  final String amount;

  /// Capture group name for merchant (mandatory).
  final String merchant;

  /// Capture group name for timestamp (mandatory).
  final String timestamp;

  /// Capture group name for last 4 digits of account (optional).
  final String? accountLast4;

  /// Capture group name for debit/credit type (optional).
  final String? type;

  const ExtractionMap({
    required this.amount,
    required this.merchant,
    required this.timestamp,
    this.accountLast4,
    this.type,
  });

  factory ExtractionMap.fromJson(Map<String, dynamic> json) =>
      _$ExtractionMapFromJson(json);

  Map<String, dynamic> toJson() => _$ExtractionMapToJson(this);
}

/// A regex pattern in the global SMS pattern registry.
@JsonSerializable()
class SmsPattern {
  final String id;

  /// SMS sender ID (e.g. "HDFCBK", "SBIUPI").
  final String sender;

  /// Java/Dart-compatible regex with named capture groups.
  final String regex;

  /// Maps capture groups to transaction fields.
  final ExtractionMap extractionMap;

  /// The original SMS that generated this pattern.
  final String sampleMessage;

  /// Global counter of successful matches across all users.
  final int usageCount;

  final DateTime createdAt;

  const SmsPattern({
    required this.id,
    required this.sender,
    required this.regex,
    required this.extractionMap,
    required this.sampleMessage,
    this.usageCount = 0,
    required this.createdAt,
  });

  factory SmsPattern.fromJson(Map<String, dynamic> json) =>
      _$SmsPatternFromJson(json);

  Map<String, dynamic> toJson() => _$SmsPatternToJson(this);
}
