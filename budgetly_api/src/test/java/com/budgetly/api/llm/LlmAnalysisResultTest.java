package com.budgetly.api.llm;

import static org.assertj.core.api.Assertions.assertThat;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;

class LlmAnalysisResultTest {

    private final ObjectMapper objectMapper = new ObjectMapper();

    @Test
    void deserializesCategoryFromJson() throws Exception {
        String json = """
                {
                  "financial": true,
                  "amount": 500.0,
                  "merchant": "Grocery Mart",
                  "transactionType": "EXPENSE",
                  "rawTimestamp": "01/10/2026 10:30",
                  "currency": "INR",
                  "category": "Groceries",
                  "notes": "Upi credit",
                  "template": "Spent Rs {amount} at {merchant} on {timestamp}",
                  "extractionMap": {"amount": "amount", "merchant": "merchant", "timestamp": "timestamp"}
                }
                """;

        LlmAnalysisResult result = objectMapper.readValue(json, LlmAnalysisResult.class);

        assertThat(result.getCategory()).isEqualTo("Groceries");
        assertThat(result.isFinancial()).isTrue();
        assertThat(result.getAmount()).isEqualTo(500.0);
    }

    @Test
    void deserializesMissingCategoryAsNull() throws Exception {
        String json = """
                {"financial": false}
                """;

        LlmAnalysisResult result = objectMapper.readValue(json, LlmAnalysisResult.class);

        assertThat(result.getCategory()).isNull();
    }

    @Test
    void serializesCategoryRoundTrip() throws Exception {
        LlmAnalysisResult result = LlmAnalysisResult.builder()
                .financial(true)
                .amount(120.0)
                .merchant("Uber")
                .transactionType("EXPENSE")
                .category("Transport")
                .build();

        String json = objectMapper.writeValueAsString(result);
        LlmAnalysisResult back = objectMapper.readValue(json, LlmAnalysisResult.class);

        assertThat(back.getCategory()).isEqualTo("Transport");
        assertThat(back.getAmount()).isEqualTo(120.0);
    }
}