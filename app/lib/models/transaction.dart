import 'package:json_annotation/json_annotation.dart';

part 'transaction.g.dart';

/// Type of financial transaction.
enum TransactionType {
  @JsonValue('EXPENSE')
  expense,
  @JsonValue('INCOME')
  income,
  @JsonValue('SUBSCRIPTION')
  subscription,
}

/// How the transaction was created.
enum SourceType {
  @JsonValue('MANUAL')
  manual,
  @JsonValue('REGEX_LOCAL')
  regexLocal,
  @JsonValue('LLM_SERVER')
  llmServer,
}

/// A financial transaction within a family group.
@JsonSerializable()
class Transaction {
  final String id;
  final String familyGroupId;
  final String createdByUserId;
  final String categoryId;
  final double amount;
  final String currency;
  final String merchant;
  final String? description;
  final TransactionType type;
  final SourceType sourceType;
  final String? sourceRawText;
  final String? matchedPatternId;
  final String? notes;
  final DateTime transactionDate;
  final DateTime createdAt;

  const Transaction({
    required this.id,
    required this.familyGroupId,
    required this.createdByUserId,
    required this.categoryId,
    required this.amount,
    this.currency = 'INR',
    required this.merchant,
    this.description,
    required this.type,
    this.sourceType = SourceType.manual,
    this.sourceRawText,
    this.matchedPatternId,
    this.notes,
    required this.transactionDate,
    required this.createdAt,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) =>
      _$TransactionFromJson(json);

  Map<String, dynamic> toJson() => _$TransactionToJson(this);

  /// Whether this is an income transaction.
  bool get isIncome => type == TransactionType.income;

  /// Whether this is an expense.
  bool get isExpense => type == TransactionType.expense;

  /// Whether this was auto-parsed from an SMS.
  bool get isSmsParsed =>
      sourceType == SourceType.regexLocal ||
      sourceType == SourceType.llmServer;
}
