package com.budgetly.api.llm;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

class SmsAnalyzerPromptTest {

    private final SmsAnalyzerPrompt prompt = new SmsAnalyzerPrompt();

    @Test
    void loadPromptFromClasspathResource() {
        assertThat(prompt).isNotNull();
    }

    @Test
    void formatInsertsSenderAndRawText() {
        String rendered = prompt.format("HDFCBK", "Rs.500 debited from a/c XX1234 for AMAZON on 05-Nov");

        assertThat(rendered)
                .contains("bank sender \"HDFCBK\"")
                .contains("Raw SMS:")
                .contains("\"Rs.500 debited from a/c XX1234 for AMAZON on 05-Nov\"")
                .contains("Return ONLY the JSON, no markdown, no explanation.");
    }

    @Test
    void formatReplacesDoubleQuotesInRawText() {
        String rendered = prompt.format("SBI", "Spent \"500\" at cafe");

        assertThat(rendered)
                .contains("\"Spent '500' at cafe\"")
                .doesNotContain("Spent \"500\" at cafe");
    }
}