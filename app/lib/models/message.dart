import 'package:json_annotation/json_annotation.dart';

part 'message.g.dart';

/// Status of a message in the SMS processing pipeline.
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

/// How the message was parsed / classified.
enum ParseSource {
  @JsonValue('REGEX_LOCAL')
  regexLocal,
  @JsonValue('LLM_SERVER')
  llmServer,
  @JsonValue('MANUAL')
  manual,
}

/// Classification for non-financial messages.
enum NonFinancialCategory {
  @JsonValue('OTP')
  otp,
  @JsonValue('PROMO')
  promo,
  @JsonValue('PERSONAL')
  personal,
  @JsonValue('DELIVERY')
  delivery,
  @JsonValue('UNKNOWN')
  unknown,
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

  /// Category for non-financial messages (OTP, promo, etc.).
  final NonFinancialCategory? nonFinancialCategory;

  /// Fields extracted by regex (e.g. {'amount': '8942', 'merchant': 'Grocery Mart'}).
  /// Null if unprocessed.
  final Map<String, String>? extractedData;

  final String? linkedTransactionId;
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
    this.nonFinancialCategory,
    this.extractedData,
    this.linkedTransactionId,
    required this.receivedAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) =>
      _$MessageFromJson(json);

  Map<String, dynamic> toJson() => _$MessageToJson(this);

  /// Whether this message is pending user review.
  bool get isPending => status == MessageStatus.pending;

  /// Regex matched but one or more mandatory fields (amount, merchant, timestamp) are missing.
  bool get isIncomplete {
    if (parseSource != ParseSource.regexLocal) return false;
    if (extractedData == null) return true;
    final data = extractedData!;
    return !data.containsKey('amount') ||
        !data.containsKey('merchant') ||
        !data.containsKey('timestamp');
  }

  /// No regex pattern matched — needs server-side LLM analysis.
  bool get isUnprocessed =>
      status == MessageStatus.pending && parseSource == null;

  /// Message was classified as non-financial.
  bool get isNonFinancial => nonFinancialCategory != null;

  /// Whether this message was fully parsed (all mandatory fields present).
  bool get isFullyParsed {
    if (extractedData == null) return false;
    final data = extractedData!;
    return data.containsKey('amount') &&
        data.containsKey('merchant') &&
        data.containsKey('timestamp');
  }

  /// Human-friendly label for the non-financial category.
  String get categoryLabel {
    switch (nonFinancialCategory) {
      case NonFinancialCategory.otp:
        return 'OTP Code';
      case NonFinancialCategory.promo:
        return 'Promotional';
      case NonFinancialCategory.personal:
        return 'Personal';
      case NonFinancialCategory.delivery:
        return 'Delivery';
      case NonFinancialCategory.unknown:
        return 'Unknown';
      case null:
        return '';
    }
  }
}
