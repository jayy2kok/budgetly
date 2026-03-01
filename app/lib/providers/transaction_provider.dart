import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transaction.dart';
import '../data/mock/mock_transaction_service.dart';

/// State for the transaction list.
class TransactionState {
  final List<Transaction> transactions;
  final bool isLoading;
  final TransactionType? filterType;
  final String searchQuery;

  const TransactionState({
    this.transactions = const [],
    this.isLoading = false,
    this.filterType,
    this.searchQuery = '',
  });

  TransactionState copyWith({
    List<Transaction>? transactions,
    bool? isLoading,
    TransactionType? filterType,
    bool clearFilter = false,
    String? searchQuery,
  }) {
    return TransactionState(
      transactions: transactions ?? this.transactions,
      isLoading: isLoading ?? this.isLoading,
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
      result = result
          .where((t) => t.merchant.toLowerCase().contains(q))
          .toList();
    }
    return result;
  }
}

class TransactionNotifier extends Notifier<TransactionState> {
  late final MockTransactionService _service;

  @override
  TransactionState build() {
    _service = MockTransactionService();
    return const TransactionState();
  }

  Future<void> loadTransactions(String familyGroupId) async {
    state = state.copyWith(isLoading: true);
    try {
      final txns = await _service.getTransactions(familyGroupId);
      state = TransactionState(transactions: txns, isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  void setFilter(TransactionType? type) {
    if (type == null) {
      state = state.copyWith(clearFilter: true);
    } else {
      state = state.copyWith(filterType: type);
    }
  }

  void setSearch(String query) {
    state = state.copyWith(searchQuery: query);
  }

  Future<void> addTransaction(Transaction transaction) async {
    try {
      final created = await _service.createTransaction(transaction);
      state = state.copyWith(transactions: [created, ...state.transactions]);
    } catch (_) {
      // Phase 2: Add error handling
    }
  }
}

final transactionProvider =
    NotifierProvider<TransactionNotifier, TransactionState>(
      TransactionNotifier.new,
    );
