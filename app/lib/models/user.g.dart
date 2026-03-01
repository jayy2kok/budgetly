// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

User _$UserFromJson(Map<String, dynamic> json) => User(
  id: json['id'] as String,
  googleId: json['googleId'] as String,
  displayName: json['displayName'] as String,
  email: json['email'] as String,
  avatarUrl: json['avatarUrl'] as String?,
  createdAt: DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
  'id': instance.id,
  'googleId': instance.googleId,
  'displayName': instance.displayName,
  'email': instance.email,
  'avatarUrl': instance.avatarUrl,
  'createdAt': instance.createdAt.toIso8601String(),
};
