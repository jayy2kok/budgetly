import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mock/mock_budget_service.dart';

/// Dashboard budget data.
class BudgetState {
  final double monthlyLimit;
  final double totalSpent;
  final double dailyAverage;
  final double projectedSpend;
  final double estimatedSavings;
  final bool isLoading;

  const BudgetState({
    this.monthlyLimit = 0,
    this.totalSpent = 0,
    this.dailyAverage = 0,
    this.projectedSpend = 0,
    this.estimatedSavings = 0,
    this.isLoading = false,
  });

  double get leftToSpend => monthlyLimit - totalSpent;
  double get spentPercent =>
      monthlyLimit > 0 ? (totalSpent / monthlyLimit).clamp(0.0, 1.0) : 0.0;
  bool get isOverBudget => totalSpent > monthlyLimit;

  BudgetState copyWith({
    double? monthlyLimit,
    double? totalSpent,
    double? dailyAverage,
    double? projectedSpend,
    double? estimatedSavings,
    bool? isLoading,
  }) {
    return BudgetState(
      monthlyLimit: monthlyLimit ?? this.monthlyLimit,
      totalSpent: totalSpent ?? this.totalSpent,
      dailyAverage: dailyAverage ?? this.dailyAverage,
      projectedSpend: projectedSpend ?? this.projectedSpend,
      estimatedSavings: estimatedSavings ?? this.estimatedSavings,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class BudgetNotifier extends Notifier<BudgetState> {
  late final MockBudgetService _service;

  @override
  BudgetState build() {
    _service = MockBudgetService();
    return const BudgetState();
  }

  Future<void> loadDashboard(String familyGroupId) async {
    state = state.copyWith(isLoading: true);
    try {
      final data = await _service.getDashboardData(familyGroupId);
      state = BudgetState(
        monthlyLimit: data['monthlyBudgetLimit'] ?? 0,
        totalSpent: data['totalSpent'] ?? 0,
        dailyAverage: data['dailyAverage'] ?? 0,
        projectedSpend: data['projectedSpend'] ?? 0,
        estimatedSavings: data['estimatedSavings'] ?? 0,
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> updateBudgetLimit(double newLimit) async {
    state = state.copyWith(isLoading: true);
    await _service.updateBudgetLimit('family_001', newLimit);
    state = state.copyWith(monthlyLimit: newLimit, isLoading: false);
  }
}

final budgetProvider = NotifierProvider<BudgetNotifier, BudgetState>(
  BudgetNotifier.new,
);
