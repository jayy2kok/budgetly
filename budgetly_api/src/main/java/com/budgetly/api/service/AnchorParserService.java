package com.budgetly.api.service;

import org.springframework.stereotype.Service;
import java.util.*;

/**
 * Splits a template into literal anchors and {@code {token}} placeholders with
 * a single linear scan. A regex like {@code \{([^}]+)\}} would behave
 * identically but is quadratic on crafted inputs (many {@code {{...}}), so it
 * is deliberately avoided here: the template is user-controlled and arrives on
 * the SMS parsing hot path (ReDoS — CodeQL {@code java/polynomial-redos}).
 */
@Service
public class AnchorParserService {

    /**
     * Parses an SMS text using literal anchor matching based on the template.
     * Returns a map of token name -> extracted value, or null if matching fails.
     */
    public Map<String, String> parse(String template, String smsText) {
        if (template == null || smsText == null) {
            return null;
        }

        List<String> literals = new ArrayList<>();
        List<String> tokens = new ArrayList<>();

        // Equivalent of \{( [^}]+ )\}: the first '{' opens a token, which runs to
        // the next '}' and must contain at least one character. Unmatched or
        // empty braces stay literal, and '{' may appear inside a token — all
        // matching the regex semantics the Dart parser mirrors.
        int lastEnd = 0;
        for (int i = 0; i < template.length();) {
            char c = template.charAt(i);
            if (c != '{') {
                i++;
                continue;
            }
            int close = template.indexOf('}', i + 1);
            if (close == -1) {
                break; // no closing brace — the rest of the template is literal
            }
            if (close == i + 1) {
                i++; // empty '{}' is not a token (parity with [^}]+)
                continue;
            }
            literals.add(template.substring(lastEnd, i));
            tokens.add(template.substring(i + 1, close));
            lastEnd = close + 1;
            i = close + 1;
        }
        literals.add(template.substring(lastEnd));

        // A template without {tokens} cannot extract anything — treat as a
        // non-match (parity with Dart SmsParserService._parseAnchorTemplate).
        if (tokens.isEmpty()) {
            return null;
        }

        Map<String, String> results = new LinkedHashMap<>();
        int currentIndex = 0;

        for (int i = 0; i < tokens.size(); i++) {
            String leftLiteral = literals.get(i);
            String rightLiteral = literals.get(i + 1);
            String tokenName = tokens.get(i);

            int leftIndex = smsText.indexOf(leftLiteral, currentIndex);
            if (leftIndex == -1) {
                return null; // Left anchor mismatch
            }
            int valueStart = leftIndex + leftLiteral.length();

            int valueEnd;
            if (rightLiteral.isEmpty()) {
                valueEnd = smsText.length();
            } else {
                valueEnd = smsText.indexOf(rightLiteral, valueStart);
                if (valueEnd == -1) {
                    return null; // Right anchor mismatch
                }
            }

            String extractedValue = smsText.substring(valueStart, valueEnd).trim();
            results.put(tokenName, extractedValue);
            currentIndex = valueEnd;
        }

        return results;
    }
}
