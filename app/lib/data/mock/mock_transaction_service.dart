import '../../models/transaction.dart';
import '../transaction_service.dart';
import 'sample_data.dart';

/// Mock transaction service for Phase 2 / offline development.
class MockTransactionService implements TransactionService {
  @override
  Future<List<Transaction>> getTransactions(
    String familyGroupId, {
    int page = 0,
    int size = 20,
    TransactionType? type,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    var result = SampleData.transactions;
    if (type != null) {
      result = result.where((t) => t.type == type).toList();
    }
    return result;
  }

  @override
  Future<Transaction> getTransaction(String familyGroupId, String id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return SampleData.transactions.firstWhere((t) => t.id == id);
  }

  @override
  Future<Transaction> createTransaction(
      String familyGroupId, Map<String, dynamic> data) async {
    await Future.delayed(const Duration(milliseconds: 300));
    // Return first sample transaction as a stand-in
    return SampleData.transactions.first;
  }

  @override
  Future<Transaction> updateTransaction(
      String familyGroupId, String id, Map<String, dynamic> data) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return SampleData.transactions.firstWhere((t) => t.id == id);
  }

  @override
  Future<void> deleteTransaction(String familyGroupId, String id) async {
    await Future.delayed(const Duration(milliseconds: 300));
  }
}
