import 'package:json_annotation/json_annotation.dart';

part 'message.g.dart';

/// Status of a message in the AI triage pipeline.
enum MessageStatus {
  @JsonValue('PENDING')
  pending,
  @JsonValue('CONFIRMED')
  confirmed,
  @JsonValue('REJECTED')
  rejected,
  @JsonValue('IGNORED')
  ignored,
}

/// Result of AI triage classification.
enum TriageResult {
  @JsonValue('TRANSACTION')
  transaction,
  @JsonValue('OTP')
  otp,
  @JsonValue('PROMO')
  promo,
  @JsonValue('PERSONAL')
  personal,
  @JsonValue('UNKNOWN')
  unknown,
}

/// An SMS message submitted for AI-powered parsing and triage.
@JsonSerializable()
class Message {
  final String id;
  final String userId;
  final String? familyGroupId;
  final String sender;
  final String rawText;
  final MessageStatus status;
  final TriageResult triageResult;
  final String? linkedTransactionId;
  final DateTime receivedAt;

  const Message({
    required this.id,
    required this.userId,
    this.familyGroupId,
    required this.sender,
    required this.rawText,
    required this.status,
    required this.triageResult,
    this.linkedTransactionId,
    required this.receivedAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) =>
      _$MessageFromJson(json);

  Map<String, dynamic> toJson() => _$MessageToJson(this);

  /// Whether this message is pending user review.
  bool get isPending => status == MessageStatus.pending;

  /// Whether this message was classified as a financial transaction.
  bool get isTransaction => triageResult == TriageResult.transaction;

  /// Whether this message was auto-skipped by AI.
  bool get isSkipped =>
      status == MessageStatus.ignored &&
      triageResult != TriageResult.transaction;

  /// Human-friendly triage label.
  String get triageLabel {
    switch (triageResult) {
      case TriageResult.transaction:
        return 'Transaction';
      case TriageResult.otp:
        return 'OTP Code';
      case TriageResult.promo:
        return 'Promotional';
      case TriageResult.personal:
        return 'Personal';
      case TriageResult.unknown:
        return 'Unknown';
    }
  }
}
