import 'package:dio/dio.dart';
import '../../models/message.dart';
import '../message_service.dart';
import 'api_client.dart';

/// Real API implementation of [MessageService].
class RemoteMessageService implements MessageService {
  final Dio _dio = ApiClient.instance.dio;

  @override
  Future<List<Message>> getPendingMessages() async {
    final response = await _dio.get('/messages/pending');
    final list = response.data as List<dynamic>;
    return list
        .map((json) => Message.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<Message>> getIgnoredMessages() async {
    final response = await _dio.get('/messages/ignored');
    final list = response.data as List<dynamic>;
    return list
        .map((json) => Message.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Map<String, dynamic>> processMessage(
      Map<String, dynamic> data) async {
    final response = await _dio.post('/messages/process', data: data);
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<int> bulkInsertMessages({
    required String familyGroupId,
    required List<Map<String, String>> messages,
  }) async {
    if (messages.isEmpty) return 0;
    // The change-stream listener processes these asynchronously (202 ACCEPTED).
    final response = await _dio.post(
      '/messages/bulk',
      data: {
        'familyGroupId': familyGroupId,
        'messages': [
          for (final m in messages) {'sender': m['sender'], 'rawText': m['rawText']},
        ],
      },
    );
    final body = response.data;
    if (body is Map<String, dynamic>) {
      return (body['acceptedCount'] as num?)?.toInt() ?? messages.length;
    }
    return messages.length;
  }

  @override
  Future<Message> confirmMessage(String messageId) async {
    final response = await _dio.post('/messages/$messageId/confirm');
    return Message.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<Message> rejectMessage(String messageId) async {
    final response = await _dio.post('/messages/$messageId/reject');
    return Message.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<Message> restoreMessage(String messageId) async {
    final response = await _dio.post('/messages/$messageId/restore');
    return Message.fromJson(response.data as Map<String, dynamic>);
  }
}
