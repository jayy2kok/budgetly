import '../models/transaction.dart';

/// Contract for transaction operations.
abstract class TransactionService {
  Future<List<Transaction>> getTransactions(
    String familyGroupId, {
    int page = 0,
    int size = 20,
    TransactionType? type,
  });

  Future<Transaction> getTransaction(String familyGroupId, String id);

  Future<Transaction> createTransaction(
      String familyGroupId, Map<String, dynamic> data);

  Future<Transaction> updateTransaction(
      String familyGroupId, String id, Map<String, dynamic> data);

  Future<void> deleteTransaction(String familyGroupId, String id);
}
