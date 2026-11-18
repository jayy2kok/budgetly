import '../../models/family_group.dart';
import '../../models/family_invite.dart';
import '../../models/family_member.dart';
import '../family_service.dart';
import 'sample_data.dart';

/// Mock family service for Phase 2 / offline development.
class MockFamilyService implements FamilyService {
  @override
  Future<FamilyGroup> createFamily(Map<String, dynamic> data) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return SampleData.familyGroup;
  }

  @override
  Future<FamilyGroup> getFamily(String familyId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return SampleData.familyGroup;
  }

  @override
  Future<FamilyGroup> updateFamily(
    String familyId,
    Map<String, dynamic> updates,
  ) async {
    await Future.delayed(const Duration(milliseconds: 300));
    // Apply the patch to the sample family so mock-mode edits are visible.
    final json = SampleData.familyGroup.toJson()..addAll(updates);
    return FamilyGroup.fromJson(json);
  }

  @override
  Future<void> deleteFamily(String familyId) async {
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Future<List<FamilyMember>> getMembers(String familyId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return SampleData.members;
  }

  @override
  Future<FamilyInvite> inviteFamily(
    String familyId,
    Map<String, dynamic> request,
  ) async {
    await Future.delayed(const Duration(milliseconds: 300));
    const code = 'MOCK-FAM-7DAY';
    return FamilyInvite(
      inviteCode: code,
      inviteLink: 'https://budgetly.app/join?code=$code',
      expiresAt: DateTime.now().add(const Duration(days: 7)),
    );
  }

  @override
  Future<FamilyMember> joinFamily(String inviteCode) async {
    await Future.delayed(const Duration(milliseconds: 300));
    // In mock mode, just return a dummy member to confirm the flow
    return FamilyMember(
      id: 'mock_member',
      userId: 'mock_user',
      familyGroupId: 'mock_family',
      role: MemberRole.member,
      status: MemberStatus.active,
      joinedAt: DateTime.now(),
      user: SampleData.members.first.user,
    );
  }
}
