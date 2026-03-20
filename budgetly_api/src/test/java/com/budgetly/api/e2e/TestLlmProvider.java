package com.budgetly.api.e2e;

import com.budgetly.api.llm.LlmAnalysisResult;
import com.budgetly.api.llm.LlmProvider;

/**
 * A test-only LlmProvider that returns a configurable result.
 * Avoids Mockito entirely — works on any Java version including 25+.
 */
public class TestLlmProvider implements LlmProvider {

    private LlmAnalysisResult nextResult = LlmAnalysisResult.builder()
            .financial(false)
            .build();

    /**
     * Configure what the next analyzeMessage() call should return.
     * Call this from your test before making the API request.
     */
    public void setNextResult(LlmAnalysisResult result) {
        this.nextResult = result;
    }

    /** Reset to default non-financial result. */
    public void resetResult() {
        this.nextResult = LlmAnalysisResult.builder()
                .financial(false)
                .build();
    }

    @Override
    public LlmAnalysisResult analyzeMessage(String sender, String rawText) {
        return nextResult;
    }
}
