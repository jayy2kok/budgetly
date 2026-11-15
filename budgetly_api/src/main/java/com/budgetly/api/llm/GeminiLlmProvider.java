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

    private final SmsAnalyzerPrompt smsAnalyzerPrompt;

    @Override
    public LlmAnalysisResult analyzeMessage(String sender, String rawText, List<String> categories) {
        String prompt = smsAnalyzerPrompt.format(sender, rawText, categories);

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
