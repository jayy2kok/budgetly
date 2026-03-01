import 'package:json_annotation/json_annotation.dart';
import 'user.dart';

part 'family_member.g.dart';

/// Role a member plays within a family group.
enum MemberRole {
  @JsonValue('ADMIN')
  admin,
  @JsonValue('MEMBER')
  member,
}

/// Membership status.
enum MemberStatus {
  @JsonValue('ACTIVE')
  active,
  @JsonValue('INVITED')
  invited,
  @JsonValue('REMOVED')
  removed,
}

/// A member within a [FamilyGroup], linking a [User] with a role.
@JsonSerializable()
class FamilyMember {
  final String id;
  final String userId;
  final String familyGroupId;
  final User? user;
  final MemberRole role;
  final MemberStatus status;
  final DateTime joinedAt;

  const FamilyMember({
    required this.id,
    required this.userId,
    required this.familyGroupId,
    this.user,
    required this.role,
    required this.status,
    required this.joinedAt,
  });

  factory FamilyMember.fromJson(Map<String, dynamic> json) =>
      _$FamilyMemberFromJson(json);

  Map<String, dynamic> toJson() => _$FamilyMemberToJson(this);

  /// Display-friendly role label.
  String get roleLabel {
    switch (role) {
      case MemberRole.admin:
        return 'Administrator';
      case MemberRole.member:
        return 'Member';
    }
  }

  bool get isAdmin => role == MemberRole.admin;
  bool get isActive => status == MemberStatus.active;
}
