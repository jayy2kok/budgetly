import 'sample_data.dart';

/// Mock budget/dashboard service for Phase 2.
class MockBudgetService {
  Future<Map<String, double>> getDashboardData(String familyGroupId) async {
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

  Future<void> updateBudgetLimit(String familyGroupId, double limit) async {
    await Future.delayed(const Duration(milliseconds: 300));
    SampleData.monthlyBudgetLimit = limit;
  }
}
