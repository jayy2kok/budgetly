import '../models/family_member.dart';

/// Resolves the payer display info (name + avatar initial) for a transaction.
///
/// Looks up [createdByUserId] in the [members] list and returns their
/// [User.displayName] and first letter. Falls back to "You"/"Y" when the
/// creator is the current user, and to "Unknown"/"?" when no match is found.
///
/// Returns a record `(name, initial)`.
({String name, String initial}) resolvePayer({
  required String createdByUserId,
  required String? currentUserId,
  required List<FamilyMember> members,
}) {
  if (createdByUserId == currentUserId) {
    return (name: 'You', initial: 'Y');
  }

  for (final member in members) {
    if (member.userId == createdByUserId) {
      final name = member.user?.displayName;
      if (name != null && name.isNotEmpty) {
        return (name: name, initial: name[0].toUpperCase());
      }
    }
  }

  return (name: 'Unknown', initial: '?');
}

/// Convenience wrapper that returns just the payer display name.
String resolvePayerName({
  required String createdByUserId,
  required String? currentUserId,
  required List<FamilyMember> members,
}) =>
    resolvePayer(
      createdByUserId: createdByUserId,
      currentUserId: currentUserId,
      members: members,
    ).name;

/// Convenience wrapper that returns just the payer avatar initial.
String payerInitial({
  required String createdByUserId,
  required String? currentUserId,
  required List<FamilyMember> members,
}) =>
    resolvePayer(
      createdByUserId: createdByUserId,
      currentUserId: currentUserId,
      members: members,
    ).initial;
