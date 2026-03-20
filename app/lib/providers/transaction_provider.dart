import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/transaction_service.dart';
import '../models/transaction.dart';
import 'auth_provider.dart';
import 'family_provider.dart';
import 'service_providers.dart';

/// State for the transaction list.
class TransactionState {
  final List<Transaction> transactions;
  final bool isLoading;
  final String? error;
  final TransactionType? filterType;
  final String searchQuery;

  const TransactionState({
    this.transactions = const [],
    this.isLoading = false,
    this.error,
    this.filterType,
    this.searchQuery = '',
  });

  TransactionState copyWith({
    List<Transaction>? transactions,
    bool? isLoading,
    String? error,
    TransactionType? filterType,
    bool clearFilter = false,
    String? searchQuery,
  }) {
    return TransactionState(
      transactions: transactions ?? this.transactions,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      filterType: clearFilter ? null : (filterType ?? this.filterType),
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  /// Filtered transactions based on current filter and search query.
  List<Transaction> get filteredTransactions {
    var result = transactions;
    if (filterType != null) {
      result = result.where((t) => t.type == filterType).toList();
    }
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      result = result.where((t) => t.merchant.toLowerCase().contains(q)).toList();
    }
    return result;
  }
}

class TransactionNotifier extends Notifier<TransactionState> {
  late final TransactionService _service;

  @override
  TransactionState build() {
    _service = ref.watch(transactionServiceProvider);
    return const TransactionState();
  }

  String _familyId() {
    final family = ref.read(familyProvider).currentFamily;
    return family?.id ?? 'family_001';
  }

  Future<void> loadTransactions({TransactionType? type}) async {
    state = state.copyWith(isLoading: true);
    try {
      final txns = await _service.getTransactions(
        _familyId(),
        type: type,
      );
      state = TransactionState(transactions: txns, filterType: type);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setFilter(TransactionType? type) {
    if (type == null) {
      state = state.copyWith(clearFilter: true);
    } else {
      state = state.copyWith(filterType: type);
    }
    // Reload with server-side filter in real-API mode
    if (useRealApi) {
      loadTransactions(type: state.filterType);
    }
  }

  void setSearch(String query) {
    state = state.copyWith(searchQuery: query);
  }

  Future<void> addTransaction(Map<String, dynamic> data) async {
    try {
      final userId = ref.read(authProvider).user?.id ?? '';
      final payload = {
        ...data,
        'createdByUserId': userId,
        'transactionDate':
            data['transactionDate'] ?? DateTime.now().toIso8601String(),
      };
      final created = await _service.createTransaction(_familyId(), payload);
      state = state.copyWith(transactions: [created, ...state.transactions]);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> deleteTransaction(String id) async {
    try {
      await _service.deleteTransaction(_familyId(), id);
      state = state.copyWith(
        transactions: state.transactions.where((t) => t.id != id).toList(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

final transactionProvider =
    NotifierProvider<TransactionNotifier, TransactionState>(
  TransactionNotifier.new,
);
