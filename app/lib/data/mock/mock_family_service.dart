import '../../models/family_group.dart';
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
      String familyId, Map<String, dynamic> updates) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return SampleData.familyGroup;
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
}
