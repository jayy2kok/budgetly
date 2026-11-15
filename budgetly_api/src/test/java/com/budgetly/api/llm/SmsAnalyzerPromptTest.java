package com.budgetly.api.llm;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;

import org.junit.jupiter.api.Test;

class SmsAnalyzerPromptTest {

    private static final List<String> CATEGORIES = List.of(
            "Groceries", "Dining", "Transport", "Shopping", "Utilities",
            "Health", "Entertainment", "Travel", "Rent", "Fuel",
            "Salary", "Investment", "Other");

    private final SmsAnalyzerPrompt prompt = new SmsAnalyzerPrompt();

    @Test
    void loadPromptFromClasspathResource() {
        assertThat(prompt).isNotNull();
    }

    @Test
    void formatInsertsSenderAndRawText() {
        String rendered = prompt.format("HDFCBK", "Rs.500 debited from a/c XX1234 for AMAZON on 05-Nov", CATEGORIES);

        assertThat(rendered)
                .contains("bank sender \"HDFCBK\"")
                .contains("Raw SMS:")
                .contains("\"Rs.500 debited from a/c XX1234 for AMAZON on 05-Nov\"")
                .contains("Return ONLY the JSON, no markdown, no explanation.");
    }

    @Test
    void formatRendersCategoryListAndUncategorizedInstruction() {
        String rendered = prompt.format("HDFCBK", "Spent Rs 500 at cafe", List.of("Groceries", "Dining"));

        assertThat(rendered)
                .contains("Categories: Groceries, Dining")
                .contains("return \"uncategorized\"")
                .contains("- category: string");
    }

    @Test
    void formatFallsBackToUncategorizedWhenCategoryListEmpty() {
        String rendered = prompt.format("HDFCBK", "Spent Rs 500 at cafe", List.of());

        assertThat(rendered).contains("Categories: uncategorized");
    }

    @Test
    void formatReplacesDoubleQuotesInRawText() {
        String rendered = prompt.format("SBI", "Spent \"500\" at cafe", CATEGORIES);

        assertThat(rendered)
                .contains("\"Spent '500' at cafe\"")
                .doesNotContain("Spent \"500\" at cafe");
    }

    @Test
    void formatSurvivesPercentSignInCategoryName() {
        // User-defined category names containing '%' must not break String.format
        // (the category list is rendered as a format argument, not re-parsed).
        String rendered = prompt.format("HDFCBK", "Rs.100 debited", List.of("Food & 100%", "Rent"));

        assertThat(rendered).contains("Categories: Food & 100%, Rent");
    }
}