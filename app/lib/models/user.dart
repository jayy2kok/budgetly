import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

/// A Budgetly user, authenticated via Google OAuth 2.0.
@JsonSerializable()
class User {
  final String id;
  final String googleId;
  final String displayName;
  final String email;
  final String? avatarUrl;
  final DateTime createdAt;

  const User({
    required this.id,
    required this.googleId,
    required this.displayName,
    required this.email,
    this.avatarUrl,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

  Map<String, dynamic> toJson() => _$UserToJson(this);

  /// Returns the user's initials for avatar fallback.
  String get initials {
    final parts = displayName.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
  }
}
