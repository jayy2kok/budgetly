import 'package:flutter_test/flutter_test.dart';

import 'package:budgetly/models/message.dart';

Map<String, dynamic> baseJson({required String status}) => {
      'id': 'msg-1',
      'userId': 'user-1',
      'sender': 'HDFCBK',
      'rawText': 'Rs.500 debited at Grocery Mart',
      'status': status,
      'receivedAt': '2026-10-01T10:00:00.000Z',
    };

void main() {
  group('MessageStatus JSON round-trip', () {
    // Backend statuses come from MessageDocument constants:
    // PENDING, IN_PROGRESS, PROCESSED, CONFIRMED, REJECTED, IGNORED, FAILED.
    const statuses = {
      'PENDING': MessageStatus.pending,
      'IN_PROGRESS': MessageStatus.inProgress,
      'PROCESSED': MessageStatus.processed,
      'CONFIRMED': MessageStatus.confirmed,
      'REJECTED': MessageStatus.rejected,
      'IGNORED': MessageStatus.ignored,
      'FAILED': MessageStatus.failed,
    };

    statuses.forEach((wireValue, enumValue) {
      test('parses and re-serializes "$wireValue"', () {
        final message = Message.fromJson(baseJson(status: wireValue));
        expect(message.status, enumValue);

        final roundTrip =
            Message.fromJson(baseJson(status: message.toJson()['status'] as String));
        expect(roundTrip.status, enumValue);
      });
    });

    test('toJson emits the wire value', () {
      final message = Message.fromJson(baseJson(status: 'PROCESSED'));
      expect(message.toJson()['status'], 'PROCESSED');
    });
  });

  group('Message convenience getters', () {
    Message messageWith({
      MessageStatus status = MessageStatus.pending,
      ParseSource? parseSource,
      Map<String, String>? extractedData,
    }) =>
        Message(
          id: 'msg-1',
          userId: 'u1',
          sender: 'HDFCBK',
          rawText: 'rs',
          status: status,
          parseSource: parseSource,
          extractedData: extractedData,
          receivedAt: DateTime.utc(2026, 10, 1),
        );

    test('isIncomplete only for regex-local matches missing a field', () {
      expect(messageWith(parseSource: ParseSource.regexLocal).isIncomplete,
          isTrue);
      expect(
          messageWith(
            parseSource: ParseSource.regexLocal,
            extractedData: {'amount': '500'},
          ).isIncomplete,
          isTrue);
      expect(
          messageWith(
            parseSource: ParseSource.regexLocal,
            extractedData: {
              'amount': '500',
              'merchant': 'Grocery Mart',
              'timestamp': '01/10/2026',
            },
          ).isIncomplete,
          isFalse);
      expect(messageWith(parseSource: ParseSource.llmServer).isIncomplete,
          isFalse);
    });
  });
}