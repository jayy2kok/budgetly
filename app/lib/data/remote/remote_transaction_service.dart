import 'package:dio/dio.dart';
import '../../models/transaction.dart';
import '../transaction_service.dart';
import 'api_client.dart';

/// Real API implementation of [TransactionService].
class RemoteTransactionService implements TransactionService {
  final Dio _dio = ApiClient.instance.dio;

  @override
  Future<List<Transaction>> getTransactions(
    String familyGroupId, {
    int page = 0,
    int size = 20,
    TransactionType? type,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'size': size,
    };
    if (type != null) {
      params['type'] = type.name.toUpperCase();
    }

    final response = await _dio.get(
      '/families/$familyGroupId/transactions',
      queryParameters: params,
    );

    final data = response.data as Map<String, dynamic>;
    final content = data['content'] as List<dynamic>;
    return content
        .map((json) => Transaction.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Transaction> getTransaction(
      String familyGroupId, String id) async {
    final response =
        await _dio.get('/families/$familyGroupId/transactions/$id');
    return Transaction.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<Transaction> createTransaction(
      String familyGroupId, Map<String, dynamic> data) async {
    final response = await _dio.post(
      '/families/$familyGroupId/transactions',
      data: data,
    );
    return Transaction.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<Transaction> updateTransaction(
      String familyGroupId, String id, Map<String, dynamic> data) async {
    final response = await _dio.put(
      '/families/$familyGroupId/transactions/$id',
      data: data,
    );
    return Transaction.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<void> deleteTransaction(String familyGroupId, String id) async {
    await _dio.delete('/families/$familyGroupId/transactions/$id');
  }
}
