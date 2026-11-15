package com.budgetly.api.llm;

import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.stream.Collectors;

import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Component;
import org.springframework.util.StreamUtils;

/**
 * Loads the single, shared SMS-analyzer prompt from the classpath resource
 * {@code SMS_ANALYZER_PROMPT.txt} and renders it with the sender ID and raw SMS
 * text. All {@link LlmProvider} implementations use this same prompt so
 * behaviour stays consistent across providers.
 */
@Component
public class SmsAnalyzerPrompt {

    public static final String RESOURCE_PATH = "SMS_ANALYZER_PROMPT.txt";

    private final String template;

    public SmsAnalyzerPrompt() {
        this.template = loadPrompt();
    }

    /**
     * Renders the shared prompt with the given sender, raw SMS text and the
     * category list the LLM should classify financial messages into.
     *
     * @param sender     SMS sender ID (e.g. "HDFCBK")
     * @param rawText    full raw SMS text
     * @param categories ordered category names the LLM may pick from
     * @return the fully-rendered prompt
     */
    public String format(String sender, String rawText, List<String> categories) {
        String categoryList = categories == null || categories.isEmpty()
                ? "uncategorized"
                : categories.stream()
                        .filter(c -> c != null && !c.isBlank())
                        .collect(Collectors.joining(", "));
        return String.format(template, sender, categoryList, rawText.replace("\"", "'"));
    }

    private static String loadPrompt() {
        try (InputStream in = new ClassPathResource(RESOURCE_PATH).getInputStream()) {
            return StreamUtils.copyToString(in, StandardCharsets.UTF_8);
        } catch (IOException e) {
            throw new IllegalStateException("Failed to load " + RESOURCE_PATH + " from classpath", e);
        }
    }
}