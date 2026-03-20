import 'package:dio/dio.dart';
import '../budget_service.dart';
import 'api_client.dart';

/// Real API implementation of [BudgetService].
class RemoteBudgetService implements BudgetService {
  final Dio _dio = ApiClient.instance.dio;

  @override
  Future<Map<String, dynamic>> getDashboardData(String familyGroupId) async {
    final response = await _dio.get('/families/$familyGroupId/dashboard');
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> getBudgetSummary(
      String familyGroupId, String? month) async {
    final params = <String, dynamic>{};
    if (month != null) params['month'] = month;

    final response = await _dio.get(
      '/families/$familyGroupId/budget/summary',
      queryParameters: params,
    );
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<void> updateBudgetLimit(String familyGroupId, double limit) async {
    await _dio.put(
      '/families/$familyGroupId/budget',
      data: {'monthlyBudgetLimit': limit},
    );
  }
}
