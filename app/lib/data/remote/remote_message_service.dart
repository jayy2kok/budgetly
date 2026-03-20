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
