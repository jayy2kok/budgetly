import 'package:flutter_test/flutter_test.dart';

import 'package:budgetly/services/transaction_date_resolver.dart';

void main() {
  const resolver = TransactionDateResolver();
  final receivedAt = DateTime(2026, 11, 20, 9, 15, 42);

  group('TransactionDateResolver', () {
    test('a body date + time wins over the received time', () {
      expect(
        resolver.resolve(receivedAt, '01/10/2026 08:30'),
        DateTime(2026, 10, 1, 8, 30),
      );
      expect(
        resolver.resolve(receivedAt, '01-10-2026 08:30:05'),
        DateTime(2026, 10, 1, 8, 30, 5),
      );
      expect(
        resolver.resolve(receivedAt, '01-10-26 08:30'),
        DateTime(2026, 10, 1, 8, 30),
      );
      expect(
        resolver.resolve(receivedAt, '2026-10-01T08:30:00'),
        DateTime(2026, 10, 1, 8, 30),
      );
    });

    test('an ISO instant with an offset is parsed as-is', () {
      final resolved = resolver.resolve(
        receivedAt,
        '2026-10-01T08:30:00Z',
      ).toUtc();
      expect(resolved, DateTime.utc(2026, 10, 1, 8, 30));
    });

    test('a date-only body takes the received time-of-day', () {
      expect(
        resolver.resolve(receivedAt, '01/10/2026'),
        DateTime(2026, 10, 1, 9, 15, 42),
      );
      expect(
        resolver.resolve(receivedAt, '01-10-2026'),
        DateTime(2026, 10, 1, 9, 15, 42),
      );
      expect(
        resolver.resolve(receivedAt, '2026-10-01'),
        DateTime(2026, 10, 1, 9, 15, 42),
      );
      // Common Indian bank form: dd-MM-yy.
      expect(
        resolver.resolve(receivedAt, '20-11-26'),
        DateTime(2026, 11, 20, 9, 15, 42),
      );
      expect(
        resolver.resolve(receivedAt, '20/11/26'),
        DateTime(2026, 11, 20, 9, 15, 42),
      );
    });

    test('a date-only body without a received time falls back to midnight', () {
      expect(
        resolver.resolve(null, '01/10/2026'),
        DateTime(2026, 10, 1),
      );
    });

    test('a missing body timestamp uses the received instant', () {
      expect(resolver.resolve(receivedAt, null), receivedAt);
      expect(resolver.resolve(receivedAt, ''), receivedAt);
      expect(resolver.resolve(receivedAt, 'not a date'), receivedAt);
    });

    test('an invalid date falls back to the received instant', () {
      expect(resolver.resolve(receivedAt, '31/13/2026'), receivedAt);
      expect(resolver.resolve(receivedAt, '2026-02-30'), receivedAt);
    });

    test('both missing falls back to now', () {
      final before = DateTime.now().subtract(const Duration(seconds: 1));
      final resolved = resolver.resolve(null, null);
      final after = DateTime.now().add(const Duration(seconds: 1));

      expect(resolved.isBefore(before), isFalse);
      expect(resolved.isAfter(after), isFalse);
    });
  });
}