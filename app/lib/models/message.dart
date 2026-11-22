import 'package:json_annotation/json_annotation.dart';

part 'message.g.dart';

/// Status of a message in the SMS processing pipeline.
///
/// Mirrors the statuses emitted by the backend
/// (`budgetly_api/.../document/MessageDocument.java`) including the
/// change-stream consumer's `IN_PROGRESS`, `PROCESSED` and `FAILED` states so
/// that any server `Message` payload round-trips without throwing.
enum MessageStatus {
  @JsonValue('PENDING')
  pending,
  @JsonValue('IN_PROGRESS')
  inProgress,
  @JsonValue('PROCESSED')
  processed,
  @JsonValue('CONFIRMED')
  confirmed,
  @JsonValue('REJECTED')
  rejected,
  @JsonValue('IGNORED')
  ignored,
  @JsonValue('FAILED')
  failed,
}

/// How the message was parsed / classified.
enum ParseSource {
  @JsonValue('REGEX_LOCAL')
  regexLocal,
  @JsonValue('LLM_SERVER')
  llmServer,
  @JsonValue('MANUAL')
  manual,
}

/// An SMS message in the processing pipeline.
@JsonSerializable()
class Message {
  final String id;
  final String userId;
  final String? familyGroupId;
  final String sender;
  final String rawText;
  final MessageStatus status;
  final ParseSource? parseSource;
  final String? matchedPatternId;

  /// Fields extracted by regex (e.g. {'amount': '8942', 'merchant': 'Grocery Mart'}).
  /// Null if unprocessed.
  final Map<String, String>? extractedData;

  final String? linkedTransactionId;

  /// Failure reason for [MessageStatus.failed] messages.
  final String? errorMessage;

  final DateTime receivedAt;

  const Message({
    required this.id,
    required this.userId,
    this.familyGroupId,
    required this.sender,
    required this.rawText,
    required this.status,
    this.parseSource,
    this.matchedPatternId,
    this.extractedData,
    this.linkedTransactionId,
    this.errorMessage,
    required this.receivedAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) =>
      _$MessageFromJson(json);

  Map<String, dynamic> toJson() => _$MessageToJson(this);

  /// Regex matched but one or more mandatory fields (amount, merchant, timestamp) are missing.
  bool get isIncomplete {
    if (parseSource != ParseSource.regexLocal) return false;
    if (extractedData == null) return true;
    final data = extractedData!;
    return !data.containsKey('amount') ||
        !data.containsKey('merchant') ||
        !data.containsKey('timestamp');
  }
}
