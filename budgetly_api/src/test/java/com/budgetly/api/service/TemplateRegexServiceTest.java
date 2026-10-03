package com.budgetly.api.service;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import static org.junit.jupiter.api.Assertions.*;

class TemplateRegexServiceTest {

    private TemplateRegexService templateRegexService;

    @BeforeEach
    void setUp() {
        templateRegexService = new TemplateRegexService();
    }

    @Test
    void generateRegex_standardTemplate_generatesNamedCaptureGroups() {
        String template = "Spent Rs {amount} at {merchant} on {timestamp}";
        String regex = templateRegexService.generateRegex(template, Map.of(
                "amount", "amount",
                "merchant", "merchant",
                "timestamp", "timestamp"
        ));

        assertNotNull(regex);
        assertTrue(regex.contains("(?<amount>\\d+(?:\\.\\d+)?)"));
        assertTrue(regex.contains("(?<merchant>.+?)"));
        assertTrue(regex.contains("(?<timestamp>\\d{2}/\\d{2}/\\d{4}|\\d{4}-\\d{2}-\\d{2})"));

        Pattern pattern = Pattern.compile(regex);
        Matcher matcher = pattern.matcher("Spent Rs 450.75 at Star Cafe on 15/04/2026");
        assertTrue(matcher.matches());
        assertEquals("450.75", matcher.group("amount"));
        assertEquals("Star Cafe", matcher.group("merchant"));
        assertEquals("15/04/2026", matcher.group("timestamp"));
    }

    @Test
    void generateRegex_withAccountLast4() {
        String template = "INR {amount} debited from A/C {accountLast4} to {merchant}";
        String regex = templateRegexService.generateRegex(template, null);

        assertNotNull(regex);
        Pattern pattern = Pattern.compile(regex);
        Matcher matcher = pattern.matcher("INR 1200 debited from A/C 9876 to SuperMart");
        assertTrue(matcher.matches());
        assertEquals("1200", matcher.group("amount"));
        assertEquals("9876", matcher.group("accountLast4"));
        assertEquals("SuperMart", matcher.group("merchant"));
    }

    @Test
    void generateRegex_withExtractionMapMappingCustomTokens() {
        String template = "Debited Rs {amt} for {payee}";
        Map<String, String> extractionMap = Map.of(
                "amt", "amount",
                "payee", "merchant"
        );
        String regex = templateRegexService.generateRegex(template, extractionMap);

        assertNotNull(regex);
        Pattern pattern = Pattern.compile(regex);
        Matcher matcher = pattern.matcher("Debited Rs 2500 for Flipkart");
        assertTrue(matcher.matches());
        assertEquals("2500", matcher.group("amt"));
        assertEquals("Flipkart", matcher.group("payee"));
    }

    @Test
    void generateRegex_withRegexMetaCharacters() {
        String template = "Rs. {amount} debited (Ref: 1234) for {merchant}.";
        String regex = templateRegexService.generateRegex(template, Map.of(
                "amount", "amount",
                "merchant", "merchant"
        ));

        assertNotNull(regex);
        Pattern pattern = Pattern.compile(regex);
        Matcher matcher = pattern.matcher("Rs. 500 debited (Ref: 1234) for Amazon.");
        assertTrue(matcher.matches());
        assertEquals("500", matcher.group("amount"));
        assertEquals("Amazon", matcher.group("merchant"));
    }

    @Test
    void generateRegex_emptyTemplate_returnsEmpty() {
        assertEquals("", templateRegexService.generateRegex("", null));
    }

    @Test
    void generateRegex_templateWithoutTokens_returnsEscapedLiteral() {
        String template = "Plain message with [brackets] and (parentheses).";
        String regex = templateRegexService.generateRegex(template, null);
        Pattern pattern = Pattern.compile(regex);
        assertTrue(pattern.matcher("Plain message with [brackets] and (parentheses).").matches());
    }

    @Test
    void generateRegex_nullTemplate_returnsNull() {
        assertNull(templateRegexService.generateRegex(null, null));
    }
}
