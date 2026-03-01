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
  triageResult: $enumDecode(_$TriageResultEnumMap, json['triageResult']),
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
  'triageResult': _$TriageResultEnumMap[instance.triageResult]!,
  'linkedTransactionId': instance.linkedTransactionId,
  'receivedAt': instance.receivedAt.toIso8601String(),
};

const _$MessageStatusEnumMap = {
  MessageStatus.pending: 'PENDING',
  MessageStatus.confirmed: 'CONFIRMED',
  MessageStatus.rejected: 'REJECTED',
  MessageStatus.ignored: 'IGNORED',
};

const _$TriageResultEnumMap = {
  TriageResult.transaction: 'TRANSACTION',
  TriageResult.otp: 'OTP',
  TriageResult.promo: 'PROMO',
  TriageResult.personal: 'PERSONAL',
  TriageResult.unknown: 'UNKNOWN',
};
