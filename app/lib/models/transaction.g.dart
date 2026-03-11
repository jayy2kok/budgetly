// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Transaction _$TransactionFromJson(Map<String, dynamic> json) => Transaction(
  id: json['id'] as String,
  familyGroupId: json['familyGroupId'] as String,
  createdByUserId: json['createdByUserId'] as String,
  categoryId: json['categoryId'] as String,
  amount: (json['amount'] as num).toDouble(),
  currency: json['currency'] as String? ?? 'INR',
  merchant: json['merchant'] as String,
  description: json['description'] as String?,
  type: $enumDecode(_$TransactionTypeEnumMap, json['type']),
  sourceType:
      $enumDecodeNullable(_$SourceTypeEnumMap, json['sourceType']) ??
      SourceType.manual,
  sourceRawText: json['sourceRawText'] as String?,
  matchedPatternId: json['matchedPatternId'] as String?,
  notes: json['notes'] as String?,
  transactionDate: DateTime.parse(json['transactionDate'] as String),
  createdAt: DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$TransactionToJson(Transaction instance) =>
    <String, dynamic>{
      'id': instance.id,
      'familyGroupId': instance.familyGroupId,
      'createdByUserId': instance.createdByUserId,
      'categoryId': instance.categoryId,
      'amount': instance.amount,
      'currency': instance.currency,
      'merchant': instance.merchant,
      'description': instance.description,
      'type': _$TransactionTypeEnumMap[instance.type]!,
      'sourceType': _$SourceTypeEnumMap[instance.sourceType]!,
      'sourceRawText': instance.sourceRawText,
      'matchedPatternId': instance.matchedPatternId,
      'notes': instance.notes,
      'transactionDate': instance.transactionDate.toIso8601String(),
      'createdAt': instance.createdAt.toIso8601String(),
    };

const _$TransactionTypeEnumMap = {
  TransactionType.expense: 'EXPENSE',
  TransactionType.income: 'INCOME',
  TransactionType.subscription: 'SUBSCRIPTION',
};

const _$SourceTypeEnumMap = {
  SourceType.manual: 'MANUAL',
  SourceType.regexLocal: 'REGEX_LOCAL',
  SourceType.llmServer: 'LLM_SERVER',
};
