import '../../models/category.dart';
import '../category_service.dart';
import 'sample_data.dart';

/// Mock category service for Phase 2 / offline development.
class MockCategoryService implements CategoryService {
  @override
  Future<List<Category>> getCategories(String familyGroupId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return SampleData.categories;
  }

  @override
  Future<Category> createCategory(
      String familyGroupId, Map<String, dynamic> data) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return SampleData.categories.first;
  }

  @override
  Future<Category> updateCategory(
      String familyGroupId, String id, Map<String, dynamic> data) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return SampleData.categories.firstWhere((c) => c.id == id);
  }

  @override
  Future<void> deleteCategory(String familyGroupId, String id) async {
    await Future.delayed(const Duration(milliseconds: 300));
  }
}
