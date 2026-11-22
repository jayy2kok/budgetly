// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sms_pattern.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ExtractionMap _$ExtractionMapFromJson(Map<String, dynamic> json) =>
    ExtractionMap(
      amount: json['amount'] as String,
      merchant: json['merchant'] as String?,
      timestamp: json['timestamp'] as String?,
      accountLast4: json['accountLast4'] as String?,
      type: json['type'] as String?,
      notes: json['notes'] as String?,
    );

Map<String, dynamic> _$ExtractionMapToJson(ExtractionMap instance) =>
    <String, dynamic>{
      'amount': instance.amount,
      'merchant': instance.merchant,
      'timestamp': instance.timestamp,
      'accountLast4': instance.accountLast4,
      'type': instance.type,
      'notes': instance.notes,
    };

SmsPattern _$SmsPatternFromJson(Map<String, dynamic> json) => SmsPattern(
  id: json['id'] as String,
  sender: json['sender'] as String,
  template: json['template'] as String,
  extractionMap: ExtractionMap.fromJson(
    json['extractionMap'] as Map<String, dynamic>,
  ),
  fixedValues:
      (json['fixedValues'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ) ??
      const {},
  sampleMessage: json['sampleMessage'] as String,
  categoryName: json['categoryName'] as String?,
  usageCount: (json['usageCount'] as num?)?.toInt() ?? 0,
  scope:
      $enumDecodeNullable(_$PatternScopeEnumMap, json['scope']) ??
      PatternScope.global,
  ownerFamilyGroupId: json['ownerFamilyGroupId'] as String?,
  createdByUserId: json['createdByUserId'] as String?,
  source:
      $enumDecodeNullable(_$PatternSourceEnumMap, json['source']) ??
      PatternSource.llm,
  active: json['active'] as bool? ?? true,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: json['updatedAt'] == null
      ? null
      : DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$SmsPatternToJson(SmsPattern instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sender': instance.sender,
      'template': instance.template,
      'extractionMap': instance.extractionMap,
      'fixedValues': instance.fixedValues,
      'sampleMessage': instance.sampleMessage,
      'categoryName': instance.categoryName,
      'usageCount': instance.usageCount,
      'scope': _$PatternScopeEnumMap[instance.scope]!,
      'ownerFamilyGroupId': instance.ownerFamilyGroupId,
      'createdByUserId': instance.createdByUserId,
      'source': _$PatternSourceEnumMap[instance.source]!,
      'active': instance.active,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };

const _$PatternScopeEnumMap = {
  PatternScope.global: 'GLOBAL',
  PatternScope.family: 'FAMILY',
};

const _$PatternSourceEnumMap = {
  PatternSource.llm: 'LLM',
  PatternSource.user: 'USER',
};
