import 'package:flutter_test/flutter_test.dart';

import 'package:budgetly/services/pattern_draft_builder.dart';
import 'package:budgetly/services/sms_parser_service.dart';

void main() {
  group('PatternDraftBuilder.fromSpans', () {
    test('interleaves literals and tokens in tagged order', () {
      const raw = 'Spent Rs 500.50 at Grocery Mart on 01/10/2026';
      final draft = PatternDraftBuilder.fromSpans(raw, const [
        TaggedSpan(field: PatternField.amount, start: 9, end: 15),
        TaggedSpan(field: PatternField.merchant, start: 19, end: 31),
        TaggedSpan(field: PatternField.timestamp, start: 35, end: 45),
      ]);

      expect(draft.template, 'Spent Rs {amount} at {merchant} on {timestamp}');
      expect(draft.isManual, isFalse);
      expect(draft.hasAmountToken, isTrue);
    });

    test('extractionMap maps each tagged field to itself', () {
      const raw = 'Paid 100 to Taxi';
      final draft = PatternDraftBuilder.fromSpans(raw, const [
        TaggedSpan(field: PatternField.amount, start: 5, end: 8),
        TaggedSpan(field: PatternField.merchant, start: 12, end: 16),
      ]);

      expect(draft.extractionMap.amount, 'amount');
      expect(draft.extractionMap.merchant, 'merchant');
      expect(draft.extractionMap.timestamp, isNull);
      expect(draft.extractionMap.accountLast4, isNull);
      expect(draft.extractionMap.type, isNull);
    });

    test('account and notes spans are carried into the extraction map', () {
      const raw = 'Rs.500 debited from a/c 1234. Rent payment';
      final draft = PatternDraftBuilder.fromSpans(raw, const [
        TaggedSpan(field: PatternField.amount, start: 3, end: 6),
        TaggedSpan(field: PatternField.accountLast4, start: 24, end: 28),
        TaggedSpan(field: PatternField.notes, start: 30, end: 42),
      ]);

      expect(
        draft.template,
        'Rs.{amount} debited from a/c {accountLast4}. {notes}',
      );
      expect(draft.extractionMap.accountLast4, 'accountLast4');
      expect(draft.extractionMap.notes, 'notes');
    });

    test('sorts spans by position regardless of tag order', () {
      const raw = 'Rs.1200 debited at Swiggy';
      final draft = PatternDraftBuilder.fromSpans(raw, const [
        TaggedSpan(field: PatternField.merchant, start: 19, end: 25),
        TaggedSpan(field: PatternField.amount, start: 3, end: 7),
      ]);

      expect(draft.template, 'Rs.{amount} debited at {merchant}');
    });

    test('amount-only tagging has no merchant timestamp', () {
      const raw = 'Paid 250 rupees';
      final draft = PatternDraftBuilder.fromSpans(raw, const [
        TaggedSpan(field: PatternField.amount, start: 5, end: 8),
      ]);

      expect(draft.hasAmountToken, isTrue);
      expect(draft.extractionMap.merchant, isNull);
      expect(draft.template, 'Paid {amount} rupees');
    });

    test('no spans yields the raw text and no amount', () {
      const raw = 'Your OTP is 123456';
      final draft = PatternDraftBuilder.fromSpans(raw, const []);

      expect(draft.template, raw);
      expect(draft.hasAmountToken, isFalse);
    });
  });

  group('PatternDraftBuilder.hasOverlap', () {
    const spans = [TaggedSpan(field: PatternField.amount, start: 5, end: 10)];

    test('detects partial overlap', () {
      expect(PatternDraftBuilder.hasOverlap(spans, 8, 12), isTrue);
      expect(PatternDraftBuilder.hasOverlap(spans, 0, 6), isTrue);
    });

    test('allows adjacent but non-overlapping ranges', () {
      expect(PatternDraftBuilder.hasOverlap(spans, 10, 14), isFalse);
      expect(PatternDraftBuilder.hasOverlap(spans, 0, 5), isFalse);
    });

    test('no spans never overlaps', () {
      expect(PatternDraftBuilder.hasOverlap(const [], 0, 10), isFalse);
    });
  });

  group('PatternDraftBuilder.fromManualTemplate', () {
    test('extracts token names and requires amount', () {
      final draft = PatternDraftBuilder.fromManualTemplate(
        'Rs.{amount} paid at {merchant}',
      );

      expect(draft.isManual, isTrue);
      expect(draft.hasAmountToken, isTrue);
      expect(draft.extractionMap.amount, 'amount');
      expect(draft.extractionMap.merchant, 'merchant');
    });

    test('template without {amount} is flagged', () {
      final draft = PatternDraftBuilder.fromManualTemplate(
        'Paid {merchant} today',
      );

      expect(draft.hasAmountToken, isFalse);
      expect(draft.extractionMap.amount, 'amount');
      expect(draft.extractionMap.merchant, 'merchant');
    });

    test('plain text with no tokens keeps amount required in map', () {
      final draft = PatternDraftBuilder.fromManualTemplate('constant text');

      expect(draft.hasAmountToken, isFalse);
    });
  });

  group('draft templates round-trip through the anchor parser', () {
    test('amount-only draft extracts exactly the amount', () {
      const raw = 'Paid 250 rupees';
      final draft = PatternDraftBuilder.fromSpans(raw, const [
        TaggedSpan(field: PatternField.amount, start: 5, end: 8),
      ]);

      final extracted = SmsParserService().dryRunTemplate(draft.template, raw);

      expect(extracted, isNotNull);
      expect(extracted!['amount'], '250');
    });

    test('multi-field draft extracts every tagged field', () {
      const raw = 'Spent Rs 500.50 at Grocery Mart on 01/10/2026';
      final draft = PatternDraftBuilder.fromSpans(raw, const [
        TaggedSpan(field: PatternField.amount, start: 9, end: 15),
        TaggedSpan(field: PatternField.merchant, start: 19, end: 31),
        TaggedSpan(field: PatternField.timestamp, start: 35, end: 45),
      ]);

      final extracted = SmsParserService().dryRunTemplate(draft.template, raw);

      expect(extracted, {
        'amount': '500.50',
        'merchant': 'Grocery Mart',
        'timestamp': '01/10/2026',
      });
    });
  });
}
