import '../models/family_group.dart';
import '../models/family_invite.dart';
import '../models/family_member.dart';

/// Contract for family group operations.
abstract class FamilyService {
  Future<FamilyGroup> createFamily(Map<String, dynamic> data);
  Future<FamilyGroup> getFamily(String familyId);
  Future<FamilyGroup> updateFamily(String familyId, Map<String, dynamic> updates);
  Future<void> deleteFamily(String familyId);
  Future<List<FamilyMember>> getMembers(String familyId);

  /// Generate a real invite (link/QR) for [familyId]. Admin only on the API.
  Future<FamilyInvite> inviteFamily(String familyId, Map<String, dynamic> request);

  /// Join a family group using an invite code.
  Future<FamilyMember> joinFamily(String inviteCode);
}
