import '../models/family_member.dart';

/// Displays the full name of the user who created a transaction.
///
/// If [createdByUserId] matches a family member's userId, returns their
/// [User.displayName]. Falls back to "You" when the creator is the
/// current user, then to "Unknown" when the member list doesn't have a match.
String resolvePayerName({
  required String createdByUserId,
  required String? currentUserId,
  required List<FamilyMember> members,
}) {
  if (createdByUserId == currentUserId) {
    return 'You';
  }

  for (final member in members) {
    if (member.userId == createdByUserId) {
      final name = member.user?.displayName;
      if (name != null && name.isNotEmpty) {
        return name;
      }
      // member has a displayable name available — fall through to caller
    }
  }

  // No match or no displayName available.
  // If members list is empty (e.g. family not yet loaded) show "Unknown".
  if (members.isEmpty) return 'Unknown';

  // Try to extract something from userId (e.g. "user_001" → "U").
  // This prevents a blank tile while real data is loading.
  return createdByUserId.isNotEmpty
      ? createdByUserId[0].toUpperCase()
      : 'Unknown';
}

/// Returns the first display initial for an avatar badge on a transaction tile.
String payerInitial({
  required String createdByUserId,
  required String? currentUserId,
  required List<FamilyMember> members,
}) {
  if (createdByUserId == currentUserId) {
    return 'Y'; // "You"
  }

  for (final member in members) {
    if (member.userId == createdByUserId) {
      final name = member.user?.displayName;
      if (name != null && name.isNotEmpty) {
        return name[0].toUpperCase();
      }
    }
  }

  return createdByUserId.isNotEmpty
      ? createdByUserId[0].toUpperCase()
      : '?';
}
