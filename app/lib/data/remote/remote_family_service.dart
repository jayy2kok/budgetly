import 'package:dio/dio.dart';
import '../../models/family_group.dart';
import '../../models/family_member.dart';
import '../family_service.dart';
import 'api_client.dart';

/// Real API implementation of [FamilyService].
class RemoteFamilyService implements FamilyService {
  final Dio _dio = ApiClient.instance.dio;

  /// Fetches (or auto-creates) the authenticated user's family group.
  Future<FamilyGroup> getMyFamily() async {
    final response = await _dio.get('/families/my');
    return FamilyGroup.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<FamilyGroup> createFamily(Map<String, dynamic> data) async {
    final response = await _dio.post('/families', data: data);
    return FamilyGroup.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<FamilyGroup> getFamily(String familyId) async {
    final response = await _dio.get('/families/$familyId');
    return FamilyGroup.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<FamilyGroup> updateFamily(
      String familyId, Map<String, dynamic> updates) async {
    final response = await _dio.put('/families/$familyId', data: updates);
    return FamilyGroup.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<void> deleteFamily(String familyId) async {
    await _dio.delete('/families/$familyId');
  }

  @override
  Future<List<FamilyMember>> getMembers(String familyId) async {
    final response = await _dio.get('/families/$familyId/members');
    final list = response.data as List<dynamic>;
    return list
        .map((json) => FamilyMember.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
