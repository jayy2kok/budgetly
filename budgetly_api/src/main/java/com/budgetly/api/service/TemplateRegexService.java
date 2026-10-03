package com.budgetly.api.service;

import org.springframework.stereotype.Service;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

@Service
public class TemplateRegexService {

    private static final Pattern TOKEN_PATTERN = Pattern.compile("\\{([^}]+)\\}");

    /**
     * Turns a tokenised template (e.g. "Spent Rs {amount} at {merchant} on {timestamp}")
     * into a Java-compatible regex with named capture groups.
     */
    public String generateRegex(String template, Map<String, String> extractionMap) {
        if (template == null) {
            return null;
        }

        Matcher m = TOKEN_PATTERN.matcher(template);
        StringBuilder sb = new StringBuilder();
        int lastEnd = 0;
        while (m.find()) {
            String literal = template.substring(lastEnd, m.start());
            sb.append(escapeRegexLiteral(literal));

            String token = m.group(1);
            String targetField = extractionMap != null ? extractionMap.getOrDefault(token, token) : token;
            String groupPattern = defaultPatternFor(targetField);
            sb.append("(?<").append(token).append(">").append(groupPattern).append(")");

            lastEnd = m.end();
        }
        sb.append(escapeRegexLiteral(template.substring(lastEnd)));

        return sb.toString();
    }

    private String escapeRegexLiteral(String literal) {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < literal.length(); i++) {
            char c = literal.charAt(i);
            if ("\\^$.*+?()[]{}|".indexOf(c) != -1) {
                sb.append('\\');
            }
            sb.append(c);
        }
        return sb.toString();
    }

    private String defaultPatternFor(String token) {
        return switch (token) {
            case "amount"    -> "\\d+(?:\\.\\d+)?";
            case "timestamp" -> "\\d{2}/\\d{2}/\\d{4}|\\d{4}-\\d{2}-\\d{2}";
            case "merchant"  -> ".+?";
            case "accountLast4" -> "\\d{4}";
            default           -> ".+?"; 
        };
    }
}
