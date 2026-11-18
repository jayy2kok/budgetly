import 'package:json_annotation/json_annotation.dart';

part 'family_invite.g.dart';

/// A generated family invite — the response of `POST /families/{id}/invite`.
///
/// The invite link is generated server-side for the actual family group
/// (admin only). It can be shared as text or rendered as a QR code.
@JsonSerializable()
class FamilyInvite {
  final String? inviteCode;
  final String? inviteLink;
  final DateTime? expiresAt;

  const FamilyInvite({
    this.inviteCode,
    this.inviteLink,
    this.expiresAt,
  });

  factory FamilyInvite.fromJson(Map<String, dynamic> json) =>
      _$FamilyInviteFromJson(json);

  Map<String, dynamic> toJson() => _$FamilyInviteToJson(this);
}