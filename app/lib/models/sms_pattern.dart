import 'package:json_annotation/json_annotation.dart';

part 'sms_pattern.g.dart';

/// Scope of a pattern in the registry.
enum PatternScope {
  @JsonValue('GLOBAL')
  global,
  @JsonValue('FAMILY')
  family,
}

/// How a pattern entered the registry.
enum PatternSource {
  @JsonValue('LLM')
  llm,
  @JsonValue('USER')
  user,
}

/// Maps regex capture group names to transaction fields.
@JsonSerializable()
class ExtractionMap {
  /// Capture group name for amount (mandatory).
  final String amount;

  /// Capture group name for merchant (optional — family-authored patterns may
  /// tag only an amount).
  final String? merchant;

  /// Capture group name for timestamp (optional).
  final String? timestamp;

  /// Capture group name for last 4 digits of account (optional).
  final String? accountLast4;

  /// Capture group name for debit/credit type (optional).
  final String? type;

  const ExtractionMap({
    required this.amount,
    this.merchant,
    this.timestamp,
    this.accountLast4,
    this.type,
  });

  factory ExtractionMap.fromJson(Map<String, dynamic> json) =>
      _$ExtractionMapFromJson(json);

  Map<String, dynamic> toJson() => _$ExtractionMapToJson(this);
}

/// A pattern in the SMS pattern registry (global or family-scoped).
@JsonSerializable()
class SmsPattern {
  final String id;

  /// SMS sender ID (e.g. "HDFCBK", "SBIUPI").
  final String sender;

  /// Anchor template with {tokens}
  final String template;

  /// Maps capture groups to transaction fields.
  final ExtractionMap extractionMap;

  /// The original SMS that generated this pattern.
  final String sampleMessage;

  /// User-overridden category name (resolved per-family when creating a transaction).
  final String? categoryName;

  /// Global counter of successful matches across all users.
  final int usageCount;

  /// Whether this pattern is global or authored by a single family.
  final PatternScope scope;

  /// Family that authored this pattern; null for global patterns.
  final String? ownerFamilyGroupId;

  /// User who authored this pattern; null for LLM-learned global patterns.
  final String? createdByUserId;

  /// How this pattern entered the registry.
  final PatternSource source;

  /// Whether the pattern is active (in the registry).
  final bool active;

  final DateTime createdAt;

  /// Last modification time (null for legacy LLM-seeded patterns).
  final DateTime? updatedAt;

  const SmsPattern({
    required this.id,
    required this.sender,
    required this.template,
    required this.extractionMap,
    required this.sampleMessage,
    this.categoryName,
    this.usageCount = 0,
    this.scope = PatternScope.global,
    this.ownerFamilyGroupId,
    this.createdByUserId,
    this.source = PatternSource.llm,
    this.active = true,
    required this.createdAt,
    this.updatedAt,
  });

  factory SmsPattern.fromJson(Map<String, dynamic> json) =>
      _$SmsPatternFromJson(json);

  Map<String, dynamic> toJson() => _$SmsPatternToJson(this);

  /// Whether this pattern was authored by a user (family-scoped or promoted).
  bool get isAuthored => source == PatternSource.user;

  /// Whether the current viewer may edit/delete this pattern: family-scoped
  /// patterns are editable by their author; global patterns are read-only.
  bool canEdit(String userId) =>
      scope == PatternScope.family && createdByUserId == userId;
}