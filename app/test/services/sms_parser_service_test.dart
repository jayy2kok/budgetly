import 'package:flutter_test/flutter_test.dart';

import 'package:budgetly/models/sms_pattern.dart';
import 'package:budgetly/services/sms_parser_service.dart';

/// Builds a pattern whose extraction map maps the *same-named* tokens
/// (amount -> 'amount', merchant -> 'merchant', ...). Used to exercise the
/// anchor parser itself, independent of mapping logic.
SmsPattern pattern(
  String sender,
  String template, {
  String id = 'p-1',
  ExtractionMap? map,
  Map<String, String> fixedValues = const {},
  PatternScope scope = PatternScope.global,
  DateTime? updatedAt,
}) => SmsPattern(
  id: id,
  sender: sender,
  template: template,
  extractionMap:
      map ??
      const ExtractionMap(
        amount: 'amount',
        merchant: 'merchant',
        timestamp: 'timestamp',
        accountLast4: 'accountLast4',
        notes: 'notes',
      ),
  fixedValues: fixedValues,
  sampleMessage: '',
  scope: scope,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: updatedAt,
);

void main() {
  group('SmsParserService anchor-template corpus', () {
    // This corpus is mirrored in budgetly_api/.../phase1/AnchorParserTest.java
    // so Dart and Java are asserted against identical inputs/outputs.
    const hdfc = 'HDFCBK';

    /// [template, sms, expected extracted map (identity keys) or null]
    const corpus = <(String, String, Map<String, String>?)>[
      // K1 — basic three-token template
      (
        'Spent Rs {amount} at {merchant} on {timestamp}',
        'Spent Rs 500.50 at Grocery Mart on 01/10/2026',
        {
          'amount': '500.50',
          'merchant': 'Grocery Mart',
          'timestamp': '01/10/2026',
        },
      ),
      // K2 — regex meta-chars in literals ('.' in "Rs.", '/' in "a/c")
      (
        'Rs.{amount} debited from a/c {accountLast4} for {merchant}',
        'Rs.1200 debited from a/c 4321 for Swiggy',
        {'amount': '1200', 'accountLast4': '4321', 'merchant': 'Swiggy'},
      ),
      // K3 — single token in the middle
      (
        'Your {merchant} payment is successful',
        'Your ZedPay payment is successful',
        {'merchant': 'ZedPay'},
      ),
      // K4 — first token has no left anchor
      (
        '{amount} debited from {accountLast4}',
        '750 debited from 2314',
        {'amount': '750', 'accountLast4': '2314'},
      ),
      // K5 — multi-byte currency symbol literal
      (
        'UPI of ₹{amount} to {merchant}',
        'UPI of ₹250 to Rahul',
        {'amount': '250', 'merchant': 'Rahul'},
      ),
      // K7 — template with comma and multi-char right anchor
      (
        'Hi {merchant}, your bill of {amount} is due on {timestamp}',
        'Hi Amazon, your bill of 899.01 is due on 2026-11-14',
        {'merchant': 'Amazon', 'amount': '899.01', 'timestamp': '2026-11-14'},
      ),
      // K8 — last token at end of template (empty right anchor) captures to end
      (
        'Order {merchant}',
        'Order Groceries Store',
        {'merchant': 'Groceries Store'},
      ),
      // K6 — left anchor mismatch -> no match
      (
        'Spent Rs {amount} at {merchant} on {timestamp}',
        'Spnt Rs 500 at Grocery Mart on 01/10/2026',
        null,
      ),
      // K9 — template without any tokens -> no match
      (
        'This is a constant message without tokens',
        'This is a constant message without tokens',
        null,
      ),
    ];

    for (final (template, sms, expected) in corpus) {
      test('template "$template" -> ${expected ?? 'null'}', () {
        final result = SmsParserService().parseMessage(hdfc, sms, [
          pattern(hdfc, template),
        ]);
        if (expected == null) {
          expect(result, isNull);
        } else {
          expect(result, isNotNull);
          expect(result!.extractedFields, expected);
        }
      });
    }
  });

  group('SmsParserService extractionMap mapping', () {
    test('maps non-identity token names to amount/merchant', () {
      final result = SmsParserService()
          .parseMessage('PAYTM', 'Paid 100 to Taxi', [
            pattern(
              'PAYTM',
              'Paid {x} to {y}',
              map: const ExtractionMap(
                amount: 'x',
                merchant: 'y',
                timestamp: 'ts',
              ),
            ),
          ]);
      expect(result, isNotNull);
      expect(result!.extractedFields, {'amount': '100', 'merchant': 'Taxi'});
    });

    test('only fields present in extractionMap are exposed', () {
      // Template yields {accountLast4} + {merchant}; extractionMap ignores
      // accountLast4, so it must not appear in extractedFields.
      final result = SmsParserService().parseMessage(
        'HDFCBK',
        'Rs.400 debited from a/c 9999 at Big Store',
        [pattern('HDFCBK', 'Rs.{amount} debited from a/c {x} at {merchant}')],
      );
      expect(result, isNotNull);
      final fields = result!.extractedFields;
      expect(fields, containsPair('amount', '400'));
      expect(fields, containsPair('merchant', 'Big Store'));
      expect(fields, isNot(contains('x')));
    });

    test('fixed values win over extracted values', () {
      final result = SmsParserService().parseMessage(
        'HDFCBK',
        'Rs.400 debited at Razorpay',
        [
          pattern(
            'HDFCBK',
            'Rs.{amount} debited at {merchant}',
            fixedValues: const {
              'merchant': 'Pan Shop',
              'bankName': 'HDFC Bank',
              'notes': 'Monthly',
            },
          ),
        ],
      );

      expect(result, isNotNull);
      expect(result!.extractedFields, containsPair('merchant', 'Pan Shop'));
      expect(result.extractedFields, containsPair('bankName', 'HDFC Bank'));
      expect(result.extractedFields, containsPair('notes', 'Monthly'));
      expect(result.extractedFields, containsPair('amount', '400'));
    });

    test('notes tagged in the template are exposed', () {
      final result = SmsParserService().parseMessage(
        'HDFCBK',
        'Rs.400 debited at Big Store. Rent payment',
        [pattern('HDFCBK', 'Rs.{amount} debited at {merchant}. {notes}')],
      );

      expect(result, isNotNull);
      expect(result!.extractedFields, containsPair('notes', 'Rent payment'));
    });
  });

  group('SmsParserService sender filtering', () {
    test('ignores patterns from other senders', () {
      final result = SmsParserService().parseMessage(
        'SBIUPI',
        'Spent Rs 500 at Grocery Mart on 01/10/2026',
        [pattern('HDFCBK', 'Spent Rs {amount} at {merchant} on {timestamp}')],
      );
      expect(result, isNull);
    });

    test('sender matching is case-insensitive', () {
      final result = SmsParserService().parseMessage(
        'hdfcbk',
        'Spent Rs 500 at Grocery Mart on 01/10/2026',
        [pattern('HDFCBK', 'Spent Rs {amount} at {merchant} on {timestamp}')],
      );
      expect(result, isNotNull);
    });
  });

  group('SmsParserService multiple patterns', () {
    test('returns the first pattern that matches', () {
      final first = pattern(
        'HDFCBK',
        'Spent Rs {amount} at {merchant} on {timestamp}',
        id: 'p-first',
      );
      final second = pattern(
        'HDFCBK',
        'Rs.{amount} debited from a/c {accountLast4} for {merchant}',
        id: 'p-second',
      );
      final result = SmsParserService().parseMessage(
        'HDFCBK',
        'Spent Rs 500 at Grocery Mart on 01/10/2026',
        [first, second],
      );
      expect(result, isNotNull);
      expect(result!.matchedPatternId, 'p-first');
    });

    test('family-scoped pattern wins over a newer global one', () {
      // Mirrors the backend precedence: family scoped patterns are tried
      // before global ones, even when the global one is newer.
      final global = pattern(
        'HDFCBK',
        'Rs.{amount} debited from A/C XX1234 at {merchant} on {timestamp}',
        id: 'p-global',
        updatedAt: DateTime.utc(2026, 3, 1),
      );
      final family = pattern(
        'HDFCBK',
        'Rs.{amount} debited from A/C XX1234 at {merchant} on {timestamp}',
        id: 'p-family',
        scope: PatternScope.family,
        fixedValues: const {'merchant': 'Pan Shop'},
        updatedAt: DateTime.utc(2026, 1, 1),
      );

      final result = SmsParserService().parseMessage(
        'HDFCBK',
        'Rs.350 debited from A/C XX1234 at Croma on 20-11-26',
        [global, family],
      );

      expect(result, isNotNull);
      expect(result!.matchedPatternId, 'p-family');
      expect(result.extractedFields, containsPair('merchant', 'Pan Shop'));
    });

    test('within a scope, the most recently updated pattern wins', () {
      final older = pattern(
        'HDFCBK',
        'Rs.{amount} debited at {merchant}',
        id: 'p-older',
        scope: PatternScope.family,
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      final newer = pattern(
        'HDFCBK',
        'Rs.{amount} debited at {merchant}',
        id: 'p-newer',
        scope: PatternScope.family,
        updatedAt: DateTime.utc(2026, 2, 1),
      );

      final result = SmsParserService().parseMessage(
        'HDFCBK',
        'Rs.350 debited at Croma',
        [older, newer],
      );

      expect(result!.matchedPatternId, 'p-newer');
    });

    test('legacy pattern without updatedAt sorts after timestamped ones', () {
      final legacy = pattern(
        'HDFCBK',
        'Rs.{amount} debited at {merchant}',
        id: 'p-legacy',
      );
      final timestamped = pattern(
        'HDFCBK',
        'Rs.{amount} debited at {merchant}',
        id: 'p-timestamped',
        updatedAt: DateTime.utc(2026, 1, 1),
      );

      final result = SmsParserService().parseMessage(
        'HDFCBK',
        'Rs.350 debited at Croma',
        [legacy, timestamped],
      );

      expect(result!.matchedPatternId, 'p-timestamped');
    });

    test('keeps trying when a pattern does not match', () {
      final first = pattern(
        'HDFCBK',
        'Spent Rs {amount} at {merchant} on {timestamp}',
        id: 'p-first',
      );
      final second = pattern(
        'HDFCBK',
        'Rs.{amount} debited from a/c {accountLast4} for {merchant}',
        id: 'p-second',
      );
      final result = SmsParserService().parseMessage(
        'HDFCBK',
        'Rs.1200 debited from a/c 4321 for Swiggy',
        [first, second],
      );
      expect(result!.matchedPatternId, 'p-second');
    });
  });

  group('SmsParserService edge cases', () {
    test('extracted values are trimmed', () {
      final result = SmsParserService().parseMessage(
        'BANK',
        'Paid   44.5   to   Canteen',
        [pattern('BANK', 'Paid {amount} to {merchant}')],
      );
      expect(result, isNotNull);
      final fields = result!.extractedFields;
      expect(fields['amount'], '44.5');
      expect(fields['merchant'], 'Canteen');
    });

    test('empty patterns list -> null', () {
      expect(SmsParserService().parseMessage('BANK', 'anything', []), isNull);
    });
  });

  group('SmsParserService.dryRunTemplate (pattern builder preview)', () {
    test('amount-only template extracts the amount', () {
      expect(
        SmsParserService().dryRunTemplate(
          'Paid {amount} rupees',
          'Paid 250 rupees',
        ),
        {'amount': '250'},
      );
    });

    test('empty token set -> null (no anchors)', () {
      expect(
        SmsParserService().dryRunTemplate(
          'This message has no tokens',
          'This message has no tokens',
        ),
        isNull,
      );
    });

    test('non-matching literal anchors -> null', () {
      expect(
        SmsParserService().dryRunTemplate(
          'Spent Rs {amount} at {merchant}',
          'Received Rs 500 from Rahul',
        ),
        isNull,
      );
    });

    test('overlapping/adjacent tokens with no literal gap', () {
      // The anchor parser allows consecutive tokens; each captures the run of
      // text between anchors. With no right anchor the last token takes the
      // remainder, so this must not throw.
      final extracted = SmsParserService().dryRunTemplate(
        '{amount} {merchant}',
        '500 Swiggy',
      );
      expect(extracted, isNotNull);
      expect(extracted!['amount'], isNotNull);
      expect(extracted['merchant'], isNotNull);
    });
  });
}
