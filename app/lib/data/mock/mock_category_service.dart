import '../../models/category.dart';
import 'sample_data.dart';

/// Mock category service for Phase 2.
class MockCategoryService {
  Future<List<Category>> getCategories(String familyGroupId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return SampleData.categories;
  }
}
