import '../../models/family_group.dart';
import '../../models/family_member.dart';
import 'sample_data.dart';

/// Mock family service for Phase 2.
class MockFamilyService {
  Future<FamilyGroup> getFamily(String familyId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return SampleData.familyGroup;
  }

  Future<List<FamilyMember>> getMembers(String familyId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return SampleData.members;
  }

  Future<FamilyGroup> updateFamily(
    String familyId,
    Map<String, dynamic> updates,
  ) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return SampleData.familyGroup;
  }
}
