package com.budgetly.api.llm;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.Map;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class LlmAnalysisResult {
    private boolean financial;
    private String merchant;
    private Double amount;
    private String transactionType;  // EXPENSE | INCOME
    private String rawTimestamp;
    private String currency;         // ISO-4217 code, e.g. INR, USD (defaults to INR when absent)
    private String category;         // chosen category name, or "uncategorized" when financial but undetermined; null when not financial

    /** OTP | PROMO | PERSONAL | DELIVERY | UNKNOWN — set only when financial is false. */
    private String nonFinancialCategory;

    private String notes;

    private Map<String, String> extractionMap;  // group → field

    // Token-based template
    private String template;
}

