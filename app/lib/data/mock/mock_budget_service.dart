import '../budget_service.dart';
import 'sample_data.dart';

/// Mock budget/dashboard service for Phase 2 / offline development.
class MockBudgetService implements BudgetService {
  @override
  Future<Map<String, dynamic>> getDashboardData(String familyGroupId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return {
      'monthlyBudgetLimit': SampleData.monthlyBudgetLimit,
      'totalSpent': SampleData.totalSpent,
      'leftToSpend': SampleData.leftToSpend,
      'dailyAverage': SampleData.dailyAverage,
      'projectedSpend': SampleData.projectedSpend,
      'estimatedSavings': SampleData.estimatedSavings,
    };
  }

  @override
  Future<Map<String, dynamic>> getBudgetSummary(
      String familyGroupId, String? month) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return {
      'month': month ?? '2026-03',
      'overallLimit': SampleData.monthlyBudgetLimit,
      'overallSpent': SampleData.totalSpent,
      'categoryBreakdowns': [],
    };
  }

  @override
  Future<void> updateBudgetLimit(String familyGroupId, double limit) async {
    await Future.delayed(const Duration(milliseconds: 300));
    SampleData.monthlyBudgetLimit = limit;
  }
}
