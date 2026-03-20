package com.budgetly.api.llm;

public interface LlmProvider {
    /**
     * Analyses a raw SMS message and returns structured financial data.
     *
     * @param sender  SMS sender ID (e.g. "HDFCBK")
     * @param rawText Full raw SMS text
     * @return LlmAnalysisResult with isFinancial, parsed fields, and generated regex
     */
    LlmAnalysisResult analyzeMessage(String sender, String rawText);
}
