import 'package:dio/dio.dart';
import '../../models/category.dart';
import '../category_service.dart';
import 'api_client.dart';

/// Real API implementation of [CategoryService].
class RemoteCategoryService implements CategoryService {
  final Dio _dio = ApiClient.instance.dio;

  @override
  Future<List<Category>> getCategories(String familyGroupId) async {
    final response = await _dio.get('/families/$familyGroupId/categories');
    final list = response.data as List<dynamic>;
    return list
        .map((json) => Category.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Category> createCategory(
      String familyGroupId, Map<String, dynamic> data) async {
    final response = await _dio.post(
      '/families/$familyGroupId/categories',
      data: data,
    );
    return Category.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<Category> updateCategory(
      String familyGroupId, String id, Map<String, dynamic> data) async {
    final response = await _dio.put(
      '/families/$familyGroupId/categories/$id',
      data: data,
    );
    return Category.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<void> deleteCategory(String familyGroupId, String id) async {
    await _dio.delete('/families/$familyGroupId/categories/$id');
  }
}
