package com.budgetly.api.service;

import org.springframework.stereotype.Service;
import java.util.*;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

@Service
public class AnchorParserService {

    private static final Pattern TOKEN_PATTERN = Pattern.compile("\\{([^}]+)\\}");

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

        Matcher matcher = TOKEN_PATTERN.matcher(template);
        int lastEnd = 0;
        while (matcher.find()) {
            literals.add(template.substring(lastEnd, matcher.start()));
            tokens.add(matcher.group(1));
            lastEnd = matcher.end();
        }
        literals.add(template.substring(lastEnd));

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
