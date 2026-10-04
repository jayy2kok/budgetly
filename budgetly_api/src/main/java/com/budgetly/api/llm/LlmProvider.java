package com.budgetly.api.llm;

public interface LlmProvider {
    /**
     * Analyses a raw SMS message and returns structured financial data.
     *
     * @param sender  SMS sender ID (e.g. "HDFCBK")
     * @param rawText Full raw SMS text
     * @return LlmAnalysisResult with isFinancial flag, parsed financial fields, and a template string for regex generation
     */
    LlmAnalysisResult analyzeMessage(String sender, String rawText);
}
