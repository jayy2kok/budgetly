package com.budgetly.api.llm;

import java.util.List;

public interface LlmProvider {
    /**
     * Analyses a raw SMS message and returns structured financial data.
     *
     * @param sender     SMS sender ID (e.g. "HDFCBK")
     * @param rawText    full raw SMS text
     * @param categories ordered category names the LLM must classify a financial
     *                   message into; the LLM returns "uncategorized" when unsure
     * @return LlmAnalysisResult with isFinancial flag, parsed financial fields,
     *         a category name, and a template string for regex generation
     */
    LlmAnalysisResult analyzeMessage(String sender, String rawText, List<String> categories);
}
