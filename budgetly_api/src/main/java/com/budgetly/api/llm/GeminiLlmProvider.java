package com.budgetly.api.llm;

import java.util.List;
import java.util.Map;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestTemplate;

import com.fasterxml.jackson.databind.ObjectMapper;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

@Slf4j
@Component
@RequiredArgsConstructor
@ConditionalOnProperty(name = "llm.provider", havingValue = "gemini")
public class GeminiLlmProvider implements LlmProvider {

    @Value("${gemini.api-key}")
    private String apiKey;

    @Value("${gemini.api-url}")
    private String apiUrl;

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
               - template: string (the SMS text with {} token placeholders, null if not financial)
               - extractionMap: object mapping token name to target field {"amount": "amount", "merchant": "merchant", "timestamp": "timestamp"}
            
            SMS text: "%s"
            
            Return ONLY the JSON, no markdown, no explanation.
            """;

    @Override
    public LlmAnalysisResult analyzeMessage(String sender, String rawText) {
        String prompt = String.format(SYSTEM_PROMPT, sender, rawText.replace("\"", "'"));

        Map<String, Object> requestBody = Map.of(
                "contents", List.of(
                        Map.of("parts", List.of(Map.of("text", prompt)))
                )
        );

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);

        HttpEntity<Map<String, Object>> entity = new HttpEntity<>(requestBody, headers);


        String url = apiUrl + "?key=" + apiKey;
        try {
            ResponseEntity<Map> response = restTemplate.postForEntity(url, entity, Map.class);
            if (response.getStatusCode().is2xxSuccessful() && response.getBody() != null) {
                String jsonText = extractTextFromResponse(response.getBody());
                return objectMapper.readValue(jsonText, LlmAnalysisResult.class);
            }
        } catch (Exception e) {
            log.error("Gemini API call failed for sender={}: {}", sender, e.getMessage(), e);
        }

        // Fallback: non-financial result
        return LlmAnalysisResult.builder()
                .financial(false)
                .notes("LLM analysis failed — defaulting to non-financial")
                .build();
    }

    @SuppressWarnings("unchecked")
    private String extractTextFromResponse(Map<String, Object> responseBody) {
        // Gemini response structure: candidates[0].content.parts[0].text
        List<Map<String, Object>> candidates = (List<Map<String, Object>>) responseBody.get("candidates");
        Map<String, Object> content = (Map<String, Object>) candidates.get(0).get("content");
        List<Map<String, Object>> parts = (List<Map<String, Object>>) content.get("parts");
        String text = (String) parts.get(0).get("text");

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
