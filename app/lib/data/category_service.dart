import '../models/category.dart';

/// Contract for category operations.
abstract class CategoryService {
  Future<List<Category>> getCategories(String familyGroupId);

  Future<Category> createCategory(
      String familyGroupId, Map<String, dynamic> data);

  Future<Category> updateCategory(
      String familyGroupId, String id, Map<String, dynamic> data);

  Future<void> deleteCategory(String familyGroupId, String id);
}
