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

    private final SmsAnalyzerPrompt smsAnalyzerPrompt;

    @Override
    public LlmAnalysisResult analyzeMessage(String sender, String rawText, List<String> categories) {
        String prompt = smsAnalyzerPrompt.format(sender, rawText, categories);

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
