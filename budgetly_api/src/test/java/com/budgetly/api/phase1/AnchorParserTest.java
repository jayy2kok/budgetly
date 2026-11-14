package com.budgetly.api.phase1;

import com.budgetly.api.service.AnchorParserService;
import org.junit.jupiter.api.Test;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Literal anchor parsers must behave identically in Java and Dart.
 *
 * <p>This corpus is mirrored in {@code app/test/services/sms_parser_service_test.dart}
 * (group {@code SmsParserService anchor-template corpus}) — keep both in sync.
 * The Dart side additionally applies the {@code extractionMap}; the Java side
 * exposes the raw token->value map, so parity is at that level.
 */
class AnchorParserTest {

    private final AnchorParserService service = new AnchorParserService();

    @Test
    void corpusMatchesDart() {
        // [template, sms, expected token->value map or null]
        Object[][] corpus = {
            // K1 — basic three-token template
            {
                "Spent Rs {amount} at {merchant} on {timestamp}",
                "Spent Rs 500.50 at Grocery Mart on 01/10/2026",
                Map.of("amount", "500.50", "merchant", "Grocery Mart", "timestamp", "01/10/2026")
            },
            // K2 — regex meta-chars in literals ('.' in "Rs.", '/' in "a/c")
            {
                "Rs.{amount} debited from a/c {accountLast4} for {merchant}",
                "Rs.1200 debited from a/c 4321 for Swiggy",
                Map.of("amount", "1200", "accountLast4", "4321", "merchant", "Swiggy")
            },
            // K3 — single token in the middle
            {
                "Your {merchant} payment is successful",
                "Your ZedPay payment is successful",
                Map.of("merchant", "ZedPay")
            },
            // K4 — first token has no left anchor
            {
                "{amount} debited from {accountLast4}",
                "750 debited from 2314",
                Map.of("amount", "750", "accountLast4", "2314")
            },
            // K5 — multi-byte currency symbol literal
            {
                "UPI of ₹{amount} to {merchant}",
                "UPI of ₹250 to Rahul",
                Map.of("amount", "250", "merchant", "Rahul")
            },
            // K7 — comma and multi-char right anchor
            {
                "Hi {merchant}, your bill of {amount} is due on {timestamp}",
                "Hi Amazon, your bill of 899.01 is due on 2026-11-14",
                Map.of("merchant", "Amazon", "amount", "899.01", "timestamp", "2026-11-14")
            },
            // K8 — last token at end of template (empty right anchor) captures to end
            {
                "Order {merchant}",
                "Order Groceries Store",
                Map.of("merchant", "Groceries Store")
            },
            // K6 — left anchor mismatch -> null
            {
                "Spent Rs {amount} at {merchant} on {timestamp}",
                "Spnt Rs 500 at Grocery Mart on 01/10/2026",
                null
            },
            // K9 — template without tokens -> null (parity with Dart)
            {
                "This is a constant message without tokens",
                "This is a constant message without tokens",
                null
            },
        };

        for (Object[] row : corpus) {
            String template = (String) row[0];
            String sms = (String) row[1];
            @SuppressWarnings("unchecked")
            Map<String, String> expected = (Map<String, String>) row[2];
            assertThat(service.parse(template, sms))
                    .as("template=%s sms=%s", template, sms)
                    .isEqualTo(expected);
        }
    }

    @Test
    void trimWhitespaceAroundTokens() {
        assertThat(service.parse("Paid {amount} to {merchant}", "Paid   44.5   to   Canteen"))
                .isEqualTo(Map.of("amount", "44.5", "merchant", "Canteen"));
    }

    @Test
    void nullInputsReturnNull() {
        assertThat(service.parse(null, "anything")).isNull();
        assertThat(service.parse("Spent {amount}", null)).isNull();
    }

    @Test
    void extractionIsOrderPreservingAndNonGreedy() {
        // The second occurrence of the same right-anchor precedes the value.
        assertThat(service.parse("{merchant} used for {merchant}", "ABC used for DEF"))
                .isEqualTo(Map.of("merchant", "DEF"));
    }
}