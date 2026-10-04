package com.budgetly.api.llm;

import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.http.*;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestTemplate;

import java.util.List;
import java.util.Map;

/**
 * OpenAI-compatible LLM provider.
 * Supports OpenAI, OmniRoute, LocalAI, Ollama, vLLM, and any /v1/chat/completions endpoint.
 */
@Slf4j
@Component
@RequiredArgsConstructor
@ConditionalOnProperty(name = "llm.provider", havingValue = "openai", matchIfMissing = true)
public class OpenAiCompatibleLlmProvider implements LlmProvider {

    @Value("${openai.base-url:http://rpi.local:20129/v1}")
    private String baseUrl;

    @Value("${openai.api-key:placeholder-key}")
    private String apiKey;

    @Value("${openai.model:auto/best-free}")
    private String model;

    private final ObjectMapper objectMapper;
    private final RestTemplate restTemplate = new RestTemplate();

    private static final String SYSTEM_PROMPT = """
            You are a financial SMS parser for Indian bank messages. Given an SMS from bank sender "%s":
            
            1. Determine if this SMS is a FINANCIAL transaction (debit/credit bank transaction).
            2. If financial, extract: amount (number only), merchant/payee name, transaction type (EXPENSE for debit, INCOME for credit), raw timestamp string.
            3. Create a template string from the raw SMS by replacing variable parts with token placeholders in curly braces:
               - Rules:
                 * Use tokens: {amount}, {merchant}, {timestamp}, and optionally {accountLast4}.
                 * Only use the tokens listed in extractionMap.
                 * Do NOT include any regex syntax (e.g. .*, \\d) – output plain text with {} placeholders.
            4. Return ONLY a valid JSON object with these fields:
               - financial: boolean
               - amount: number (null if not financial)
               - merchant: string (null if not financial)
               - transactionType: "EXPENSE" or "INCOME" (null if not financial)
               - rawTimestamp: string (null if not financial)
               - notes: string (brief explanation)
               - template: string (e.g. "Rs.{amount} debited from a/c {accountLast4} for {merchant} on {timestamp}")
               - extractionMap: object mapping token names to fields {"amount": "amount", "merchant": "merchant", "timestamp": "timestamp"}
            
            Raw SMS:
            "%s"
            
            Return ONLY the JSON, no markdown, no explanation.
            """;

    @Override
    public LlmAnalysisResult analyzeMessage(String sender, String rawText) {
        String prompt = String.format(SYSTEM_PROMPT, sender, rawText.replace("\"", "'"));

        String endpoint = baseUrl.replaceAll("/+$", "") + "/chat/completions";

        Map<String, Object> requestBody = Map.of(
                "model", model,
                "messages", List.of(
                        Map.of("role", "user", "content", prompt)
                ),
                "temperature", 0.1
        );

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        if (apiKey != null && !apiKey.isBlank() && !apiKey.equals("placeholder-key")) {
            headers.setBearerAuth(apiKey);
        } else {
            // Provide a dummy bearer token for servers requiring the header
            headers.setBearerAuth("token");
        }

        HttpEntity<Map<String, Object>> entity = new HttpEntity<>(requestBody, headers);

        try {
            ResponseEntity<Map> response = restTemplate.postForEntity(endpoint, entity, Map.class);
            if (response.getStatusCode().is2xxSuccessful() && response.getBody() != null) {
                String jsonText = extractTextFromResponse(response.getBody());
                return objectMapper.readValue(jsonText, LlmAnalysisResult.class);
            }
        } catch (Exception e) {
            log.error("OpenAI-compatible LLM call failed for sender={}: {}", sender, e.getMessage(), e);
        }

        // Fallback: non-financial result
        return LlmAnalysisResult.builder()
                .financial(false)
                .notes("LLM analysis failed — defaulting to non-financial")
                .build();
    }

    @SuppressWarnings("unchecked")
    private String extractTextFromResponse(Map<String, Object> responseBody) {
        // OpenAI format: choices[0].message.content
        List<Map<String, Object>> choices = (List<Map<String, Object>>) responseBody.get("choices");
        if (choices == null || choices.isEmpty()) {
            throw new IllegalStateException("OpenAI response contains no choices: " + responseBody);
        }
        Map<String, Object> message = (Map<String, Object>) choices.get(0).get("message");
        String text = (String) message.get("content");

        // Strip markdown code fences if present
        text = text.trim();
        if (text.startsWith("```")) {
            int start = text.indexOf('\n') + 1;
            int end = text.lastIndexOf("```");
            if (end > start) text = text.substring(start, end).trim();
        }
        return text;
    }
}
