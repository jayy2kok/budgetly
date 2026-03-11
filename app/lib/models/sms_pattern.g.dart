// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sms_pattern.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ExtractionMap _$ExtractionMapFromJson(Map<String, dynamic> json) =>
    ExtractionMap(
      amount: json['amount'] as String,
      merchant: json['merchant'] as String,
      timestamp: json['timestamp'] as String,
      accountLast4: json['accountLast4'] as String?,
      type: json['type'] as String?,
    );

Map<String, dynamic> _$ExtractionMapToJson(ExtractionMap instance) =>
    <String, dynamic>{
      'amount': instance.amount,
      'merchant': instance.merchant,
      'timestamp': instance.timestamp,
      'accountLast4': instance.accountLast4,
      'type': instance.type,
    };

SmsPattern _$SmsPatternFromJson(Map<String, dynamic> json) => SmsPattern(
  id: json['id'] as String,
  sender: json['sender'] as String,
  regex: json['regex'] as String,
  extractionMap: ExtractionMap.fromJson(
    json['extractionMap'] as Map<String, dynamic>,
  ),
  sampleMessage: json['sampleMessage'] as String,
  usageCount: (json['usageCount'] as num?)?.toInt() ?? 0,
  createdAt: DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$SmsPatternToJson(SmsPattern instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sender': instance.sender,
      'regex': instance.regex,
      'extractionMap': instance.extractionMap,
      'sampleMessage': instance.sampleMessage,
      'usageCount': instance.usageCount,
      'createdAt': instance.createdAt.toIso8601String(),
    };
