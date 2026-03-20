import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/budget_service.dart';
import 'service_providers.dart';

/// Dashboard budget data.
class BudgetState {
  final double monthlyLimit;
  final double totalSpent;
  final double dailyAverage;
  final double projectedSpend;
  final double estimatedSavings;
  final bool isLoading;
  final String? error;

  const BudgetState({
    this.monthlyLimit = 0,
    this.totalSpent = 0,
    this.dailyAverage = 0,
    this.projectedSpend = 0,
    this.estimatedSavings = 0,
    this.isLoading = false,
    this.error,
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
    String? error,
  }) {
    return BudgetState(
      monthlyLimit: monthlyLimit ?? this.monthlyLimit,
      totalSpent: totalSpent ?? this.totalSpent,
      dailyAverage: dailyAverage ?? this.dailyAverage,
      projectedSpend: projectedSpend ?? this.projectedSpend,
      estimatedSavings: estimatedSavings ?? this.estimatedSavings,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class BudgetNotifier extends Notifier<BudgetState> {
  late final BudgetService _service;

  @override
  BudgetState build() {
    _service = ref.watch(budgetServiceProvider);
    return const BudgetState();
  }

  Future<void> loadDashboard(String familyGroupId) async {
    state = state.copyWith(isLoading: true);
    try {
      final data = await _service.getDashboardData(familyGroupId);
      state = BudgetState(
        monthlyLimit: (data['monthlyBudgetLimit'] as num?)?.toDouble() ?? 0,
        totalSpent: (data['totalSpent'] as num?)?.toDouble() ?? 0,
        dailyAverage: (data['dailyAverage'] as num?)?.toDouble() ?? 0,
        projectedSpend: (data['projectedSpend'] as num?)?.toDouble() ?? 0,
        estimatedSavings: (data['estimatedSavings'] as num?)?.toDouble() ?? 0,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> updateBudgetLimit(String familyGroupId, double newLimit) async {
    state = state.copyWith(isLoading: true);
    try {
      await _service.updateBudgetLimit(familyGroupId, newLimit);
      state = state.copyWith(monthlyLimit: newLimit, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final budgetProvider = NotifierProvider<BudgetNotifier, BudgetState>(
  BudgetNotifier.new,
);
