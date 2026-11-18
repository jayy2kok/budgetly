// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'family_invite.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FamilyInvite _$FamilyInviteFromJson(Map<String, dynamic> json) => FamilyInvite(
  inviteCode: json['inviteCode'] as String?,
  inviteLink: json['inviteLink'] as String?,
  expiresAt: json['expiresAt'] == null
      ? null
      : DateTime.parse(json['expiresAt'] as String),
);

Map<String, dynamic> _$FamilyInviteToJson(FamilyInvite instance) =>
    <String, dynamic>{
      'inviteCode': instance.inviteCode,
      'inviteLink': instance.inviteLink,
      'expiresAt': instance.expiresAt?.toIso8601String(),
    };
