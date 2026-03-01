// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'family_member.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FamilyMember _$FamilyMemberFromJson(Map<String, dynamic> json) => FamilyMember(
  id: json['id'] as String,
  userId: json['userId'] as String,
  familyGroupId: json['familyGroupId'] as String,
  user: json['user'] == null
      ? null
      : User.fromJson(json['user'] as Map<String, dynamic>),
  role: $enumDecode(_$MemberRoleEnumMap, json['role']),
  status: $enumDecode(_$MemberStatusEnumMap, json['status']),
  joinedAt: DateTime.parse(json['joinedAt'] as String),
);

Map<String, dynamic> _$FamilyMemberToJson(FamilyMember instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'familyGroupId': instance.familyGroupId,
      'user': instance.user,
      'role': _$MemberRoleEnumMap[instance.role]!,
      'status': _$MemberStatusEnumMap[instance.status]!,
      'joinedAt': instance.joinedAt.toIso8601String(),
    };

const _$MemberRoleEnumMap = {
  MemberRole.admin: 'ADMIN',
  MemberRole.member: 'MEMBER',
};

const _$MemberStatusEnumMap = {
  MemberStatus.active: 'ACTIVE',
  MemberStatus.invited: 'INVITED',
  MemberStatus.removed: 'REMOVED',
};
