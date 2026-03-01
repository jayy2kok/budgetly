import '../../models/transaction.dart';
import 'sample_data.dart';

/// Mock transaction service for Phase 2.
class MockTransactionService {
  Future<List<Transaction>> getTransactions(String familyGroupId) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return SampleData.transactions;
  }

  Future<Transaction> getTransaction(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return SampleData.transactions.firstWhere((t) => t.id == id);
  }

  Future<Transaction> createTransaction(Transaction transaction) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return transaction;
  }
}
