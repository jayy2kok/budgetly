// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Message _$MessageFromJson(Map<String, dynamic> json) => Message(
  id: json['id'] as String,
  userId: json['userId'] as String,
  familyGroupId: json['familyGroupId'] as String?,
  sender: json['sender'] as String,
  rawText: json['rawText'] as String,
  status: $enumDecode(_$MessageStatusEnumMap, json['status']),
  parseSource: $enumDecodeNullable(_$ParseSourceEnumMap, json['parseSource']),
  matchedPatternId: json['matchedPatternId'] as String?,
  nonFinancialCategory: $enumDecodeNullable(
    _$NonFinancialCategoryEnumMap,
    json['nonFinancialCategory'],
  ),
  extractedData: (json['extractedData'] as Map<String, dynamic>?)?.map(
    (k, e) => MapEntry(k, e as String),
  ),
  linkedTransactionId: json['linkedTransactionId'] as String?,
  receivedAt: DateTime.parse(json['receivedAt'] as String),
);

Map<String, dynamic> _$MessageToJson(Message instance) => <String, dynamic>{
  'id': instance.id,
  'userId': instance.userId,
  'familyGroupId': instance.familyGroupId,
  'sender': instance.sender,
  'rawText': instance.rawText,
  'status': _$MessageStatusEnumMap[instance.status]!,
  'parseSource': _$ParseSourceEnumMap[instance.parseSource],
  'matchedPatternId': instance.matchedPatternId,
  'nonFinancialCategory':
      _$NonFinancialCategoryEnumMap[instance.nonFinancialCategory],
  'extractedData': instance.extractedData,
  'linkedTransactionId': instance.linkedTransactionId,
  'receivedAt': instance.receivedAt.toIso8601String(),
};

const _$MessageStatusEnumMap = {
  MessageStatus.pending: 'PENDING',
  MessageStatus.confirmed: 'CONFIRMED',
  MessageStatus.rejected: 'REJECTED',
  MessageStatus.ignored: 'IGNORED',
};

const _$ParseSourceEnumMap = {
  ParseSource.regexLocal: 'REGEX_LOCAL',
  ParseSource.llmServer: 'LLM_SERVER',
  ParseSource.manual: 'MANUAL',
};

const _$NonFinancialCategoryEnumMap = {
  NonFinancialCategory.otp: 'OTP',
  NonFinancialCategory.promo: 'PROMO',
  NonFinancialCategory.personal: 'PERSONAL',
  NonFinancialCategory.delivery: 'DELIVERY',
  NonFinancialCategory.unknown: 'UNKNOWN',
};
