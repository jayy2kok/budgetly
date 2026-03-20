/// Contract for dashboard & budget operations.
abstract class BudgetService {
  /// Get aggregated dashboard data for a family.
  Future<Map<String, dynamic>> getDashboardData(String familyGroupId);

  /// Get monthly budget summary with per-category breakdowns.
  Future<Map<String, dynamic>> getBudgetSummary(
      String familyGroupId, String? month);

  /// Update the overall monthly budget limit.
  Future<void> updateBudgetLimit(String familyGroupId, double limit);
}
